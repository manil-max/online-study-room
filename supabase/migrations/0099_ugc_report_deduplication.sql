-- 0099_ugc_report_deduplication.sql
-- WP-427: Aynı hedef şikâyetlerini yönetici kuyruğunda tek vaka olarak toplar.
-- Geri alma (Rollback): drop function if exists public.admin_ugc_report_groups();

create or replace function public.admin_ugc_report_groups()
returns table (
  target_type text, target_id text, report_count bigint, report_ids uuid[],
  reasons text[], status text, latest_at timestamptz
)
language plpgsql security definer set search_path = public stable as $$
begin
  if not public.is_super_admin() then raise exception 'not_super_admin' using errcode = '42501'; end if;
  return query
  select r.target_type, r.target_id, count(*), array_agg(r.id order by r.created_at desc),
    array_agg(distinct r.reason),
    case when bool_or(r.status = 'open') then 'open' else max(r.status) end,
    max(r.created_at)
  from public.ugc_reports r
  group by r.target_type, r.target_id
  order by max(r.created_at) desc;
end;
$$;
revoke all on function public.admin_ugc_report_groups() from public, anon;
grant execute on function public.admin_ugc_report_groups() to authenticated;

create or replace function public.admin_set_ugc_report_group_status(
  p_target_type text, p_target_id text, p_status text
) returns bigint language plpgsql security definer set search_path = public as $$
declare v_count bigint;
begin
  if not public.is_super_admin() then raise exception 'not_super_admin' using errcode = '42501'; end if;
  if p_status not in ('in_review', 'resolved', 'rejected') then raise exception 'invalid_ugc_status'; end if;
  update public.ugc_reports set status = p_status, updated_at = now()
  where target_type = p_target_type and target_id = p_target_id;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke all on function public.admin_set_ugc_report_group_status(text, text, text) from public, anon;
grant execute on function public.admin_set_ugc_report_group_status(text, text, text) to authenticated;
