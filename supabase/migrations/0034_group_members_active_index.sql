-- 0034: Aktif üye partial index (WP-106 / R12)
--
-- group_members sorguları ve group_daily_totals join'i sıkça
-- `left_at is null` (aktif üyelik) filtreler. Partial index bu yolu hızlandırır;
-- semantik / RLS değişmez.
--
-- Not: `CONCURRENTLY` transaction içinde çalışmaz. Supabase SQL Editor'da
-- bu dosyayı tek statement olarak çalıştırın (başka BEGIN bloğu yok).
--
-- Geri alma (Rollback):
--   drop index if exists public.idx_group_members_active;

create index concurrently if not exists idx_group_members_active
  on public.group_members (group_id)
  where left_at is null;
