begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(37);

create temporary table route_fixture (
  route text primary key,
  user_id uuid not null,
  source text not null
) on commit drop;

insert into route_fixture(route, user_id, source) values
  ('manual', '10000000-0000-0000-0000-000000000011', 'manual'),
  ('stopwatch', '10000000-0000-0000-0000-000000000012', 'live'),
  ('countdown', '10000000-0000-0000-0000-000000000013', 'live'),
  ('pomodoro', '10000000-0000-0000-0000-000000000014', 'live'),
  ('native_widget', '10000000-0000-0000-0000-000000000015', 'live');

insert into auth.users(id, email, raw_user_meta_data)
select user_id, route || '@equal-source.invalid',
  jsonb_build_object('display_name', 'Route ' || route)
from route_fixture;

insert into public.groups(id, name, invite_code, created_by, created_at)
values (
  '20000000-0000-0000-0000-000000000011',
  'Equal Source Group', 'EQUAL011',
  '10000000-0000-0000-0000-000000000011', now() - interval '60 days'
);

insert into public.group_members(group_id, user_id, role, joined_at)
select '20000000-0000-0000-0000-000000000011', user_id,
  case when route = 'manual' then 'admin' else 'member' end,
  now() - interval '60 days'
from route_fixture;

-- end_time intentionally carries the historical +3h drift. 0063 must use the
-- canonical duration_seconds, so every route is exactly 4.5h and qualifies for
-- Break Enemy without gaining three phantom hours.
with fixture_time as (
  select (date_trunc('day', timezone('Europe/Istanbul', now()))
    + interval '9 hours') at time zone 'Europe/Istanbul' as started_at
)
insert into public.study_sessions(
  id, user_id, start_time, end_time, duration_seconds, source
)
select gen_random_uuid(), f.user_id, t.started_at,
  t.started_at + interval '7.5 hours', 16200, f.source
from route_fixture f cross join fixture_time t;

select is(
  (
    select array_agg(
      (public._achievement_metrics(user_id)->>'total_hours')::integer
      order by route
    )::text from route_fixture
  ),
  '{4,4,4,4,4}',
  'five input routes produce the same canonical personal duration metric'
);

select is(
  (select array_agg(public.break_enemy_metric(user_id) order by route)::text from route_fixture),
  '{1,1,1,1,1}',
  'five input routes produce the same Break Enemy metric'
);

select is(
  (select count(*) from public.achievement_rewards ar
    join route_fixture f on f.user_id = ar.user_id
    where ar.achievement_id = 'secret_break_enemy' and ar.status = 'pending'),
  5::bigint,
  'Break Enemy candidate chain routes all five sources to pending inbox rewards'
);

select is(
  (select count(*) from public.achievement_reward_candidates c
    join route_fixture f on f.user_id = c.user_id
    where c.achievement_id = 'secret_break_enemy'
      and c.source_version = 'break_all_sessions_v2' and c.status = 'consumed'),
  5::bigint,
  'Break Enemy candidates are consumed only after pending routing succeeds'
);

select is(
  public.project_group_day(
    '20000000-0000-0000-0000-000000000011',
    (timezone('Europe/Istanbul', now()))::date
  ),
  5,
  'daily source-neutral projector writes every route'
);

select is(
  (select array_agg(campfire_seconds order by user_id)::text
    from public.group_achievement_daily
    where group_id = '20000000-0000-0000-0000-000000000011'
      and istanbul_day = (timezone('Europe/Istanbul', now()))::date),
  '{16200,16200,16200,16200,16200}',
  'group campfire duration is equal and ignores timestamp drift for every route'
);

select is(
  public.project_group_week(
    '20000000-0000-0000-0000-000000000011',
    date_trunc('week', timezone('Europe/Istanbul', now()))::date
  ),
  5,
  'weekly source-neutral projector writes every route'
);

