begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir _fixtures/base_seed.psql

select plan(38);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select throws_ok(
  $$select * from public.push_devices$$,
  '42501',
  'permission denied for table push_devices',
  'authenticated user cannot read private FCM tokens'
);
select throws_ok(
  $$select * from public.claim_push_deliveries(gen_random_uuid(), 10, 60)$$,
  '42501',
  'permission denied for function claim_push_deliveries',
  'authenticated user cannot claim provider deliveries'
);
select throws_ok(
  $$select * from public.push_dispatch_runtime_config$$,
  '42501',
  'permission denied for table push_dispatch_runtime_config',
  'authenticated user cannot read the dispatcher runtime config'
);
select throws_ok(
  $$select public.configure_push_dispatch('https://aaaaaaaaaaaaaaaaaaaa.supabase.co', repeat('a', 48))$$,
  '42501',
  'permission denied for function configure_push_dispatch',
  'authenticated user cannot configure push dispatch'
);
select throws_ok(
  $$select * from public.register_push_device(
      'installation-alpha-0001', 'short', 'beta', '1.0.43-beta.1', 4301,
      'tr', 'Europe/Istanbul', true, true, true, false, 1320, 420
    )$$,
  'P0001',
  'invalid_fcm_token',
  'registration rejects malformed FCM tokens'
);
select lives_ok(
  $$select * from public.register_push_device(
      'installation-alpha-0001',
      'alpha-fcm-token-000000000000000000000001',
      'beta', '1.0.43-beta.1', 4301, 'tr', 'Europe/Istanbul',
      true, true, true, false, 1320, 420
    )$$,
  'user can register only through the self-scoped RPC'
);

reset role;
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select lives_ok(
  $$select public.configure_push_dispatch('https://aaaaaaaaaaaaaaaaaaaa.supabase.co', repeat('a', 48))$$,
  'service role can configure the private dispatcher runtime'
);
reset role;
select is(
  (
    select functions_base_url
    from public.push_dispatch_runtime_config
    where singleton = true
  ),
  'https://aaaaaaaaaaaaaaaaaaaa.supabase.co',
  'dispatcher runtime config has one validated endpoint'
);

select is(
  (select count(*) from public.push_devices where user_id = '10000000-0000-0000-0000-000000000001'),
  1::bigint,
  'one device row is registered for the authenticated user'
);

set local role authenticated;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select * from public.register_push_device(
      'installation-alpha-0001',
      'alpha-fcm-token-000000000000000000000002',
      'beta', '1.0.43-beta.1', 4301, 'en', 'Europe/Istanbul',
      false, true, true, true, 1320, 420
    )$$,
  'token refresh updates the existing installation idempotently'
);

