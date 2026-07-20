begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(9);

select is(
  (public._achievement_metrics('10000000-0000-0000-0000-000000000001')->>'total_hours')::integer,
  1,
  'live seed contributes one total hour'
);
select is(
  (public._achievement_metrics('10000000-0000-0000-0000-000000000002')->>'total_hours')::integer,
  1,
  'manual seed contributes one total hour'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is(
  (public.process_achievement_event('manual_refresh', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  50,
  'live source receives 50 XP for its first hour'
);
select is(
  (public.process_achievement_event('manual_refresh', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  0,
  'live source hour XP retry is idempotent'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select is(
  (public.process_achievement_event('manual_refresh', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  50,
  'manual source receives the same 50 XP for its first hour'
);
select is(
  (public.process_achievement_event('manual_refresh', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  0,
  'manual source hour XP retry is idempotent'
);

reset role;
select is(
  (select xp from public.gamification_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
  (select xp from public.gamification_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
  'equal durations produce equal profile XP'
);
select is(
  (
    select count(*) from public.gamification_profiles gp
    where gp.user_id in (
      '10000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000002'
    )
      and gp.xp <> (
        select coalesce(sum(xp_amount), 0)::integer
        from public.xp_ledger xl where xl.user_id = gp.user_id
      )
  ),
  0::bigint,
  'profile XP equals append-only ledger total'
);
select is(
  public.project_group_week(
    '20000000-0000-0000-0000-000000000001',
    date_trunc('week', timezone('Europe/Istanbul', now()))::date
  ),
  2,
  'weekly source-neutral projector writes both users'
);

select * from finish();
rollback;
