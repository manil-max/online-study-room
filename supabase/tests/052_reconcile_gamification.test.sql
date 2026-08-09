-- 052_reconcile_gamification.test.sql
-- WP-634: calisma kaydi silinince XP / basarim / tac geri gider.
--
-- Olcum hedefi tek cumle: **silinen kaydin kazanimi kalmamali, hak edilmis
-- kazanim ise KALMALI.** Ikinci yari en az birincisi kadar onemli -- "hepsini
-- sil" cozumu de birinci iddiadan gecerdi ve kullanicilarin gercek XP'sini
-- yok ederdi.
--
-- 🔴 Ayrica hesap silme yolu burada tekrar olculuyor. Bu depoda `study_sessions`
-- uzerine konulan yaz-geri tetikleyicileri hesap silmeyi TAMAMEN bloke etmisti
-- (WP-549 / `0124`, bir gecede kesfedildi). 0126 ayni tabloya yeni bir AFTER
-- DELETE tetikleyicisi ekliyor; o hatanin geri gelmedigi KANITLANMADAN bu
-- migration guvenli sayilamaz.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'

select plan(11);

-- ===========================================================================
-- KURULUM: alpha 2 saat GERCEK calismis, ustune 11 saatlik SAHTE oturum.
-- ===========================================================================
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
) values (
  '55000000-0000-0000-0000-000000000001', :'alpha',
  now() - interval '30 day', now() - interval '30 day' + interval '2 hour',
  7200, 'live'
);

insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
) values (
  '55000000-0000-0000-0000-0000000000ff', :'alpha',
  now() - interval '1 day', now() - interval '1 day' + interval '11 hour',
  39600, 'live'
);

-- Saat XP'si: 13 saatin hepsi icin defter satiri (gercek + sahte).
insert into public.xp_ledger (user_id, achievement_id, tier, xp_amount, event_key)
select :'alpha', 'study_hour_xp', 1, 50,
       :'alpha' || '|study_hour_xp|h_' || g
from generate_series(1, 13) g;

-- Sahte gecenin actigi kademe: `day_hero` tier 1 (esik 3 saat/gun).
insert into public.xp_ledger (user_id, achievement_id, tier, xp_amount, event_key)
values (:'alpha', 'day_hero', 1,
        (select (t->>'xp')::integer from public.achievements_dict d
          cross join lateral jsonb_array_elements(d.tiers) t
         where d.id = 'day_hero' and (t->>'tier')::integer = 1),
        :'alpha' || '|day_hero|tier_1');

-- 🔴 KAPSAM DISI kazanim: `alpha_wolf` baska bir yoldan verilir ve
-- `_session_derived_progress` onu NULL doner. Uzlastirma buna DOKUNMAMALI.
insert into public.xp_ledger (user_id, achievement_id, tier, xp_amount, event_key)
values (:'alpha', 'alpha_wolf', 1,
        (select (t->>'xp')::integer from public.achievements_dict d
          cross join lateral jsonb_array_elements(d.tiers) t
         where d.id = 'alpha_wolf' and (t->>'tier')::integer = 1),
        :'alpha' || '|alpha_wolf|tier_1');

-- Baska bir kullanicinin defteri: uzlastirma ONA da dokunmamali.
insert into public.xp_ledger (user_id, achievement_id, tier, xp_amount, event_key)
select :'beta', 'study_hour_xp', 1, 50,
       :'beta' || '|study_hour_xp|h_' || g
from generate_series(1, 3) g;

select is(
  (select count(*)::int from public.xp_ledger
    where user_id = :'alpha' and achievement_id = 'study_hour_xp'),
  13,
  'kurgu dogru: sahte gece dahil 13 saatlik defter satiri var'
);

select ok(
  (select xp from public.gamification_profiles where user_id = :'alpha') > 0,
  'kurgu dogru: bakiye defterden birikti (tetikleyici zinciri calisiyor)'
);

-- ===========================================================================
-- 1. SAHTE OTURUM SILININCE
-- ===========================================================================
delete from public.study_sessions
 where id = '55000000-0000-0000-0000-0000000000ff';

select is(
  (select count(*)::int from public.xp_ledger
    where user_id = :'alpha' and achievement_id = 'study_hour_xp'),
  2,
  'hak edilmeyen saat XP satirlari DUSTU (13 -> 2, gercek calisma kadar)'
);

select is(
  (select count(*)::int from public.xp_ledger
    where user_id = :'alpha' and event_key = :'alpha' || '|day_hero|tier_1'),
  0,
  'sahte gecenin actigi basarim kademesi GERI ALINDI'
);

-- 🔴 Ters iddia 1: kapsam disi kazanim DURUYOR.
select is(
  (select count(*)::int from public.xp_ledger
    where user_id = :'alpha' and achievement_id = 'alpha_wolf'),
  1,
  'kapsam DISI basarim korunur (oturumdan turemez, silinmez)'
);

-- 🔴 Ters iddia 2: baska kullanicinin defteri korunur.
select is(
  (select count(*)::int from public.xp_ledger where user_id = :'beta'),
  3,
  'baska kullanicinin defterine DOKUNULMAZ'
);

-- ===========================================================================
-- 2. BAKIYE VE TAC DEFTERDEN YENIDEN TURETILIR
-- ===========================================================================
select is(
  (select xp from public.gamification_profiles where user_id = :'alpha'),
  (select coalesce(sum(xp_amount), 0)::integer from public.xp_ledger
    where user_id = :'alpha'),
  'bakiye defterin toplamina esitlendi'
);

select is(
  (select crown_rank from public.gamification_profiles where user_id = :'alpha'),
  public._recalc_crown_rank(
    (select coalesce(sum(xp_amount), 0)::integer from public.xp_ledger
      where user_id = :'alpha')
  ),
  'tac yeni bakiyeden yeniden hesaplandi'
);

-- ===========================================================================
-- 3. SERBEST KALAN SAAT ANAHTARI
-- ===========================================================================
-- Sahte gece `h_3..h_13` anahtarlarini HARCAMISTI. Satirlar dustugu icin
-- kullanici o saatleri gercekten calisirsa XP'yi bu kez alabilir.
select is(
  (select count(*)::int from public.xp_ledger
    where user_id = :'alpha'
      and event_key = :'alpha' || '|study_hour_xp|h_5'),
  0,
  'harcanmis saat anahtari SERBEST kaldi (gercek calisma yine XP alabilir)'
);

-- ===========================================================================
-- 4. HESAP SILME HALA CALISIYOR (WP-549 sinifi)
-- ===========================================================================
-- Yeni AFTER DELETE tetikleyicisi `auth.users` cascade'i sirasinda da atesler.
-- `_account_still_exists` kapisi olmasaydi burada 23503 ile duserdi.
select lives_ok(
  format($$delete from auth.users where id = %L$$, :'beta'),
  'oturumu ve defteri olan hesap SILINEBILIYOR (tetikleyici bloke etmiyor)'
);

select is(
  (select count(*)::int from public.xp_ledger where user_id = :'beta'),
  0,
  'silinen hesabin defteri cascade ile gitti'
);

select * from finish();
rollback;
