-- 059_fire_streak_retraction_contract.test.sql
-- LANE J OLCUM (duzeltme YOK -- sahip karari bekliyor; WP numarasini lider
-- verir).
--
-- Sikayet: "serim geri gitti ama seri basarimim hala duruyor."
--
-- 🔴 Bu dosya bir DUZELTMENIN testi degil, bir CELISKININ olcusudur. Sebebi:
-- `0126:38-40` su cumleyi tasiyor --
--
--     "`fire_streak`, `weekend_goal_days`, `perfect_month` -- projeksiyon
--      `0058`den beri KUMULATIF GREATEST'tir, yani deger tasarim geregi
--      dusmez."
--
-- Bu cumle `fire_streak` icin YANLIS. `0050:45` onu `'current'` olarak
-- kaydeder ve hicbir sonraki migration bunu degistirmez; istemci aynasi da
-- ayni sey der (`app/lib/core/stats/achievement_ledger_engine.dart:353`,
-- `kCurrentAchievementMetrics = {'fire_streak'}`). Yani ilerleme degeri
-- TASARIM GEREGI duser, kilit ise durur -- kullanicinin gordugu celiski budur.
--
-- Duzeltmedim, cunku bu bir urun karari: `streak_days` kullanicinin VERI
-- SILMEDEN de dusurebildigi tek olcudur (iki gun tatil yeter). `0126`nin geri
-- aldigi uc olcu (`marathon_total`, `steel_will`, `day_hero`) tumu HER ZAMANKI
-- EN IYI degerdir ve yalnizca kayit silinince duser. Ayni kurali seriye
-- uygulamak, 365 gun kesintisiz calisip sonra tatile cikan kullanicinin
-- kademesini yakardi.
--
-- Bu dosya bugunku davraniisi SABITLER. Sahip "kademe de geri alinsin" derse
-- son iki iddia kirmiziya doner ve bilincli olarak guncellenir.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'

select plan(7);

-- ===========================================================================
-- 1) SEMADAN OLCU -- `0126:38`i yalanlayan iddia
-- ===========================================================================
select is(
  (select projection_kind from public.achievement_metric_definitions
    where achievement_id = 'fire_streak'),
  'current',
  '🔴 fire_streak KUMULATIF DEGIL: projeksiyonu current, yani deger DUSER'
);

select is(
  (select projection_kind from public.achievement_metric_definitions
    where achievement_id = 'weekend_goal_days'),
  'cumulative',
  'karsilastirma: weekend_goal_days gercekten kumulatif (ikisi ayni degil)'
);

-- Kok neden: uzlastirma fire_streak'i tanimiyor, o yuzden kademeye dokunmuyor.
select ok(
  public._session_derived_progress(
    jsonb_build_object('streak_days', 0), 'fire_streak'
  ) is null,
  'uzlastirma fire_streak kademesini KAPSAM DISI birakir (0126:79)'
);

-- ===========================================================================
-- 2) KURULUM -- 8 gunluk gercek seri
-- ===========================================================================
update public.profiles set daily_goal_minutes = 60 where id = :'alpha';

insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  ('32000000-0000-0000-0000-' || lpad(g::text, 12, '0'))::uuid,
  :'alpha'::uuid,
  b.base - make_interval(days => g) + interval '9 hours',
  b.base - make_interval(days => g) + interval '10 hours',
  3600, 'live'
from generate_series(1, 7) g
cross join (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b;

-- Gercek yol: metrik hesabi projeksiyonu da yazar (`0116:216`).
select ok(
  (public._achievement_metrics(:'alpha') ->> 'streak_days')::integer >= 7,
  'kurgu dogru: alpha kesintisiz 8 gunluk seri tasiyor (fixture + 7 gun)'
);

select ok(
  (select metric_value from public.achievement_metric_progress
    where user_id = :'alpha' and achievement_id = 'fire_streak') >= 7,
  'kullanicinin GORDUGU ilerleme kademe 1 esigini (7) gecti'
);

-- Kademe kazanimi `052` desenindeki gibi defterden kurulur.
insert into public.xp_ledger (user_id, achievement_id, tier, xp_amount, event_key)
select :'alpha', 'fire_streak', 1, (t->>'xp')::integer,
       :'alpha' || '|fire_streak|tier_1'
  from public.achievements_dict d
  cross join lateral jsonb_array_elements(d.tiers) t
 where d.id = 'fire_streak' and (t->>'tier')::integer = 1;

-- 🔴 UPSERT sart. Bu satiri oturum yazimindaki basarim projeksiyonu ZATEN
-- olusturmus olabilir; duz insert `user_achievements_user_id_achievement_id_key`
-- ihlaliyle duser. Olculdu: CI local replay run 31387144433, 059:105
--   duplicate key ... Key (user_id, achievement_id)=(...,fire_streak) already exists
-- Bu dosya bu hostta hic kosturulamadigi icin (Docker kalkmiyor) hata ancak
-- gercek Postgres'te goruldu -- kapinin ilk kosumu.
insert into public.user_achievements (
  user_id, achievement_id, tier, progress, unlocked_at
) values (:'alpha', 'fire_streak', 1, 7, now())
on conflict (user_id, achievement_id) do update
  set tier = excluded.tier,
      progress = excluded.progress,
      unlocked_at = excluded.unlocked_at;

-- ===========================================================================
-- 3) SERIYI KIR -- iki gunun kaydi silinir
-- ===========================================================================
-- Bugun + dun gider; `0025`teki geri sayim ilk iki gunde de hedefin altini
-- gorur ve seri 0'a duser. Silme `0126` uzlastirmasini atesler.
delete from public.study_sessions
 where id in ('30000000-0000-0000-0000-000000000001',
              '32000000-0000-0000-0000-000000000001');

select is(
  (select metric_value from public.achievement_metric_progress
    where user_id = :'alpha' and achievement_id = 'fire_streak'),
  0::bigint,
  '🔴 ekrandaki seri ilerlemesi 0''a duser (projection_kind = current)'
);

-- 🔴 CELISKININ IKINCI YARISI: rozet yerinde kalir.
select is(
  (select tier from public.user_achievements
    where user_id = :'alpha' and achievement_id = 'fire_streak'),
  1,
  '🔴 ayni ekranda kademe 1 KILIDI ACIK kalir -- sahip karari bekleyen celiski'
);

select * from finish();
rollback;
