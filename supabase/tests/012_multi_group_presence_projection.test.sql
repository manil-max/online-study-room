begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql
select plan(12);

select ok(
  to_regclass('public.user_live_presence_state') is not null
    and to_regclass('public.group_live_presence') is not null
    and to_regprocedure('public.apply_multi_group_presence_state(text,timestamp with time zone,integer,uuid)') is not null,
  'WP-338 exposes canonical state, projection and guarded state RPC'
);
select ok(
  not has_table_privilege('authenticated', 'public.user_live_presence_state', 'insert')
    and not has_table_privilege('authenticated', 'public.group_live_presence', 'insert'),
  'authenticated clients cannot directly write state or group projections'
);

insert into public.groups (id, name, invite_code, created_by, created_at)
values ('20000000-0000-0000-0000-000000000020', 'Presence Secondary', 'PRESENCE20',
  '10000000-0000-0000-0000-000000000001', clock_timestamp());
insert into public.group_members (group_id, user_id, role, joined_at)
values ('20000000-0000-0000-0000-000000000020',
  '10000000-0000-0000-0000-000000000001', 'admin', clock_timestamp());

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select public.apply_multi_group_presence_state('studying', clock_timestamp(), 120, null);
reset role;

select is(
  (select count(*)::integer from public.group_live_presence
    where user_id = '10000000-0000-0000-0000-000000000001'),
  2,
  'one active state fans out once to every active membership'
);
select is(
  (select count(*)::integer from public.group_live_presence
    where user_id = '10000000-0000-0000-0000-000000000001'
      and counts_for_group_progression),
  1,
  'exactly one active projection is marked for group progression'
);
select ok(
  exists (
    select 1 from public.group_live_presence
    where group_id = '20000000-0000-0000-0000-000000000001'
      and user_id = '10000000-0000-0000-0000-000000000001'
      and counts_for_group_progression
  ) and exists (
    select 1 from public.group_live_presence
    where group_id = '20000000-0000-0000-0000-000000000020'
      and user_id = '10000000-0000-0000-0000-000000000001'
      and not counts_for_group_progression
  ),
  'primary and secondary projections retain distinct progression flags'
);

insert into public.groups (id, name, invite_code, created_by, created_at)
values ('20000000-0000-0000-0000-000000000021', 'Presence Primary Switch', 'PRESENCE21',
  '10000000-0000-0000-0000-000000000001', clock_timestamp());
insert into public.group_members (group_id, user_id, role, joined_at)
values ('20000000-0000-0000-0000-000000000021',
  '10000000-0000-0000-0000-000000000001', 'admin', clock_timestamp());
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select public.set_primary_group('20000000-0000-0000-0000-000000000021', 1);
reset role;
select ok(
  exists (
    select 1 from public.group_live_presence
    where group_id = '20000000-0000-0000-0000-000000000021'
      and user_id = '10000000-0000-0000-0000-000000000001'
      and counts_for_group_progression
  ) and not exists (
    select 1 from public.group_live_presence
    where group_id = '20000000-0000-0000-0000-000000000001'
      and user_id = '10000000-0000-0000-0000-000000000001'
      and counts_for_group_progression
  ),
  'primary-preference change reflags the active projection without a heartbeat fan-out'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select ok(
  not exists (
    select 1 from public.group_live_presence
    where group_id = '20000000-0000-0000-0000-000000000021'
  ),
  'RLS hides a projection from users without an active shared membership'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select public.heartbeat_multi_group_presence();
reset role;
select is(
  (select state_version from public.user_live_presence_state
    where user_id = '10000000-0000-0000-0000-000000000001'),
  1::bigint,
  'heartbeat renews the canonical lease without a state transition'
);
select is(
  (select max(state_version) from public.group_live_presence
    where user_id = '10000000-0000-0000-0000-000000000001'),
  1::bigint,
  -- WP-367: heartbeat artık fan-out lease'ini tazeler (bkz. 015), ama hâlâ bir
  -- durum geçişi değildir: state_version'ı bump etmez.
  'heartbeat does not bump the fan-out projection state_version'
);

update public.group_members
set left_at = clock_timestamp()
where group_id = '20000000-0000-0000-0000-000000000020'
  and user_id = '10000000-0000-0000-0000-000000000001';
select ok(
  not exists (
    select 1 from public.group_live_presence
    where group_id = '20000000-0000-0000-0000-000000000020'
      and user_id = '10000000-0000-0000-0000-000000000001'
  ),
  'membership leave removes the former group projection immediately'
);

update public.user_live_presence_state
set lease_expires_at = clock_timestamp() - interval '1 second'
where user_id = '10000000-0000-0000-0000-000000000001';
select is(public.expire_multi_group_presence_leases(10), 1,
  'locked sweeper transitions one expired canonical state');
select ok(
  not exists (
    select 1 from public.group_live_presence
    where user_id = '10000000-0000-0000-0000-000000000001'
  ) and (select status from public.user_live_presence_state
    where user_id = '10000000-0000-0000-0000-000000000001') = 'offline',
  'expiry clears all projections exactly once'
);

select * from finish();
rollback;
