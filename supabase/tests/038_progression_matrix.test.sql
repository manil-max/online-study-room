-- 038_progression_matrix.test.sql
-- WP-455: seri ve butun ilerleme kabul matrisinin SUNUCU ucu.
--
-- Istemci esi: `app/test/data/progression_matrix_wp455_test.dart`.
--
-- 037 seri motorunun kendi sozlesmesini olcuyordu (grace, kapsam ayrimi,
-- cift artis). Burada olculen sey motorun KOMSULARIYLA iliskisi ve yalnizca
-- gercek bir veritabaninda gorunebilen satirlar:
--
--   * gun siniri kapsamin saat dilimine gore kesiliyor mu (23:59 / 00:01),
--   * oturum kaynagi (live/manual) hedefe esit sayiliyor mu,
--   * kisisel ve grup FARKLI hedeflerle ayni gunde farkli sonuc veriyor mu,
--   * ayni gunu iki cihazdan bildirmek seriyi iki kez artiriyor mu,
--   * ve `streak_days` basarim metrigi ile `goal_streak_projection` ayni
--     gecmiste ayni sayiyi veriyor mu.
--
-- 🔴 Son bolum bir BULGUYU sabitliyor, bir kabulu degil: iki tanim ayrisiyor.
-- Ayrinti ve karar notu `docs/qa/V57-PROGRESSION-EVIDENCE.md` §4.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

select plan(20);

-- ===========================================================================
-- Kurulum
-- ===========================================================================
select ok(
  to_regprocedure('public._goal_day_seconds(uuid,date,text)') is not null,
  'gun toplami yardimcisi 0112 ile geldi'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public._goal_day_seconds(uuid,date,text)', 'execute'
  ),
  'gun toplami yardimcisi istemciye kapali'
);

-- ===========================================================================
-- 1. Oturum kaynagi ayrimciligi yok
-- ===========================================================================
-- base_seed bugun alpha'ya 1 saat `live`, beta'ya 1 saat `manual` birakiyor.
-- Kronometre/geri sayim/pomodoro ucu de `live` yazar (study_providers.dart),
-- elle giris `manual`. Hedef hesabi kaynaga BAKMAMALI.
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  '30000000-0000-0000-0000-0000000000aa'::uuid,
  :'alpha'::uuid,
  started_at,
  started_at + interval '30 minutes',
  1800,
  'manual'
from (
  select (
    date_trunc('day', timezone('Europe/Istanbul', now())) + interval '10 hours'
  ) at time zone 'Europe/Istanbul' as started_at
) t;

select is(
  public._goal_day_seconds(
    :'alpha', (now() at time zone 'Europe/Istanbul')::date, 'Europe/Istanbul'
  ),
  5400::bigint,
  'live 3600 + manual 1800 = 5400: kaynak ayrimi yapilmaz'
);

-- ===========================================================================
-- 2. Gun siniri: 23:59 / 00:01
-- ===========================================================================
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
values
  (
    '30000000-0000-0000-0000-0000000000b1'::uuid,
    :'beta'::uuid,
    (date '2026-03-08' + time '23:59') at time zone 'Europe/Istanbul',
    (date '2026-03-09' + time '00:29') at time zone 'Europe/Istanbul',
    1800,
    'live'
  ),
  (
    '30000000-0000-0000-0000-0000000000b2'::uuid,
    :'beta'::uuid,
    (date '2026-03-09' + time '00:01') at time zone 'Europe/Istanbul',
    (date '2026-03-09' + time '00:31') at time zone 'Europe/Istanbul',
    1800,
    'live'
  );

