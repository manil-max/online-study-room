-- 0097_moderation_report_detail.sql
-- WP-425: Süper-admin için tam şikâyet içeriği, mesaj bağlamı ve hedef geçmişi.
--
-- İşleyiş: yalnız super-admin çağırabilir; mesaj hedefinde +/-5 konuşma satırı,
-- tüm hedeflerde önceki rapor sayısı/yaptırım denetimi döner. Ek yalnız private
-- yol olarak döner; istemci signed URL üretirken Storage RLS yeniden doğrular.
--
-- Geri alma (Rollback): drop function if exists public.admin_ugc_report_detail(uuid);

create or replace function public.admin_ugc_report_detail(p_report_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_report public.ugc_reports%rowtype;
  v_message public.class_messages%rowtype;
  v_context jsonb := '[]'::jsonb;
  v_history jsonb := '{}'::jsonb;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;

  select * into v_report from public.ugc_reports where id = p_report_id;
  if not found then
    raise exception 'ugc_report_not_found';
  end if;

  if v_report.target_type = 'message'
    and v_report.target_id ~* '^[0-9a-f-]{36}$' then
    select * into v_message
    from public.class_messages
    where id = v_report.target_id::uuid;

    if found then
      select coalesce(jsonb_agg(row_data order by created_at), '[]'::jsonb)
      into v_context
      from (
        select m.created_at,
          jsonb_build_object(
            'id', m.id, 'user_id', m.user_id, 'body', m.body,
            'created_at', m.created_at, 'display_name', p.display_name,
            'avatar_url', p.avatar_url, 'is_target', m.id = v_message.id
          ) as row_data
        from public.class_messages m
        left join public.profiles p on p.id = m.user_id
        where m.group_id = v_message.group_id
          and m.created_at between v_message.created_at - interval '1 day'
                               and v_message.created_at + interval '1 day'
        order by abs(extract(epoch from (m.created_at - v_message.created_at))), m.created_at
        limit 11
      ) nearby;
    end if;
  end if;

  select jsonb_build_object(
    'report_count', (
      select count(*) from public.ugc_reports r
      where r.target_type = v_report.target_type and r.target_id = v_report.target_id
    ),
    'sanctions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'action', audit.action, 'reason', audit.reason, 'created_at', audit.created_at
      ) order by audit.created_at desc)
      from public.admin_audit_logs audit
      where audit.target_user_id::text = v_report.target_id
    ), '[]'::jsonb)
  ) into v_history;

  return jsonb_build_object(
    'report', jsonb_build_object(
      'id', v_report.id, 'target_type', v_report.target_type,
      'target_id', v_report.target_id, 'reason', v_report.reason,
      'details', v_report.details, 'content_snapshot', v_report.content_snapshot,
      'attachment_path', v_report.attachment_path, 'status', v_report.status,
      'created_at', v_report.created_at
    ),
    'context', v_context,
    'history', v_history
  );
end;
$$;

revoke all on function public.admin_ugc_report_detail(uuid) from public, anon;
grant execute on function public.admin_ugc_report_detail(uuid) to authenticated;

comment on function public.admin_ugc_report_detail(uuid) is
  'WP-425: super-admin-only moderation detail with full snapshot, +/-5 message context and target history.';