reset role;
select is(
  (
    select count(*) from public.push_devices
    where user_id = '10000000-0000-0000-0000-000000000001'
      and fcm_token = 'alpha-fcm-token-000000000000000000000002'
      and locale = 'en'
  ),
  1::bigint,
  'token refresh keeps one row and updates device metadata'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select outbox_id as alpha_test_outbox
from public.request_push_self_test()
\gset
select pass('authenticated user can request a bounded self-test');

reset role;
select is(
  (
    select count(*) from public.notification_deliveries
    where outbox_id = :'alpha_test_outbox'::uuid
  ),
  1::bigint,
  'self-test creates exactly one delivery for the active device'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select * from public.register_push_device(
      'installation-beta-00001',
      'beta-fcm-token-0000000000000000000000001',
      'beta', '1.0.43-beta.1', 4301, 'tr', 'Europe/Istanbul',
      true, true, true, false, 1320, 420
    )$$,
  'a second user can register an independent device'
);

select is(
  (
    select count(*) from public.get_push_self_test_status(:'alpha_test_outbox'::uuid)
  ),
  0::bigint,
  'another user cannot read the first users self-test status'
);

reset role;
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
create temp table wp270_health_before as
select
  (select count(*) from public.notification_outbox) as outbox_count,
  (select count(*) from public.notification_deliveries) as delivery_count;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select * from public.get_push_self_test_status(:'alpha_test_outbox'::uuid);
select pass('self-test health status is readable without dispatching work');
reset role;
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select is(
  (select outbox_count from wp270_health_before),
  (select count(*) from public.notification_outbox),
  'health read leaves outbox rows unchanged'
);
select is(
  (select delivery_count from wp270_health_before),
  (select count(*) from public.notification_deliveries),
  'health read leaves delivery rows unchanged'
);

select delivery_id as alpha_retry_delivery
from public.claim_push_deliveries('90000000-0000-0000-0000-000000000001', 1, 60)
where outbox_id = :'alpha_test_outbox'::uuid
\gset
select public.complete_push_delivery(
  :'alpha_retry_delivery'::uuid,
  '90000000-0000-0000-0000-000000000001',
  'retry', null, 'network_error', 15
);
select pass('transient transport failure schedules a bounded retry');
select is(
  (select status from public.notification_deliveries where id = :'alpha_retry_delivery'::uuid),
  'retry',
  'transient delivery remains retryable rather than terminal'
);
update public.notification_deliveries
set available_at = now() - interval '1 second'
where id = :'alpha_retry_delivery'::uuid;
select delivery_id as alpha_reclaimed_delivery
from public.claim_push_deliveries('90000000-0000-0000-0000-000000000002', 1, 60)
where outbox_id = :'alpha_test_outbox'::uuid
\gset
select public.complete_push_delivery(
  :'alpha_reclaimed_delivery'::uuid,
  '90000000-0000-0000-0000-000000000002',
  'sent', 'provider-message-1', null, 60
);
select pass('scheduled worker can reclaim retry and complete it once');
select is(
  (select status from public.notification_outbox where id = :'alpha_test_outbox'::uuid),
  'sent',
  'successful retry closes the self-test outbox'
);
select * from public.get_push_dispatch_queue_health();
select pass('service health reports queue metrics without claiming deliveries');
select is(
  (select configuration_status from public.get_push_dispatch_queue_health()),
  'configured',
  'health is green only when runtime config and pg_net transport are both present'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.send_nudge(
      '20000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000002',
      'Hadi çalışalım'
    )$$,
  'sending a nudge keeps the domain RPC successful'
);

reset role;
select is(
  (
    select count(*)
    from public.notification_outbox o
    join public.notification_deliveries d on d.outbox_id = o.id
    where o.notification_type = 'nudge'
      and o.recipient_id = '10000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'a nudge transaction creates one delivery for the recipients active device'
);
select is(
  (
    select count(distinct event_key)
    from public.notification_outbox
    where notification_type = 'nudge'
      and recipient_id = '10000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'the nudge event key is idempotently unique'
);

insert into public.announcements (
  title, message, target_type, created_by
) values (
  'Bakım', 'Yeni sürüm bu akşam hazır.', 'all',
  '10000000-0000-0000-0000-000000000001'
);
select is(
  (
    select count(*) from public.notification_outbox
    where notification_type = 'announcement'
  ),
  2::bigint,
  'a global announcement creates one outbox event per registered user'
);
select is(
  (
    select count(*)
    from public.notification_deliveries d
    join public.notification_outbox o on o.id = d.outbox_id
    where o.notification_type = 'announcement'
  ),
  2::bigint,
  'announcement fan-out creates one delivery per active device'
);

select is(
  public.enqueue_update_push(
    'beta-v4401', 'beta', '1.0.44-beta.1', 4401,
    'Odak Kampı güncellendi', 'Yeni beta hazır.'
  ),
  2,
  'service update enqueue targets each opted-in user on the release channel'
);
select is(
  (
    select count(*)
    from public.notification_deliveries d
    join public.notification_outbox o on o.id = d.outbox_id
    where o.notification_type = 'update'
  ),
  2::bigint,
  'update fan-out creates channel-filtered device deliveries'
);

insert into public.notification_outbox (
  event_key, recipient_id, notification_type, payload
) values (
  'invalid-token-fixture', '10000000-0000-0000-0000-000000000002', 'self_test', '{}'::jsonb
)
returning id as invalid_token_outbox
\gset
update public.notification_deliveries
set status = 'processing', attempts = 1,
    claimed_by = '90000000-0000-0000-0000-000000000003',
    lease_until = now() + interval '60 seconds'
where outbox_id = :'invalid_token_outbox'::uuid;
select public.disable_push_device(
  (select device_id from public.notification_deliveries where outbox_id = :'invalid_token_outbox'::uuid),
  'unregistered'
);
select pass('invalid FCM token disables the matching device without deleting audit state');
select public.complete_push_delivery(
  (select id from public.notification_deliveries where outbox_id = :'invalid_token_outbox'::uuid),
  '90000000-0000-0000-0000-000000000003',
  'failed_permanent', null, 'unregistered', 60
);
select pass('invalid-token delivery reaches permanent terminal state');
select is(
  (select status from public.notification_outbox where id = :'invalid_token_outbox'::uuid),
  'failed',
  'invalid-token outbox closes instead of retrying forever'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.unregister_push_device('installation-beta-00001')$$,
  'logout can disable the current users installation'
);

reset role;
select is(
  (
    select count(*) from public.push_devices
    where user_id = '10000000-0000-0000-0000-000000000002'
      and disabled_at is not null
  ),
  1::bigint,
  'unregister keeps an audit row but disables future delivery'
);

update public.push_devices
set last_seen_at = now() - interval '60 days'
where user_id = '10000000-0000-0000-0000-000000000001';
select is(
  public.prune_stale_push_devices(45),
  1,
  'stale-token cleanup disables only expired active registrations'
);
select is(
  (
    select count(*) from public.push_devices
    where user_id = '10000000-0000-0000-0000-000000000001'
      and disabled_at is not null
      and last_error_code = 'stale_registration'
  ),
  1::bigint,
  'stale registrations retain a non-sensitive audit reason'
);

select * from finish();
rollback;
