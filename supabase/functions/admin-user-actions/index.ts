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
    const { targetUserId, reason, options, sanctionAction, idempotencyKey, caseId, sanctionId } = body
    let action = body.action

    const jsonResponse = (data: unknown) => new Response(JSON.stringify({ data }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

    // WP-441: Eski `mute_24h` çağrısı auth ban kuruyordu; kullanıcı okuyamıyor,
    // giriş bile yapamıyordu. Artık yalnız-yazma kısıtı olarak yaptırım
    // hattına düşer. Eski çağrı idempotency anahtarı göndermediği için dakika
    // kovasından türetiyoruz: aynı dakikadaki yeniden denemeler tek yaptırım.
    let derivedIdempotencyKey = idempotencyKey
    if (action === 'mute_24h') {
      action = 'moderation_sanction'
      derivedIdempotencyKey = idempotencyKey
        ?? `legacy-mute-${targetUserId}-${Math.floor(Date.now() / 60000)}`
    }
    const effectiveSanctionAction = sanctionAction ?? 'mute_24h'

    // WP-441 yaptırım hattı: aç → auth işini yap → kapat. Denetim satırını
    // RPC yazar, bu yüzden aşağıdaki eski audit bloğuna hiç girilmez.
    if (action === 'moderation_sanction' || action === 'moderation_revoke') {
      if (action === 'moderation_revoke') {
        if (!sanctionId || !reason?.trim()) {
          throw new Error('sanctionId and reason are required')
        }
        const { data: revoked, error: revokeError } = await supabaseClient
          .rpc('admin_revoke_moderation_sanction', {
            p_sanction_id: sanctionId,
            p_reason: reason.trim(),
          })
        if (revokeError) throw revokeError
        // Kısıt auth tarafında da kalkar; yoksa süre dolmadan geri alınan
        // askı kullanıcıyı dışarıda bırakmaya devam ederdi.
        if (revoked?.target_user_id) {
          const { error: authError } = await supabaseAdmin.auth.admin
            .updateUserById(revoked.target_user_id, { ban_duration: 'none' })
          if (authError) throw authError
        }
        return jsonResponse(revoked)
      }

      if (!targetUserId || !reason?.trim() || !derivedIdempotencyKey) {
        throw new Error('targetUserId, reason and idempotencyKey are required')
      }

      const { data: opened, error: beginError } = await supabaseClient
        .rpc('admin_begin_moderation_sanction', {
          p_target_user_id: targetUserId,
          p_action: effectiveSanctionAction,
          p_reason: reason.trim(),
          p_idempotency_key: derivedIdempotencyKey,
          p_case_id: caseId ?? null,
        })
      if (beginError) throw beginError
      // Tekrar gönderim: kayıt zaten kapanmış, auth işi ikinci kez koşmaz.
      if (opened.state !== 'pending') return jsonResponse(opened)

      const banDurations: Record<string, string> = {
        suspend_24h: '24h',
        suspend_7d: '168h',
        suspend_14d: '336h',
        suspend_30d: '720h',
        ban_permanent: '876000h',
      }

      let failure: string | null = null
      try {
        if (effectiveSanctionAction === 'name_reset') {
          const { data: profile, error: profileReadError } = await supabaseAdmin
            .from('profiles').select('display_name').eq('id', targetUserId).single()
          if (profileReadError) throw profileReadError
          const { error: resetError } = await supabaseAdmin
            .from('moderation_name_resets')
            .upsert(
              { target_type: 'user', target_id: targetUserId, previous_name: profile.display_name, reset_by: user.id },
              { onConflict: 'target_type,target_id', ignoreDuplicates: true },
            )
          if (resetError) throw resetError
          const { error: renameError } = await supabaseAdmin
            .from('profiles').update({ display_name: 'İsimsiz kullanıcı' }).eq('id', targetUserId)
          if (renameError) throw renameError
        } else if (banDurations[effectiveSanctionAction]) {
          const { error: banError } = await supabaseAdmin.auth.admin
            .updateUserById(targetUserId, { ban_duration: banDurations[effectiveSanctionAction] })
          if (banError) throw banError
        } else if (!['no_action', 'warn', 'mute_24h'].includes(effectiveSanctionAction)) {
          throw new Error('Bilinmeyen yaptırım: ' + effectiveSanctionAction)
        }
        // `warn` ve `mute_24h` auth tarafına dokunmaz: uyarı bildirimi ve
        // yazma kısıtı kapanış RPC'sinde yazılır, kullanıcı okumaya devam eder.
      } catch (sanctionError) {
        failure = sanctionError instanceof Error ? sanctionError.message : String(sanctionError)
      }

      const { data: finished, error: finishError } = await supabaseClient
        .rpc('admin_finish_moderation_sanction', {
          p_sanction_id: opened.id,
          p_succeeded: failure === null,
          p_failure_reason: failure,
        })
      if (finishError) throw finishError
      if (failure) throw new Error(failure)
      return jsonResponse(finished)
    }

    if (action !== 'list_users' && (!targetUserId || !reason?.trim())) {
      throw new Error('targetUserId and reason are required')
    }

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

      case 'warn_user': {
        result = { success: true }
        break
      }

      case 'reset_user_name': {
        const { data: profile, error: profileReadError } = await supabaseAdmin
          .from('profiles')
          .select('display_name')
          .eq('id', targetUserId)
          .single()
        if (profileReadError) throw profileReadError
        const { error: resetError } = await supabaseAdmin
          .from('moderation_name_resets')
          .upsert(
            { target_type: 'user', target_id: targetUserId, previous_name: profile.display_name, reset_by: user.id },
            { onConflict: 'target_type,target_id', ignoreDuplicates: true },
          )
        if (resetError) throw resetError
        const { error } = await supabaseAdmin
          .from('profiles')
          .update({ display_name: 'İsimsiz kullanıcı' })
          .eq('id', targetUserId)
        if (error) throw error
        result = { success: true }
        break
      }

      case 'restore_user_name': {
        const { data: reset, error: resetReadError } = await supabaseAdmin
          .from('moderation_name_resets')
          .select('previous_name')
          .eq('target_type', 'user')
          .eq('target_id', targetUserId)
          .single()
        if (resetReadError) throw resetReadError
        const { error } = await supabaseAdmin
          .from('profiles')
          .update({ display_name: reset.previous_name })
          .eq('id', targetUserId)
        if (error) throw error
        const { error: deleteError } = await supabaseAdmin.from('moderation_name_resets').delete()
          .eq('target_type', 'user').eq('target_id', targetUserId)
        if (deleteError) throw deleteError
        result = { success: true }
        break
      }

      case 'suspend_24h':
      case 'suspend_7d':
      case 'suspend_14d':
      case 'suspend_30d':
      case 'suspend_user':
      case 'suspend_permanent': {
        const durations: Record<string, string> = {
          suspend_24h: '24h',
          suspend_7d: '168h',
          suspend_14d: '336h',
          suspend_30d: '720h',
          suspend_user: '876000h',
          suspend_permanent: '876000h',
        }
        const { error } = await supabaseAdmin.auth.admin.updateUserById(targetUserId, {
          ban_duration: durations[action],
        })
        if (error) throw error
        result = { success: true }
        break
      }
      
      case 'unsuspend_user':
      case 'revoke_sanction': {
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
      if (auditError) throw auditError
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
