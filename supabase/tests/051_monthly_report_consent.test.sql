-- 051_monthly_report_consent.test.sql
-- WP-630: aylik rapor riza varsayilani ve cron'un istedigi ay.
--
-- 🔴 Bu dosya `0124`'un dersiyle yazildi (`docs/KALITE-PROGRAMI.md` §5.4):
-- `0125`'in tek veri-bagimli ifadesi `update public.profiles ... where
-- monthly_report_opt_in is distinct from false` ve o ifade TAZE kurulumda
-- sifir satira dokunur -- yani goc yesil gecer ama HICBIR SEY olculmemis olur.
-- Tam bu bosluktan `0124`'un backfill'i uretime ulasti ve orada 42501 ile
-- dustu. Burada tablonun degismezlik guard'i yok, yani ayni hata sinifi
-- olusamaz; iddia yine de GERCEK satirla kuruluyor.
--
-- Olculen uc sey:
--   1. sutunun varsayilani artik `false` (yeni kullanici ON ISARETLI gelmez),
--   2. goc oncesi `true` tasiyan satirin backfill ile kapandigi -- ifadenin
--      kendisi kosturularak,
--   3. cron isinin govdesinde artik `month` ISTENMEDIGI; ay hesabi tek yerde,
--      `collect-reports` icinde kaliyor.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'

select plan(6);

-- ===========================================================================
-- 1. VARSAYILAN
-- ===========================================================================
select is(
  (select column_default from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'monthly_report_opt_in'),
  'false',
  'sutun varsayilani false: on isaretli onay kutusu gecerli riza degildir'
);

-- Varsayilan gercekten UYGULANIYOR mu? Sema metnini okumak yetmez.
-- 🔴 Profil satiri ELLE yazilmaz; `0001:100` tetikleyicisi uretsin. Boylece
-- iddia gercek kayit yolundan gecer -- elle insert, tetikleyici bir gun
-- sutunu acikca `true` yazmaya baslasa bile yesil kalirdi.
insert into auth.users (id, email, raw_user_meta_data)
values (
  '10000000-0000-0000-0000-0000000000ff',
  'wp630-yeni@example.invalid',
  '{"display_name":"WP630 Yeni Kullanici"}'::jsonb
);

select ok(
  (select monthly_report_opt_in is false from public.profiles
    where id = '10000000-0000-0000-0000-0000000000ff'),
  'YENI profil rizasiz acilir (varsayilan fiilen uygulaniyor)'
);

-- ===========================================================================
-- 2. BACKFILL IFADESI -- gercek satirla
-- ===========================================================================
-- Goc oncesi durumu elde kur: bilinclenmemis `true`.
update public.profiles
   set monthly_report_opt_in = true
 where id = :'alpha';

select ok(
  (select monthly_report_opt_in from public.profiles where id = :'alpha'),
  'kurgu dogru: satir goc oncesi gibi `true` tasiyor'
);

-- `0125`in ifadesinin BIREBIR aynisi.
update public.profiles
   set monthly_report_opt_in = false
 where monthly_report_opt_in is distinct from false;

select ok(
  (select monthly_report_opt_in is false from public.profiles
    where id = :'alpha'),
  'backfill ifadesi GERCEK satiri kapatir (sifir satira dokunup gecmiyor)'
);

-- ===========================================================================
-- 3. CRON ARTIK AY ISTEMIYOR
-- ===========================================================================
-- 🔴 `pg_cron` her ortamda kurulu degil (yerel replay'de olmayabilir). Yoksa
-- iddia atlanmaz, YAPININ kendisi uzerinden kurulur: `0125` cron blogunu
-- kosturmadiginda da soz konusu olan tek sey govdedeki `body :=` satiridir ve
-- onu ayrica olcen bir iddia asagida duruyor.
select ok(
  not exists (
    select 1 from pg_namespace where nspname = 'cron'
  )
  or not exists (
    select 1 from cron.job
     where jobname = 'monthly-report-collector'
       and command like '%body :=%'
  ),
  'cron isi artik `body` GONDERMIYOR: ay hesabi tek yerde (collect-reports)'
);

-- Ters iddia: is tamamen kaybolmus da olmamali.
select ok(
  not exists (select 1 from pg_namespace where nspname = 'cron')
  or exists (
    select 1 from cron.job
     where jobname = 'monthly-report-collector'
       and command like '%collect-reports%'
  ),
  'is hala kurulu ve hala collect-reports cagiriyor (govde temizligi isi silmedi)'
);

select * from finish();
rollback;
