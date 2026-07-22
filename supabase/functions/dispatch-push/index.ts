import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

type ServiceAccount = {
  project_id: string
  client_email: string
  private_key: string
  token_uri?: string
}

type ClaimedDelivery = {
  delivery_id: string
  outbox_id: string
  device_id: string
  fcm_token: string
  notification_type: "nudge" | "announcement" | "update" | "self_test"
  payload: Record<string, unknown>
  locale: string
  time_zone: string
  quiet_hours_enabled: boolean
  quiet_start_minutes: number
  quiet_end_minutes: number
  attempt: number
}

type DeliveryResult = {
  result: "sent" | "retry" | "failed_permanent" | "skipped"
  providerMessageId?: string
  errorCode?: string
  retryAfterSeconds?: number
  disableDevice?: boolean
}

const jsonHeaders = { "content-type": "application/json; charset=utf-8" }
const oauthScope = "https://www.googleapis.com/auth/firebase.messaging"

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders })
}

function secureEqual(left: string, right: string): boolean {
  if (left.length !== right.length || left.length === 0) return false
  let diff = 0
  for (let index = 0; index < left.length; index++) {
    diff |= left.charCodeAt(index) ^ right.charCodeAt(index)
  }
  return diff === 0
}

function base64Url(bytes: Uint8Array): string {
  let binary = ""
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "")
}

function utf8Base64Url(value: string): string {
  return base64Url(new TextEncoder().encode(value))
}

function pemToBytes(pem: string): Uint8Array {
  const clean = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll(/\s/g, "")
  const binary = atob(clean)
  return Uint8Array.from(binary, (char) => char.charCodeAt(0))
}