select is(
  (select array_agg(total_seconds order by user_id)::text
    from public.group_achievement_weekly
    where group_id = '20000000-0000-0000-0000-000000000011'
      and iso_week_start = date_trunc('week', timezone('Europe/Istanbul', now()))::date),
  '{16200,16200,16200,16200,16200}',
  'weekly totals are equal across all five input routes'
);

-- The server-finalized route must earn equally without sacrificing the 0051
-- live_run audit link or allowing client mutation of the linked row.
insert into auth.users(id, email, raw_user_meta_data) values (
  '10000000-0000-0000-0000-000000000016',
  'verified-native@equal-source.invalid',
  '{"display_name":"Verified Native"}'::jsonb
);
insert into public.group_members(group_id, user_id, role, joined_at) values (
  '20000000-0000-0000-0000-000000000011',
  '10000000-0000-0000-0000-000000000016', 'member', now() - interval '60 days'
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000016', true);
create temporary table verified_run_fixture on commit drop as
select (public.start_verified_live_run(
  '40000000-0000-0000-0000-000000000016',
  '20000000-0000-0000-0000-000000000011', null, 42
)->>'run_token')::uuid as run_token;
update public.live_study_runs
set started_at = now() - interval '4.5 hours'
where run_token = (select run_token from verified_run_fixture);
update public.live_study_segments
set started_at = now() - interval '4.5 hours'
where run_id = (select id from public.live_study_runs
  where run_token = (select run_token from verified_run_fixture));
select public.finalize_verified_live_run((select run_token from verified_run_fixture));

select is(
  (select duration_seconds from public.study_sessions
    where user_id = '10000000-0000-0000-0000-000000000016'
      and live_run_id is not null),
  16200,
  'server-finalized native route preserves canonical duration and live_run audit link'
);
select is(
  (select count(*) from public.achievement_rewards
    where user_id = '10000000-0000-0000-0000-000000000016'
      and achievement_id = 'secret_break_enemy' and status = 'pending'),
  1::bigint,
  'server-finalized route reaches the same Break Enemy pending reward'
);
set local role authenticated;
update public.study_sessions set duration_seconds = 1
where user_id = '10000000-0000-0000-0000-000000000016';
select is(
  (select duration_seconds from public.study_sessions
    where user_id = '10000000-0000-0000-0000-000000000016'),
  16200,
  'authenticated client cannot mutate a server-finalized linked session'
);
select is(
  (public.process_achievement_event('session_completed', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  200,
  'server-finalized route receives the same four hourly XP grants'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
select is(
  (public.process_achievement_event('session_completed', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  200,
  'manual route receives four hourly XP grants'
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000012', true);
select is(
  (public.process_achievement_event('session_completed', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  200,
  'stopwatch route receives the same hourly XP'
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000013', true);
select is(
  (public.process_achievement_event('session_completed', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  200,
  'countdown route receives the same hourly XP'
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000014', true);
select is(
  (public.process_achievement_event('session_completed', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  200,
  'Pomodoro route receives the same hourly XP'
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000015', true);
select is(
  (public.process_achievement_event('session_completed', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  200,
  'native/widget route receives the same hourly XP'
);

reset role;
select is(
  (select array_agg(xp order by user_id)::text from public.gamification_profiles
    where user_id in (select user_id from route_fixture)),
  '{200,200,200,200,200}',
  'all five routes have identical banked XP before reward claim'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
set local role authenticated;
select is(
  (public.claim_achievement_reward(
    (select id from public.achievement_rewards
      where user_id = '10000000-0000-0000-0000-000000000011'
        and achievement_id = 'secret_break_enemy')
  )->>'xp_granted')::integer,
  2500,
  'pending Break Enemy reward claims through the server ledger'
);
select is(
  (public.claim_achievement_reward(
    (select id from public.achievement_rewards
      where user_id = '10000000-0000-0000-0000-000000000011'
        and achievement_id = 'secret_break_enemy')
  )->>'xp_granted')::integer,
  0,
  'second claim is idempotent and grants no duplicate XP'
);

reset role;
select is(
  (select count(*) from public.gamification_profiles gp
    where gp.user_id in (select user_id from route_fixture)
      and gp.xp <> (select coalesce(sum(xp_amount), 0)::integer
        from public.xp_ledger xl where xl.user_id = gp.user_id)),
  0::bigint,
  'profile XP equals append-only ledger after claim'
);

-- Closed Istanbul days exercise Alpha/Campfire/Locomotive and closed ISO weeks
-- exercise Weekly Alpha. Inserts are intentionally batched before finalization:
-- an offline historical session must never mint a temporary winner mid-sync.
insert into auth.users(id, email, raw_user_meta_data) values
  ('10000000-0000-0000-0000-000000000021', 'daily-leader@equal-source.invalid',
    '{"display_name":"Daily Leader"}'::jsonb),
  ('10000000-0000-0000-0000-000000000022', 'daily-follower@equal-source.invalid',
    '{"display_name":"Daily Follower"}'::jsonb);

insert into public.groups(id, name, invite_code, created_by, created_at)
values (
  '20000000-0000-0000-0000-000000000021',
  'Reward Chain Group', 'CHAIN021',
  '10000000-0000-0000-0000-000000000021', now() - interval '90 days'
);
insert into public.group_members(group_id, user_id, role, joined_at) values
  ('20000000-0000-0000-0000-000000000021',
    '10000000-0000-0000-0000-000000000021', 'admin', now() - interval '90 days'),
  ('20000000-0000-0000-0000-000000000021',
    '10000000-0000-0000-0000-000000000022', 'member', now() - interval '90 days');

with days as (
  select d,
    (((timezone('Europe/Istanbul', now()))::date - d + time '08:00')
      at time zone 'Europe/Istanbul') as started_at
  from generate_series(1, 11) d
)
insert into public.study_sessions(id, user_id, start_time, end_time, duration_seconds, source)
select gen_random_uuid(), '10000000-0000-0000-0000-000000000021'::uuid,
  started_at, started_at + interval '2 hours', 7200,
  case when d % 2 = 0 then 'manual' else 'live' end
from days
union all
select gen_random_uuid(), '10000000-0000-0000-0000-000000000022'::uuid,
  started_at + interval '5 minutes', started_at + interval '65 minutes', 3600,
  case when d % 2 = 0 then 'live' else 'manual' end
from days;

select lives_ok(
  $$do $block$
  declare d date;
  begin
    for d in
      select distinct (timezone('Europe/Istanbul', start_time))::date
      from public.study_sessions
      where user_id = '10000000-0000-0000-0000-000000000021'
    loop
      perform public.finalize_group_day(
        '20000000-0000-0000-0000-000000000021', d
      );
    end loop;
  end
  $block$;$$,
  'closed Istanbul days finalize only after the complete offline batch exists'
);

select cmp_ok(
  (select metric_value from public.achievement_metric_progress
    where user_id = '10000000-0000-0000-0000-000000000021'
      and achievement_id = 'alpha_wolf'),
  '>=', 11::bigint,
  'Alpha progress counts the unique all-source leader on every closed day'
);
select cmp_ok(
  (select metric_value from public.achievement_metric_progress
    where user_id = '10000000-0000-0000-0000-000000000021'
      and achievement_id = 'campfire_hours'),
  '>=', 10::bigint,
  'Campfire progress includes overlapping manual and live source time'
);
select cmp_ok(
  (select metric_value from public.achievement_metric_progress
    where user_id = '10000000-0000-0000-0000-000000000021'
      and achievement_id = 'locomotive'),
  '>=', 5::bigint,
  'Locomotive progress includes all-source follower starts'
);
select is(
  (select count(distinct achievement_id) from public.achievement_reward_candidates
    where user_id = '10000000-0000-0000-0000-000000000021'
      and achievement_id in ('alpha_wolf', 'campfire_hours', 'locomotive')
      and status = 'consumed'),
  3::bigint,
  'daily group achievements move from candidate to pending exactly once'
);
select is(
  (select count(distinct achievement_id) from public.achievement_rewards
    where user_id = '10000000-0000-0000-0000-000000000021'
      and achievement_id in ('alpha_wolf', 'campfire_hours', 'locomotive')
      and status = 'pending'),
  3::bigint,
  'daily Alpha/Campfire/Locomotive rewards are claimable in the inbox'
);

select lives_ok(
  $$do $block$
  declare w date;
  begin
    for w in
      select distinct date_trunc('week', timezone('Europe/Istanbul', start_time))::date
      from public.study_sessions
      where user_id = '10000000-0000-0000-0000-000000000021'
        and date_trunc('week', timezone('Europe/Istanbul', start_time))::date
          < date_trunc('week', timezone('Europe/Istanbul', now()))::date
    loop
      perform public.finalize_group_week(
        '20000000-0000-0000-0000-000000000021', w
      );
    end loop;
  end
  $block$;$$,
  'closed Europe/Istanbul ISO weeks finalize without touching the open week'
);
select cmp_ok(
  (select metric_value from public.achievement_metric_progress
    where user_id = '10000000-0000-0000-0000-000000000021'
      and achievement_id = 'alpha_wolf_weekly'),
  '>=', 1::bigint,
  'Weekly Alpha progress counts a unique all-source weekly leader'
);
select is(
  (select count(*) from public.achievement_rewards
    where user_id = '10000000-0000-0000-0000-000000000021'
      and achievement_id = 'alpha_wolf_weekly' and status = 'pending'),
  1::bigint,
  'Weekly Alpha candidate reaches the pending inbox'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000021', true);
select cmp_ok(
  (public.claim_all_achievement_rewards(50)->>'claimed_count')::integer,
  '>=', 4,
  'daily and weekly group rewards claim through the server ledger'
);
select is(
  (public.claim_all_achievement_rewards(50)->>'xp_granted')::integer,
  0,
  'second group reward claim grants no duplicate XP'
);
reset role;

create temporary table reconciliation_fixture(run_id uuid) on commit drop;
insert into reconciliation_fixture values (public.prepare_equal_source_reconciliation(100, null));

select is(
  (select status from public.equal_source_reconciliation_runs
    where id = (select run_id from reconciliation_fixture)),
  'prepared',
  'reconciliation prepares a private shadow/diff run without applying it'
);

select is(
  public.apply_equal_source_reconciliation((select run_id from reconciliation_fixture)),
  (select user_count from public.equal_source_reconciliation_runs
    where id = (select run_id from reconciliation_fixture)),
  'bounded reconciliation applies exactly its prepared user batch'
);

select is(
  public.apply_equal_source_reconciliation((select run_id from reconciliation_fixture)),
  0,
  'second reconciliation apply is an idempotent no-op'
);

select is(
  (select count(*) from public.equal_source_reconciliation_runs
    where id = (select run_id from reconciliation_fixture)
      and status = 'applied'
      and baseline_session_count = (select count(*) from public.study_sessions)
      and baseline_duration_seconds = (select sum(duration_seconds) from public.study_sessions)
      and baseline_ledger_count = (select count(*) from public.xp_ledger)
      and baseline_claimed_reward_count =
        (select count(*) from public.achievement_rewards where status = 'claimed')),
  1::bigint,
  'reconciliation preserves session/duration/ledger/claimed reward invariants'
);

create temporary table stale_reconciliation_fixture(run_id uuid) on commit drop;
insert into stale_reconciliation_fixture
values (public.prepare_equal_source_reconciliation(100, null));
insert into public.study_sessions(
  id, user_id, start_time, end_time, duration_seconds, source
) values (
  gen_random_uuid(), '10000000-0000-0000-0000-000000000001',
  now() - interval '1 second', now(), 1, 'manual'
);
select throws_ok(
  format(
    'select public.apply_equal_source_reconciliation(%L::uuid)',
    (select run_id from stale_reconciliation_fixture)
  ),
  'P0001',
  'reconciliation_baseline_changed_reprepare_required',
  'active session writes invalidate a prepared run before bounded apply'
);

select * from finish();
rollback;
