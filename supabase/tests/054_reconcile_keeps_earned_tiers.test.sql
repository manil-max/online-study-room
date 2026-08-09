-- 054_reconcile_keeps_earned_tiers.test.sql
-- WP-635: uzlastirma HAK EDILMIS kademeleri ekranda birakmali.
--
-- 🔴 Bu dosya gercek bir uretim regresyonundan dogdu. `0126`nin uzlastirmasi
-- `user_achievements` satirini "dusen kademe" ile eslestirip SILIYORDU. O
-- tablo her basarim icin TEK satir tutar (`0022:26`) ve satirdaki `tier` en
-- yuksek kademedir; sahibin `steel_will` satirinda 6 yaziyordu, 6 dustu, satir
-- gitti ve kullanici hak ettigi 1-4'u de ekranda kaybetti. Defterde
-- duruyorlardi -- yani veri degil GORUNUM yok olmustu.
--
-- `052` bunu goremezdi cunku oradaki kurgu kademe 1 ve 2 uzerineydi ve satir
-- tier 2 ile eslesip silinince "tier 1 korunur" iddiasi DEFTERE bakiyordu,
-- kilit satirina degil. Bu dosya tam o boslugu kapatir.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'

select plan(6);

-- Alpha 4 saatlik (240 dk) GERCEK bir oturum yapmis: steel_will esikleri
-- 60/90/120/180 asilir, 300 ve 480 asilmaz (`0065`).
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
) values (
  '56000000-0000-0000-0000-000000000001', :'alpha',
  now() - interval '10 day', now() - interval '10 day' + interval '4 hour',
  14400, 'live'
);

-- Sahte 8 saatlik oturum: tier 5 (300) ve 6 (480) da acilir.
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
) values (
  '56000000-0000-0000-0000-0000000000ff', :'alpha',
  now() - interval '2 day', now() - interval '2 day' + interval '8 hour',
  28800, 'live'
);

-- Alti kademenin defter satiri (tetikleyici kilit satirini tier 6 yapar).
insert into public.xp_ledger (user_id, achievement_id, tier, xp_amount, event_key)
select :'alpha', 'steel_will', (t->>'tier')::integer, (t->>'xp')::integer,
       :'alpha' || '|steel_will|tier_' || (t->>'tier')
  from public.achievements_dict d
  cross join lateral jsonb_array_elements(d.tiers) t
 where d.id = 'steel_will';

select is(
  (select tier from public.user_achievements
    where user_id = :'alpha' and achievement_id = 'steel_will'),
  6,
  'kurgu dogru: kilit satiri en yuksek kademeyi (6) tasiyor'
);

-- ===========================================================================
-- SAHTE OTURUM SILINIR
-- ===========================================================================
delete from public.study_sessions
 where id = '56000000-0000-0000-0000-0000000000ff';

-- 🔴 ASIL IDDIA: satir SILINMEZ, dusurulur.
select is(
  (select count(*)::int from public.user_achievements
    where user_id = :'alpha' and achievement_id = 'steel_will'),
  1,
  'kilit satiri SILINMEDI (kullanici hak ettigi kademeleri ekranda gorur)'
);

select is(
  (select tier from public.user_achievements
    where user_id = :'alpha' and achievement_id = 'steel_will'),
  4,
  'kilit satiri kalan en yuksek kademeye (4) DUSURULDU'
);

select is(
  (select count(*)::int from public.xp_ledger
    where user_id = :'alpha' and achievement_id = 'steel_will'),
  4,
  'defterde de yalniz hak edilen dort kademe kaldi'
);

-- ===========================================================================
-- "EN IYI" DEGERI DE GERCEGE CEKILIR
-- ===========================================================================
-- `0050:296` bu olcuyu kumulatif yazar (deger dusmez). Oturumdan tureyen
-- olculerde bu YANLIS: silinmis oturumun rekoru ekranda kalirdi.
select is(
  (select metric_value::int from public.achievement_metric_progress
    where user_id = :'alpha' and achievement_id = 'steel_will'),
  240,
  '"en iyi" degeri gercek oturumlarin en iyisine (240 dk) cekildi'
);

-- 🔴 Ters iddia: hicbir kademesi kalmayan basarimin satiri GIDER.
-- `marathon_total` icin hic defter satiri yok; alpha'nin toplam saati de
-- esiklerin altinda kalir. Satir varsa temizlenmeli.
select is(
  (select count(*)::int from public.user_achievements
    where user_id = :'alpha' and achievement_id = 'marathon_total'
      and not exists (
        select 1 from public.xp_ledger l
         where l.user_id = :'alpha' and l.achievement_id = 'marathon_total'
      )),
  0,
  'defterde hic kademesi olmayan basarimin kilit satiri KALMAZ'
);

select * from finish();
rollback;
