import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { generateReportHtml } from "./templates.ts"

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

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
    
    // 1. Kuyruktan pending olan işleri al (Maksimum 30 adet)
    const { data: jobs, error: fetchError } = await supabaseAdmin
      .from('email_job_queue')
      .select('*')
      .eq('status', 'pending')
      .limit(30)

    if (fetchError) throw fetchError

    if (!jobs || jobs.length === 0) {
      return new Response(JSON.stringify({ message: 'No pending jobs.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    const results = [];

    // 2. Her bir işi işle
    for (const job of jobs) {
      try {
        // İşi processing yap
        await supabaseAdmin.from('email_job_queue').update({ status: 'processing' }).eq('id', job.id);

        // İstatistikleri çek
        const { data: stats, error: statsError } = await supabaseAdmin
          .rpc('get_user_monthly_stats', { p_user_id: job.user_id, p_month: job.report_month });
          
        if (statsError) throw statsError;

        // E-posta adresini al
        const { data: userData, error: userError } = await supabaseAdmin.auth.admin.getUserById(job.user_id);
        if (userError || !userData?.user?.email) {
          throw new Error('User or email not found');
        }
        const userEmail = userData.user.email;

        // Unsubscribe token oluştur
        const { data: tokenData, error: tokenError } = await supabaseAdmin
          .from('email_unsubscribe_tokens')
          .insert({ user_id: job.user_id })
          .select('id')
          .single();
          
        if (tokenError) throw tokenError;

        // HTML'i oluştur
        const html = generateReportHtml(stats, job.report_month, tokenData.id);

        // Resend ile gönder (API Key varsa)
        if (RESEND_API_KEY && RESEND_API_KEY !== 'mock') {
          const resendResponse = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${RESEND_API_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              from: "Odak Kampı <rapor@mail.odakkampi.com>",
              to: userEmail,
              subject: `[Aylık Çalışma Özeti] ${job.report_month}`,
              html: html,
              headers: { "List-Unsubscribe": "<mailto:unsubscribe@mail.odakkampi.com>" },
            }),
          });
          
          if (!resendResponse.ok) {
            const errorText = await resendResponse.text();
            throw new Error(`Resend API Error: ${errorText}`);
          }
        } else {
          // Mock mode: Sadece konsola yaz
          console.log(`[Mock] Email would be sent to ${userEmail} for month ${job.report_month}`);
        }

        // Başarılı
        await supabaseAdmin
          .from('email_job_queue')
          .update({ status: 'sent', processed_at: new Date().toISOString() })
          .eq('id', job.id);
          
        results.push({ id: job.id, status: 'success' });

      } catch (err) {
        console.error(`Error processing job ${job.id}:`, err);
        const retryCount = job.retry_count + 1;
        const newStatus = retryCount >= 3 ? 'abandoned' : 'failed';
        
        await supabaseAdmin
          .from('email_job_queue')
          .update({ 
            status: newStatus, 
            retry_count: retryCount,
            error_log: String(err)
          })
          .eq('id', job.id);
          
        results.push({ id: job.id, status: newStatus, error: String(err) });
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
