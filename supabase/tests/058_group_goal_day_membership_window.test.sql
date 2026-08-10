-- 058_group_goal_day_membership_window.test.sql
-- WP-658 (migration `0132`): bir uye gruptan ayrilinca grubun GECMIS hedef
-- gunleri ayakta kaliyor mu?
--
-- 🔴 Lider'in supheci ifadesi "ayrilma grup serisini GERI ALMIYOR" idi; kod
-- bunun TERSINI soyluyordu. Grup gunu toplamini hesaplayan uc yer de
-- (`0120:88`, `0129:114`, `0129:299`) grubun BUGUNKU uyelerine bakiyordu, yani
-- ayrilma gecmis grup gunlerini geri aliyordu -- ama ayrilma aninda degil,
-- grupta KALAN birinin o gune ait bir oturumu silmesi/duzenlemesi aninda. Bu
-- dosya tam o zincirin ortasindan olcuyor.
--
-- Kural uydurulmadi: `0121:191` grup basarim projeksiyonunda ayni yuklemi
-- (`gm.left_at is null or s.start_time < gm.left_at`) zaten tasiyor.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

select plan(10);

select ok(
  not has_function_privilege(
    'authenticated', 'public._group_goal_day_seconds(uuid,date,text)', 'execute'
  ),
  'grup gun toplaminin tek tanimi istemciye kapali'
);

-- ===========================================================================
-- KURULUM
-- ===========================================================================
-- Grup hedefi 100 dk = 6000 sn. Kisisel hedefler bilerek 600 dk yapiliyor:
-- kisisel olaylar bu dosyanin olcusune karismasin.
update public.groups set daily_goal_minutes = 100, time_zone = 'Europe/Istanbul'
 where id = :'grp';
update public.profiles set daily_goal_minutes = 600
 where id in (:'alpha', :'beta');

-- 3 gun once YALNIZ beta calisti: 6000 sn = tam hedef.
-- Bugun alpha'ya ek 1 saat: grup toplami 3600 + 3600 + 3600 = 10800 >= 6000.
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  '31000000-0000-0000-0000-000000000001'::uuid, :'beta'::uuid,
  b.base - interval '3 days' + interval '9 hours',
  b.base - interval '3 days' + interval '9 hours' + interval '6000 seconds',
  6000, 'live'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b
union all
select
  '31000000-0000-0000-0000-000000000002'::uuid, :'alpha'::uuid,
  b.base + interval '13 hours', b.base + interval '14 hours', 3600, 'manual'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b;

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date),
  1,
  'kurgu dogru: grup bugun hedefi tutturdu'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date - 3),
  1,
  'kurgu dogru: 3 gun once grup hedefi YALNIZ beta ile tuttu'
);

-- ===========================================================================
-- beta ayrilir (`0111` kapisi: sahip degil, `auth.uid()` null -> gecer)
-- ===========================================================================
-- 🔴 Damga `now()` DEGIL, bugunun sonu. Sebep olculebilirlik: fixture bugunku
-- oturumlari 08:00 Istanbul'a yaziyor ve kapi gece yarisi ile 08:00 arasinda
-- kosarsa `now()` o oturumlardan ONCE olurdu -- test gunun saatine gore
-- renk degistirirdi. "beta bugun gun sonunda ayrildi" kurgusu her saatte ayni.
update public.group_members
   set left_at = (date_trunc('day', timezone('Europe/Istanbul', now()))
                    + interval '1 day') at time zone 'Europe/Istanbul'
 where group_id = :'grp' and user_id = :'beta';

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'
      and event_kind = 'goal_completed'),
  2,
  'ayrilmanin kendisi hicbir grup gununu dusurmez'
);

-- ===========================================================================
-- 🔴 ASIL IDDIA 1 -- ALAKASIZ bir silme gecmisi yeniden yargilamamali
-- ===========================================================================
-- alpha bugunku ek kaydini siler. Kalan gercek saniyeler:
--   alpha 3600 + beta 3600 (beta uyeyken calisti) = 7200 >= 6000  -> DURMALI
-- Eski davranis beta'yi yok sayardi: 3600 < 6000 -> gun SILINIRDI.
delete from public.study_sessions
 where id = '31000000-0000-0000-0000-000000000002';

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date),
  1,
  '🔴 ayrilan uyenin uyeyken calistigi sure grup gununu ayakta tutar'
);

select is(
  public._group_goal_day_seconds(
    :'grp', (now() at time zone 'Europe/Istanbul')::date, 'Europe/Istanbul'),
  7200::bigint,
  'grup gun toplami ayrilan uyenin saniyelerini sayar'
);

-- ===========================================================================
-- 🔴 ASIL IDDIA 2 -- onarim fonksiyonu da ayni tanimi kullanmali
-- ===========================================================================
-- `0129:345` bu fonksiyonu APPLY sirasinda cagirdi (bu sabah staging +
-- production). Eski olcutle 3 gun onceki gun "arkasinda tek saniye yok"
-- sayilir ve SESSIZCE dusurulurdu.
select is(
  public.repair_orphan_goal_completions(),
  0,
  '🔴 onarim, katkisi ayrilmis uyeden gelen grup gununu dusurmez'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date - 3),
  1,
  '3 gun onceki grup gunu onarimdan sonra da durur'
);

-- ===========================================================================
-- SINIR: ayrildiktan SONRA baslayan oturum gruba sayilmaz
-- ===========================================================================
-- Pencere tek yonlu genisletme degildir; ust sinir da olculur. beta'nin
-- ayrilisi 4 gun oncesine cekilirse 3 gun onceki oturumu artik gruba ait
-- degildir.
update public.group_members
   set left_at = (date_trunc('day', timezone('Europe/Istanbul', now()))
                    - interval '4 days') at time zone 'Europe/Istanbul'
 where group_id = :'grp' and user_id = :'beta';

select is(
  public._group_goal_day_seconds(
    :'grp', (now() at time zone 'Europe/Istanbul')::date - 3, 'Europe/Istanbul'),
  0::bigint,
  'ayrildiktan SONRA baslayan oturum grup gunune sayilmaz'
);

update public.group_members
   set left_at = (date_trunc('day', timezone('Europe/Istanbul', now()))
                    + interval '1 day') at time zone 'Europe/Istanbul'
 where group_id = :'grp' and user_id = :'beta';

select is(
  public._group_goal_day_seconds(
    :'grp', (now() at time zone 'Europe/Istanbul')::date - 3, 'Europe/Istanbul'),
  6000::bigint,
  'ayrilis penceresi geri alininca ayni gun yine sayilir'
);

select * from finish();
rollback;
