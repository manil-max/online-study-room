begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(38);

select is(
  (select count(*)::integer from supabase_migrations.schema_migrations),
  67,
  'all 67 migrations are recorded'
);
select is(
  (select max(version) from supabase_migrations.schema_migrations),
  '0067',
  '0067 is the migration head'
);
select ok(
  to_regclass('public.push_devices') is not null
    and to_regclass('public.notification_outbox') is not null
    and to_regclass('public.notification_deliveries') is not null,
  '0066 installs the private push registry and delivery outbox'
);
select is(
  (
    select count(*)::integer from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('push_devices', 'notification_outbox', 'notification_deliveries')
      and c.relrowsecurity
  ),
  3,
  'all push tables have RLS enabled'
);
select ok(
  not has_table_privilege('authenticated', 'public.push_devices', 'select')
    and not has_table_privilege('authenticated', 'public.notification_outbox', 'select')
    and not has_table_privilege('authenticated', 'public.notification_deliveries', 'select'),
  'authenticated cannot read private push tables directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.push_devices', 'insert')
    and not has_table_privilege('authenticated', 'public.notification_outbox', 'insert')
    and not has_table_privilege('authenticated', 'public.notification_deliveries', 'insert'),
  'authenticated cannot write private push tables directly'
);
select ok(
  to_regprocedure(
    'public.register_push_device(text,text,text,text,integer,text,text,boolean,boolean,boolean,boolean,integer,integer)'
  ) is not null
    and to_regprocedure('public.unregister_push_device(text)') is not null,
  '0066 installs self-scoped device lifecycle RPCs'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.register_push_device(text,text,text,text,integer,text,text,boolean,boolean,boolean,boolean,integer,integer)',
    'execute'
  ),
  'authenticated can call the guarded registration RPC'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.claim_push_deliveries(uuid,integer,integer)', 'execute'
  )
    and not has_function_privilege(
      'authenticated',
      'public.complete_push_delivery(uuid,uuid,text,text,text,integer)',
      'execute'
    ),
  'authenticated cannot claim or complete provider deliveries'
);
select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid = 'public.nudges'::regclass
      and tgname = 'nudges_enqueue_push'
      and not tgisinternal
  ),
  'nudge inserts enqueue an idempotent push event'
);
select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid = 'public.announcements'::regclass
      and tgname = 'announcements_enqueue_push'
      and not tgisinternal
  ),
  'announcement inserts fan out through the push outbox'
);
select ok(
  to_regprocedure(
    'public.enqueue_update_push(text,text,text,integer,text,text)'
  ) is not null
    and not has_function_privilege(
      'authenticated',
      'public.enqueue_update_push(text,text,text,integer,text,text)',
      'execute'
    )
    and to_regprocedure('public.prune_stale_push_devices(integer)') is not null,
  'update fan-out and stale-token cleanup stay service-only'
);
select is(
  (
    select count(*)::integer from pg_trigger
    where tgrelid = 'public.notification_outbox'::regclass
      and tgname in ('a_push_outbox_create_deliveries', 'z_push_outbox_request_dispatch')
      and not tgisinternal
  ),
  2,
  'outbox creates device deliveries before requesting async dispatch'
);
select ok(
  exists(
    select 1 from pg_indexes
    where schemaname = 'public'
      and tablename = 'notification_outbox'
      and indexdef ilike '%unique%event_key%'
  )
    and exists(
      select 1 from pg_indexes
      where schemaname = 'public'
        and tablename = 'notification_deliveries'
        and indexdef ilike '%unique%outbox_id%device_id%'
    ),
  'outbox and per-device delivery idempotency keys are unique'
);
select ok(
  to_regclass('public.push_dispatch_runtime_config') is not null
    and (select relrowsecurity from pg_class where oid = 'public.push_dispatch_runtime_config'::regclass)
    and not has_table_privilege('authenticated', 'public.push_dispatch_runtime_config', 'select'),
  '0067 keeps dispatcher runtime config private behind RLS'
);
select ok(
  to_regprocedure('public.configure_push_dispatch(text,text)') is not null
    and not has_function_privilege(
      'authenticated', 'public.configure_push_dispatch(text,text)', 'execute'
    )
    and has_function_privilege(
      'service_role', 'public.configure_push_dispatch(text,text)', 'execute'
    ),
  'only service role can configure the dispatcher endpoint and secret'
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
select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid = 'public.study_sessions'::regclass
      and tgname = 'study_sessions_guard_verified_update'
      and not tgisinternal
  ),
  'server-finalized study session immutability guard is preserved'
);
select ok(
  to_regclass('public.equal_source_reconciliation_runs') is not null
    and to_regclass('public.equal_source_reconciliation_users') is not null,
  '0063 installs private shadow reconciliation tables'
);
select ok(
  to_regprocedure('public.prepare_equal_source_reconciliation(integer,uuid)') is not null
    and to_regprocedure('public.apply_equal_source_reconciliation(uuid)') is not null,
  '0063 installs bounded prepare/apply reconciliation RPCs'
);
select ok(
  to_regprocedure('public.project_verified_group_day(uuid,date)') is null
    and to_regprocedure('public.project_verified_group_week(uuid,date)') is null,
  'stale verified-only projectors are removed'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.prepare_equal_source_reconciliation(integer,uuid)',
    'execute'
  ),
  'authenticated role cannot prepare reconciliation'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.apply_equal_source_reconciliation(uuid)', 'execute'
  ),
  'authenticated role cannot apply reconciliation'
);
select is(public._recalc_crown_rank(19999), 'bronze_beginner', '19,999 XP remains bronze');
select is(public._recalc_crown_rank(20000), 'silver_learner', 'silver crown starts at 20,000 XP');
select is(
  (
    select array_agg(jobname order by jobname)::text
    from cron.job
    where jobname in (
      'group-achievement-day-finalizer',
      'group-achievement-week-finalizer',
      'verified-session-rollout-retention'
    )
  ),
  '{group-achievement-day-finalizer,group-achievement-week-finalizer,verified-session-rollout-retention}',
  'critical session/reward cron jobs are installed once'
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
