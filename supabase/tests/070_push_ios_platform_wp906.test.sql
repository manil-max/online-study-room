-- 070_push_ios_platform_wp906.test.sql
-- WP-906 (migration `0144`): iOS cihaz push kaydi yapabilir, eski istemci
-- (p_platform gondermeyen) 'android' olarak kalir, gecersiz platform reddedilir
-- ve dispatcher `claim_push_deliveries` uzerinden cihazin platformunu gorur.
--
-- Kimlik `005_push_delivery.test.sql` ile ayni yoldan verilir:
-- `set local role authenticated` + `request.jwt.claim.sub`.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

select plan(13);

-- ===========================================================================
-- 0) SEMA -- imza, grant, kisit
-- ===========================================================================
select ok(
  to_regprocedure(
    'public.register_push_device(text,text,text,text,integer,text,text,boolean,boolean,boolean,boolean,integer,integer,text)'
  ) is not null,
  '00 0144 register_push_device 14 parametreli imzayi kurar'
);
select ok(
  to_regprocedure(
    'public.register_push_device(text,text,text,text,integer,text,text,boolean,boolean,boolean,boolean,integer,integer)'
  ) is null,
  '01 eski 13 parametreli overload kalmadi (PostgREST belirsizligi yok)'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.register_push_device(text,text,text,text,integer,text,text,boolean,boolean,boolean,boolean,integer,integer,text)',
    'execute'
  )
    and not has_function_privilege(
      'anon',
      'public.register_push_device(text,text,text,text,integer,text,text,boolean,boolean,boolean,boolean,integer,integer,text)',
      'execute'
    ),
  '02 kayit RPC yalniz authenticated tarafindan cagrilir'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.claim_push_deliveries(uuid,integer,integer)', 'execute'
  )
    and not has_function_privilege(
      'anon', 'public.claim_push_deliveries(uuid,integer,integer)', 'execute'
    )
    and has_function_privilege(
      'service_role', 'public.claim_push_deliveries(uuid,integer,integer)', 'execute'
    ),
  '03 claim_push_deliveries yeniden kurulunca da yalniz service_role'
);
select throws_ok(
  $$insert into public.push_devices (
      user_id, installation_id, fcm_token, platform, app_channel, app_version
    ) values (
      '10000000-0000-0000-0000-000000000001', 'installation-web-000001',
      'web-fcm-token-00000000000000000000000001', 'web', 'beta', '1.0.0'
    )$$,
  '23514',
  null,
  '04 tablo kisiti android/ios disini reddeder'
);

-- ===========================================================================
-- 1) VARSAYILAN -- p_platform gondermeyen eski istemci android kalir
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select * from public.register_push_device(
      'installation-andr-00001',
      'andr-fcm-token-0000000000000000000000001',
      'beta', '1.0.90-beta.1', 9001, 'tr', 'Europe/Istanbul',
      true, true, true, false, 1320, 420
    )$$,
  '05 13 argumanli (eski istemci) cagri hala calisir'
);
reset role;
select is(
  (select platform from public.push_devices
    where installation_id = 'installation-andr-00001'),
  'android',
  '06 p_platform verilmezse satir android yazilir'
);

-- ===========================================================================
-- 2) iOS kabul edilir, gecersiz platform reddedilir
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select * from public.register_push_device(
      'installation-ios-000001',
      'ios-fcm-token-00000000000000000000000001',
      'stable', '1.0.90', 9001, 'en', 'Europe/Istanbul',
      true, true, true, false, 1320, 420,
      p_platform => 'ios'
    )$$,
  '07 p_platform => ios kabul edilir'
);
select throws_ok(
  $$select * from public.register_push_device(
      'installation-win-000001',
      'win-fcm-token-00000000000000000000000001',
      'stable', '1.0.90', 9001, 'en', 'Europe/Istanbul',
      true, true, true, false, 1320, 420,
      p_platform => 'windows'
    )$$,
  'P0001',
  'invalid_platform',
  '08 gecersiz platform invalid_platform ile reddedilir'
);
reset role;
select is(
  (select platform from public.push_devices
    where installation_id = 'installation-ios-000001'),
  'ios',
  '09 iOS satiri ios olarak saklanir'
);
select is(
  (select count(*)::integer from public.push_devices
    where installation_id = 'installation-win-000001'),
  0,
  '10 reddedilen cagri satir birakmaz'
);

-- ===========================================================================
-- 3) Dispatcher cihazin platformunu gorur
-- ===========================================================================
select id as ios_device
from public.push_devices
where installation_id = 'installation-ios-000001'
\gset
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select outbox_id as ios_outbox
from public.request_push_self_test(:'ios_device'::uuid)
\gset
reset role;
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
create temp table wp906_claimed as
select outbox_id, device_id, platform
from public.claim_push_deliveries('90000000-0000-0000-0000-000000000906', 100, 60);
select is(
  (select platform from wp906_claimed where outbox_id = :'ios_outbox'::uuid),
  'ios',
  '11 claim_push_deliveries iOS teslimi icin platform=ios doner'
);
select is(
  (select count(*)::integer from wp906_claimed
    where outbox_id = :'ios_outbox'::uuid and device_id = :'ios_device'::uuid),
  1,
  '12 self-test yalniz hedef iOS cihaza tek teslim uretir'
);
reset role;

select * from finish();
rollback;
