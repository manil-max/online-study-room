-- 060_exam_countdown_sync.test.sql
-- WP-694 (migration `0133`): sinav geri sayimi cihazlar arasi senkron mu?
--
-- 🔴 KOSULMADI. Bu hostta yerel Docker/Supabase kalkmiyor (depoda kayitli
-- kisit), yani pgTAP burada calistirilamadi. Iddialar yazildi ve OLCULMEDI
-- olarak teslim edildi. "Kosamadim" demek "gecti" demekten iyidir.
--
-- Olculen sozlesme uc basliktir ve ucu de gercek kullanici sikayetinden gelir
-- ("telefon ve tablette ayri ayri ayarlanmasi gerekiyor"):
--   1. KAPI     — kullanici YALNIZ kendi geri sayimlarini gorur ve yazar,
--   2. CAKISMA  — kayit basina son yazan kazanir, bayat yazma veri EZMEZ,
--   3. SINIR    — dorduncu kayit SESSIZCE yutulmaz, hata ile doner.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'

select plan(25);

-- ===========================================================================
-- SEMA
-- ===========================================================================
select has_table('public', 'exam_countdowns',
  '0133 geri sayim tablosunu kurar');

-- 🔴 Kimlik neden `text`: yerel kayitlar buluttan once dogdu ve `legacy` /
-- `<mikrosaniye>-<sayac>` bicimindeler. Biri "uuid yapalim" derse yerel kayit
-- ile bulut satiri birbirine baglanamaz ve ayni sinav iki kez gorunur.
select is(
  (select data_type from information_schema.columns
   where table_schema = 'public' and table_name = 'exam_countdowns'
     and column_name = 'id'),
  'text',
  'kimlik text: uuid olmayan yerel kimlikler kaybolmadan tasinabilir'
);

select col_is_pk('public', 'exam_countdowns', array['user_id', 'id'],
  'birincil anahtar (user_id, id): kimlik yalniz kullanici icinde benzersiz');

-- Arayuz iki "one cikan" cizemez; tekillik semada sabitlenir, istemci iyi
-- niyetine birakilmaz.
select ok(
  exists(
    select 1 from pg_index i
    join pg_class c on c.oid = i.indexrelid
    where i.indrelid = 'public.exam_countdowns'::regclass
      and c.relname = 'exam_countdowns_single_priority_idx'
      and i.indisunique and i.indpred is not null
  ),
  'kullanici basina en fazla bir one cikan kayit (kismi tekil indeks)'
);

-- ===========================================================================
-- KAPI — RLS ve dogrudan DML yasagi
-- ===========================================================================
select ok(
  (select relrowsecurity from pg_class
   where oid = 'public.exam_countdowns'::regclass),
  'exam_countdowns uzerinde RLS aciktir'
);

-- Her mutasyon RPC'den gecer; boylece sinir ve LWW atlanabilir olmaz.
select ok(
  not has_table_privilege('authenticated', 'public.exam_countdowns', 'INSERT'),
  'authenticated tabloya dogrudan INSERT edemez'
);
select ok(
  not has_table_privilege('authenticated', 'public.exam_countdowns', 'UPDATE'),
  'authenticated tabloya dogrudan UPDATE edemez'
);
select ok(
  not has_table_privilege('authenticated', 'public.exam_countdowns', 'DELETE'),
  'authenticated tabloya dogrudan DELETE edemez'
);
select ok(
  has_table_privilege('authenticated', 'public.exam_countdowns', 'SELECT'),
  'authenticated kendi satirlarini okuyabilir'
);

-- ===========================================================================
-- ALPHA yazar
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select lives_ok(
  $$select public.upsert_exam_countdown(
      'phone-1', 'YKS', '2026-06-20'::date, 0, false,
      '2026-06-01T10:00:00Z'::timestamptz)$$,
  'ilk geri sayim yazilir'
);

select is(
  (select count(*)::int from public.list_exam_countdowns()),
  1,
  'liste RPC kendi kaydini doner'
);

