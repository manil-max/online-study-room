import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  authBanDurationFor,
  isLadderAction,
  legacyIdempotencyKey,
  legacyLadderActionFor,
  PERMANENT_BAN_DURATION,
  requiresAuthBan,
  shouldClearAuthBanOnRevoke,
} from "../_shared/admin_sanction_policy.ts"

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

    // WP-441 + WP-625: TÜM eski eylem adları yaptırım hattına çevrilir.
    //
    // WP-441 bunu yalnız `mute_24h` için yapmıştı (o dal auth ban kuruyordu,
    // susturulan kullanıcı giriş bile yapamıyordu). WP-625'te aynı hastalığın
    // daha kötüsü çıktı: `suspend_user` süresi sorulmayan, kaydı olmayan
    // ≈100 yıllık bir ban kuruyordu. Basamağa çevrilen çağrı artık
    // `moderation_sanctions`'a satır yazar → Moderasyon sekmesinde görünür,
    // geri alınabilir, süresi dolunca kendiliğinden açılır.
    //
    // Eski çağrılar idempotency anahtarı göndermiyor; dakika kovasından
    // türetiyoruz: aynı dakikadaki yeniden denemeler tek yaptırım açar.
    let derivedIdempotencyKey = idempotencyKey
    let derivedSanctionAction = sanctionAction
    const legacyLadderAction = typeof action === 'string'
      ? legacyLadderActionFor(action)
      : null
    if (legacyLadderAction) {
      derivedSanctionAction = sanctionAction ?? legacyLadderAction
      derivedIdempotencyKey = idempotencyKey
        ?? legacyIdempotencyKey(action, targetUserId, Date.now())
      action = 'moderation_sanction'
    }
    const effectiveSanctionAction = derivedSanctionAction

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
        //
        // 🔴 WP-625: ama YALNIZ auth ban kurmuş bir basamak geri alınırsa.
        // Önceden koşul sadece "geri alınan satırın hedefi var mı" idi: eski
        // bir UYARIYI geri almak, o kullanıcının ilgisiz kalıcı yasağını da
        // kaldırıyordu. Soft-delete edilmiş hesap da bu yoldan geri açılıyordu.
        if (revoked?.target_user_id) {
          const { data: revokeTarget, error: revokeTargetError } =
            await supabaseAdmin.auth.admin.getUserById(revoked.target_user_id)
          if (revokeTargetError) throw revokeTargetError
          const clearBan = shouldClearAuthBanOnRevoke({
            revokedAction: revoked.action,
            softDeleted: revokeTarget?.user?.user_metadata?.deleted === true,
          })
          if (clearBan) {
            const { error: authError } = await supabaseAdmin.auth.admin
              .updateUserById(revoked.target_user_id, { ban_duration: 'none' })
            if (authError) throw authError
          }
        }
        return jsonResponse(revoked)
      }

      if (!targetUserId || !reason?.trim() || !derivedIdempotencyKey) {
        throw new Error('targetUserId, reason and idempotencyKey are required')
      }
      // WP-625: bilinmeyen basamak KAYIT AÇMADAN reddedilir. Önce açıp sonra
      // düşmek, hedefte `failed` bir satır ve tek-aktif-kısıt indeksinde
      // gereksiz gürültü bırakıyordu.
      if (!effectiveSanctionAction || !isLadderAction(effectiveSanctionAction)) {
        throw new Error('Bilinmeyen yaptırım: ' + effectiveSanctionAction)
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

      // Süre tablosu `_shared/admin_sanction_policy.ts`te tek yerde durur;
      // "hangi basamak auth'a dokunur" sorusunun cevabı geri alma yolunda da
      // aynı tablodan okunur.
      const banDuration = authBanDurationFor(effectiveSanctionAction)

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
        } else if (banDuration) {
          const { error: banError } = await supabaseAdmin.auth.admin
            .updateUserById(targetUserId, { ban_duration: banDuration })
          if (banError) throw banError
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

      // 🔴 WP-625: eski `warn_user` / `suspend_*` dalları SİLİNDİ. İkisi de
      // yukarıdaki takma ad tablosuyla yaptırım hattına düşer; burada kopya
      // bırakmak, kaydı olmayan 100 yıllık ban'ın geri gelmesi için açık
      // kapıydı (`warn_user` da hiçbir şey yapmadan "başarılı" diyordu).

      case 'unsuspend_user':
      case 'revoke_sanction': {
        // WP-625: askı artık `moderation_sanctions` satırıyla birlikte kurulur.
        // Yalnız auth ban'ını kaldırmak kaydı `applied` bırakırdı: kullanıcı
        // içeri girer, ama tek-aktif-kısıt indeksi yüzünden ona bir daha
        // yaptırım uygulanamaz ve Moderasyon sekmesi hâlâ "askıda" gösterirdi.
        // Bu yüzden önce kayıt geri alınır (denetim satırını RPC yazar), sonra
        // auth ban'ı kalkar.
        //
        // Okuma bilerek çağıranın KENDİ client'ıyla: `0105` bu tabloda
        // `authenticated`a select veriyor ve politika süper admini geçiriyor
        // (`moderation_sanctions_select_own`). service_role'e düşmek, kapıyı
        // migration'ın söylemediği bir varsayıma bağlardı.
        const { data: openSanctions, error: openSanctionsError } =
          await supabaseClient
            .from('moderation_sanctions')
            .select('id, action')
            .eq('target_user_id', targetUserId)
            .in('state', ['pending', 'applied'])
        if (openSanctionsError) throw openSanctionsError
        for (const row of openSanctions ?? []) {
          // Susturma/uyarı hesabı kapatmaz; "Askıyı Kaldır" onları silmez.
          if (!requiresAuthBan(row.action)) continue
          const { error: revokeError } = await supabaseClient
            .rpc('admin_revoke_moderation_sanction', {
              p_sanction_id: row.id,
              p_reason: reason.trim(),
            })
          if (revokeError) throw revokeError
        }
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
          ban_duration: PERMANENT_BAN_DURATION
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
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
