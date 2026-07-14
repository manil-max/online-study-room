import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Authorization header is missing')
    }

    // Cron job (veya manuel) çağrısı `service_role` bekler
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    // İstekten hedef ay bilgisini al (Yoksa varsayılan olarak bir önceki ay)
    const body = await req.json().catch(() => ({}))
    let targetMonth = body.month
    if (!targetMonth) {
      const d = new Date()
      d.setMonth(d.getMonth() - 1)
      const year = d.getFullYear()
      const month = String(d.getMonth() + 1).padStart(2, '0')
      targetMonth = `${year}-${month}`
    }

    // 1. Opt-in olan ve bounce etmemiş aktif kullanıcıları çek
    const { data: users, error: fetchError } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('monthly_report_opt_in', true)
      .eq('email_bounced', false)

    if (fetchError) throw fetchError

    if (!users || users.length === 0) {
      return new Response(JSON.stringify({ message: 'No eligible users found.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // 2. Kuyruğa eklemek için payload hazırla
    const queueData = users.map((u: any) => ({
      user_id: u.id,
      report_month: targetMonth,
      status: 'pending'
    }))

    // 3. Kuyruğa upsert et (Eğer daha önce girildiyse ignore eder - unique constraint 'user_id, report_month')
    const { error: insertError } = await supabaseAdmin
      .from('email_job_queue')
      .upsert(queueData, { onConflict: 'user_id,report_month', ignoreDuplicates: true })

    if (insertError) throw insertError

    return new Response(JSON.stringify({ 
      success: true, 
      message: `${users.length} users queued for ${targetMonth} report.` 
    }), {
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
