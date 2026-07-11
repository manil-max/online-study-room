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

    let result = null

    switch (action) {
      case 'delete_group': {
        const { error } = await supabaseAdmin
          .from('study_groups')
          .delete()
          .eq('id', targetGroupId)
        if (error) throw error
        result = { success: true }
        break
      }
      case 'remove_group_member': {
        const { error } = await supabaseAdmin
          .from('study_group_members')
          .delete()
          .eq('group_id', targetGroupId)
          .eq('user_id', targetUserId)
        if (error) throw error
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
    if (auditError) console.error('Audit Log Error:', auditError)

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
