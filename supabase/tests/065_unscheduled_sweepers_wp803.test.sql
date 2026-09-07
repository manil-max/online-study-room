-- 065_unscheduled_sweepers_wp803.test.sql
-- WP-803: yazilmis ama HIC ZAMANLANMAMIS uc supurucu.
--
-- 🔴 Bu dosyanin varlik sebebi bir SINIF hatasidir, tek bir kusur degil:
-- fonksiyon yazilir, grant edilir, pgTAP'te sinanir ve `cron.job` icine
-- HIC girmez. Testi yesil gecer cunku test fonksiyonu DOGRUDAN cagirir --
-- yani "calisiyor" olcumu, "cagriliyor" olcumunu icermez.
--
-- 0106'nin kendi basligi *"Kanit artik suresiz durmaz"* diyordu ve kanit
-- suresiz duruyordu. 0089 ayni hatayi bir kez daha yakalamisti
-- (`expire_global_timer_v2_leases` 0082'den beri zamanlanmamisti).
--
-- Olculen sey burada FONKSIYONUN DAVRANISI DEGIL, ZAMANLANMIS OLMASIDIR.

begin;
select plan(14);

-- ===========================================================================
-- 1. Uc is de kayitli ve DOGRU fonksiyonu cagiriyor
-- ===========================================================================

select ok(
  exists (select 1 from cron.job where jobname = 'moderation-evidence-purge'),
  '🔴 kanit redaksiyonu cron job KAYITLI (0106 - 0139 arasi HIC calismadi)'
);
select is(
  (select command from cron.job where jobname = 'moderation-evidence-purge'),
  'select public.moderation_purge_expired_evidence()',
  'kanit isi dogru fonksiyonu cagiriyor'
);

select ok(
  exists (select 1 from cron.job where jobname = 'multi-group-presence-lease-sweeper'),
  'presence kira supurucusu cron job KAYITLI'
);
select is(
  (select command from cron.job where jobname = 'multi-group-presence-lease-sweeper'),
  'select public.expire_multi_group_presence_leases(200)',
  'presence isi dogru fonksiyonu ve limiti cagiriyor'
);

select ok(
  exists (select 1 from cron.job where jobname = 'push-device-stale-pruner'),
  'bayat push cihazi temizleyicisi cron job KAYITLI'
);
select is(
  (select command from cron.job where jobname = 'push-device-stale-pruner'),
  'select public.prune_stale_push_devices(45)',
  'push isi dogru fonksiyonu ve esigi cagiriyor'
);

-- ===========================================================================
-- 2. Cagrilan fonksiyonlar GERCEKTEN var
--    (cron komutu bir dize; yanlis ad yazilirsa is her gece sessizce duser)
-- ===========================================================================

select ok(
  to_regprocedure('public.moderation_purge_expired_evidence()') is not null,
  'kanit isinin cagirdigi fonksiyon gercekten var'
);
select ok(
  to_regprocedure('public.expire_multi_group_presence_leases(integer)') is not null,
  'presence isinin cagirdigi fonksiyon gercekten var'
);
select ok(
  to_regprocedure('public.prune_stale_push_devices(integer)') is not null,
  'push isinin cagirdigi fonksiyon gercekten var'
);

-- ===========================================================================
-- 3. 🔴 ASIL TUZAK: kanit fonksiyonu CRON BAGLAMINDA calisabiliyor mu
--
-- 0139 oncesi govdenin ilk satiri `if not public.is_super_admin() then raise`
-- idi. `cron.schedule` isi tablo sahibi olarak kosar; JWT yoktur,
-- `auth.uid()` NULL'dur, `is_super_admin()` FALSE doner. Fonksiyonu OLDUGU
-- GIBI zamanlamak her gece exception uretirdi ve bu yalniz
-- `cron.job_run_details` icinde gorunurdu -- yani "zamanladim" denip yine
-- hic calismamis olurdu.
--
-- Burada JWT YOKTUR (pgTAP oturumu), yani bu cagri cron baglamini taklit
-- eder. `lives_ok` gecmezse is her gece sessizce duserdi.
-- ===========================================================================

select lives_ok(
  $$ select public.moderation_purge_expired_evidence() $$,
  '🔴 kanit redaksiyonu JWT OLMADAN kosabiliyor (cron baglami)'
);

select isnt(
  (select public.moderation_purge_expired_evidence()),
  null,
  'redaksiyon kac satir imha ettigini doner (cron ciktisi olculebilir)'
);

-- Kardes supuruculer de ayni baglamda kosabilmeli.
select lives_ok(
  $$ select public.expire_multi_group_presence_leases(200) $$,
  'presence supurucusu JWT olmadan kosabiliyor'
);
select lives_ok(
  $$ select public.prune_stale_push_devices(45) $$,
  'push temizleyicisi JWT olmadan kosabiliyor'
);

-- ===========================================================================
-- 4. Yetki GENISLEDI ama kullaniciya acilan yuzey AYNI kaldi
--
-- Muhafiz "service_role/postgres VEYA super admin"e cevrildi. Genisleyen
-- taraf yalniz sunucunun kendisi; `authenticated` grant'i duruyor ve normal
-- kullanici hala ancak super adminse cagirabiliyor.
-- ===========================================================================

select ok(
  has_function_privilege(
    'authenticated', 'public.moderation_purge_expired_evidence()', 'execute'
  ),
  'authenticated grant KORUNDU (super admin yolu bozulmadi)'
);

select * from finish();
rollback;
