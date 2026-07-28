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

    if (!targetGroupId || !reason?.trim()) {
      throw new Error('targetGroupId and reason are required')
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

    // Audit log
    const { error: auditError } = await supabaseAdmin
      .from('admin_audit_logs')
      .insert({
        admin_id: user.id,
        target_user_id: targetUserId,
        action: action,
        reason: reason || 'Gerekçe belirtilmedi',
      })
    if (auditError) throw auditError

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
