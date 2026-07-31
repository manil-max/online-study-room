begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql
-- 12 iddia var; dosya ilk yazıldığında `plan(11)` sayılmıştı. Test hiç
-- koşmadığı için bu sapma da görünmemişti (WP-473).
select plan(12);

-- WP-431 sunucu sözleşmesi.
--
-- WP-430 kanıtı (`docs/qa/V57-TIMER-EVIDENCE.md`) üç sunucu kusuru gösterdi:
-- okuma yolu kirayı süzmüyordu, çevrimdışı başlangıç zamanı flush anına
-- kayıyordu ve "hesap-geneli tek aktif koşu" yalnız uygulama mantığında
-- yaşıyordu. Bu dosya üçünü de invariant olarak kilitler.

insert into public.push_devices (
  id, user_id, installation_id, fcm_token, app_channel, app_version, build_number,
  locale, time_zone, nudge_enabled, announcement_enabled, update_enabled,
  quiet_hours_enabled, quiet_start_minutes, quiet_end_minutes
) values
  ('30000000-0000-0000-0000-000000000061', '10000000-0000-0000-0000-000000000001',
   'wp431-source-installation-061', 'wp431-source-token-00000000000000000061',
   'beta', '1.0.0', 1, 'tr', 'Europe/Istanbul', false, false, false, true, 0, 0),
  ('30000000-0000-0000-0000-000000000062', '10000000-0000-0000-0000-000000000001',
   'wp431-mirror-installation-062', 'wp431-mirror-token-00000000000000000062',
   'beta', '1.0.0', 1, 'tr', 'Europe/Istanbul', false, false, false, true, 0, 0);

-- 🔴 Rol disiplini (WP-473): `live_study_runs`, `user_timer_state` ve
-- `global_timer_commands` `0051`/`0082`'den beri `authenticated`'a **kapalıdır**
-- (`revoke all`). RPC çağrıları `auth.uid()` gerektirdiği için `authenticated`
-- rolünde yapılır, fakat iç tabloların doğrulaması `reset role` ile ayrıcalıklı
-- rolde okunur. Bu dosya ilk yazıldığında hiç koşmadığı için doğrulamalar da
-- `authenticated` altında duruyordu ve replay'de 11/11 "permission denied"
-- veriyordu. Aşağıdaki `reset role` / `set local role authenticated` çiftleri
-- `018_global_timer_command_contract` dosyasındaki yerleşik kalıbı izler.
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

-- --------------------------------------------- 1. çevrimdışı başlangıç korunur
select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000061', '30000000-0000-0000-0000-000000000061',
  'start', null, null, clock_timestamp() - interval '3 hours',
  jsonb_build_object('origin', 'app'), 2
)->'run'->>'id')::uuid as offline_run \gset

reset role;
select ok(
  (select effective_started_at < clock_timestamp() - interval '2 hours 50 minutes'
   from public.live_study_runs where id = :'offline_run'),
  'an offline start keeps its real start time instead of collapsing onto the flush moment'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

-- ------------------------------------ 2. çevrimdışı başlangıç 24 saatle sınırlı
select public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000062', '30000000-0000-0000-0000-000000000061',
  'stop', :'offline_run'::uuid, 1, clock_timestamp(), '{}'::jsonb, 2);

select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000063', '30000000-0000-0000-0000-000000000061',
  'start', null, null, clock_timestamp() - interval '40 hours',
  jsonb_build_object('origin', 'app'), 2
)->'run'->>'id')::uuid as ancient_run \gset

reset role;
select ok(
  (select effective_started_at >= clock_timestamp() - interval '24 hours 1 minute'
   from public.live_study_runs where id = :'ancient_run'),
  'a start older than 24 hours is clamped instead of creating an unbounded ghost run'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

-- ------------------------------------------- 3. gelecekten gelen komut reddedilir
select public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000064', '30000000-0000-0000-0000-000000000061',
  'stop', :'ancient_run'::uuid, 1, clock_timestamp(), '{}'::jsonb, 2);

select throws_ok(
  $$select public.apply_global_timer_command(
      '40000000-0000-0000-0000-000000000065', '30000000-0000-0000-0000-000000000061',
      'start', null, null, clock_timestamp() + interval '10 minutes',
      jsonb_build_object('origin', 'app'), 2)$$,
  'client_clock_skew_rejected',
  'a future dated command is rejected instead of producing a permanently fresh run'
);

-- -------------------------------------------------- 4. ayna cihaz durdurabilir
select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000066', '30000000-0000-0000-0000-000000000061',
  'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'app'), 2
)->'run'->>'id')::uuid as shared_run \gset

