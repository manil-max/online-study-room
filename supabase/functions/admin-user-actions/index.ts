import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Authorization header is missing')
    }

    // Supabase Admin yetkisi (service_role) gerektiren işlemler için
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Kullanıcının kimliğini doğrulamak için kendi token'ıyla çağrı yapıyoruz
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Süper admin mi kontrolü
    const { data: isSuperAdmin } = await supabaseClient.rpc('is_super_admin')
    if (!isSuperAdmin) {
      return new Response(JSON.stringify({ error: 'Forbidden: Sadece süper adminler bu işlemi yapabilir.' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const body = await req.json()
    const { action, targetUserId, reason, options } = body

    let result = null
    let targetUserEmail = null

    // TargetUser detayları action'a göre gerekebilir
    if (action !== 'list_users' && targetUserId) {
        const { data: targetUser, error: targetError } = await supabaseAdmin.auth.admin.getUserById(targetUserId)
        if (targetError) throw targetError
        targetUserEmail = targetUser.user.email
    }

    switch (action) {
      case 'list_users': {
        const page = options?.page ?? 1
        const limit = options?.limit ?? 100
        
        const { data, error } = await supabaseAdmin.auth.admin.listUsers({
          page: page,
          perPage: limit,
        })
        if (error) throw error
        
        // Kullanıcıların ban durumu "banned_until" gibi auth alanlarında saklanıyor.
        result = data.users.map(u => ({
          id: u.id,
          email: u.email,
          createdAt: u.created_at,
          lastSignInAt: u.last_sign_in_at,
          bannedUntil: u.banned_until,
          deleted: u.user_metadata?.deleted === true,
        }))
        break
      }
      
      case 'send_password_reset': {
        if (!targetUserEmail) throw new Error('Kullanıcı e-postası bulunamadı.')
        const { error } = await supabaseAdmin.auth.admin.generateLink({
          type: 'recovery',
          email: targetUserEmail,
        })
        if (error) throw error
        result = { success: true }
        break
      }

      case 'suspend_user': {
        const { error } = await supabaseAdmin.auth.admin.updateUserById(targetUserId, {
          ban_duration: '876000h' // 100 yıl ban (kalıcı askıya alma)
        })
        if (error) throw error
        result = { success: true }
        break
      }
      
      case 'unsuspend_user': {
        const { error } = await supabaseAdmin.auth.admin.updateUserById(targetUserId, {
          ban_duration: 'none'
        })
        if (error) throw error
        result = { success: true }
        break
      }

      case 'soft_delete_user': {
        // Kullanıcıyı hem banla hem de silindi olarak işaretle
        const { error } = await supabaseAdmin.auth.admin.updateUserById(targetUserId, {
          user_metadata: { deleted: true },
          ban_duration: '876000h'
        })
        if (error) throw error
        
        // Profili anonimleştir
        const { error: profileError } = await supabaseAdmin
          .from('profiles')
          .update({ display_name: 'Silinmiş Kullanıcı' })
          .eq('id', targetUserId)
        
        if (profileError) throw profileError

        result = { success: true }
        break
      }

      default:
        throw new Error('Bilinmeyen eylem: ' + action)
    }

    // Denetim (Audit) loguna yaz
    if (action !== 'list_users') {
      const { error: auditError } = await supabaseAdmin
        .from('admin_audit_logs')
        .insert({
          admin_id: user.id,
          target_user_id: targetUserId,
          target_user_email: targetUserEmail,
          action: action,
          reason: reason || 'Gerekçe belirtilmedi',
        })
      if (auditError) console.error('Audit Log Hatası:', auditError)
    }

    return new Response(JSON.stringify({ data: result }), {
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
