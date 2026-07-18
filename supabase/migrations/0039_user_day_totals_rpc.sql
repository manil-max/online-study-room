--0039_user_day_totals_rpc.sql
-- Kişisel gün toplamları (WP-161)
-- user_study_day tablosu ERTELENDİ; mevcut study_sessions üzerinden aggregate.
-- Kolon: study_sessions.start_time (0001; s.start diye bir kolon yok).
-- SECURITY DEFINER + search_path; yalnız auth.uid() kendi verisini görür.
-- Geri alma: drop function public.get_user_day_totals(date, date);

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
  'WP-161: personal day totals Istanbul calendar; self-only via auth.uid()';
