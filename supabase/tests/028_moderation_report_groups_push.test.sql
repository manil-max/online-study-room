begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'

select plan(6);

insert into public.app_admins (user_id) values (:'alpha'::uuid)
on conflict do nothing;

insert into public.ugc_reports (
  reporter_id, target_type, target_id, reason, content_snapshot
)
select
  :'beta'::uuid,
  'message',
  'same-message',
  'reason-' || value::text,
  'aynı içerik'
from generate_series(1, 10) as value;

select is(
  (select count(*) from public.notification_outbox
   where event_key like 'ugc-report:%'),
  1::bigint,
  'on şikâyet aynı açık vaka için yalnız bir admin push üretir'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select is(
  (select report_count from public.admin_ugc_report_groups()
   where target_type = 'message' and target_id = 'same-message'),
  10::bigint,
  'on şikâyet yöneticiye tek grupta sayılır'
);
select is(
  (select cardinality(reasons) from public.admin_ugc_report_groups()
   where target_type = 'message' and target_id = 'same-message'),
  10,
  'farklı gerekçeler grup içinde kaybolmaz'
);
select is(
  public.admin_set_ugc_report_group_status('message', 'same-message', 'resolved'),
  10::bigint,
  'tek grup işlemi bütün eşleşen raporları çözer'
);
select is(
  (select count(*) from public.ugc_reports
   where target_type = 'message' and target_id = 'same-message'
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
