import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { generateReportHtml } from "./templates.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-cron-secret',
}

/** WP-108/109: yalnız cron secret veya service_role Bearer. */
function authorizeCron(req: Request): Response | null {
  const cronSecret = Deno.env.get('CRON_SECRET') ?? ''
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const headerSecret = req.headers.get('x-cron-secret') ?? ''
  const authHeader = req.headers.get('Authorization') ?? ''

  if (cronSecret && headerSecret === cronSecret) return null
  if (cronSecret && authHeader === `Bearer ${cronSecret}`) return null
  if (serviceKey && authHeader === `Bearer ${serviceKey}`) return null

  return new Response(JSON.stringify({ error: 'Unauthorized' }), {
    status: 401,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const denied = authorizeCron(req)
    if (denied) return denied

    // Admin client: env service_role (istek Authorization ile ezme — WP-109).
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

    // WP-108 (B2): pending + failed (retry_count < 3). abandoned alınmaz.
    const { data: jobs, error: fetchError } = await supabaseAdmin
      .from('email_job_queue')
      .select('*')
      .in('status', ['pending', 'failed'])
      .lt('retry_count', 3)
      .order('created_at', { ascending: true })
      .limit(30)

    if (fetchError) throw fetchError

    if (!jobs || jobs.length === 0) {
      return new Response(JSON.stringify({ message: 'No pending jobs.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    const results = []

    for (const job of jobs) {
      try {
        await supabaseAdmin
          .from('email_job_queue')
          .update({ status: 'processing' })
          .eq('id', job.id)

        const { data: stats, error: statsError } = await supabaseAdmin
          .rpc('get_user_monthly_stats', {
            p_user_id: job.user_id,
            p_month: job.report_month,
          })

        if (statsError) throw statsError

        const { data: userData, error: userError } =
          await supabaseAdmin.auth.admin.getUserById(job.user_id)
        if (userError || !userData?.user?.email) {
          throw new Error('User or email not found')
        }
        const userEmail = userData.user.email

        const { data: tokenData, error: tokenError } = await supabaseAdmin
          .from('email_unsubscribe_tokens')
          .insert({ user_id: job.user_id })
          .select('id')
          .single()

        if (tokenError) throw tokenError

        const html = generateReportHtml(stats, job.report_month, tokenData.id)

        if (RESEND_API_KEY && RESEND_API_KEY !== 'mock') {
          const resendResponse = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${RESEND_API_KEY}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              from: 'Odak Kampı <rapor@mail.odakkampi.com>',
              to: userEmail,
              subject: `[Aylık Çalışma Özeti] ${job.report_month}`,
              html: html,
              headers: {
                'List-Unsubscribe':
                  '<mailto:unsubscribe@mail.odakkampi.com>',
              },
            }),
          })

          if (!resendResponse.ok) {
            const errorText = await resendResponse.text()
            throw new Error(`Resend API Error: ${errorText}`)
          }
        } else {
          console.log(
            `[Mock] Email would be sent to ${userEmail} for month ${job.report_month}`,
          )
        }

        await supabaseAdmin
          .from('email_job_queue')
          .update({
            status: 'sent',
            processed_at: new Date().toISOString(),
          })
          .eq('id', job.id)

        results.push({ id: job.id, status: 'success' })
      } catch (err) {
        console.error(`Error processing job ${job.id}:`, err)
        const retryCount = (job.retry_count ?? 0) + 1
        const newStatus = retryCount >= 3 ? 'abandoned' : 'failed'

        await supabaseAdmin
          .from('email_job_queue')
          .update({
            status: newStatus,
            retry_count: retryCount,
            error_log: String(err),
          })
          .eq('id', job.id)

        results.push({ id: job.id, status: newStatus, error: String(err) })
      }
    }

    return new Response(JSON.stringify({ results }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
