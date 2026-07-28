begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

select plan(4);

insert into public.class_messages (id, group_id, user_id, body, created_at)
values
  ('40000000-0000-0000-0000-000000000001', :'grp'::uuid, :'alpha'::uuid, 'önce', now() - interval '2 minutes'),
  ('40000000-0000-0000-0000-000000000002', :'grp'::uuid, :'beta'::uuid, 'hedef mesaj', now()),
  ('40000000-0000-0000-0000-000000000003', :'grp'::uuid, :'alpha'::uuid, 'sonra', now() + interval '2 minutes');

insert into public.ugc_reports (id, reporter_id, target_type, target_id, reason, details, content_snapshot)
values ('50000000-0000-0000-0000-000000000001', :'alpha'::uuid, 'message',
        '40000000-0000-0000-0000-000000000002', 'hate', 'serbest açıklama', 'tam içerik');

set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);
select throws_ok(
  $$select public.admin_ugc_report_detail('50000000-0000-0000-0000-000000000001')$$,
  '42501', 'not_super_admin', 'super-admin olmayan detay RPC''sini çağıramaz'
);
reset role;

insert into public.app_admins (user_id) values (:'alpha'::uuid) on conflict do nothing;
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select is(
  public.admin_ugc_report_detail('50000000-0000-0000-0000-000000000001')->'report'->>'content_snapshot',
  'tam içerik', 'tam content snapshot kesilmeden döner'
);
select is(
  jsonb_array_length(public.admin_ugc_report_detail('50000000-0000-0000-0000-000000000001')->'context'),
  3, 'hedef mesajın bağlamı döner'
);
select is(
  public.admin_ugc_report_detail('50000000-0000-0000-0000-000000000001')->'history'->>'report_count',
  '1', 'hedef rapor geçmişi sayılır'
);

reset role;
select * from finish();
rollback;
