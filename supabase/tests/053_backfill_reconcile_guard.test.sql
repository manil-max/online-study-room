-- 053_backfill_reconcile_guard.test.sql
-- WP-634: `0127` gecmis temizliginin KENDINI DOGRULAMASI gercekten olcuyor mu?
--
-- 🔴 Bu dosyanin varlik sebebi `docs/KALITE-PROGRAMI.md` §5.4: taze kurulumda
-- sifir satira dokunan bir goc SINANMAMISTIR. `0127` bir dongudur ve replay
-- sirasinda `gamification_profiles` BOSTUR -- yani dongu hic donmez, dogrulama
-- hic bir sey bulmaz ve goc "yesil" gecer. Tam bu bosluktan `0124` uretime
-- ulasti ve orada patladi (ayni gece).
--
-- Burada durum ELDE kuruluyor ve iki sey olculuyor:
--   1. uzlastirma sonrasi bakiye = defter toplami (gocun bekledigi son hal),
--   2. 🔴 dogrulama sorgusu SAPMAYI GERCEKTEN GORUYOR -- yoksa `0127`in
--      kendini dogrulama iddiasi bos bir cumle olurdu.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'

select plan(4);

-- Hayalet kazanim: 20 saatlik defter satiri, gercek calisma 1 saat
-- (`base_seed.psql:49` bugun 1 saat verir).
insert into public.xp_ledger (user_id, achievement_id, tier, xp_amount, event_key)
select :'alpha', 'study_hour_xp', 1, 50,
       :'alpha' || '|study_hour_xp|h_' || g
from generate_series(1, 20) g;

select is(
  (select count(*)::int from public.xp_ledger
    where user_id = :'alpha' and achievement_id = 'study_hour_xp'),
  20,
  'kurgu dogru: 20 saatlik hayalet defter satiri var'
);

-- `0127`in yaptigi cagri, birebir.
select ok(
  (public.reconcile_user_gamification(:'alpha') ->> 'removed_hour_rows')::integer > 0,
  'uzlastirma hayalet satirlari dusurdu'
);

-- Gocun bekledigi son hal.
select is(
  (select g.xp from public.gamification_profiles g where g.user_id = :'alpha'),
  (select coalesce(sum(l.xp_amount), 0)::integer from public.xp_ledger l
    where l.user_id = :'alpha'),
  'bakiye defter toplamina esit (gocun dogrulama kosulu saglandi)'
);

-- ===========================================================================
-- 🔴 DOGRULAMANIN KENDISI OLCULUYOR
-- ===========================================================================
-- Bakiyeyi bilerek bozup `0127`deki sapma sorgusunun AYNISINI kosturuyoruz.
-- Sifir dondururse gocun "kendini dogrular" iddiasi bos demektir.
select set_config('app.allow_xp_write', 'on', true);
update public.gamification_profiles
   set xp = xp + 12345
 where user_id = :'alpha';

select ok(
  (select count(*)
     from public.gamification_profiles g
    where public._account_still_exists(g.user_id)
      and g.xp is distinct from (
        select coalesce(sum(l.xp_amount), 0)::integer
          from public.xp_ledger l where l.user_id = g.user_id
      )) > 0,
  'dogrulama sorgusu SAPMAYI goruyor (goc kendini gercekten sinar)'
);

select * from finish();
rollback;
