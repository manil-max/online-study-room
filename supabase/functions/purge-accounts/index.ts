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
 * WP-113 / WP-127: Süresi dolan hesap silme isteklerini işler (service_role).
 * Sıra: claim → storage avatar → related scrub → auth.admin.deleteUser.
 *
 * Retry (WP-127): attempt_count < MAX_PURGE_ATTEMPTS olan scheduled|failed işler
 * seçilir. Hata sonrası attempt < 5 → status='scheduled' (yeniden dene);
 * attempt >= 5 → status='failed' terminal (fetch `.lt(attempt_count, 5)` ile
 * bir daha seçilmez). last_error_code gerçek hata sınıfını taşır.
 *
 * Not: auth.admin.deleteUser sonrası account_deletion_requests satırı genelde
 * user_id FK ON DELETE CASCADE ile silinir; status='completed' update'i 0 satır
 * etkileyebilir — tamamlanma izi results[] + log ile kalır (ayrı audit tablosu yok).
 */
const MAX_PURGE_ATTEMPTS = 5

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
  // Truncate noisy stack for column size safety.
  const slug = raw.replace(/\s+/g, " ").slice(0, 120)
  return slug.length > 0 ? `purge_failed:${slug}` : "purge_failed"
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

    // WP-127 (a): attempt eşiğini geçen failed işler bir daha seçilmez.
    const { data: jobs, error: fetchError } = await admin
      .from("account_deletion_requests")
      .select("id, user_id, attempt_count, status")
      .in("status", ["scheduled", "failed"])
      .lt("attempt_count", MAX_PURGE_ATTEMPTS)
      .lte("purge_after", new Date().toISOString())
      .order("purge_after", { ascending: true })
      .limit(limit)

    if (fetchError) throw fetchError
    if (!jobs?.length) {
      return new Response(
        JSON.stringify({ processed: 0, message: "no due jobs" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        },
      )
    }

    const results: Array<Record<string, unknown>> = []

    for (const job of jobs) {
      const uid = job.user_id as string
      const id = job.id as string
      try {
        if (!dryRun) {
          await admin
            .from("account_deletion_requests")
            .update({
              status: "processing",
              updated_at: new Date().toISOString(),
            })
            .eq("id", id)
            .in("status", ["scheduled", "failed"])
            .lt("attempt_count", MAX_PURGE_ATTEMPTS)
        }

        // E-posta kuyruğu: pending işleri iptal et
        if (!dryRun) {
          await admin
            .from("email_job_queue")
            .update({ status: "abandoned", error_log: "account_deletion" })
            .eq("user_id", uid)
            .eq("status", "pending")
        }

        // Avatar storage: {uid}/ önek
        if (!dryRun) {
          const { data: files } = await admin.storage
            .from("avatars")
            .list(uid, { limit: 100 })
          if (files?.length) {
            const paths = files.map((f) => `${uid}/${f.name}`)
            await admin.storage.from("avatars").remove(paths)
          }
        }

        // Grup ownership: created_by bu kullanıcı ise en eski aktif üyeye devret
        if (!dryRun) {
          const { data: owned } = await admin
            .from("groups")
            .select("id")
            .eq("created_by", uid)
          for (const g of owned ?? []) {
            const { data: members } = await admin
              .from("group_members")
              .select("user_id, joined_at")
              .eq("group_id", g.id)
              .is("left_at", null)
              .neq("user_id", uid)
              .order("joined_at", { ascending: true })
              .limit(1)
            if (members?.length) {
              await admin
                .from("groups")
                .update({ created_by: members[0].user_id })
                .eq("id", g.id)
            } else {
              await admin.from("groups").delete().eq("id", g.id)
            }
          }
        }

        // Sohbet scrub (display only path; body keep length-safe placeholder)
        if (!dryRun) {
          await admin
            .from("class_messages")
            .update({ body: "[silindi]" })
            .eq("user_id", uid)
        }

        if (!dryRun) {
          const { error: delErr } = await admin.auth.admin.deleteUser(uid)
          if (delErr) throw delErr

          // deleteUser CASCADE ile request satırını silebilir → 0 satır güncelleme normal.
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
        })
      } catch (err) {
        const attempt = (job.attempt_count ?? 0) + 1
        const code = classifyPurgeError(err)
        // attempt >= 5 → terminal failed; altında scheduled (retry kuyruğu).
        const nextStatus = attempt >= MAX_PURGE_ATTEMPTS ? "failed" : "scheduled"
        if (!dryRun) {
          await admin
            .from("account_deletion_requests")
            .update({
              status: nextStatus,
              attempt_count: attempt,
              last_error_code: code,
              updated_at: new Date().toISOString(),
            })
            .eq("id", id)
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