select is(
  public.apply_global_timer_command(
    '40000000-0000-0000-0000-000000000067', '30000000-0000-0000-0000-000000000062',
    'stop', :'shared_run'::uuid, 1, clock_timestamp(),
    jsonb_build_object('origin', 'notification'), 2
  )->>'result_code',
  'applied',
  'the mirror device can terminate the run the source device started (V56-S01)'
);

reset role;
select ok(
  (select status = 'stopped' from public.live_study_runs where id = :'shared_run'),
  'the run really terminates for every device, not only for the mirror surface'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

-- ------------------------------------- 5. terminal durum her zaman üstün gelir
select is(
  public.apply_global_timer_command(
    '40000000-0000-0000-0000-000000000068', '30000000-0000-0000-0000-000000000061',
    'stop', :'shared_run'::uuid, 2, clock_timestamp(), '{}'::jsonb, 2
  )->>'result_code',
  'already_stopped',
  'a late stop from the source device cannot resurrect or double terminate the run'
);

-- ----------------------------------- 6. aynı komut 20 kez → tek terminal sonuç
select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000069', '30000000-0000-0000-0000-000000000061',
  'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'app'), 2
)->'run'->>'id')::uuid as repeat_run \gset

-- Koşu kimliği doğrudan `:'repeat_run'`den gelir ve döngü `generate_series`
-- ile kurulur. Önceki hâli `do $$ … $$` bloğu içinde her turda
-- `user_timer_state`i okuyordu; o tablo `authenticated`'a kapalı olduğu için
-- döngü hiç çalışamıyordu. psql, dollar-quote edilmiş gövdenin içinde değişken
-- enterpolasyonu yapmadığı için kimliği bloğa sokmanın yolu da yoktu; düz SQL
-- biçimi hem bu kısıtı kaldırıyor hem de testin niyetini — **aynı komut
-- kimliğinin** 20 kez teslimi — daha doğrudan ifade ediyor.
-- `apply_global_timer_command` VOLATILE olduğu için satır başına bir kez çalışır.
select count(public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000070', '30000000-0000-0000-0000-000000000062',
  'stop', :'repeat_run'::uuid, 1, clock_timestamp(), '{}'::jsonb, 2))
from generate_series(1, 20);

reset role;
select is(
  (select count(*)::int from public.global_timer_commands
   where command_id = '40000000-0000-0000-0000-000000000070'),
  1,
  'twenty deliveries of the same command id leave exactly one terminal result'
);

select is(
  (select run_revision::int from public.live_study_runs where id = :'repeat_run'),
  2,
  'the repeated deliveries advance the revision exactly once'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

-- --------------------------------- 7. kirası dolmuş koşu snapshot'ta işaretli
select (public.apply_global_timer_command(
  '40000000-0000-0000-0000-000000000071', '30000000-0000-0000-0000-000000000061',
  'start', null, null, clock_timestamp(), jsonb_build_object('origin', 'app'), 2
)->'run'->>'id')::uuid as lease_run \gset

select ok(
  not ((public.get_global_timer_v2_snapshot('30000000-0000-0000-0000-000000000062')
        ->'run'->>'lease_expired')::boolean),
  'a healthy run is not flagged as lease expired'
);

reset role;
update public.live_study_runs
set lease_expires_at = clock_timestamp() - interval '8 hours'
where id = :'lease_run';
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select ok(
  ((public.get_global_timer_v2_snapshot('30000000-0000-0000-0000-000000000062')
    ->'run'->>'lease_expired')::boolean),
  'an expired lease is reported to the mirror even before the sweeper runs (V56-S04)'
);

-- ------------------------------- 8. kira süpürücüsü oturum UYDURMAZ
reset role;
select public.expire_global_timer_v2_leases(200);

select is(
  (select count(*)::int from public.study_sessions
   where user_id = '10000000-0000-0000-0000-000000000001'),
  0,
  'expiring a lease abandons the run without fabricating a study session'
);

-- ------------------------------- 9. hesap-geneli tek aktif koşu invariant'ı
select throws_ok(
  $$insert into public.live_study_runs(
      user_id, status, protocol_version, run_kind, effective_started_at,
      run_revision, user_state_version, lease_expires_at)
    values
      ('10000000-0000-0000-0000-000000000001', 'running', 2, 'study',
       clock_timestamp(), 1, 1, clock_timestamp() + interval '150 seconds'),
      ('10000000-0000-0000-0000-000000000001', 'running', 2, 'study',
       clock_timestamp(), 1, 1, clock_timestamp() + interval '150 seconds')$$,
  '23505',
  'two simultaneously running v2 runs for one account are impossible at the schema level'
);

select * from finish();
rollback;