select is(
  public._goal_day_seconds(:'beta', '2026-03-08', 'Europe/Istanbul'),
  1800::bigint,
  '23:59 oturumu 8 Mart gunune yazilir'
);
select is(
  public._goal_day_seconds(:'beta', '2026-03-09', 'Europe/Istanbul'),
  1800::bigint,
  '00:01 oturumu 9 Mart gunune yazilir: gece yarisi gunu boler'
);
-- Ayni iki oturum baska bir bolgede baska gunlere duser. Grup kendi saat
-- dilimini tasidigi icin bu satir kozmetik degil: Tokyo grubunun gunu
-- Istanbul gunuyle ayni degildir.
select is(
  public._goal_day_seconds(:'beta', '2026-03-09', 'Asia/Tokyo'),
  3600::bigint,
  'Asia/Tokyo bolgesinde iki oturum da 9 Mart gunune duser'
);

-- ===========================================================================
-- 3. Kisisel ve grup FARKLI hedefler
-- ===========================================================================
-- Bugun: alpha 5400 sn, beta 3600 sn. Grup toplami 9000 sn.
-- Kisisel hedef 180 dk (10800 sn) -> alpha ULASAMAZ.
-- Grup hedefi 120 dk (7200 sn)    -> grup ULASIR.
update public.profiles set daily_goal_minutes = 180 where id = :'alpha';
update public.groups set daily_goal_minutes = 120 where id = :'grp';

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select is(
  public.record_goal_completion(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date
  ),
  false,
  'kisisel hedef karsilanmadi: kendi gunu 5400 < 10800'
);
select is(
  public.record_goal_completion(
    'group', :'grp', (now() at time zone 'Europe/Istanbul')::date
  ),
  true,
  'grup hedefi karsilandi: uyelerin toplami 9000 >= 7200'
);
reset role;

-- Ayni gun, ayni kisi, iki farkli sonuc. Sizinti olsaydi grup tamamlamasi
-- kisisel ledgere de duserdi.
select is(
  (select count(*)::int from public.goal_progress_events
   where scope_type = 'personal' and scope_id = :'alpha'),
  0,
  'grup tamamlamasi kisisel ledgere sizmaz'
);
select is(
  (select count(*)::int from public.goal_progress_events
   where scope_type = 'group' and scope_id = :'grp'),
  1,
  'grup tamamlamasi yalniz grup ledgerine yazilir'
);
select is(
  (select current_streak from public.goal_streak_projection(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date
  )),
  0,
  'kisisel seri ilerlemedi'
);
select is(
  (select current_streak from public.goal_streak_projection(
    'group', :'grp', (now() at time zone 'Europe/Istanbul')::date
  )),
  1,
  'grup serisi 1 ilerledi'
);

-- ===========================================================================
-- 4. Iki cihaz ayni gunu iki kez bildirir
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);
select is(
  public.record_goal_completion(
    'group', :'grp', (now() at time zone 'Europe/Istanbul')::date
  ),
  true,
  'ikinci cihaz da true alir: cagri idempotent, hata degil'
);
reset role;

select is(
  (select count(*)::int from public.goal_progress_events
   where scope_type = 'group' and scope_id = :'grp'
     and goal_day = (now() at time zone 'Europe/Istanbul')::date),
  1,
  'iki cihazdan iki bildirim TEK satir birakir'
);
select is(
  (select current_streak from public.goal_streak_projection(
    'group', :'grp', (now() at time zone 'Europe/Istanbul')::date
  )),
  1,
  'iki cihaz seriyi 2 yapmaz: cift artis 0'
);

-- ===========================================================================
-- 5. Hedef siniri tam degerde
-- ===========================================================================
-- alpha bugun 5400 sn calisti. Hedef tam 90 dk (5400 sn) olunca esitlik
-- KABUL edilmeli; 91 dk olunca reddedilmeli. "> mu >= mi" hatasi tam burada
-- gorunur.
update public.profiles set daily_goal_minutes = 90 where id = :'alpha';
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select is(
  public.record_goal_completion(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date
  ),
  true,
  'gun toplami hedefe TAM esitse tamamlama kabul edilir'
);
reset role;

delete from public.goal_progress_events
where scope_type = 'personal' and scope_id = :'alpha';

