-- 0055_group_avatar_read_policy_fix.sql
-- beta-v41 · Grup avatarı OKUMA (signed URL) düzeltmesi.
--
-- Sorun: 0049'daki `group_avatars_member_read` SELECT politikası, alt sorgu
-- içinde niteliksiz `name` kolonuna dayanıyordu:
--   exists (select 1 from public.groups g
--           where g.id::text = (storage.foldername(name))[1] ...)
-- Alt sorguda hem `storage.objects.name` hem `public.groups.name` kapsamda
-- olduğu için PostgreSQL niteliksiz `name`'i en içteki tabloya (`g.name`) bağladı.
-- Yani politika `storage.foldername(g.name)` — grubun ADINI klasör sanıyordu
-- (ör. "deneme01" → boş dizi → [1] = NULL → hiçbir grupla eşleşmez).
-- Sonuç: signed URL üretimi (storage SELECT) HER grup için reddediliyordu; avatar
-- yüklenip DB'ye yazılsa da uygulama okuyamayıp baş harfe düşüyordu.
-- Yükleme çalışıyordu çünkü INSERT/UPDATE/DELETE politikalarında alt sorgu yok;
-- `name` doğru şekilde `storage.objects.name`'e bağlanıyor.
--
-- Çözüm: Nesne yolundan klasör (grup id) çıkarımını alt sorgunun DIŞINA taşı ve
-- `in (...)` ile karşılaştır. Böylece alt sorgu `name`'e hiç dokunmaz; belirsizlik
-- ortadan kalkar. Davranış 0049'daki asıl niyetle birebir aynıdır: nesne, klasörü
-- (grup id) açık bir gruba ait ya da kullanıcının üyesi olduğu bir gruba ait ise
-- okunabilir.
--
-- Not: Yalnız DB politikası düzeltilir; istemci kodu (createSignedUrl) zaten doğru.
-- Yeni APK gerekmez — mevcut beta-v41 bu migration uygulanınca avatarı gösterir.
--
-- Geri alma (Rollback): 0049'daki hatalı sürüme dönmek okumayı yeniden kırar;
-- bu migration ileri-yönlüdür.

drop policy if exists group_avatars_member_read on storage.objects;
create policy group_avatars_member_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'group-avatars'
    and array_length(storage.foldername(name), 1) >= 1
    and (storage.foldername(name))[1] in (
      select g.id::text
      from public.groups g
      where g.visibility = 'public'
        or public.is_group_member(g.id)
    )
  );

notify pgrst, 'reload schema';
