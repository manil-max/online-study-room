-- =====================================================================
-- 0008_membership_lifecycle.sql — Üyelik yaşam döngüsü (soft-delete)
-- Bkz. progress.md §1B (K1, K3). Üye çıkınca satır SİLİNMEZ,
-- left_at = now() yazılır → geçmiş veri ve isim korunur.
--
-- Değişiklikler:
--   1. group_members.left_at timestamptz sütunu eklenir (null = aktif üye).
--   2. is_group_member(gid) güncellenir: left_at is null koşulu eklenir.
--      Etki: ayrılan kişi gruba erişimi yitirir; kalan üyeler onun
--      satırını + geçmiş oturumlarını görmeye devam eder.
--   3. Soft-delete için UPDATE politikası: kullanıcı kendini çıkarabilir
--      VEYA admin başkasını çıkarabilir (is_group_admin ile).
--
-- Olmadan: üye çıkınca satır silinir, geçmiş veri kaybolur.
-- Sıra: 0008 → 0009 → 0010 → 0011 (zorunlu).
--
-- Çalıştırma: Supabase paneli → SQL Editor → New query → yapıştır → Run.
-- =====================================================================

-- 1) left_at sütunu: null = aktif üye, dolu = ayrılmış üye
alter table public.group_members
  add column if not exists left_at timestamptz;

-- 2) is_group_member artık yalnız AKTİF üyeliği sayar
create or replace function public.is_group_member(gid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid and user_id = auth.uid() and left_at is null
  );
$$;

-- 3) Soft-delete için UPDATE politikası
--    Kendi kendini çıkarabilir VEYA admin (is_group_admin) başkasını çıkarabilir.
--    (0004'teki members_delete politikasının aynı mantığı UPDATE'e taşınıyor.)
drop policy if exists members_update_self on public.group_members;
create policy members_update_self on public.group_members
  for update to authenticated
  using (user_id = auth.uid() or public.is_group_admin(group_id))
  with check (user_id = auth.uid() or public.is_group_admin(group_id));
