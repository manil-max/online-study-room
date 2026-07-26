begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir _fixtures/base_seed.psql

select plan(9);

select ok(
  to_regprocedure('public.set_primary_group(uuid,bigint)') is not null
    and has_function_privilege(
      'authenticated', 'public.set_primary_group(uuid,bigint)', 'execute'
    ),
  'WP-329 exposes the guarded primary-group compare-and-swap RPC'
);

select ok(
  not has_table_privilege('authenticated', 'public.user_group_preferences', 'insert')
    and not has_table_privilege('authenticated', 'public.user_group_preferences', 'update')
    and not has_table_privilege('authenticated', 'public.user_group_preference_history', 'select'),
  'preference and append-only history reject direct authenticated writes/reads'
);

select is(
  (
    select primary_group_id from public.user_group_preferences
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  '20000000-0000-0000-0000-000000000001'::uuid,
  'a single active membership is deterministically backfilled as primary'
);

insert into public.groups (id, name, invite_code, created_by, created_at)
values (
  '20000000-0000-0000-0000-000000000009',
  'Second Fixture Group',
  'PRIMARY9',
  '10000000-0000-0000-0000-000000000001',
  now()
);
insert into public.group_members (group_id, user_id, role, joined_at)
values (
  '20000000-0000-0000-0000-000000000009',
  '10000000-0000-0000-0000-000000000001',
  'admin',
  now()
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (
    select primary_group_id
    from public.set_primary_group(
      '20000000-0000-0000-0000-000000000009', 1
    )
  ),
  '20000000-0000-0000-0000-000000000009'::uuid,
  'an active member can explicitly select another primary group'
);

select is(
  (
    select selection_revision
    from public.user_group_preferences
    where user_id = auth.uid()
  ),
  2::bigint,
  'server owns and increments the selection revision'
);

select throws_ok(
  $$ select public.set_primary_group('20000000-0000-0000-0000-000000000001', 1) $$,
  'primary_group_stale_selection',
  'a stale device selection cannot overwrite the current primary group'
);

select throws_ok(
  $$ select public.set_primary_group('20000000-0000-0000-0000-000000000099', 2) $$,
  'primary_group_not_active_member',
  'a user cannot select a group without an active membership'
);

reset role;

update public.group_members
set left_at = now()
where group_id = '20000000-0000-0000-0000-000000000009'
  and user_id = '10000000-0000-0000-0000-000000000001';

select is(
  (
    select primary_group_id from public.user_group_preferences
    where user_id = '10000000-0000-0000-0000-000000000001'
  ),
  '20000000-0000-0000-0000-000000000001'::uuid,
  'leaving the primary group reconciles under the user lock to the sole remaining group'
);

select ok(
  exists (
    select 1 from public.user_group_preference_history
    where user_id = '10000000-0000-0000-0000-000000000001'
      and primary_group_id = '20000000-0000-0000-0000-000000000001'
      and reason = 'automatic_single'
  ),
  'automatic reconciliation is retained in append-only preference history'
);

select * from finish();
rollback;
