begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql
select plan(8);

select ok(
  to_regprocedure('public.enqueue_timer_sync_push(text,uuid,uuid,bigint,bigint,uuid)') is not null
    and to_regclass('public.timer_sync_push_runtime_config') is not null,
  'timer-sync has its own guarded enqueue policy and closed-by-default runtime flag'
);
select throws_ok(
  $$select public._push_type_enabled(null::public.push_devices, 'unknown_type')$$,
  'P0001', 'invalid_push_notification_type', 'unknown push types fail loudly rather than silently dropping'
);

insert into public.push_devices(id, user_id, installation_id, fcm_token, app_channel, app_version, build_number, locale, time_zone, nudge_enabled, announcement_enabled, update_enabled, quiet_hours_enabled, quiet_start_minutes, quiet_end_minutes)
values
 ('30000000-0000-0000-0000-000000000031','10000000-0000-0000-0000-000000000001','timer-origin-installation-000031','timer-origin-token-000000000000000031','beta','1.0.0',1,'tr','Europe/Istanbul',false,false,false,true,0,0),
 ('30000000-0000-0000-0000-000000000032','10000000-0000-0000-0000-000000000001','timer-target-installation-000032','timer-target-token-000000000000000032','beta','1.0.0',1,'tr','Europe/Istanbul',false,false,false,true,0,0);
insert into public.user_timer_state(user_id, state_version) values ('10000000-0000-0000-0000-000000000001', 1);
insert into public.live_study_runs(id, user_id, client_request_id, status, protocol_version, run_kind, effective_started_at, run_revision, user_state_version, lease_expires_at)
values ('50000000-0000-0000-0000-000000000031','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000031','running',2,'study',clock_timestamp(),1,1,clock_timestamp()+interval '2 minutes');

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
-- 0088 enables delivery after wiring a real producer. This test still proves
-- the kill switch by establishing its closed precondition explicitly.
update public.timer_sync_push_runtime_config set enabled = false where singleton;
select throws_ok(
  $$select public.enqueue_timer_sync_push('closed', '10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000031', 1, 1, '30000000-0000-0000-0000-000000000031')$$,
  'P0001', 'timer_sync_push_disabled', 'timer sync enqueue is fail-closed before rollout enablement'
);
update public.timer_sync_push_runtime_config set enabled = true where singleton;
select public.enqueue_timer_sync_push('state-1', '10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000031', 1, 1, '30000000-0000-0000-0000-000000000031') as timer_outbox \gset
reset role;

select is((select count(*)::integer from public.notification_deliveries where outbox_id = :'timer_outbox'::uuid), 1,
  'origin device is excluded while another active device receives the timer signal');
select ok(
  (select notification_type = 'timer_sync' and expires_at > clock_timestamp() and collapse_key = 'timer_sync:10000000-0000-0000-0000-000000000001'
    and payload = jsonb_build_object('schema_version','1','kind','timer_sync','run_id','50000000-0000-0000-0000-000000000031','state_version',1,'run_revision',1)
   from public.notification_outbox where id = :'timer_outbox'::uuid),
  'timer payload is minimal and carries bounded expiry plus per-account collapse key'
);
select ok(public._push_type_enabled((select d from public.push_devices d where id = '30000000-0000-0000-0000-000000000032'), 'timer_sync'),
  'timer sync bypasses normal notification preference and quiet-hours policy');

update public.notification_outbox set expires_at = clock_timestamp() - interval '1 second' where id = :'timer_outbox'::uuid;
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select is((select count(*)::integer from public.claim_push_deliveries('90000000-0000-0000-0000-000000000031', 10, 60) where outbox_id = :'timer_outbox'::uuid), 0,
  'expired timer signal is not sent after its short TTL');
reset role;
select is((select last_error_code from public.notification_deliveries where outbox_id = :'timer_outbox'::uuid), 'expired',
  'expiry is retained as delivery telemetry instead of silently deleting audit state');

select * from finish();
rollback;
