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

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

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

    const { data: isSuperAdmin } = await supabaseClient.rpc('is_super_admin')
    if (!isSuperAdmin) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const body = await req.json()
    const { action, targetGroupId, targetUserId, reason } = body

    // 🔴 Salt-okuma eylemleri (WP-F): bir listeyi GORMEK bir yaptirim degildir.
    // Kosulsuz gerekce zorunlulugu okumayi da reddediyordu; denetim kaydi ise
    // her ekran acilisinda sisiyordu.
    const READ_ONLY_ACTIONS = ['list_group_members']
    const isReadOnly = READ_ONLY_ACTIONS.includes(action)

    if (!targetGroupId) {
      throw new Error('targetGroupId is required')
    }
    if (!isReadOnly && !reason?.trim()) {
      throw new Error('reason is required')
    }

    let result = null

    switch (action) {
      case 'delete_group': {
        const { error } = await supabaseAdmin
          .from('groups')
          .delete()
          .eq('id', targetGroupId)
        if (error) throw error
        result = { success: true }
        break
      }
      case 'list_group_members': {
        // 🔴 Neden bu dal var: yonetici bir gruptan uye ATABILIYOR
        // (`remove_group_member`) ama kimin uye oldugunu GOREMIYORDU.
        //   * `0115_profile_titles.sql:103` — `group_member_directory` cagirani
        //     `is_group_member` ile suzer, uye olmayana `42501` doner.
        //   * `0001_initial_schema.sql:156` — `members_select` politikasi da
        //     `is_group_member(group_id)`; yonetici icin SELECT istisnasi yok.
        // Bu dal `supabaseAdmin` (service role) ile calisir, yani RLS'i asar,
        // ve yukaridaki yonetici kapisinin ARKASINDADIR. RLS'e kalici bir
        // yonetici istisnasi acilmadi: `is_group_member` bu depoda cok yerde
        // kullaniliyor, oraya acilan istisna butun yuzeyleri etkilerdi.
        const { data: memberRows, error: memberError } = await supabaseAdmin
          .from('group_members')
          .select('user_id, joined_at, left_at')
          .eq('group_id', targetGroupId)
        if (memberError) throw memberError

        const rows = memberRows ?? []
        const userIds = rows.map((row) => row.user_id)
        if (userIds.length === 0) {
          result = []
          break
        }

        const { data: profileRows, error: profileError } = await supabaseAdmin
          .from('profiles')
          .select(
            'id, display_name, avatar_url, created_at, daily_goal_minutes, animal, monthly_report_opt_in, title_achievement_id',
          )
          .in('id', userIds)
        if (profileError) throw profileError

        const profileById = new Map(
          (profileRows ?? []).map((profile) => [profile.id, profile]),
        )

        // 🔴 Engellenen uye kurali (0115) BURADA UYGULANMAZ ve orada da
        // degistirilmedi: kamp atesinde engellenen kisi satirda kalir ama
        // kimligi bosalir. Moderasyon gorunumu bunun tersini ister —
        // yoneticinin kisisel engel listesi kimi attigini gormesini
        // engellememeli. Ayrim bilinclidir: bu dal yalniz yoneticiye acik.
        result = rows
          .map((row) => {
            const profile = profileById.get(row.user_id)
            return {
              id: row.user_id,
              // Profil satiri silinmis olabilir; uye yine de LISTELENIR,
              // yoksa yonetici atayamadigi bir hayalet uyeyle kalir.
              display_name: profile?.display_name ?? '',
              avatar_url: profile?.avatar_url ?? null,
              created_at: profile?.created_at ?? row.joined_at,
              daily_goal_minutes: profile?.daily_goal_minutes ?? null,
              animal: profile?.animal ?? null,
              monthly_report_opt_in: profile?.monthly_report_opt_in ?? false,
              title_achievement_id: profile?.title_achievement_id ?? null,
              is_active: row.left_at === null,
              joined_at: row.joined_at,
              left_at: row.left_at,
            }
          })
          .sort((a, b) =>
            (a.display_name || a.id).localeCompare(b.display_name || b.id, 'tr'),
          )
        break
      }
      case 'remove_group_member': {
        const { error } = await supabaseAdmin
          .from('group_members')
          .delete()
          .eq('group_id', targetGroupId)
          .eq('user_id', targetUserId)
        if (error) throw error
        result = { success: true }
        break
      }
      case 'reset_group_name': {
        const { data: group, error: groupReadError } = await supabaseAdmin
          .from('groups')
          .select('name')
          .eq('id', targetGroupId)
          .single()
        if (groupReadError) throw groupReadError
        const { error: resetError } = await supabaseAdmin
          .from('moderation_name_resets')
          .upsert(
            { target_type: 'group', target_id: targetGroupId, previous_name: group.name, reset_by: user.id },
            { onConflict: 'target_type,target_id', ignoreDuplicates: true },
          )
        if (resetError) throw resetError
        const { error } = await supabaseAdmin
          .from('groups')
          .update({ name: 'Adsız grup' })
          .eq('id', targetGroupId)
        if (error) throw error
        result = { success: true }
        break
      }
      case 'restore_group_name': {
        const { data: reset, error: resetReadError } = await supabaseAdmin
          .from('moderation_name_resets')
          .select('previous_name')
          .eq('target_type', 'group')
          .eq('target_id', targetGroupId)
          .single()
        if (resetReadError) throw resetReadError
        const { error } = await supabaseAdmin
          .from('groups')
          .update({ name: reset.previous_name })
          .eq('id', targetGroupId)
        if (error) throw error
        const { error: deleteError } = await supabaseAdmin
          .from('moderation_name_resets')
          .delete()
          .eq('target_type', 'group')
          .eq('target_id', targetGroupId)
        if (deleteError) throw deleteError
        result = { success: true }
        break
      }
      default:
        throw new Error('Unknown action: ' + action)
    }

    // Audit log — salt-okuma eylemi denetim kaydi yazmaz (WP-F).
    if (!isReadOnly) {
      const { error: auditError } = await supabaseAdmin
        .from('admin_audit_logs')
        .insert({
          admin_id: user.id,
          target_user_id: targetUserId,
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
