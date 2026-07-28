begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

select plan(8);

select is(public.normalize_public_name(' A_M-K '), 'amk', 'separator and Turkish normalization is deterministic');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$update public.profiles set display_name = 'a_m-k' where id = '10000000-0000-0000-0000-000000000001'$$,
  'P0001', 'public_name_not_allowed', 'profile update rejects an obfuscated blocked term'
);
select lives_ok(
  $$update public.profiles set display_name = 'Çiğdem' where id = '10000000-0000-0000-0000-000000000001'$$,
  'legitimate Turkish display name is accepted'
);
select throws_ok(
  $$select public.create_group_with_access('f.u_c-k', 'private', 2, 'Europe/Istanbul')$$,
  'P0001', 'public_name_not_allowed', 'group creation rejects an obfuscated blocked term'
);
select throws_ok(
  $$update public.groups set name = 'bad shit' where id = '20000000-0000-0000-0000-000000000001'$$,
  'P0001', 'public_name_not_allowed', 'group rename rejects a blocked term server-side'
);
select lives_ok(
  $$update public.groups set name = 'Odak Arkadaşları' where id = '20000000-0000-0000-0000-000000000001'$$,
  'legitimate group rename is accepted'
);
reset role;
set local role authenticated;
select throws_ok(
  $$select * from public.public_name_blocked_terms$$,
  '42501', null, 'blocked-term data is not readable by ordinary users'
);
reset role;
select ok(
  exists (select 1 from public.groups where id = '20000000-0000-0000-0000-000000000001'),
  'existing groups are not retroactively deleted'
);
select * from finish();
rollback;
