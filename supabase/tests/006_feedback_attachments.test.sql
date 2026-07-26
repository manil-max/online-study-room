begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir _fixtures/base_seed.psql

insert into public.app_admins (user_id)
values ('10000000-0000-0000-0000-000000000002')
on conflict (user_id) do nothing;

select plan(5);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'feedback_attachments',
      '10000000-0000-0000-0000-000000000001/own.png'
    )$$,
  'authenticated user can upload only under the own UUID folder'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'feedback_attachments',
      '10000000-0000-0000-0000-000000000002/foreign.png'
    )$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'authenticated user cannot upload under another user folder'
);

reset role;
insert into storage.objects (bucket_id, name)
values (
  'feedback_attachments',
  '10000000-0000-0000-0000-000000000002/admin.png'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);
select is(
  (select count(*) from storage.objects where bucket_id = 'feedback_attachments'),
  1::bigint,
  'normal user reads only the own attachment'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002',
  true
);
select is(
  (select count(*) from storage.objects where bucket_id = 'feedback_attachments'),
  2::bigint,
  'super-admin reads attachments from every user folder'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000099',
  true
);
select is(
  (select count(*) from storage.objects where bucket_id = 'feedback_attachments'),
  0::bigint,
  'unrelated authenticated user reads no attachment'
);

reset role;
select * from finish();
rollback;
