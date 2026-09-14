-- 067_goal_frozen_on_completion_wp828.test.sql
-- WP-828 (migration `0141`): hedef AYARI degisince gecmis yeniden yargilanmaz.
--
-- Kusur: "hedef tutuldu mu" karari gecmisteki her gun icin BUGUNKU
-- `profiles.daily_goal_minutes` ile yeniden veriliyordu. Iki yonu vardi:
--
--   * OKUMA -- hedefini dusuren kullanici, calismasi hic degismeden gecmisten
--     rozet kazaniyordu: hafta sonu gunleri (`0025`), Kusursuz Ay (`0058`),
--     gizli "son saniye" ve "sinir yok" (`0025`).
--   * SILME -- hedefini YUKSELTEN kullanici gecmis bir gunun oturumunu
--     duzenleyince `_retract_goal_completion` (`0132`) o gunu bugunku hedefle
--     yargilayip tamamlama olayini SILIYORDU; ates serisi o gun kiriliyordu.
--     `055` bu kurali onarim yolunda zaten koyuyordu ("hedef sonradan yukselse
--     de calisilmis gunun serisi YANMAZ") -- ama yalniz onarim yolunda.
--
-- Senaryolar grup uyeligi OLMAYAN uc temiz kullaniciyla kurulur; grup
-- tetikleyicileri iddialara karismaz. Tarihler sabit ve gecmistir.
--
-- Sahip sarti (2026-09-14): kimsenin verisi/rozeti silinmez. Bu yuzden
-- "hedef yukselince sayi DUSMEZ" iddialari (A5, C1, C3) kusurun kendisi kadar
-- onemlidir.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set wk '10000000-0000-0000-0000-000000000821'
\set nl '10000000-0000-0000-0000-000000000822'
\set rt '10000000-0000-0000-0000-000000000823'

select plan(17);

insert into auth.users (id, email, raw_user_meta_data)
values
  (:'wk', 'fixture-wp828-weekend@example.invalid', '{"display_name":"WP828 Weekend"}'::jsonb),
  (:'nl', 'fixture-wp828-secrets@example.invalid', '{"display_name":"WP828 Secrets"}'::jsonb),
  (:'rt', 'fixture-wp828-retract@example.invalid', '{"display_name":"WP828 Retract"}'::jsonb)
on conflict (id) do nothing;

-- ===========================================================================
-- A) HAFTA SONU + KUSURSUZ AY -- hedefi dusurmek gecmisi sisirmemeli
-- ===========================================================================
-- Hedef 3 sa. Iki hafta sonu gunu 4 sa (tutar), iki hafta sonu gunu 2 sa
-- (tutmaz). Subat 2026'nin 28 gununun hepsi 2 sa (hicbiri tutmaz).
update public.profiles set daily_goal_minutes = 180 where id = :'wk';

insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  gen_random_uuid(), :'wk'::uuid,
  ((d.day + time '10:00') at time zone 'Europe/Istanbul'),
  ((d.day + time '10:00') at time zone 'Europe/Istanbul') + make_interval(secs => d.secs),
  d.secs, 'manual'
from (values
  (date '2026-03-07', 14400),
  (date '2026-03-08', 14400),
  (date '2026-03-14', 7200),
  (date '2026-03-15', 7200)
) as d(day, secs);

insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  gen_random_uuid(), :'wk'::uuid,
  ((g.day::date + time '10:00') at time zone 'Europe/Istanbul'),
  ((g.day::date + time '10:00') at time zone 'Europe/Istanbul') + interval '2 hours',
  7200, 'manual'
from generate_series(date '2026-02-01', date '2026-02-28', interval '1 day') as g(day);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'wk'
      and event_kind = 'goal_completed'),
  2,
  'A0 kurulum: yalniz hedefi (3 sa) tutan iki hafta sonu gunu tamamlandi yazildi'
);

select is(
  (public._achievement_metrics(:'wk')->>'weekend_goal_days')::integer,
  2,
  'A1 hafta sonu: hedef 3 sa iken 2 gun'
);

select is(
  (public._achievement_metrics(:'wk')->>'perfect_months')::integer,
  0,
  'A2 Kusursuz Ay: 2 saatlik Subat hedefi (3 sa) hic tutmadi -> 0'
);

