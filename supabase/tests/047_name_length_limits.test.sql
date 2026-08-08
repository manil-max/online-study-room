-- 047_name_length_limits.test.sql
-- WP-517: gorunen ad 24, grup adi 30 karakter (migration 0122).
--
-- 🔴 Neden sunucuda olculuyor: istemci `maxLength`i kozmetiktir. Ad yazan uc
-- yol var ve ikisi RPC bile degil — `profiles` ve `groups` uzerinde DOGRUDAN
-- `update`. Yani sinir yalnizca ekranda dursaydi, eski bir istemci ya da ham
-- bir API cagrisi 500 karakterlik ad yazabilirdi.
--
-- Bu dosya dordunu birden sabitler:
--   1. iki kisit da VAR ve sinir ustunu REDDEDIYOR;
--   2. tam sinirdaki ad KABUL ediliyor (kisit bir fazla siki degil);
--   3. sondaki bosluk uzunluga sayilmiyor (btrim ile olculuyor);
--   4. grup olusturma RPC'si artik 64'u degil 30'u zorluyor — "olusturulabiliyor
--      ama kesifte gorunmuyor" tutarsizligi uretilemiyor.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set grp1  '20000000-0000-0000-0000-000000000001'

select plan(10);

-- ===========================================================================
-- 1. Kisitlar var
-- ===========================================================================
select hasnt_column(
  'public', 'profiles', 'display_name_length',
  'sinir ayri bir kolon degil, kisit olarak duruyor'
);

select ok(
  exists (
    select 1 from pg_constraint
     where conname = 'profiles_display_name_max_len'
       and conrelid = 'public.profiles'::regclass
  ),
  '0122 profiles.display_name ust sinir kisitini ekler'
);

select ok(
  exists (
    select 1 from pg_constraint
     where conname = 'groups_name_max_len'
       and conrelid = 'public.groups'::regclass
  ),
  '0122 groups.name ust sinir kisitini ekler'
);

-- ===========================================================================
-- 2. Sinir ustu reddediliyor, tam sinir kabul ediliyor
-- ===========================================================================
select throws_ok(
  format(
    'update public.profiles set display_name = %L where id = %L',
    repeat('a', 25), :'alpha'
  ),
  '23514',
  null,
  '25 karakterlik gorunen ad REDDEDILIR (24 sinir)'
);

select lives_ok(
  format(
    'update public.profiles set display_name = %L where id = %L',
    repeat('a', 24), :'alpha'
  ),
  'tam 24 karakter KABUL EDILIR — kisit bir fazla siki degil'
);

select throws_ok(
  format(
    'update public.groups set name = %L where id = %L',
    repeat('b', 31), :'grp1'
  ),
  '23514',
  null,
  '31 karakterlik grup adi REDDEDILIR (30 sinir)'
);

select lives_ok(
  format(
    'update public.groups set name = %L where id = %L',
    repeat('b', 30), :'grp1'
  ),
  'tam 30 karakter KABUL EDILIR'
);

-- ===========================================================================
-- 3. Sondaki bosluk uzunluga sayilmiyor
-- ===========================================================================
select lives_ok(
  format(
    'update public.groups set name = %L where id = %L',
    repeat('b', 30) || '     ', :'grp1'
  ),
  '30 karakter + bosluk kabul edilir (kisit btrim ile olcuyor)'
);

-- ===========================================================================
-- 4. Grup olusturma RPC'si 30'u zorluyor (eski deger 64'tu)
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'alpha')::text, true);

select throws_ok(
  format(
    $q$select public.create_group_with_access(%L, 'private', 4, 'Europe/Istanbul')$q$,
    repeat('c', 31)
  ),
  null,
  'Grup adı 1 ile 30 karakter arasında olmalı.',
  'RPC artik 64'' degil 30 zorluyor — kesif tutarsizligi uretilemez'
);

select lives_ok(
  format(
    $q$select public.create_group_with_access(%L, 'private', 4, 'Europe/Istanbul')$q$,
    repeat('c', 30)
  ),
  'tam 30 karakterle grup olusturulabiliyor'
);

reset role;
select * from finish();
rollback;
