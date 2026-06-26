-- =====================================================================
-- 0011_group_daily_totals_v2.sql — RPC v2 (üyelik penceresi ile)
-- Bkz. progress.md §1B (K7). group_id kaldırıldıktan sonra
-- group_daily_totals RPC'si study_sessions ⨝ group_members join'iyle
-- çalışır. Üyelik penceresi: sadece üyenin katıldığı tarihten ayrıldığı
-- tarihe kadar olan oturumlar gruba sayılır.
--
-- İmza aynı kalır: (p_group_id uuid) → (user_id, day, seconds)
-- Dart tarafında _fetchDailyStats ve DailyStat.fromMap DEĞİŞMEZ.
--
-- SECURITY INVOKER kalır: çağıranın RLS'i geçerli (can_see_user_sessions
-- 0009'da tanımlandı; 0010'da sessions_select buna geçti).
--
-- Sıra: 0008 → 0009 → 0010 → 0011 (zorunlu).
--
-- Çalıştırma: Supabase paneli → SQL Editor → New query → yapıştır → Run.
-- =====================================================================

create or replace function public.group_daily_totals(p_group_id uuid)
returns table (
  user_id uuid,
  day date,
  seconds bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    s.user_id,
    (s.start_time at time zone 'Europe/Istanbul')::date as day,
    sum(s.duration_seconds)::bigint as seconds
  from public.study_sessions s
  join public.group_members gm
    on gm.user_id = s.user_id and gm.group_id = p_group_id
  where s.start_time >= gm.joined_at
    and (gm.left_at is null or s.start_time < gm.left_at)
  group by s.user_id, (s.start_time at time zone 'Europe/Istanbul')::date;
$$;

grant execute on function public.group_daily_totals(uuid) to authenticated;
