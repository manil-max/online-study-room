-- 0019_feedback_attachments.sql
-- Geri bildirimlere ekran görüntüsü (attachment) ekleme desteği.

alter table public.feedback_tickets
  add column if not exists attachment_path text;

-- Storage bucket oluştur
insert into storage.buckets (id, name, public)
values ('feedback_attachments', 'feedback_attachments', false)
on conflict (id) do nothing;

-- Storage objeleri için RLS kuralları
-- Sadece authenticated kullanıcılar dosya yükleyebilir.
-- Yükleme yolu: user_id/uuid.ext olmalıdır.

-- Migration daha önce kısmen çalışmış olabilir; politika tanımlarını her
-- çalıştırmada aynı güvenli kurallarla yeniden kur.
drop policy if exists "kullanici_kendi_ekini_yukleyebilir" on storage.objects;
create policy "kullanici_kendi_ekini_yukleyebilir"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'feedback_attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Okuma (SELECT): Kullanıcı sadece kendi klasöründekini okuyabilir, süper-adminler tüm klasörleri okuyabilir.
drop policy if exists "kullanici_ve_admin_ekleri_okuyabilir" on storage.objects;
create policy "kullanici_ve_admin_ekleri_okuyabilir"
on storage.objects for select to authenticated
using (
  bucket_id = 'feedback_attachments'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_super_admin()
  )
);
