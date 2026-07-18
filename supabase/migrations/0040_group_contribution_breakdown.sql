--0040_group_contribution_breakdown.sql
-- Grup üye katkı payı (WP-161)
-- Kolon: study_sessions.start_time (0001).
-- Yalnız aktif grup üyesi çağırabilir; ham oturum satırı döndürmez.
-- Geri alma: drop function public.group_contribution_breakdown(uuid, date, date);
--           drop function public.group_leaderboard_series(uuid, date, date);

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

-- Liderlik zaman serisi: gün × kullanıcı saniye (aggregate only).
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
  'WP-161: member contribution seconds in range; member-only';
comment on function public.group_leaderboard_series(uuid, date, date) is
  'WP-161: per-day member seconds for history charts; member-only';
