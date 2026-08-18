-- 063_fire_streak_equals_paused_streak.test.sql
-- WP-739: Alevli Seri metrigi ile alev rozetinin okudugu duraklamali seri AYNI
-- sayiyi vermek zorunda; hak edilmis kademeler geriye donuk verilir.
--
-- 🔴 Bu dosya bir ACIK BULGUyu kapatir. `038_progression_matrix.test.sql §6`
-- uzun sure "iki seri tanimi ayni gecmiste ayni sayiyi vermiyor" diye kirmizi
-- olmayan bir kusur olcuyordu (karar sahibindi). Sahip 2026-08-19'da karari
-- verdi; artik olculen sey ESITLIK.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'

select plan(17);

-- ---------------------------------------------------------------------------
-- 1) Sozlesme: metrik tanimi yeni kaynagi ilan eder
-- ---------------------------------------------------------------------------
select is(
  (select projection_kind || ':' || source_version
     from public.achievement_metric_definitions
    where achievement_id = 'fire_streak'),
  'current:goal_completion_grace_v3',
  'fire_streak current kalir ama kaynak duraklamali seri kuralidir'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public._best_fire_streak_days(uuid,date)', 'execute'
  ),
  'istemci rekor seri yardimcisini dogrudan cagiramaz'
);

-- ---------------------------------------------------------------------------
-- 2) Ayni gecmis, iki motor: tamamla-bos-tamamla-bos-tamamla
-- ---------------------------------------------------------------------------
-- beta'nin bugunku fixture oturumu var; once onu ve turettigi olayi temizleyip
-- gecmisi sifirdan kuruyoruz ki olculen tek sey bu kurgu olsun.
delete from public.study_sessions where user_id = :'beta';
delete from public.goal_progress_events
 where scope_type = 'personal' and scope_id = :'beta';

insert into public.goal_progress_events(
  event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
)
select 'wp739-gap-' || d::text, 'personal', :'beta', 'Europe/Istanbul',
       'goal_completed', d, now()
from (
  select ((timezone('Europe/Istanbul', now()))::date - n) as d
  from (values (0), (2), (4)) as v(n)
) t
on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;

select is(
  (select current_streak from public.goal_streak_projection(
    'personal', :'beta', (timezone('Europe/Istanbul', now()))::date
  )),
  3,
  'alev motoru (0112): tamamla-bos-tamamla-bos-tamamla = 3'
);
select is(
  public._current_fire_streak_days(:'beta'),
  3,
  'basarim metrigi ayni gecmiste ayni sayiyi verir'
);
-- 🔴 Iddianin kendisi: iki tanim ARTIK ayrilamaz. `038 §6` bunun tersini
-- olcuyordu; ayrisma geri gelirse bu satir kirmiziya doner.
select is(
  public._current_fire_streak_days(:'beta'),
  (select current_streak from public.goal_streak_projection(
    'personal', :'beta', (timezone('Europe/Istanbul', now()))::date
  )),
  'alev ile basarim TEK kurala bagli'
);
select is(
  (public._achievement_metrics(:'beta')->>'streak_days')::integer,
  3,
  'buyuk metrik hatti da duraklamali sayiyi tasir'
);

-- Iki ardisik bos gun hala sifirlar: grace TEK kacirmaliktir.
insert into public.goal_progress_events(
  event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
) values (
  'wp739-old', 'personal', :'beta', 'Europe/Istanbul', 'goal_completed',
  (timezone('Europe/Istanbul', now()))::date - 40, now()
) on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;
select is(
  public._current_fire_streak_days(
    :'beta', (timezone('Europe/Istanbul', now()))::date - 37
  ),
  0,
  'uc gun onceki tek tamamlama guncel seriyi ayakta tutmaz'
);
select is(
  public._current_fire_streak_days(
    :'beta', (timezone('Europe/Istanbul', now()))::date - 38
  ),
  1,
  'iki gun mesafede seri hala canlidir (grace)'
);

