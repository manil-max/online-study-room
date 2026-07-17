-- 0042: study_sessions zaman kolonu düzeltmesi (WP-164)
--
-- Sorun: 0040/0041 fonksiyonları `s.start` kullandı; gerçek şema kolonu
-- `start_time` (0001_initial_schema). Canlıda 0040/41 uygulanmış olabilir.
--
-- İşleyiş: CREATE OR REPLACE ile aynı imzalı fonksiyonları `start_time` ve
-- Istanbul gün sınırı ile yeniden tanımlar. SECURITY DEFINER + search_path=public.
-- Ham session satırı dönmez; yalnız aggregate.
--
-- Geri alma (rollback):
--   drop function if exists public.get_user_day_totals(date, date);
--   drop function if exists public.group_contribution_breakdown(uuid, date, date);
--   drop function if exists public.group_leaderboard_series(uuid, date, date);
--   (gerekirse 0040/0041 içeriğini bilerek yeniden uygula — start_time ile)

create or replace function public.get_user_day_totals(
  p_from date,
  p_to date
)
returns table (day date, seconds int)
language sql
security definer
set search_path = public
stable
as $$
  select
    ((s.start_time at time zone 'Europe/Istanbul')::date) as day,
    sum(s.duration_seconds)::int as seconds
  from public.study_sessions s
  where s.user_id = auth.uid()
    and ((s.start_time at time zone 'Europe/Istanbul')::date) between p_from and p_to
  group by 1
  order by 1;
$$;

grant execute on function public.get_user_day_totals(date, date) to authenticated;

comment on function public.get_user_day_totals(date, date) is
  'WP-164: personal day totals Istanbul calendar; self-only via auth.uid(); uses start_time';

create or replace function public.group_contribution_breakdown(
  p_group_id uuid,
  p_from date,
  p_to date
)
returns table (user_id uuid, seconds int)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null or not public.is_group_member(p_group_id) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  select
    s.user_id,
    sum(s.duration_seconds)::int as seconds
  from public.study_sessions s
  inner join public.group_members gm
    on gm.user_id = s.user_id
   and gm.group_id = p_group_id
   and gm.left_at is null
  where ((s.start_time at time zone 'Europe/Istanbul')::date) between p_from and p_to
  group by s.user_id
  order by seconds desc;
end;
$$;

grant execute on function public.group_contribution_breakdown(uuid, date, date)
  to authenticated;

create or replace function public.group_leaderboard_series(
  p_group_id uuid,
  p_from date,
  p_to date
)
returns table (day date, user_id uuid, seconds int)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null or not public.is_group_member(p_group_id) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  select
    ((s.start_time at time zone 'Europe/Istanbul')::date) as day,
    s.user_id,
    sum(s.duration_seconds)::int as seconds
  from public.study_sessions s
  inner join public.group_members gm
    on gm.user_id = s.user_id
   and gm.group_id = p_group_id
   and gm.left_at is null
  where ((s.start_time at time zone 'Europe/Istanbul')::date) between p_from and p_to
  group by 1, 2
  order by 1, 3 desc;
end;
$$;

grant execute on function public.group_leaderboard_series(uuid, date, date)
  to authenticated;

comment on function public.group_contribution_breakdown(uuid, date, date) is
  'WP-164: member contribution seconds; member-only; start_time';
comment on function public.group_leaderboard_series(uuid, date, date) is
  'WP-164: per-day member seconds; member-only; start_time; no raw sessions';
