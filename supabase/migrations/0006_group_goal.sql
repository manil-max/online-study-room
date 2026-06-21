-- =====================================================================
-- 0006_group_goal.sql — Grup günlük hedefi (groups.daily_goal_minutes)
-- Bkz. project.md §3.4/§3.7. Grup için ortak günlük hedef (dakika): grubun o
-- günkü TOPLAM çalışması bu değere ulaşırsa "grup hedefi tutuldu" sayılır;
-- grup serisi (streak) ve grup hedef ilerlemesi buna göre hesaplanır.
--
-- Hedefi yalnızca admin (groups.created_by) değiştirebilir — mevcut
-- `groups_update` RLS politikası (0004) tüm sütunları kapsadığı için ek
-- politika gerekmez.
--
-- Olmadan: grup hedefi her zaman varsayılan (360 dk) görünür ve düzenleme
-- kalıcı olmaz.
--
-- Çalıştırma: Supabase paneli → SQL Editor → New query → yapıştır → Run.
-- =====================================================================

alter table public.groups
  add column if not exists daily_goal_minutes integer not null default 360;
