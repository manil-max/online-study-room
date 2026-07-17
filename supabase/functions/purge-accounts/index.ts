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
 * WP-113: Süresi dolan hesap silme isteklerini işler (service_role).
 * Sıra: claim → storage avatar → related scrub → auth.admin.deleteUser.
 * Idempotent: completed tekrarlanmaz; failed retry_count artar.
 */
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

    const { data: jobs, error: fetchError } = await admin
      .from("account_deletion_requests")
      .select("id, user_id, attempt_count, status")
      .in("status", ["scheduled", "failed"])
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

          await admin
            .from("account_deletion_requests")
            .update({
              status: "completed",
              completed_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
              last_error_code: null,
            })
            .eq("id", id)
        }

        results.push({
          id,
          user_id: uid,
          status: dryRun ? "dry_run_ok" : "completed",
        })
      } catch (err) {
        const attempt = (job.attempt_count ?? 0) + 1
        const code = "purge_failed"
        if (!dryRun) {
          await admin
            .from("account_deletion_requests")
            .update({
              status: attempt >= 5 ? "failed" : "failed",
              attempt_count: attempt,
              last_error_code: code,
              updated_at: new Date().toISOString(),
            })
            .eq("id", id)
        }
        results.push({
          id,
          user_id: uid,
          status: "failed",
          error_code: code,
        })
        console.error("purge failed", id, String(err))
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
