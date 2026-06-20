-- =====================================================================
-- 0002_avatars_storage.sql — Profil fotoğrafları için Storage kurulumu
-- Bkz. project.md §3.2 (profil fotoğrafı) ve §7 (güvenlik).
--
-- Bu dosyayı Supabase panelinde:  SQL Editor → New query → yapıştır → Run
-- ile bir kez çalıştırın. `avatars` adında herkese açık (public) bir bucket
-- oluşturur ve kullanıcıların yalnızca KENDİ klasörlerine yazmasına izin verir.
--
-- Dosya yolu kuralı:  <kullanıcı_id>/avatar.jpg
--   → (storage.foldername(name))[1] = kullanıcının auth.uid()'si olmalı.
-- =====================================================================

-- Public bucket: avatar URL'leri herkese açık okunur (görselin gösterimi basit olur).
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

-- Okuma: herkes (giriş yapmamış olsa da) avatar görsellerini okuyabilir.
drop policy if exists avatars_public_read on storage.objects;
create policy avatars_public_read on storage.objects
  for select to public
  using (bucket_id = 'avatars');

-- Yükleme: kullanıcı yalnızca kendi id'siyle başlayan klasöre yazar.
drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Güncelleme (upsert): kendi dosyasını günceller.
drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Silme: kendi dosyasını siler.
drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