-- Calisma HIC degismedi; yalniz ayar 1 saate indi.
update public.profiles set daily_goal_minutes = 60 where id = :'wk';

select is(
  (public._achievement_metrics(:'wk')->>'weekend_goal_days')::integer,
  2,
  'A3 hedefi dusurmek gecmis hafta sonlarini SISIRMEZ (eski kod: 12)'
);

select is(
  (public._achievement_metrics(:'wk')->>'perfect_months')::integer,
  0,
  'A4 hedefi dusurmek gecmis Subati Kusursuz Ay YAPMAZ (eski kod: 1)'
);

-- Ters yon: ayar 10 saate cikti. Kazanilmis gun GITMEMELI.
update public.profiles set daily_goal_minutes = 600 where id = :'wk';

select is(
  (public._achievement_metrics(:'wk')->>'weekend_goal_days')::integer,
  2,
  'A5 hedefi yukseltmek kazanilmis hafta sonu gunlerini SILMEZ (eski kod: 0)'
);

-- ===========================================================================
-- B) GIZLI ROZETLER -- "sinir yok" ve "son saniye"
-- ===========================================================================
-- Hedef 2 sa. 1 Nisan: 2 sa (tutar; 3 kati 6 sa -> sinir yok DEGIL).
-- 2 Nisan: 22:00-23:57 = 7020 sn (tutmaz; 23:57de biter).
update public.profiles set daily_goal_minutes = 120 where id = :'nl';

insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
values
  (
    gen_random_uuid(), :'nl'::uuid,
    ((date '2026-04-01' + time '10:00') at time zone 'Europe/Istanbul'),
    ((date '2026-04-01' + time '12:00') at time zone 'Europe/Istanbul'),
    7200, 'manual'
  ),
  (
    gen_random_uuid(), :'nl'::uuid,
    ((date '2026-04-02' + time '22:00') at time zone 'Europe/Istanbul'),
    ((date '2026-04-02' + time '23:57') at time zone 'Europe/Istanbul'),
    7020, 'manual'
  );

select is(
  (public._achievement_metrics(:'nl')->'secrets'->>'no_limits')::boolean,
  false,
  'B1 sinir yok: 2 sa, 2 saatlik hedefin 3 kati degil'
);

select is(
  (public._achievement_metrics(:'nl')->'secrets'->>'last_second')::boolean,
  false,
  'B2 son saniye: 23:57de biten gun hedefi tutmadi'
);

update public.profiles set daily_goal_minutes = 30 where id = :'nl';

select is(
  (public._achievement_metrics(:'nl')->'secrets'->>'no_limits')::boolean,
  false,
  'B3 hedefi dusurmek gecmis gunu "sinir yok" YAPMAZ (eski kod: true)'
);

select is(
  (public._achievement_metrics(:'nl')->'secrets'->>'last_second')::boolean,
  false,
  'B4 hedefi dusurmek gecmis 23:57 gununu "son saniye" YAPMAZ (eski kod: true)'
);

-- Pozitif kontrol: yeni hedef (30 dk) ALTINDA gercekten kazanilan gun hala
-- odullendirilmeli. 3 Nisan 21:00-23:56 = 10560 sn >= 30 dk, >= 3 x 30 dk.
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
values (
  gen_random_uuid(), :'nl'::uuid,
  ((date '2026-04-03' + time '21:00') at time zone 'Europe/Istanbul'),
  ((date '2026-04-03' + time '23:56') at time zone 'Europe/Istanbul'),
  10560, 'manual'
);

select is(
  (public._achievement_metrics(:'nl')->'secrets'->>'last_second')::boolean,
  true,
  'B5 pozitif kontrol: o gunun hedefiyle kazanilan "son saniye" hala verilir'
);

select is(
  (public._achievement_metrics(:'nl')->'secrets'->>'no_limits')::boolean,
  true,
  'B6 pozitif kontrol: o gunun hedefinin 3 kati hala "sinir yok" verir'
);

-- ===========================================================================
-- C) GERI ALMA -- hedefi yukseltip gecmis oturumu duzenlemek gunu SILMEMELI
-- ===========================================================================
update public.profiles set daily_goal_minutes = 120 where id = :'rt';

insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
values
  (
    '30000000-0000-0000-0000-000000082801'::uuid, :'rt'::uuid,
    ((date '2026-05-04' + time '10:00') at time zone 'Europe/Istanbul'),
    ((date '2026-05-04' + time '12:00') at time zone 'Europe/Istanbul'),
    7200, 'manual'
  ),
  (
    '30000000-0000-0000-0000-000000082802'::uuid, :'rt'::uuid,
    ((date '2026-05-04' + time '14:00') at time zone 'Europe/Istanbul'),
    ((date '2026-05-04' + time '15:00') at time zone 'Europe/Istanbul'),
    3600, 'manual'
  );

update public.profiles set daily_goal_minutes = 600 where id = :'rt';

-- 1 saatlik oturum 30 dk'ya kisaldi: gun 2,5 sa -- o gunun hedefini (2 sa)
-- hala tutuyor, bugunku hedefi (10 sa) tutmuyor.
update public.study_sessions
   set end_time = start_time + interval '30 minutes', duration_seconds = 1800
 where id = '30000000-0000-0000-0000-000000082802';

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'rt'
      and event_kind = 'goal_completed' and goal_day = date '2026-05-04'),
  1,
  'C1 hedef sonradan yukselse de duzenlenen gecmis gun SILINMEZ (eski kod: 0)'
);

-- Gercek geri alma korunur: gun 1 saate indi, o gunun hedefinin (2 sa) altinda.
update public.study_sessions
   set end_time = start_time + interval '30 minutes', duration_seconds = 1800
 where id = '30000000-0000-0000-0000-000000082801';

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'rt'
      and event_kind = 'goal_completed' and goal_day = date '2026-05-04'),
  0,
  'C2 gun o gunun kendi hedefinin altina dusunce geri alma HALA calisir'
);

-- ===========================================================================
-- D + eski olaylar) Yeni kolon. Bu bolum `0141` oncesi semada kolon olmadigi
-- icin bilerek EN SONDA durur; yukaridaki davranis iddialari once raporlanir.
-- ===========================================================================
select is(
  (select min(goal_seconds) from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'wk'
      and event_kind = 'goal_completed'),
  10800::bigint,
  'D1 tamamlama olayi yazildigi gunun hedefini (3 sa) kendi uzerinde dondurur'
);

-- `0141` oncesi yazilmis olaylarin hedef bilgisi YOK (kolon null). Onlar icin
-- guvenli taban 60 sn: yazici `daily_goal_minutes > 0` ister, yani hicbir gun
-- 1 dakikadan kucuk bir hedefle tamamlanmis olamaz. Taban, kazanilmis gunu
-- asla silmez; yalniz arkasinda calisma kalmayan gunu temizler.
update public.profiles set daily_goal_minutes = 60 where id = :'rt';

insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
values (
  '30000000-0000-0000-0000-000000082803'::uuid, :'rt'::uuid,
  ((date '2026-05-11' + time '10:00') at time zone 'Europe/Istanbul'),
  ((date '2026-05-11' + time '11:30') at time zone 'Europe/Istanbul'),
  5400, 'manual'
);

-- `0141` oncesi satiri taklit et: olay gercek yoldan yazildi, hedef bilgisi
-- silinerek eski bicime getirildi.
update public.goal_progress_events
   set goal_seconds = null
 where scope_type = 'personal' and scope_id = :'rt'
   and event_kind = 'goal_completed' and goal_day = date '2026-05-11';

update public.profiles set daily_goal_minutes = 600 where id = :'rt';

update public.study_sessions
   set end_time = start_time + interval '5000 seconds', duration_seconds = 5000
 where id = '30000000-0000-0000-0000-000000082803';

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'rt'
      and event_kind = 'goal_completed' and goal_day = date '2026-05-11'),
  1,
  'C3 hedef bilgisi olmayan eski olay, bugunku hedefle SILINMEZ'
);

delete from public.study_sessions
 where id = '30000000-0000-0000-0000-000000082803';

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'rt'
      and event_kind = 'goal_completed' and goal_day = date '2026-05-11'),
  0,
  'C4 arkasinda calisma kalmayan eski olay yine temizlenir'
);

select * from finish();
rollback;
