begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set msg   '40000000-0000-0000-0000-000000000010'
\set case  '60000000-0000-0000-0000-000000000001'

select plan(6);

insert into public.app_admins (user_id) values (:'alpha'::uuid)
on conflict do nothing;

-- 🔴 WP-473: bu dosya WP-428 (`0100`) sözleşmesine göre yazılmıştı ve `0104`
-- vaka sözleşmesini getirince sessizce anlamsızlaştı. Artık hem admin push'u
-- hem de toplu durum değişimi **vaka üzerinden** yürür: tetikleyici
-- `case_id is null` olan satırı atlar ve `admin_set_ugc_report_group_status`
-- `case_id in (...)` ile günceller. Doğrudan eklenen vakasız satırlar bu yüzden
-- sıfır push ve sıfır güncelleme veriyordu — test yeşil kalsaydı bile hiçbir
-- şeyi kanıtlamıyordu. Şikâyetler şimdi gerçek bir açık vakaya bağlanıyor;
-- hedef kimliği de `0104`'ün beklediği gibi uuid.
insert into public.moderation_cases (id, target_type, target_id, status)
values (:'case'::uuid, 'message', :'msg', 'open');

insert into public.ugc_reports (
  reporter_id, target_type, target_id, reason, content_snapshot, case_id
)
select
  :'beta'::uuid,
  'message',
  :'msg',
  'reason-' || value::text,
  'aynı içerik',
  :'case'::uuid
from generate_series(1, 10) as value;

select is(
  (select count(*) from public.notification_outbox
   where event_key like 'ugc-case:%'),
  1::bigint,
  'on şikâyet aynı açık vaka için yalnız bir admin push üretir'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select is(
  (select report_count from public.admin_ugc_report_groups()
   where target_type = 'message' and target_id = :'msg'),
  10::bigint,
  'on şikâyet yöneticiye tek grupta sayılır'
);
select is(
  (select cardinality(reasons) from public.admin_ugc_report_groups()
   where target_type = 'message' and target_id = :'msg'),
  10,
  'farklı gerekçeler grup içinde kaybolmaz'
);
select is(
  public.admin_set_ugc_report_group_status('message', :'msg', 'resolved'),
  10::bigint,
  'tek grup işlemi bütün eşleşen raporları çözer'
);
select is(
  (select count(*) from public.ugc_reports
   where target_type = 'message' and target_id = :'msg'
     and status = 'resolved'),
  10::bigint,
  'gruptaki her raporun durumu güncellenir'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);
select throws_ok(
  $$select public.admin_ugc_report_groups()$$,
  '42501', 'not_super_admin',
  'süper-admin olmayan kişi gruplanmış şikâyet kuyruğunu okuyamaz'
);
reset role;

select * from finish();
rollback;
