begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql
select plan(9);

-- WP-373 regresyon kapanı.
--
-- Bu dosya, çoklu cihaz sayaç senkronunu WP-341'den WP-373'ye kadar sessizce
-- ölü tutan sözleşme ihlalini ölçer. Mevcut testler sunucuyu KENDİ uydurduğu
-- 'app' değeriyle çağırıyordu; istemcinin gerçekte ne gönderdiğine bakan tek
-- bir iddia yoktu. Buradaki 2-4 numaralı iddialar, istemcinin ESKİ sözlüğünün
-- reddedildiğini kayda geçirir — Kotlin üreticisi bir gün yeniden ham
-- `startOrigin` yazarsa, `test/core/timer_v2_origin_contract_test.dart` bunu
-- istemci ucunda yakalar ve bu dosya da sunucu ucunda neden yakalandığını anlatır.

insert into public.push_devices (
  id, user_id, installation_id, fcm_token, app_channel, app_version, build_number,
  locale, time_zone, nudge_enabled, announcement_enabled, update_enabled,
  quiet_hours_enabled, quiet_start_minutes, quiet_end_minutes
) values
  ('30000000-0000-0000-0000-000000000051', '10000000-0000-0000-0000-000000000001',
   'timer-contract-installation-051', 'timer-contract-token-0000000000000000051',
   'beta', '1.0.0', 1, 'tr', 'Europe/Istanbul', false, false, false, true, 0, 0);

-- ---------------------------------------------------------------- 1. sözlük
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000051', '30000000-0000-0000-0000-000000000051',
  'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'app'), 2
)->'run'->>'id')::uuid as run_app \gset
select public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000052', '30000000-0000-0000-0000-000000000051',
  'stop', :'run_app'::uuid, 1, clock_timestamp(), '{}'::jsonb, 2);

select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000053', '30000000-0000-0000-0000-000000000051',
  'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'widget'), 2
)->'run'->>'id')::uuid as run_widget \gset
select public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000054', '30000000-0000-0000-0000-000000000051',
  'stop', :'run_widget'::uuid, 1, clock_timestamp(), '{}'::jsonb, 2);

select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000055', '30000000-0000-0000-0000-000000000051',
  'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'notification'), 2
)->'run'->>'id')::uuid as run_notification \gset
select public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000056', '30000000-0000-0000-0000-000000000051',
  'stop', :'run_notification'::uuid, 1, clock_timestamp(), '{}'::jsonb, 2);

select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000057', '30000000-0000-0000-0000-000000000051',
  'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'recovery'), 2
)->'run'->>'id')::uuid as run_recovery \gset
select public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000058', '30000000-0000-0000-0000-000000000051',
  'stop', :'run_recovery'::uuid, 1, clock_timestamp(), '{}'::jsonb, 2);
reset role;

select is(
  (select array_agg(distinct origin order by origin)
   from public.live_study_runs
   where user_id = '10000000-0000-0000-0000-000000000001' and protocol_version = 2),
  array['app', 'notification', 'recovery', 'widget'],
  'every origin the client is allowed to emit is accepted end to end'
);

-- ------------------------------------------------- 2-4. eski istemci sözlüğü
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select public.apply_global_timer_command(
    '40000000-0000-0000-0000-000000000061', '30000000-0000-0000-0000-000000000051',
    'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'dart_app'), 2)$$,
  'P0001', 'invalid_global_timer_origin',
  'the pre-WP-373 in-app origin is rejected — this silently killed every start'
);
select throws_ok(
  $$select public.apply_global_timer_command(
    '40000000-0000-0000-0000-000000000062', '30000000-0000-0000-0000-000000000051',
    'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'native_widget'), 2)$$,
  'P0001', 'invalid_global_timer_origin',
  'the pre-WP-373 widget origin is rejected'
);
select throws_ok(
  $$select public.apply_global_timer_command(
    '40000000-0000-0000-0000-000000000063', '30000000-0000-0000-0000-000000000051',
    'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'native_notification'), 2)$$,
  'P0001', 'invalid_global_timer_origin',
  'the pre-WP-373 notification origin is rejected'
);

-- ------------------------------------------------------- 5. durdurma sözleşmesi
select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000071', '30000000-0000-0000-0000-000000000051',
  'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'app'), 2
)->'run'->>'id')::uuid as live_run \gset

-- psql, dollar-quote içinde değişken doldurmaz; sorgu metni `format` ile kurulur.
select throws_ok(
  format(
    $$select public.apply_global_timer_command(
      '40000000-0000-0000-0000-000000000072', '30000000-0000-0000-0000-000000000051',
      'stop', %L::uuid, null, clock_timestamp(), '{}'::jsonb, 2)$$,
    :'live_run'
  ),
  'P0001', 'stop_run_revision_required',
  'a stop without the expected revision is refused — the native envelope must carry it'
);
reset role;

-- --------------------------------------------------------------- 6. heartbeat
update public.live_study_runs
set lease_expires_at = clock_timestamp() + interval '10 seconds'
where id = :'live_run';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000073', '30000000-0000-0000-0000-000000000051',
  'heartbeat', :'live_run'::uuid, null, clock_timestamp(), '{}'::jsonb, 2);
reset role;

select ok(
  (select lease_expires_at > clock_timestamp() + interval '100 seconds'
   from public.live_study_runs where id = :'live_run'),
  'a heartbeat renews the lease so a live run is never swept while it runs'
);

-- ------------------------------------------------------------- 7-8. süpürücü
select ok(
  exists(
    select 1 from cron.job
    where jobname = 'global-timer-v2-lease-sweeper'
      and schedule = '* * * * *'
      and command = 'select public.expire_global_timer_v2_leases(200)'
  ),
  'WP-373 schedules the lease sweeper that 0082 defined but never wired up'
);
select is(
  public.expire_global_timer_v2_leases(200), 0,
  'the scheduled limit is inside the accepted range and sweeps nothing while leases are fresh'
);

-- --------------------------------------------------- 9. ölü koşu gerçekten kapanır
update public.live_study_runs
set lease_expires_at = clock_timestamp() - interval '12 hours 1 second'
where id = :'live_run';
select public.expire_global_timer_v2_leases(200);

select ok(
  (select status = 'abandoned' from public.live_study_runs where id = :'live_run')
    and (select current_run_id is null from public.user_timer_state
         where user_id = '10000000-0000-0000-0000-000000000001'),
  'a run beyond the recovery grace is abandoned and cleared so the mirroring device stops too'
);

select * from finish();
rollback;
