begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

-- WP-423: şikâyet/destek foto eki. Bucket private, okuma yalnız super-admin,
-- boyut ve MIME sunucuda zorlanır, ek opsiyoneldir.
\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'

select plan(16);

-- ---------------------------------------------------------------------
-- Bucket sözleşmesi
-- ---------------------------------------------------------------------
select is(
  (select public from storage.buckets where id = 'report_attachments'),
  false,
  'rapor eki bucket''ı public DEĞİL'
);

select is(
  (select file_size_limit from storage.buckets where id = 'report_attachments'),
  5242880::bigint,
  'bucket 5 MB boyut sınırını sunucuda taşır'
);

select is(
  (select allowed_mime_types from storage.buckets where id = 'report_attachments'),
  array['image/jpeg', 'image/png', 'image/webp'],
  'bucket yalnız resim MIME türlerine izin verir'
);

-- 🔴 avatars bucket'ı yeniden kullanılmadı: o public, bu değil.
select ok(
  (select public from storage.buckets where id = 'avatars')
    is distinct from (select public from storage.buckets where id = 'report_attachments'),
  'rapor eki public avatars bucket''ından ayrı tutuldu'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'report_attachments_select_admin'
      and qual like '%is_super_admin%'
  ),
  'ek okuma politikası super-admin şartı taşır (imzalı URL de buradan geçer)'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'report_attachments_insert_own'
      and with_check like '%auth.uid()%'
  ),
  'yükleme yalnız kullanıcının kendi klasörüne'
);

-- ---------------------------------------------------------------------
-- Sunucu kapısı: sahiplik / varlık / boyut / MIME
-- ---------------------------------------------------------------------
-- Geçerli ek: alpha'nın klasöründe 1 MB'lık bir PNG.
insert into storage.objects (bucket_id, name, owner, metadata)
values (
  'report_attachments',
  :'alpha' || '/valid.png',
  :'alpha'::uuid,
  '{"size": 1048576, "mimetype": "image/png"}'::jsonb
);
-- Çok büyük ek: 6 MB.
insert into storage.objects (bucket_id, name, owner, metadata)
values (
  'report_attachments',
  :'alpha' || '/huge.png',
  :'alpha'::uuid,
  '{"size": 6291456, "mimetype": "image/png"}'::jsonb
);
-- Resim olmayan ek.
insert into storage.objects (bucket_id, name, owner, metadata)
values (
  'report_attachments',
  :'alpha' || '/payload.pdf',
  :'alpha'::uuid,
  '{"size": 2048, "mimetype": "application/pdf"}'::jsonb
);
-- Başkasının klasöründeki ek.
insert into storage.objects (bucket_id, name, owner, metadata)
values (
  'report_attachments',
  :'beta' || '/other.png',
  :'beta'::uuid,
  '{"size": 2048, "mimetype": "image/png"}'::jsonb
);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select is(
  public.assert_report_attachment_allowed(null),
  null,
  'ek opsiyoneldir — yol yoksa kapı sessizce geçer'
);

select throws_ok(
  format($$select public.report_ugc('user', %L, 'spam', null, null, %L)$$,
         :'beta', :'alpha' || '/huge.png'),
  'P0001', 'attachment_too_large', '5 MB üstü ek sunucuda reddedilir'
);

select throws_ok(
  format($$select public.report_ugc('user', %L, 'spam', null, null, %L)$$,
         :'beta', :'alpha' || '/payload.pdf'),
  'P0001', 'attachment_type_not_allowed', 'resim olmayan dosya sunucuda reddedilir'
);

select throws_ok(
  format($$select public.report_ugc('user', %L, 'spam', null, null, %L)$$,
         :'beta', :'beta' || '/other.png'),
  'P0001', 'attachment_not_owned', 'başkasının klasöründeki ek reddedilir'
);

select throws_ok(
  format($$select public.report_ugc('user', %L, 'spam', null, null, %L)$$,
         :'beta', :'alpha' || '/hayalet.png'),
  'P0001', 'attachment_missing', 'var olmayan yol uydurulamaz'
);

-- Eksiz şikâyet: ek yükleme başarısız olsa da şikâyet gönderilebilmeli.
select isnt(
  (select public.report_ugc('user', :'beta', 'spam', 'eksiz', null, null)),
  null,
  'ek olmadan şikâyet gönderilebilir'
);

-- Geçerli ek kaydedilir.
select is(
  (select public.report_ugc('user', :'beta', 'hate', null, null,
                            :'alpha' || '/valid.png')
   is not null),
  true,
  'geçerli resim eki kabul edilir'
);

select is(
  (select attachment_path from public.ugc_reports
    where reporter_id = :'alpha'::uuid and reason = 'hate'),
  :'alpha' || '/valid.png',
  'kabul edilen ek şikâyet satırına yazılır'
);

-- 0090 sözleşmesi korunur ve ek bilete de taşınır (Lane B WP-425 oradan okur).
select is(
  (
    select t.attachment_path
    from public.feedback_tickets t
    join public.ugc_reports r on r.id = t.ugc_report_id
    where r.reporter_id = :'alpha'::uuid and r.reason = 'hate'
  ),
  :'alpha' || '/valid.png',
  'şikâyete bağlı destek bileti aynı eki taşır'
);

-- Destek sorusu da aynı kapıdan geçer.
select throws_ok(
  format($$select public.submit_faq_question('Bu bir destek sorusu', %L)$$,
         :'alpha' || '/payload.pdf'),
  'P0001', 'attachment_type_not_allowed',
  'destek sorusu eki de sunucuda doğrulanır'
);

reset role;
select * from finish();
rollback;