update public.profiles set daily_goal_minutes = 91 where id = :'alpha';
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select is(
  public.record_goal_completion(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date
  ),
  false,
  'hedefin 1 dakika altinda tamamlama yazilmaz'
);
reset role;

-- ===========================================================================
-- 6. 🔴 BULGU: `streak_days` ile `goal_streak_projection` ayrisiyor
-- ===========================================================================
-- Ayni calisma gecmisi, iki farkli "seri" tanimi:
--   * `goal_streak_projection` (0112, WP-453) tek kacirmayi affeder,
--   * `_achievement_metrics.streak_days` (0025 govdesi) ilk eksik gunde durur.
-- Bu satirlar farkin BUGUN var oldugunu sabitliyor. Kapatilmasi XP esiklerini
-- degistirir; karar sahibindir (docs/qa/V57-PROGRESSION-EVIDENCE.md §4).
update public.profiles set daily_goal_minutes = 30 where id = :'beta';

-- beta icin: bugun, bugun-2 ve bugun-4 hedefi asar; bugun-1 ve bugun-3 bos.
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  ('30000000-0000-0000-0000-0000000000c' || n)::uuid,
  :'beta'::uuid,
  started_at,
  started_at + interval '1 hour',
  3600,
  'live'
from (
  select
    n,
    (
      date_trunc('day', timezone('Europe/Istanbul', now()))
        - make_interval(days => n) + interval '9 hours'
    ) at time zone 'Europe/Istanbul' as started_at
  from (values (0), (2), (4)) as v(n)
) t;

-- Ayni gunler kanonik hedef olayi olarak da yaziliyor.
--
-- 🔴 `on conflict do nothing` WP-501 turunda eklendi ve sebebi bir REGRESYON:
-- WP-492'nin `0120` tetikleyicisi ayni olaylari artik `study_sessions`
-- yaziminda **kendisi** uretiyor ve event_key birebir ayni bicimde
-- (`0120:117`). Bu insert o yuzden `goal_progress_events_pkey` cakismasi
-- veriyordu. Hata `b8aaa3f` push'undan beri main'de duruyordu ama GitHub
-- Actions o pencerede (2026-08-06 17:07-23:08 UTC) hic run acmadigi icin
-- kimse gormedi; ilk kez WP-501'in Database Gates kosumunda ortaya cikti.
--
-- Insert silinmiyor: testin niyeti "bu gunler tamamlanmis sayilsin"; olayi
-- kimin yazdigi (tetikleyici mi, bu satir mi) iddiayi degistirmez.
insert into public.goal_progress_events
  (event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at)
select
  'personal:' || :'beta' || ':goal_completed:' || d::text,
  'personal', :'beta', 'Europe/Istanbul', 'goal_completed', d, now()
from (
  select ((now() at time zone 'Europe/Istanbul')::date - n) as d
  from (values (0), (2), (4)) as v(n)
) t
on conflict (event_key) do nothing;

select is(
  (select current_streak from public.goal_streak_projection(
    'personal', :'beta', (now() at time zone 'Europe/Istanbul')::date
  )),
  3,
  'seri motoru (0112): tamamla-bos-tamamla-bos-tamamla = 3'
);

select is(
  ((public._achievement_metrics(:'beta')->>'streak_days')::integer),
  1,
  'basarim metrigi (streak_days) ayni gecmiste 1 sayar: grace tanimiyor'
);

-- Iddia bos dusmesin: farkin kendisi acikca olculuyor. Ayrisma kapatildiginda
-- bu satir kirmiziya doner ve KASTEN guncellenir.
select isnt(
  ((public._achievement_metrics(:'beta')->>'streak_days')::integer),
  (select current_streak from public.goal_streak_projection(
    'personal', :'beta', (now() at time zone 'Europe/Istanbul')::date
  )),
  '🔴 iki seri tanimi ayni gecmiste ayni sayiyi vermiyor (acik bulgu)'
);

select * from finish();
rollback;
