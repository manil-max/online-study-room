import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

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

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const body = await req.json().catch(() => ({}))
    let targetMonth = body.month
    if (!targetMonth) {
      const d = new Date()
      d.setMonth(d.getMonth() - 1)
      const year = d.getFullYear()
      const month = String(d.getMonth() + 1).padStart(2, '0')
      targetMonth = `${year}-${month}`
    }

    const { data: users, error: fetchError } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('monthly_report_opt_in', true)
      .eq('email_bounced', false)

    if (fetchError) throw fetchError

    if (!users || users.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No eligible users found.' }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        },
      )
    }

    const queueData = users.map((u: { id: string }) => ({
      user_id: u.id,
      report_month: targetMonth,
      status: 'pending',
    }))

    const { error: insertError } = await supabaseAdmin
      .from('email_job_queue')
      .upsert(queueData, {
        onConflict: 'user_id,report_month',
        ignoreDuplicates: true,
      })

    if (insertError) throw insertError

    return new Response(
      JSON.stringify({
        success: true,
        message: `${users.length} users queued for ${targetMonth} report.`,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
