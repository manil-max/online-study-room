begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

insert into auth.users (id, email, raw_user_meta_data)
values (
  '10000000-0000-0000-0000-000000000099',
  'local-outsider@example.invalid',
  '{"display_name":"Local Outsider"}'::jsonb
);

select plan(7);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is((select count(*) from public.study_sessions), 2::bigint, 'group member sees both seeded sessions');
select lives_ok(
  $$insert into public.study_sessions (
      id, user_id, start_time, end_time, duration_seconds, source
    ) values (
      '30000000-0000-0000-0000-000000000011',
      '10000000-0000-0000-0000-000000000001',
      now() - interval '10 minutes', now(), 600, 'manual'
    )$$,
  'authenticated user can insert an own manual session'
);
select throws_ok(
  $$insert into public.study_sessions (
      id, user_id, start_time, end_time, duration_seconds, source
    ) values (
      '30000000-0000-0000-0000-000000000012',
      '10000000-0000-0000-0000-000000000002',
      now() - interval '10 minutes', now(), 600, 'live'
    )$$,
  '42501',
  'new row violates row-level security policy for table "study_sessions"',
  'authenticated user cannot insert a session for another user'
);
update public.study_sessions set duration_seconds = 1
where id = '30000000-0000-0000-0000-000000000002';
select is(
  (
    select duration_seconds from public.study_sessions
    where id = '30000000-0000-0000-0000-000000000002'
  ),
  3600,
  'authenticated user cannot update another user session'
);
select throws_ok(
  $$insert into public.xp_ledger (
      user_id, achievement_id, tier, xp_amount, reason, event_key
    ) values (
      '10000000-0000-0000-0000-000000000001',
      'study_hour_xp', 1, 999999, 'abuse', 'local-abuse-attempt'
    )$$,
  '42501',
  'permission denied for table xp_ledger',
  'authenticated client cannot mint XP directly'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000099', true);
select is((select count(*) from public.study_sessions), 0::bigint, 'non-member sees no other sessions');

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is((select count(*) from public.study_sessions), 0::bigint, 'anonymous role sees no sessions');

reset role;
select * from finish();
rollback;
