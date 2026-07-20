begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

select is(
  (select count(*)::integer from supabase_migrations.schema_migrations),
  63,
  'all 63 migrations are recorded locally'
);
select is(
  (select max(version) from supabase_migrations.schema_migrations),
  '0063',
  '0063 is the local migration head'
);
select is(current_setting('server_version_num')::integer / 10000, 17, 'PostgreSQL major is 17');
select ok(exists(select 1 from pg_extension where extname = 'pg_cron'), 'pg_cron prerequisite is installed');
select ok(to_regclass('public.study_sessions') is not null, 'study_sessions exists');
select ok(
  exists(
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'study_sessions' and column_name = 'source'
  ),
  'study_sessions.source exists'
);
select ok(
  exists(
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'study_sessions' and column_name = 'live_run_id'
  ),
  'legacy live_run_id remains for audit compatibility'
);
select ok(
  exists(
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'group_achievement_weekly' and column_name = 'total_seconds'
  ),
  '0063 source-neutral weekly total exists'
);
select ok(
  not exists(
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'group_achievement_weekly' and column_name = 'verified_seconds'
  ),
  'verified-only weekly column is gone after 0063'
);
select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid = 'public.study_sessions'::regclass
      and tgname = 'study_sessions_project_break_enemy'
      and not tgisinternal
  ),
  'source-neutral break metric trigger exists'
);
select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid = 'public.study_sessions'::regclass
      and tgname = 'study_sessions_project_group_metrics'
      and not tgisinternal
  ),
  'source-neutral group metric trigger exists'
);
select ok(
  not exists(
    select 1 from pg_trigger
    where tgname in ('live_runs_project_group_metrics', 'live_segments_project_group_metrics')
      and not tgisinternal
  ),
  'verified-only group projection triggers are removed'
);
select is(public._recalc_crown_rank(19999), 'bronze_beginner', '19,999 XP remains bronze');
select is(public._recalc_crown_rank(20000), 'silver_learner', 'silver crown starts at 20,000 XP');
select is(
  (select array_agg(jobname order by jobname)::text from cron.job),
  '{group-achievement-day-finalizer,group-achievement-week-finalizer,monthly-report-collector}',
  'expected local cron jobs are installed once'
);
select ok(
  not has_function_privilege('anon', 'public.break_enemy_metric(uuid)', 'execute'),
  'anonymous role cannot execute internal break projector'
);
select ok(
  not has_function_privilege('authenticated', 'public.catch_up_group_weeks()', 'execute'),
  'authenticated role cannot execute internal weekly catch-up'
);
select ok(
  has_function_privilege('authenticated', 'public.process_achievement_event(text,jsonb)', 'execute'),
  'authenticated role can execute the intended achievement RPC'
);

select * from finish();
rollback;
