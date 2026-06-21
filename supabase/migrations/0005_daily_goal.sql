-- =====================================================================
-- 0005_daily_goal.sql — Günlük çalışma hedefi (profiles.daily_goal_minutes)
-- Bkz. project.md §3.7. Seri (streak) ve hedef ilerleme bu değere bağlı.
--
-- Olmadan: hedef her zaman varsayılan (360 dk) görünür ve düzenleme kalıcı olmaz.
--
-- Çalıştırma: Supabase paneli → SQL Editor → New query → yapıştır → Run.
-- =====================================================================

alter table public.profiles
  add column if not exists daily_goal_minutes integer not null default 360;
