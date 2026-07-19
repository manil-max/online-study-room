-- 0054_group_avatar_cleanup_fix.sql
-- beta-v41 · Grup avatarı yükleme/değiştirme hatası düzeltmesi (plan WP-H).
--
-- Sorun: 0049'daki `cleanup_group_avatar_object` trigger'ı, avatar_path değişince
-- veya grup silinince eski nesneyi `DELETE FROM storage.objects` ile doğrudan
-- siliyordu. Güncel Supabase Storage bu doğrudan silmeyi yasakladı:
--   "Direct deletions from storage tables is not allowed, use the storage API."
-- Bu yüzden avatar UPDATE'i (dolayısıyla yükleme) PostgrestException ile
-- başarısız oluyor ("Grup fotoğrafı güncellenemedi: ...").
--
-- Çözüm: DB tarafındaki doğrudan storage silmesini kaldır. Eski nesne temizliği
-- artık istemcinin sorumluluğu (Storage API `remove()` — `uploadGroupAvatar`
-- başarılı değişimden sonra eski path'i siler) + periyodik storage-audit.
-- Trigger + fonksiyon düşürülür; `groups.avatar_path` UPDATE'i artık serbest.
--
-- Geri alma (Rollback): 0049'daki `cleanup_group_avatar_object` fonksiyonu ve
-- `groups_cleanup_avatar_object` trigger'ı yeniden oluşturulabilir; ancak güncel
-- Storage doğrudan silmeyi yasakladığından bu, avatar değişimini yeniden kırar.
-- Bu migration ileri-yönlüdür; geri almak yerine istemci temizliği korunmalıdır.

drop trigger if exists groups_cleanup_avatar_object on public.groups;
drop function if exists public.cleanup_group_avatar_object();

notify pgrst, 'reload schema';
