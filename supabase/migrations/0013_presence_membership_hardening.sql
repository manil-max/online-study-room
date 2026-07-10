-- =====================================================================
-- 0013_presence_membership_hardening.sql — Presence yazımı üyelik doğrulaması
-- Bkz. Güvenlik denetimi: presence insert/update politikaları kimliği
-- kontrol ediyordu, ancak group_id'nin kullanıcının aktif üyesi olduğu bir
-- gruba ait olduğunu zorlamıyordu.
--
-- SORUN (öncesi):
--   • Kullanıcı kendi user_id'siyle, üyesi olmadığı bir group_id'ye presence
--     yazabiliyordu. Bu, o grubun üyelerinin canlı ekranda sahte bir çalışma
--     durumu görmesine yol açabilirdi.
--
-- ÇÖZÜM:
--   • presence insert/update with check koşulları artık hem user_id = auth.uid()
--     hem de group_id null veya public.is_group_member(group_id) olmasını ister.
--   • public.is_group_member 0008 sonrasında yalnız aktif üyeliği sayar
--     (left_at is null), bu yüzden gruptan çıkan kullanıcı eski gruba presence
--     yazamaz.
--
-- Not: presence_select politikasına dokunulmaz; zaten is_group_member(group_id)
-- kullanarak yalnız aktif grup üyelerine okuma izni verir.
--
-- Çalıştırma: Supabase paneli → SQL Editor → New query → yapıştır → Run.
-- =====================================================================

-- Presence yazımı: kişi yalnız KENDİ satırını ve yalnız AKTİF üyesi olduğu
-- gruba yazabilir. group_id null = grupsuz/offline durumlar için izinli.
drop policy if exists presence_upsert on public.presence;
create policy presence_upsert on public.presence
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (group_id is null or public.is_group_member(group_id))
  );

drop policy if exists presence_update on public.presence;
create policy presence_update on public.presence
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and (group_id is null or public.is_group_member(group_id))
  );
