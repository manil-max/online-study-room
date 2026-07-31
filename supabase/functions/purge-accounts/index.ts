import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
}

function authorizeCron(req: Request): Response | null {
  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  const headerSecret = req.headers.get("x-cron-secret") ?? ""
  const authHeader = req.headers.get("Authorization") ?? ""
  if (cronSecret && headerSecret === cronSecret) return null
  if (cronSecret && authHeader === `Bearer ${cronSecret}`) return null
  if (serviceKey && authHeader === `Bearer ${serviceKey}`) return null
  return new Response(JSON.stringify({ error: "Unauthorized" }), {
    status: 401,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

/**
 * WP-113 / WP-127 / WP-464: süresi dolan hesap silme isteklerini işler.
 *
 * WP-464 öncesi bu dosya doğruydu ama ÖLÜYDÜ: onu çağıran hiçbir şey yoktu
 * (ne cron, ne workflow). `0113` zamanlayıcıyı bağladı; bu sürüm de kartın
 * saydığı yapısal açıkları kapatıyor:
 *
 *   1. Claim artık atomik — `claim_account_deletion_jobs` RPC'si
 *      `for update skip locked` ile seçip aynı ifadede `processing` yazar.
 *      Eskiden select + update ayrıydı ve update'in SONUCU OKUNMUYORDU, yani
 *      iki worker aynı kullanıcıyı iki kez silmeye çalışabiliyordu.
 *   2. Çökmüş worker kurtarması — lease süresi dolan `processing` satırı
 *      yeniden claim edilir. Eskiden o satır bir daha HİÇ seçilmiyordu.
 *   3. Storage sayfalama — eskiden yalnız ilk 100 nesne siliniyordu, gerisi
 *      sessizce kalıyordu.
 *   4. Ara adım hataları artık sessiz değil; her biri kontrol edilir ve işi
 *      retry kuyruğuna düşürür.
 *   5. Tamamlanma izi — `deleteUser` cascade ile istek satırını sildiği için
 *      geriye kanıt kalmıyordu. Artık `record_account_purge_outcome` PII'siz
 *      (sha256 uid) bir denetim satırı yazar.
 *
 * Retry (WP-127): attempt_count < MAX_PURGE_ATTEMPTS olan işler seçilir.
 * Hata sonrası attempt < 5 → 'scheduled' (yeniden dene); >= 5 → 'failed'
 * terminal. last_error_code gerçek hata sınıfını taşır.
 */
const MAX_PURGE_ATTEMPTS = 5
const LEASE_SECONDS = 1800
const STORAGE_PAGE_SIZE = 100

function classifyPurgeError(err: unknown): string {
  const raw = String(err ?? "unknown")
  const lower = raw.toLowerCase()
  if (lower.includes("not authorized") || lower.includes("unauthorized") || lower.includes("401")) {
    return "auth_unauthorized"
  }
  if (lower.includes("user not found") || lower.includes("not_found") || lower.includes("404")) {
    return "user_not_found"
  }
  if (lower.includes("network") || lower.includes("fetch failed") || lower.includes("timeout")) {
    return "network_error"
  }
  if (lower.includes("storage")) return "storage_error"
  if (lower.includes("permission") || lower.includes("rls") || lower.includes("42501")) {
    return "permission_error"
  }
  const slug = raw.replace(/\s+/g, " ").slice(0, 120)
  return slug.length > 0 ? `purge_failed:${slug}` : "purge_failed"
}

/**
 * Ara adımların sessizce yutulmasını engeller.
 *
 * 🔴 Bu fonksiyonun varlık sebebi: eski sürümde e-posta kuyruğu, storage
 * silme, grup devri ve sohbet scrub adımlarının HİÇBİRİ hata kontrolü
 * yapmıyordu. Bir adım sessizce başarısız olsa bile akış `deleteUser`a kadar
 * devam ediyor, kullanıcı siliniyor ve arkada temizlenmemiş veri kalıyordu.
 */
function must<T extends { error: unknown }>(result: T, step: string): T {
  if (result?.error) {
    throw new Error(`${step}: ${String((result.error as { message?: string })?.message ?? result.error)}`)
  }
  return result
}

/** Avatar klasörünü SAYFALAYARAK siler; 100 nesne sınırı yoktur. */
async function purgeAvatars(
  admin: ReturnType<typeof createClient>,
  uid: string,
): Promise<number> {
  let removed = 0
  // Her turda BAŞTAN okunur: bir önceki tur o nesneleri zaten sildiği için
  // offset ilerletmek gerekmez (ilerletmek tam tersine, kayan liste yüzünden
  // nesne atlardı). Sayfa dolu geldiği sürece devam eder.
  const MAX_PAGES = 200
  for (let page = 0; page < MAX_PAGES; page++) {
    const listed = await admin.storage
      .from("avatars")
      .list(uid, { limit: STORAGE_PAGE_SIZE })
    must(listed, "storage_list")
    const files = listed.data ?? []
    if (files.length === 0) break

    const paths = files.map((f) => `${uid}/${f.name}`)
    must(await admin.storage.from("avatars").remove(paths), "storage_remove")
    removed += paths.length

    if (files.length < STORAGE_PAGE_SIZE) break
  }
  return removed
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const denied = authorizeCron(req)
    if (denied) return denied

    const body = await req.json().catch(() => ({}))
    const limit = Math.min(Number(body.limit ?? 5), 20)
    const dryRun = body.dry_run === true

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    type Job = {
      id: string
      user_id: string
      attempt_count: number
      purge_after: string | null
      recovered_from_stale?: boolean
    }
    let jobs: Job[] = []

    if (dryRun) {
      // Dry-run hiçbir satırı claim ETMEZ; yalnız neyin sırada olduğunu okur.
      const { data, error } = await admin
        .from("account_deletion_requests")
        .select("id, user_id, attempt_count, purge_after")
        .in("status", ["scheduled", "failed"])
        .lt("attempt_count", MAX_PURGE_ATTEMPTS)
        .lte("purge_after", new Date().toISOString())
        .order("purge_after", { ascending: true })
        .limit(limit)
      if (error) throw error
      jobs = (data ?? []) as Job[]
    } else {
      // 🔴 Tek kapı: seçim ve işaretleme aynı ifadede, `skip locked` ile.
      // Claim'i kazanamayan worker o işi hiç görmez.
      const { data, error } = await admin.rpc("claim_account_deletion_jobs", {
        p_limit: limit,
        p_lease_seconds: LEASE_SECONDS,
        p_max_attempts: MAX_PURGE_ATTEMPTS,
      })
      if (error) throw error
      jobs = (data ?? []) as Job[]
    }

    if (!jobs.length) {
      return new Response(
        JSON.stringify({ processed: 0, dry_run: dryRun, message: "no due jobs" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        },
      )
    }

    const results: Array<Record<string, unknown>> = []

    for (const job of jobs) {
      const uid = job.user_id
      const id = job.id
      try {
        if (!dryRun) {
          // E-posta kuyruğu: pending işleri iptal et.
          must(
            await admin
              .from("email_job_queue")
              .update({ status: "abandoned", error_log: "account_deletion" })
              .eq("user_id", uid)
              .eq("status", "pending"),
            "email_queue_abandon",
          )

          await purgeAvatars(admin, uid)

          // Grup ownership: created_by bu kullanıcı ise en eski aktif üyeye
          // devret, aktif üye yoksa grubu sil.
          const owned = must(
            await admin.from("groups").select("id").eq("created_by", uid),
            "groups_owned_fetch",
          )
          for (const g of owned.data ?? []) {
            const members = must(
              await admin
                .from("group_members")
                .select("user_id, joined_at")
                .eq("group_id", g.id)
                .is("left_at", null)
                .neq("user_id", uid)
                .order("joined_at", { ascending: true })
                .limit(1),
              "group_members_fetch",
            )
            if (members.data?.length) {
              must(
                await admin
                  .from("groups")
                  .update({ created_by: members.data[0].user_id })
                  .eq("id", g.id),
                "group_owner_transfer",
              )
            } else {
              must(
                await admin.from("groups").delete().eq("id", g.id),
                "group_delete",
              )
            }
          }

          // Sohbet scrub. Retention kararı §5.3: metin scrub edilir, satır
          // grup geçmişini bozmamak için durur.
          must(
            await admin
              .from("class_messages")
              .update({ body: "[silindi]" })
              .eq("user_id", uid),
            "class_messages_scrub",
          )

          const { error: delErr } = await admin.auth.admin.deleteUser(uid)
          if (delErr) throw delErr

          // 🔴 Denetim izi CASCADE'den ÖNCE değil sonra yazılır ve istek
          // satırına bağlı değildir; `deleteUser` o satırı silmiş olabilir.
          // PII yok: sunucu tarafında sha256(uid) saklanır.
          const { error: auditErr } = await admin.rpc(
            "record_account_purge_outcome",
            {
              p_request_id: id,
              p_user_id: uid,
              p_outcome: "completed",
              p_attempt_count: job.attempt_count ?? 0,
              p_error_code: null,
              p_purge_after: job.purge_after,
            },
          )
          if (auditErr) {
            // Kullanıcı gerçekten silindi; denetim yazılamadıysa bunu
            // yutmuyoruz ama işi de "başarısız" sayıp tekrar silmeye
            // çalışmıyoruz — silinecek kullanıcı kalmadı.
            console.error("purge audit write failed", id, auditErr.message)
          }

          const { data: completedRows, error: completeErr } = await admin
            .from("account_deletion_requests")
            .update({
              status: "completed",
              completed_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
              last_error_code: null,
            })
            .eq("id", id)
            .select("id")

          if (completeErr) {
            console.warn(
              "purge complete update skipped/failed (likely cascade delete)",
              id,
              completeErr.message,
            )
          } else if (!completedRows?.length) {
            console.info(
              "purge complete: request row already gone (ON DELETE CASCADE after deleteUser)",
              id,
            )
          }
        }

        results.push({
          id,
          user_id: uid,
          status: dryRun ? "dry_run_ok" : "completed",
          recovered_from_stale: job.recovered_from_stale ?? false,
        })
      } catch (err) {
        const attempt = (job.attempt_count ?? 0) + 1
        const code = classifyPurgeError(err)
        const nextStatus = attempt >= MAX_PURGE_ATTEMPTS ? "failed" : "scheduled"
        if (!dryRun) {
          const { error: updErr } = await admin
            .from("account_deletion_requests")
            .update({
              status: nextStatus,
              attempt_count: attempt,
              last_error_code: code,
              claimed_at: null,
              updated_at: new Date().toISOString(),
            })
            .eq("id", id)
          if (updErr) {
            // Bunu yutmak, işin `processing`de asılı kalması demekti. Lease
            // kurtarması yine de devreye girer, ama iz bırakmadan geçmeyiz.
            console.error("purge status writeback failed", id, updErr.message)
          }

          // Terminal başarısızlık da denetim izine girer: "neden silinmedi"
          // sorusunun cevabı kalmalı.
          if (nextStatus === "failed") {
            const { error: auditErr } = await admin.rpc(
              "record_account_purge_outcome",
              {
                p_request_id: id,
                p_user_id: uid,
                p_outcome: "failed",
                p_attempt_count: attempt,
                p_error_code: code,
                p_purge_after: job.purge_after,
              },
            )
            if (auditErr) {
              console.error("purge audit write failed", id, auditErr.message)
            }
          }
        }
        results.push({
          id,
          user_id: uid,
          status: nextStatus,
          attempt_count: attempt,
          error_code: code,
          terminal: nextStatus === "failed",
        })
        console.error("purge failed", id, code, String(err))
      }
    }

    return new Response(
      JSON.stringify({ processed: results.length, dry_run: dryRun, results }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    })
  }
})
