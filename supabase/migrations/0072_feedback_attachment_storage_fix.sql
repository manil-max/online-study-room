-- 0072_feedback_attachment_storage_fix.sql
-- WP-316: Eksik private geri bildirim görsel bucket'ını ve RLS sözleşmesini ileri migration olarak kurar.
--
-- Production salt-okunur teşhisinde `feedback_tickets.attachment_path` ve
-- `is_super_admin()` mevcutken `feedback_attachments` bucket'ının bulunmadığı
-- doğrulandı. Bucket private kalır; kullanıcı yalnız kendi klasörüne yükler,
-- kendi ekini okur, süper-admin tüm ekleri okuyabilir.
--
-- Geri alma (Rollback): Yeni kurulum geri alınacaksa aşağıdaki iki policy
-- düşürülür. Bucket/veri otomatik silinmez:
-- drop policy if exists "kullanici_kendi_ekini_yukleyebilir" on storage.objects;
-- drop policy if exists "kullanici_ve_admin_ekleri_okuyabilir" on storage.objects;

alter table public.feedback_tickets
  add column if not exists attachment_path text;

insert into storage.buckets (id, name, public)
values ('feedback_attachments', 'feedback_attachments', false)
on conflict (id) do update
set name = excluded.name,
    public = false;

drop policy if exists "kullanici_kendi_ekini_yukleyebilir"
  on storage.objects;
create policy "kullanici_kendi_ekini_yukleyebilir"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'feedback_attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "kullanici_ve_admin_ekleri_okuyabilir"
  on storage.objects;
create policy "kullanici_ve_admin_ekleri_okuyabilir"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'feedback_attachments'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_super_admin()
  )
);
