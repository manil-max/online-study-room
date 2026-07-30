begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql
select plan(8);

select has_column(
  'public', 'notification_outbox', 'target_device_id',
  'outbox stores an explicit optional target device'
);

insert into public.push_devices (
  id, user_id, installation_id, fcm_token, app_channel, app_version, build_number,
  locale, time_zone, nudge_enabled, announcement_enabled, update_enabled,
  quiet_hours_enabled, quiet_start_minutes, quiet_end_minutes
) values
  ('30000000-0000-0000-0000-000000000081', '10000000-0000-0000-0000-000000000001',
   'wp432-self-test-a-000081', 'wp432-self-test-token-a-000000000000000081',
   'beta', '1.0.0', 1, 'tr', 'Europe/Istanbul', true, true, true, false, 0, 0),
  ('30000000-0000-0000-0000-000000000082', '10000000-0000-0000-0000-000000000001',
   'wp432-self-test-b-000082', 'wp432-self-test-token-b-000000000000000082',
   'beta', '1.0.0', 1, 'tr', 'Europe/Istanbul', true, true, true, false, 0, 0);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select outbox_id as self_test_outbox
from public.request_push_self_test('30000000-0000-0000-0000-000000000081')
\gset
reset role;

select is(
  (select count(*)::integer from public.notification_deliveries
   where outbox_id = :'self_test_outbox'::uuid),
  1,
  'self-test creates one delivery even when the account owns two active devices'
);
select is(
  (select device_id from public.notification_deliveries
   where outbox_id = :'self_test_outbox'::uuid),
  '30000000-0000-0000-0000-000000000081'::uuid,
  'self-test delivery targets only the calling device'
);
select is(
  (select target_device_id from public.notification_outbox
   where id = :'self_test_outbox'::uuid),
  '30000000-0000-0000-0000-000000000081'::uuid,
  'self-test outbox retains its target for audit and idempotent delivery'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$select * from public.request_push_self_test('30000000-0000-0000-0000-000000000081')$$,
  'P0001', 'push_test_target_device_required',
  'another account cannot direct a self-test to this device'
);
reset role;

update public.push_devices
set disabled_at = clock_timestamp()
where id = '30000000-0000-0000-0000-000000000081';
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select * from public.request_push_self_test('30000000-0000-0000-0000-000000000081')$$,
  'P0001', 'push_test_target_device_required',
  'disabled or stale device tokens cannot receive a new self-test'
);
reset role;

insert into public.notification_outbox (
  event_key, recipient_id, notification_type, payload, origin_device_id
) values (
  'wp432-timer-sync-origin-exclusion',
  '10000000-0000-0000-0000-000000000001',
  'timer_sync',
  jsonb_build_object('schema_version', '1', 'kind', 'timer_sync'),
  '30000000-0000-0000-0000-000000000081'
) returning id as timer_sync_outbox
\gset

select is(
  (select count(*)::integer from public.notification_deliveries
   where outbox_id = :'timer_sync_outbox'::uuid),
  1,
  'timer sync still fans out to the other active device when no target is set'
);
select is(
  (select device_id from public.notification_deliveries
   where outbox_id = :'timer_sync_outbox'::uuid),
  '30000000-0000-0000-0000-000000000082'::uuid,
  'timer sync excludes its origin device without confusing it with self-test target'
);

select * from finish();
rollback;
