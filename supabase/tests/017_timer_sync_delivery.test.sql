begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql
select plan(9);

select ok(
  (select enabled from public.timer_sync_push_runtime_config where singleton),
  'WP-370 enables timer-sync delivery only after the producer is wired'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public._enqueue_global_timer_v2_sync(uuid,uuid,bigint,bigint,uuid,uuid)',
    'execute'
  ),
  'authenticated callers cannot enqueue arbitrary timer-sync deliveries'
);

insert into public.push_devices (
  id, user_id, installation_id, fcm_token, app_channel, app_version, build_number,
  locale, time_zone, nudge_enabled, announcement_enabled, update_enabled,
  quiet_hours_enabled, quiet_start_minutes, quiet_end_minutes
) values
  ('30000000-0000-0000-0000-000000000041', '10000000-0000-0000-0000-000000000001',
   'timer-origin-installation-000041', 'timer-origin-token-000000000000000041',
   'beta', '1.0.0', 1, 'tr', 'Europe/Istanbul', false, false, false, true, 0, 0),
  ('30000000-0000-0000-0000-000000000042', '10000000-0000-0000-0000-000000000001',
   'timer-target-installation-000042', 'timer-target-token-000000000000000042',
   'beta', '1.0.0', 1, 'tr', 'Europe/Istanbul', false, false, false, true, 0, 0);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000041',
  '30000000-0000-0000-0000-000000000041',
  'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'app'), 2
)->'run'->>'id')::uuid as timer_run \gset
reset role;

select is(
  (select count(*)::integer from public.notification_outbox
   where recipient_id = '10000000-0000-0000-0000-000000000001'
     and notification_type = 'timer_sync'),
  1,
  'a successful V2 start produces exactly one timer-sync outbox event'
);
select ok(
  (select payload = jsonb_build_object(
      'schema_version', '1', 'kind', 'timer_sync', 'run_id', :'timer_run',
      'state_version', 1, 'run_revision', 1
    ) and origin_device_id = '30000000-0000-0000-0000-000000000041'::uuid
   from public.notification_outbox where notification_type = 'timer_sync'),
  'start signal contains the accepted run and state revision, not timer truth'
);
select is(
  (select count(*)::integer from public.notification_deliveries d
   join public.notification_outbox o on o.id = d.outbox_id
   where o.notification_type = 'timer_sync'
     and d.device_id = '30000000-0000-0000-0000-000000000042'),
  1,
  'start delivery reaches the other active device and excludes origin'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000042',
  '30000000-0000-0000-0000-000000000041',
  'stop', :'timer_run'::uuid, 1, clock_timestamp(), '{}'::jsonb, 2
);
reset role;

select is(
  (select count(*)::integer from public.notification_outbox
   where recipient_id = '10000000-0000-0000-0000-000000000001'
     and notification_type = 'timer_sync'),
  2,
  'a successful stop produces one additional timer-sync event'
);
select ok(
  (select payload ->> 'schema_version' = '1'
      and payload ->> 'kind' = 'timer_sync'
      and payload ->> 'run_id' = :'timer_run'
      and (payload ->> 'state_version')::bigint = 2
      and (payload ->> 'run_revision')::bigint = 2
   from public.notification_outbox
    where notification_type = 'timer_sync'
      and event_key like 'timer_sync:global_timer_v2:40000000-0000-0000-0000-000000000042:%'),
  'stop signal advances state and run revision so delayed signals cannot be trusted'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is(
  public.apply_global_timer_command(
    '40000000-0000-0000-0000-000000000043',
    '30000000-0000-0000-0000-000000000041',
    'stop', :'timer_run'::uuid, 1, clock_timestamp(), '{}'::jsonb, 2
  )->>'result_code',
  'already_stopped',
  'a delayed old stop does not transition the terminal run again'
);
reset role;
select is(
  (select count(*)::integer from public.notification_outbox
   where recipient_id = '10000000-0000-0000-0000-000000000001'
     and notification_type = 'timer_sync'),
  2,
  'a stale terminal command cannot enqueue a misleading third signal'
);

select * from finish();
rollback;
