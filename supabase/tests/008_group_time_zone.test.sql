begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir _fixtures/base_seed.psql

select plan(8);

select is(
  (select time_zone from public.groups where id = '20000000-0000-0000-0000-000000000001'),
  'Europe/Istanbul',
  'existing groups keep the Istanbul default time zone'
);

select ok(
  to_regprocedure('public.update_group_time_zone(uuid,text)') is not null
    and has_function_privilege(
      'authenticated', 'public.update_group_time_zone(uuid,text)', 'execute'
    ),
  'guarded group time-zone RPC is available to authenticated users'
);

select ok(
  public.is_valid_group_time_zone('America/New_York')
    and public.is_valid_group_time_zone('Asia/Kolkata')
    and not public.is_valid_group_time_zone('-5')
    and not public.is_valid_group_time_zone('not-an-iana-zone'),
  'only IANA names (or UTC) are accepted; fixed offsets are rejected'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (select time_zone from public.update_group_time_zone(
    '20000000-0000-0000-0000-000000000001', 'America/New_York'
  )),
  'America/New_York',
  'group admin can set an IANA time zone'
);

select throws_ok(
  $$select public.update_group_time_zone(
    '20000000-0000-0000-0000-000000000001', '-5'
  )$$,
  'P0001',
  'invalid_group_time_zone',
  'admin cannot store a fixed UTC offset'
);

select is(
  (select time_zone from public.create_group_with_access(
    'New York fixture', 'private', 8, 'America/New_York'
  )),
  'America/New_York',
  'new group creation persists the chosen time zone transactionally'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);

select throws_ok(
  $$select public.update_group_time_zone(
    '20000000-0000-0000-0000-000000000001', 'Asia/Tokyo'
  )$$,
  'P0001',
  'not_group_admin',
  'ordinary group member cannot change the group time zone'
);

reset role;

select is(
  (select (timestamp with time zone '2026-07-01 03:30:00+00'
    at time zone 'America/New_York')::date),
  date '2026-06-30',
  'New York day boundary uses daylight-saving-aware IANA conversion'
);

select * from finish();
rollback;
