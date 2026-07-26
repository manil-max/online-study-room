begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir _fixtures/base_seed.psql

select plan(7);

update public.groups
set visibility = 'public', time_zone = 'Europe/Istanbul', created_at = '2026-07-01 00:00:00+00'
where id = '20000000-0000-0000-0000-000000000001';

insert into public.groups (
  id, name, invite_code, created_by, created_at, visibility, member_limit, time_zone
)
values
  ('20000000-0000-0000-0000-000000000002', 'New York nearest', 'TZTEST02',
   '10000000-0000-0000-0000-000000000001', '2026-07-03 00:00:00+00', 'public', 8, 'America/New_York'),
  ('20000000-0000-0000-0000-000000000003', 'Chicago next', 'TZTEST03',
   '10000000-0000-0000-0000-000000000001', '2026-07-02 00:00:00+00', 'public', 8, 'America/Chicago'),
  ('20000000-0000-0000-0000-000000000004', 'Full New York', 'TZTEST04',
   '10000000-0000-0000-0000-000000000001', '2026-07-04 00:00:00+00', 'public', 2, 'America/New_York');

insert into public.group_members (group_id, user_id, role, joined_at)
values
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'admin', now()),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'admin', now()),
  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'admin', now()),
  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', 'member', now());

select ok(
  to_regprocedure('public.discover_public_groups(text,text,text,boolean,integer,integer)') is not null
    and has_function_privilege(
      'authenticated',
      'public.discover_public_groups(text,text,text,boolean,integer,integer)',
      'execute'
    ),
  'WP-328 exposes the guarded six-argument discovery RPC'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (
    select id
    from public.discover_public_groups('', null, 'America/New_York', false, 0, 20)
    limit 1
  ),
  '20000000-0000-0000-0000-000000000004'::uuid,
  'same-zone groups come first and created_at breaks their tie descending'
);

select is(
  (
    select array_agg(time_zone order by id)
    from public.discover_public_groups('', 'America/New_York', 'America/New_York', true, 0, 20)
  ),
  array['America/New_York']::text[],
  'region and open-seat filters exclude other regions and full groups'
);

select ok(
  not exists (
    select 1
    from public.discover_public_groups('', null, 'America/New_York', false, 0, 20) summary
    where to_jsonb(summary) ? 'invite_code'
  ),
  'new discovery RPC still never exposes invite codes'
);

select is(
  (
    with first_page as (
      select id from public.discover_public_groups('', null, 'America/New_York', false, 0, 2)
    ), second_page as (
      select id from public.discover_public_groups('', null, 'America/New_York', false, 2, 2)
    )
    select count(*)::integer from (select id from first_page intersect select id from second_page) overlap
  ),
  0,
  'stable sort keys prevent pagination overlap'
);

select ok(
  exists (
    select 1
    from public.discover_public_groups('', null, 'not-a-zone', false, 0, 20)
  ),
  'invalid user zone safely falls back instead of breaking discovery'
);

reset role;

select is(
  (select count(*)::integer from public.discover_public_groups('', 0, 20)),
  4,
  '0077 three-argument RPC remains backward compatible'
);

select * from finish();
rollback;
