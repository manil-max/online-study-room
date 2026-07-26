begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql
select plan(6);

select ok(
  to_regclass('public.study_session_group_attribution') is not null
    and to_regprocedure('public.groups_for_session_progression(uuid,uuid,timestamp with time zone,timestamp with time zone)') is not null,
  'WP-336 has a private one-to-zero/one attribution store and server resolver'
);
select ok(
  not has_table_privilege('authenticated', 'public.study_session_group_attribution', 'insert'),
  'client cannot choose a session attribution directly'
);
select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.group_progression_attribution_config'::regclass)
    and not has_table_privilege('anon', 'public.group_progression_attribution_config', 'select')
    and not has_table_privilege('authenticated', 'public.group_progression_attribution_config', 'select')
    and not has_table_privilege('authenticated', 'public.group_progression_attribution_config', 'update'),
  'attribution cutover config is RLS-protected and private from clients'
);

insert into public.groups (id, name, invite_code, created_by, created_at)
values ('20000000-0000-0000-0000-000000000010', 'Secondary Fixture', 'ATTRIB10',
  '10000000-0000-0000-0000-000000000001', clock_timestamp());
insert into public.group_members (group_id, user_id, role, joined_at)
values ('20000000-0000-0000-0000-000000000010',
  '10000000-0000-0000-0000-000000000001', 'admin', clock_timestamp());

insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
) values (
  '30000000-0000-0000-0000-000000000010',
  '10000000-0000-0000-0000-000000000001',
  clock_timestamp(), clock_timestamp() + interval '1 minute', 60, 'manual'
);

select is(
  (select group_id from public.study_session_group_attribution
    where session_id = '30000000-0000-0000-0000-000000000010'),
  '20000000-0000-0000-0000-000000000001'::uuid,
  'post-cutover session captures the primary group at session start'
);
select is(
  (select count(*)::integer from public.groups_for_session_progression(
    '30000000-0000-0000-0000-000000000010',
    '10000000-0000-0000-0000-000000000001',
    (select start_time from public.study_sessions where id = '30000000-0000-0000-0000-000000000010'),
    (select end_time from public.study_sessions where id = '30000000-0000-0000-0000-000000000010')
  ) where group_id = '20000000-0000-0000-0000-000000000010'),
  0,
  'secondary memberships are absent from post-cutover progression'
);
select ok(
  not exists (
    select 1 from public.group_achievement_daily
    where group_id = '20000000-0000-0000-0000-000000000010'
      and user_id = '10000000-0000-0000-0000-000000000001'
  ),
  'secondary daily progression remains zero after the session projector runs'
);
select * from finish();
rollback;