-- ---------------------------------------------------------------------------
-- 3) Rekor seri: odul hakkinin dayanagi, anlik degerle silinmez
-- ---------------------------------------------------------------------------
select is(
  public._best_fire_streak_days(:'beta'),
  3,
  'gecmisteki en uzun duraklamali kosu 3 (40 gun oncesi tek basina 1)'
);

-- ---------------------------------------------------------------------------
-- 4) Sahibin vakasi: 9 gunluk alev, arada tek bos gunler → kademe 1 hak edilir
-- ---------------------------------------------------------------------------
delete from public.study_sessions where user_id = :'alpha';
delete from public.goal_progress_events
 where scope_type = 'personal' and scope_id = :'alpha';
delete from public.achievement_rewards
 where user_id = :'alpha' and achievement_id = 'fire_streak';

-- 0, 1, 3, 4, 6, 7, 9, 10, 11 gun once: dokuz tamamlama, uc tane TEK bos gun.
-- Eski "ust uste" kurali bu gecmiste yalniz 2 sayardi; sahip ekranda 2/7
-- goruyordu.
insert into public.goal_progress_events(
  event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
)
select 'wp739-owner-' || d::text, 'personal', :'alpha', 'Europe/Istanbul',
       'goal_completed', d, now()
from (
  select ((timezone('Europe/Istanbul', now()))::date - n) as d
  from (values (0), (1), (3), (4), (6), (7), (9), (10), (11)) as v(n)
) t
on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;

select is(
  public._current_fire_streak_days(:'alpha'),
  9,
  'sahibin gecmisi: dokuz gunluk alev'
);
select is(
  (select current_streak from public.goal_streak_projection(
    'personal', :'alpha', (timezone('Europe/Istanbul', now()))::date
  )),
  9,
  'rozet de ayni dokuzu gosterir'
);

-- Tetikleyici zaten her olay yaziminda projeksiyonu kosturdu; backfill ayni
-- sonucu idempotent uretmelidir.
select ok(
  public.backfill_wp739_fire_streak() >= 2,
  'backfill butun kullanicilari isler'
);
select is(
  (select metric_value from public.achievement_metric_progress
    where user_id = :'alpha' and achievement_id = 'fire_streak'),
  9::bigint,
  'ekrandaki ilerleme 2/7 degil 9/7 olur'
);
select is(
  (select array_agg(tier order by tier) from public.achievement_rewards
    where user_id = :'alpha' and achievement_id = 'fire_streak'),
  array[1],
  'hak edilmis ilk kademe gelen kutusuna duser; ikinci kademe (30) verilmez'
);

-- Idempotent: ikinci backfill ikinci odul uretmez.
select public.backfill_wp739_fire_streak();
select is(
  (select count(*)::integer from public.achievement_rewards
    where user_id = :'alpha' and achievement_id = 'fire_streak'),
  1,
  'ikinci backfill cift odul uretmez'
);

-- ---------------------------------------------------------------------------
-- 5) Seri kirilinca ekran duser ama kademe durmaya devam eder
-- ---------------------------------------------------------------------------
delete from public.goal_progress_events
 where scope_type = 'personal' and scope_id = :'alpha'
   and event_kind = 'goal_completed'
   and goal_day >= (timezone('Europe/Istanbul', now()))::date - 2;

select is(
  (select metric_value from public.achievement_metric_progress
    where user_id = :'alpha' and achievement_id = 'fire_streak'),
  0::bigint,
  'uc gun ust uste bos: canli ilerleme sifira geri cekilir'
);
select is(
  (select array_agg(tier order by tier) from public.achievement_rewards
    where user_id = :'alpha' and achievement_id = 'fire_streak'),
  array[1],
  'kazanilmis kademe geri alinmaz (URUN-POLITIKALARI §3)'
);

select * from finish();
rollback;
