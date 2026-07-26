begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql
select plan(18);

select ok(
  to_regclass('public.user_timer_state') is not null
    and to_regclass('public.global_timer_commands') is not null
    and to_regclass('public.global_timer_device_state') is not null
    and to_regprocedure('public.apply_global_timer_command(uuid,uuid,text,uuid,bigint,timestamp with time zone,jsonb,integer)') is not null,
  'WP-341 exposes the V2 state head, command ledger, device state and guarded RPC'
);
select ok(
  not has_table_privilege('authenticated', 'public.user_timer_state', 'insert')
    and not has_table_privilege('authenticated', 'public.global_timer_commands', 'insert')
    and not has_table_privilege('authenticated', 'public.global_timer_device_state', 'insert'),
  'authenticated clients cannot directly mutate V2 timer state tables'
);

insert into public.push_devices (
  id, user_id, installation_id, fcm_token, app_channel, app_version, build_number,
  locale, time_zone, nudge_enabled, announcement_enabled, update_enabled,
  quiet_hours_enabled, quiet_start_minutes, quiet_end_minutes
) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'global-timer-device-alpha-0001', 'global-timer-alpha-token-000000000000000000001',
   'beta', '1.0.0', 1, 'tr', 'Europe/Istanbul', true, true, true, false, 1320, 420),
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002',
   'global-timer-device-beta-00001', 'global-timer-beta-token-0000000000000000000002',
   'beta', '1.0.0', 1, 'tr', 'Europe/Istanbul', true, true, true, false, 1320, 420);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select public.apply_global_timer_command(
    '40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001',
    'start', null, null, clock_timestamp(), '{}'::jsonb, 2)$$,
  'P0001', 'global_timer_v2_disabled',
  'the V2 mutator is fail-closed while its rollout flag is disabled'
);
reset role;

update public.global_timer_v2_runtime_config set v2_enabled = true where singleton;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001',
  'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'app'), 2
)->'run'->>'id')::uuid as alpha_run \gset
reset role;

select ok(
  (select protocol_version = 2 and status = 'running' and run_revision = 1
    and user_state_version = 1 and lease_expires_at is not null
   from public.live_study_runs where id = :'alpha_run'::uuid)
  and (select current_run_id = :'alpha_run'::uuid and state_version = 1
       from public.user_timer_state where user_id = '10000000-0000-0000-0000-000000000001')
  and (select status = 'studying' from public.user_live_presence_state
       where user_id = '10000000-0000-0000-0000-000000000001'),
  'V2 start creates revision-one global run, state head and canonical presence atomically'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is(
  public.apply_global_timer_command(
    '40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001',
    'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'app'), 2
  )->>'result_code',
  'duplicate',
  'same user command ID retries return the stored result'
);
select throws_ok(
  $$select public.apply_global_timer_command(
    '40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001',
    'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'widget'), 2)$$,
  'P0001', 'command_id_payload_mismatch',
  'same command ID with changed payload is rejected rather than silently reused'
);
reset role;
select is(
  (select count(*)::integer from public.global_timer_commands
   where user_id = '10000000-0000-0000-0000-000000000001'),
  1,
  'duplicate retries do not create another command ledger row'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select ok(
  (public.apply_global_timer_command(
    '40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002',
    'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'app'), 2
  )->>'user_id') = '10000000-0000-0000-0000-000000000002',
  'the same command ID is independent per account and cannot return another users snapshot'
);
reset role;

select (select state_version from public.user_timer_state
  where user_id = '10000000-0000-0000-0000-000000000001') as alpha_state_before_heartbeat \gset
select (select state_version from public.user_live_presence_state
  where user_id = '10000000-0000-0000-0000-000000000001') as alpha_presence_before_heartbeat \gset
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001',
  'heartbeat', :'alpha_run'::uuid, 1, clock_timestamp(), '{}'::jsonb, 2
);
reset role;
select is(
  (select state_version from public.user_timer_state
   where user_id = '10000000-0000-0000-0000-000000000001'),
  :'alpha_state_before_heartbeat'::bigint,
  'heartbeat renews only the V2 lease and does not advance account state version'
);
select is(
  (select state_version from public.user_live_presence_state
   where user_id = '10000000-0000-0000-0000-000000000001'),
  :'alpha_presence_before_heartbeat'::bigint,
  'heartbeat does not fan out a multi-group presence transition'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is(
  public.apply_global_timer_command(
    '40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001',
    'stop', :'alpha_run'::uuid, 99, clock_timestamp(), '{}'::jsonb, 2
  )->>'result_code',
  'stale',
  'a stale stop cannot end a newer run revision'
);
reset role;
select is((select status from public.live_study_runs where id = :'alpha_run'::uuid), 'running',
  'stale stop leaves the active run untouched');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000001',
  'stop', :'alpha_run'::uuid, 1, clock_timestamp(), '{}'::jsonb, 2
);
reset role;
select ok(
  (select status = 'stopped' and run_revision = 2 and ended_at is not null
   from public.live_study_runs where id = :'alpha_run'::uuid)
  and (select current_run_id is null and state_version = 2
       from public.user_timer_state where user_id = '10000000-0000-0000-0000-000000000001')
  and (select status = 'offline' from public.user_live_presence_state
       where user_id = '10000000-0000-0000-0000-000000000001'),
  'CAS-correct stop advances state once and closes the canonical presence state'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000001',
  'start', null, null, clock_timestamp(), '{}'::jsonb, 2
)->'run'->>'id')::uuid as alpha_second_run \gset
reset role;
select ok(
  (select run_revision = 1 and user_state_version = 3
   from public.live_study_runs where id = :'alpha_second_run'::uuid),
  'a new run restarts run revision at one while account state version remains monotonic'
);

update public.live_study_runs set lease_expires_at = clock_timestamp() - interval '1 second'
where id = :'alpha_second_run'::uuid;
select is(public.expire_global_timer_v2_leases(10), 1,
  'locked V2 sweeper abandons one expired global run');
select is(public.expire_global_timer_v2_leases(10), 0,
  'a second sweeper sees no duplicate terminal transition');
select ok(
  (select status = 'abandoned' and current_run_id is null
   from public.live_study_runs r join public.user_timer_state s on s.user_id = r.user_id
   where r.id = :'alpha_second_run'::uuid),
  'abandoned V2 run no longer blocks a future active run'
);

update public.push_devices set disabled_at = clock_timestamp()
where id = '30000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select public.get_global_timer_v2_snapshot('30000000-0000-0000-0000-000000000001')$$,
  'P0001', 'active_device_required',
  'revoked devices cannot read or mutate V2 device-bound snapshots'
);
reset role;

select * from finish();
rollback;