async function createAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const tokenUri = account.token_uri || "https://oauth2.googleapis.com/token"
  const header = utf8Base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }))
  const claims = utf8Base64Url(JSON.stringify({
    iss: account.client_email,
    sub: account.client_email,
    aud: tokenUri,
    scope: oauthScope,
    iat: now,
    exp: now + 3600,
  }))
  const unsigned = `${header}.${claims}`
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  )
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  )
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`
  const response = await fetch(tokenUri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  })
  const body = await response.json().catch(() => ({})) as Record<string, unknown>
  const token = typeof body.access_token === "string" ? body.access_token : ""
  if (!response.ok || token.length === 0) {
    throw new Error(`oauth_${response.status}`)
  }
  return token
}

function wallClockMinutes(timeZone: string): number {
  try {
    const parts = new Intl.DateTimeFormat("en-GB", {
      timeZone,
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(new Date())
    const hour = Number(parts.find((part) => part.type === "hour")?.value ?? "0")
    const minute = Number(parts.find((part) => part.type === "minute")?.value ?? "0")
    return hour * 60 + minute
  } catch {
    const now = new Date()
    return now.getUTCHours() * 60 + now.getUTCMinutes()
  }
}

function quietRetrySeconds(delivery: ClaimedDelivery): number | null {
  if (!delivery.quiet_hours_enabled) return null
  const start = delivery.quiet_start_minutes
  const end = delivery.quiet_end_minutes
  if (start === end) return null
  const now = wallClockMinutes(delivery.time_zone)
  const within = start < end
    ? now >= start && now < end
    : now >= start || now < end
  if (!within) return null
  const minutes = (end - now + 1440) % 1440 || 1440
  // DB RPC tek retry'ı bir saatle sınırlar; uzun sessiz aralıkta worker saatlik
  // kontrol eder. Böylece timezone değişikliği de eski bir güne kilitlenmez.
  return Math.min(3600, Math.max(60, minutes * 60))
}

function localizedContent(delivery: ClaimedDelivery): { title: string; body: string } {
  const language = delivery.locale.toLowerCase().split(/[-_]/)[0]
  const payload = delivery.payload
  const sender = String(payload.sender_display_name ?? "").trim()
  const message = String(payload.message ?? "").trim()

  if (delivery.notification_type === "self_test") {
    if (language === "tr") return { title: "Odak Kampı", body: "Uzak bildirim testi başarıyla ulaştı." }
    if (language === "de") return { title: "Fokuscamp", body: "Der Remote-Benachrichtigungstest ist angekommen." }
    if (language === "ar") return { title: "مخيم التركيز", body: "وصل اختبار الإشعار البعيد بنجاح." }
    return { title: "Focus Camp", body: "The remote notification test arrived successfully." }
  }

  if (delivery.notification_type === "nudge") {
    if (language === "tr") {
      return {
        title: sender ? `${sender} seni dürttü 👋` : "Bir arkadaşın seni dürttü 👋",
        body: message || "Seni çalışmaya çağırıyor.",
      }
    }
    if (language === "de") {
      return {
        title: sender ? `${sender} hat dich angestupst 👋` : "Jemand hat dich angestupst 👋",
        body: message || "Zeit für eine Fokus-Session.",
      }
    }
    if (language === "ar") {
      return {
        title: sender ? `${sender} أرسل لك تنبيهًا 👋` : "أرسل لك صديق تنبيهًا 👋",
        body: message || "حان وقت التركيز.",
      }
    }
    return {
      title: sender ? `${sender} nudged you 👋` : "A friend nudged you 👋",
      body: message || "Time for a focus session.",
    }
  }

  const title = String(payload.title ?? "").trim()
  const body = String(payload.body ?? "").trim()
  return {
    title: title || (language === "tr" ? "Odak Kampı" : "Focus Camp"),
    body: body || (language === "tr" ? "Yeni bir bildirimin var." : "You have a new notification."),
  }
}

function stringData(delivery: ClaimedDelivery): Record<string, string> {
  const output: Record<string, string> = {
    schema_version: String(delivery.payload.schema_version ?? "1"),
    notification_type: delivery.notification_type,
    outbox_id: delivery.outbox_id,
  }
  for (const [key, value] of Object.entries(delivery.payload)) {
    if (value === null || value === undefined) continue
    output[key] = typeof value === "string" ? value : JSON.stringify(value)
  }
  return output
}

function providerErrorCode(body: Record<string, unknown>): string {
  const error = body.error
  if (!error || typeof error !== "object") return "provider_error"
  const record = error as Record<string, unknown>
  const details = Array.isArray(record.details) ? record.details : []
  for (const detail of details) {
    if (!detail || typeof detail !== "object") continue
    const code = (detail as Record<string, unknown>).errorCode
    if (typeof code === "string" && code.length > 0) return code.toLowerCase()
  }
  return String(record.status ?? "provider_error").toLowerCase()
}

async function sendToFcm(
  delivery: ClaimedDelivery,
  projectId: string,
  accessToken: string,
): Promise<DeliveryResult> {
  const quietSeconds = quietRetrySeconds(delivery)
  if (quietSeconds !== null && delivery.notification_type !== "self_test") {
    return { result: "retry", errorCode: "quiet_hours", retryAfterSeconds: quietSeconds }
  }

  const content = localizedContent(delivery)
  const channelId = delivery.notification_type === "nudge"
    ? "social_nudges"
    : delivery.notification_type === "self_test"
    ? "push_system_test"
    : delivery.notification_type === "update"
    ? "app_updates"
    : "announcements"
  const eventId = String(delivery.payload.event_id ?? delivery.outbox_id)
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: delivery.fcm_token,
          notification: content,
          data: stringData(delivery),
          android: {
            priority: "HIGH",
            ttl: delivery.notification_type === "self_test" ? "60s" : "3600s",
            notification: {
              channel_id: channelId,
              tag: `${delivery.notification_type}:${eventId}`,
              visibility: "PUBLIC",
              notification_priority: "PRIORITY_HIGH",
              default_sound: true,
            },
          },
        },
      }),
    },
  )
  const body = await response.json().catch(() => ({})) as Record<string, unknown>
  if (response.ok) {
    return {
      result: "sent",
      providerMessageId: typeof body.name === "string" ? body.name : undefined,
    }
  }

  const code = providerErrorCode(body)
  if (code === "unregistered" || code === "registration-token-not-registered") {
    return { result: "failed_permanent", errorCode: "unregistered", disableDevice: true }
  }
  if (response.status === 429 || response.status >= 500 ||
      ["unavailable", "internal", "quota_exceeded"].includes(code)) {
    const retry = Math.min(3600, 30 * (2 ** Math.min(6, Math.max(0, delivery.attempt - 1))))
    return { result: "retry", errorCode: code, retryAfterSeconds: retry }
  }
  return { result: "failed_permanent", errorCode: code }
}

serve(async (request) => {
  if (request.method !== "POST") return json(405, { error: "method_not_allowed" })

  const expectedSecret = Deno.env.get("PUSH_DISPATCH_SECRET") ?? ""
  const suppliedSecret = request.headers.get("x-push-dispatch-secret") ?? ""
  if (!secureEqual(suppliedSecret, expectedSecret)) {
    return json(401, { error: "unauthorized" })
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  const rawAccount = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? ""
  if (!supabaseUrl || !serviceRoleKey || !rawAccount) {
    return json(503, { error: "push_not_configured" })
  }

  let account: ServiceAccount
  try {
    account = JSON.parse(rawAccount) as ServiceAccount
    if (!account.project_id || !account.client_email || !account.private_key) throw new Error()
  } catch {
    return json(503, { error: "invalid_service_account" })
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const requestBody = await request.json().catch(() => ({})) as Record<string, unknown>
  let enqueued = 0
  if (requestBody.action === "enqueue_update") {
    const channel = String(requestBody.channel ?? "")
    const versionName = String(requestBody.version_name ?? "")
    const buildNumber = Number(requestBody.build_number ?? 0)
    const eventKey = String(requestBody.event_key ?? "")
    const title = String(requestBody.title ?? "")
    const body = String(requestBody.body ?? "")
    if (!["beta", "stable"].includes(channel) || !eventKey || !versionName ||
        !Number.isInteger(buildNumber) || buildNumber < 1) {
      return json(400, { error: "invalid_update_push" })
    }
    const { data: enqueueCount, error: enqueueError } = await admin.rpc("enqueue_update_push", {
      p_event_key: eventKey,
      p_channel: channel,
      p_version_name: versionName,
      p_build_number: buildNumber,
      p_title: title,
      p_body: body,
    })
    if (enqueueError) return json(500, { error: "enqueue_failed" })
    enqueued = Number(enqueueCount ?? 0)
  }
  const workerId = crypto.randomUUID()
  const { data, error } = await admin.rpc("claim_push_deliveries", {
    p_worker_id: workerId,
    p_limit: 50,
    p_lease_seconds: 90,
  })
  if (error) return json(500, { error: "claim_failed" })

  const deliveries = (data ?? []) as ClaimedDelivery[]
  if (deliveries.length === 0) {
    return json(200, { enqueued, claimed: 0, sent: 0, retried: 0, failed: 0 })
  }

  let accessToken: string
  try {
    accessToken = await createAccessToken(account)
  } catch {
    // Lease süresi dolunca teslimler tekrar claim edilebilir. Credential ayrıntısı
    // log/response'a taşınmaz.
    return json(503, { error: "provider_auth_failed", claimed: deliveries.length })
  }

  let sent = 0
  let retried = 0
  let failed = 0
  for (const delivery of deliveries) {
    let result: DeliveryResult
    try {
      result = await sendToFcm(delivery, account.project_id, accessToken)
    } catch {
      const retry = Math.min(3600, 30 * (2 ** Math.min(6, Math.max(0, delivery.attempt - 1))))
      result = { result: "retry", errorCode: "network_error", retryAfterSeconds: retry }
    }

    if (result.disableDevice) {
      await admin.rpc("disable_push_device", {
        p_device_id: delivery.device_id,
        p_error_code: result.errorCode ?? "unregistered",
      })
    }
    const { error: completionError } = await admin.rpc("complete_push_delivery", {
      p_delivery_id: delivery.delivery_id,
      p_worker_id: workerId,
      p_result: result.result,
      p_provider_message_id: result.providerMessageId ?? null,
      p_error_code: result.errorCode ?? null,
      p_retry_after_seconds: result.retryAfterSeconds ?? 60,
    })
    if (completionError) {
      failed++
      continue
    }
    if (result.result === "sent") sent++
    else if (result.result === "retry") retried++
    else failed++
  }

  return json(200, { enqueued, claimed: deliveries.length, sent, retried, failed })
})