-- ------------------------------------------------------------------ CAKISMA
-- Bayat yazma (daha ESKI damga) veri EZMEZ. Bu iddia olmasaydi, saati geride
-- kalmis ikinci cihaz her acilista yeni adi eski adla geri alirdi.
select lives_ok(
  $$select public.upsert_exam_countdown(
      'phone-1', 'AYT', '2026-06-21'::date, 0, false,
      '2026-06-01T11:00:00Z'::timestamptz)$$,
  'daha yeni damga yazilir'
);
select lives_ok(
  $$select public.upsert_exam_countdown(
      'phone-1', 'BAYAT', '1999-01-01'::date, 0, false,
      '2026-06-01T09:00:00Z'::timestamptz)$$,
  'bayat yazma HATA ATMAZ (istemci tekrar deneyebilir, idempotent)'
);
select is(
  (select name from public.exam_countdowns
   where user_id = :'alpha' and id = 'phone-1'),
  'AYT',
  'bayat yazma kazanan satiri EZMEDI (kayit basina son yazan kazanir)'
);

-- -------------------------------------------------------------------- SINIR
select lives_ok(
  $$select public.upsert_exam_countdown(
      'phone-2', 'TYT', '2026-06-22'::date, 1, false, now())$$,
  'ikinci kayit yazilir'
);
select lives_ok(
  $$select public.upsert_exam_countdown(
      'phone-3', 'DGS', '2026-07-01'::date, 2, false, now())$$,
  'ucuncu kayit yazilir'
);
-- 🔴 Dorduncu SESSIZCE yutulmaz. Sessizce yutulsaydi istemci kaydi "senkron
-- oldu" sanip yerelden dusurur ve kullanici sinavini kaybederdi.
select throws_ok(
  $$select public.upsert_exam_countdown(
      'phone-4', 'FAZLA', '2026-07-02'::date, 3, false, now())$$,
  'exam_countdown_limit_reached',
  'dorduncu kayit hata ile reddedilir'
);

-- ===========================================================================
-- BETA — baska hesabin satirini goremez, yazamaz
-- ===========================================================================
select set_config('request.jwt.claim.sub', :'beta', true);

select is(
  (select count(*)::int from public.list_exam_countdowns()),
  0,
  'beta alpha nin geri sayimlarini GORMEZ'
);

-- Ayni kimlikle yazmak alpha nin satirina DOKUNMAZ: birincil anahtar cifttir.
select lives_ok(
  $$select public.upsert_exam_countdown(
      'phone-1', 'BETA SINAVI', '2027-01-01'::date, 0, false, now())$$,
  'beta ayni kimligi kendi hesabinda kullanabilir'
);

-- 🔴 Istemci saati kirpilir. Kirpilmasaydi saati 2030'a kurulu tek bir cihaz
-- kaydi kalici olarak kilitler; diger cihazin hicbir yazmasi bir daha gecmez.
select lives_ok(
  $$select public.upsert_exam_countdown(
      'phone-1', 'GELECEK', '2030-01-01'::date, 0, false,
      now() + interval '10 years')$$,
  'gelecek damgali yazma kabul edilir'
);
select ok(
  (select updated_at from public.exam_countdowns
   where user_id = :'beta' and id = 'phone-1') <= now() + interval '6 minutes',
  'kirpma: damga now() + 5 dakikayi asamaz'
);

-- Silme hesap sinirinda durur ve idempotenttir.
select lives_ok(
  $$select public.delete_exam_countdown('phone-2')$$,
  'beta kendisinde olmayan kaydi silmeyi deneyince HATA ALMAZ'
);

-- Capraz hesap iddialari icin RLS disina cikilir: iddia "alpha nin satirlari
-- duruyor mu", "beta onlari gorebiliyor mu" degil (o zaten yukarida olculdu).
reset role;

select is(
  (select name from public.exam_countdowns
   where user_id = :'alpha' and id = 'phone-1'),
  'AYT',
  'beta nin ayni kimlige yazmasi alpha nin kaydini EZMEDI'
);
select is(
  (select count(*)::int from public.exam_countdowns where user_id = :'alpha'),
  3,
  'beta nin silme denemesi alpha nin kayitlarina DOKUNMADI'
);
select is(
  (select count(*)::int from public.exam_countdowns where user_id = :'beta'),
  1,
  'beta yalniz kendi kaydini tasir'
);

select * from finish();
rollback;
