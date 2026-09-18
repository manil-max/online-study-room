-- 069_theme_prefs_wp838.test.sql
-- WP-838 (migration `0143`): tema tercihleri hesapta saklanir ve YALNIZ
-- sahibine aciktir.
--
-- Bu testin asil sinavi sahiplik izolasyonudur. `base_seed` alpha ile beta'yi
-- AYNI gruba koyar, yani `public.can_see_user_sessions(beta)` alpha icin true
-- doner ve alpha beta'nin `public.profiles` satirini GERCEKTEN okuyabilir
-- (`profiles_select`, `0036:81`). Tema tercihleri o satira konsaydi alpha
-- beta'nin ozel tema adlarini gorurdu; asagidaki A/B bloklari once bu
-- gorunurlugu olcer, sonra yeni tablonun onu kapattigini kanitlar.
--
-- RLS gercek rolle olculur: `set local role authenticated` + `request.jwt.claims`
-- (`047_name_length_limits.test.sql` ile ayni yol). `postgres` rolu RLS'i
-- atladigi icin kurulum satirlari rol degistirmeden once yazilir.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'

select plan(17);

-- ===========================================================================
-- 0) SEMA -- tablo, RLS, kisit, FK ve grant'lar
-- ===========================================================================
select ok(
  to_regclass('public.user_theme_prefs') is not null,
  '00 0143 user_theme_prefs tablosunu kurar'
);
select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.user_theme_prefs'::regclass),
  '01 tabloda RLS acik'
);
select is(
  (select count(*)::integer from pg_policies
    where schemaname = 'public' and tablename = 'user_theme_prefs'),
  3,
  '02 tam olarak select/insert/update politikalari var (delete yolu yok)'
);
select ok(
  not has_table_privilege('authenticated', 'public.user_theme_prefs', 'delete')
    and not has_table_privilege('anon', 'public.user_theme_prefs', 'select'),
  '03 istemci silemez; anonim rol hic okuyamaz'
);
-- Hesap silme zinciri: `auth.users` cascade'i bu tabloyu kendiliginden
-- toplar ve yeni bir `restrict` FK eklenmez (`050` envanteri korunur).
select is(
  (select con.confdeltype::text
     from pg_constraint con
     join pg_class c on c.oid = con.conrelid
    where con.contype = 'f'
      and c.relname = 'user_theme_prefs'
      and con.confrelid = 'auth.users'::regclass),
  'c',
  '04 user_id -> auth.users bagi CASCADE (hesap silmeyi bloklamaz)'
);
select throws_ok(
  $sql$
    insert into public.user_theme_prefs (user_id, prefs)
    values ('10000000-0000-0000-0000-000000000001', '"duz-metin"'::jsonb)
  $sql$,
  '23514',
  null,
  '05 prefs bir JSON nesnesi olmak zorunda (skaler reddedilir)'
);

-- ===========================================================================
-- 1) GORUNURLUK KARSILASTIRMASI -- neden profiles kolonu degil
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'alpha')::text, true);

-- On kosul: alpha, beta ile ayni grupta oldugu icin beta'nin PROFIL satirini
-- okuyabiliyor. Tema tercihi oraya konsaydi bu satirla birlikte sizardi.
select is(
  (select count(*)::integer from public.profiles where id = :'beta'),
  1,
  '10 on kosul: grup arkadasi beta''nin profiles satirini okuyabiliyor'
);

-- ===========================================================================
-- 2) SAHIP -- kendi satirini yazar ve okur
-- ===========================================================================
select lives_ok(
  $sql$
    insert into public.user_theme_prefs (user_id, prefs)
    values (
      '10000000-0000-0000-0000-000000000001',
      '{"version":1,"family":"campfire_day","palette":"navy","mode":"light",
        "colorSource":"family","customThemes":[{"id":"custom_1","name":"Alpha Gece"}],
        "activeCustomTheme":"custom_1","updatedAt":"2026-09-18T10:00:00.000Z"}'::jsonb
    )
  $sql$,
  '20 sahip kendi tema tercihini yazabilir'
);
select is(
  (select prefs ->> 'family' from public.user_theme_prefs where user_id = :'alpha'),
  'campfire_day',
  '21 sahip kendi tercihini geri okuyabilir'
);
select lives_ok(
  $sql$
    update public.user_theme_prefs
       set prefs = jsonb_set(prefs, '{family}', '"deep_amoled"')
     where user_id = '10000000-0000-0000-0000-000000000001'
  $sql$,
  '22 sahip kendi tercihini guncelleyebilir'
);
select is(
  (select prefs ->> 'family' from public.user_theme_prefs where user_id = :'alpha'),
  'deep_amoled',
  '23 guncelleme kalici'
);

-- Baskasi adina satir yazmak reddedilir (with check).
select throws_ok(
  $sql$
    insert into public.user_theme_prefs (user_id, prefs)
    values ('10000000-0000-0000-0000-000000000002', '{"family":"sahte"}'::jsonb)
  $sql$,
  '42501',
  null,
  '24 kullanici BASKASI adina tercih satiri ekleyemez'
);

-- ===========================================================================
-- 3) YABANCI (ayni gruptaki beta) -- okuyamaz, yazamaz
-- ===========================================================================
select set_config('request.jwt.claims', json_build_object('sub', :'beta')::text, true);

select is(
  (select count(*)::integer from public.user_theme_prefs where user_id = :'alpha'),
  0,
  '30 grup arkadasi beta, alpha''nin tema tercihini OKUYAMAZ'
);
select is(
  (select count(*)::integer from public.user_theme_prefs),
  0,
  '31 beta icin tablo tamamen bos gorunur (enumerasyon yok)'
);

-- Guncelleme RLS'te sessizce 0 satira duser (hata firlatmaz); veri degismez.
update public.user_theme_prefs
   set prefs = '{"family":"ele-gecirildi"}'::jsonb
 where user_id = :'alpha';

-- Beta kendi satirini yazabilir: politika sahibi engellemiyor.
select lives_ok(
  $sql$
    insert into public.user_theme_prefs (user_id, prefs)
    values ('10000000-0000-0000-0000-000000000002',
            '{"family":"ocean_glass","updatedAt":"2026-09-18T11:00:00.000Z"}'::jsonb)
  $sql$,
  '32 beta kendi tema tercihini yazabilir'
);

reset role;
select is(
  (select prefs ->> 'family' from public.user_theme_prefs where user_id = :'alpha'),
  'deep_amoled',
  '33 beta''nin update denemesi alpha''nin satirini DEGISTIRMEDI'
);

-- ===========================================================================
-- 4) MEVCUT SATIRLAR -- migration hicbir sey bozmaz
-- ===========================================================================
select ok(
  not exists(
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name = 'theme_prefs'
  ),
  '40 profiles semasi degismedi (tercihler ayri tabloda)'
);

select * from finish();
rollback;
