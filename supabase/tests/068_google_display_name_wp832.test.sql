-- 068_google_display_name_wp832.test.sql
-- WP-832 (migration `0142`): Google ile gelen kullanicinin gorunen adi ve
-- kayit tetikleyicisinin cokmemesi.
--
-- Kusur: `handle_new_user` (`0001`) adi YALNIZ `display_name` metadata
-- alanindan okuyordu. Google (`signInWithIdToken`) `full_name`/`name` getirir,
-- `display_name` getirmez -> bos ad. Daha kotusu, tetikleyici `auth.users`
-- insert'inin icinde kostugu icin ad filtresine (`0094`) takilan ya da 24
-- sinirini (`0122`) asan bir ad TUM KAYDI dusuruyordu.
--
-- Her senaryo kendi temiz kullanicisiyla, `auth.users`e GERCEK insert ile
-- kurulur; profil tetikleyiciden okunur. Gruba uye olunmaz.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set g_full  '10000000-0000-0000-0000-000000008321'
\set g_both  '10000000-0000-0000-0000-000000008322'
\set g_name  '10000000-0000-0000-0000-000000008323'
\set g_block '10000000-0000-0000-0000-000000008324'
\set g_empty '10000000-0000-0000-0000-000000008325'
\set g_null  '10000000-0000-0000-0000-000000008326'
\set g_space '10000000-0000-0000-0000-000000008327'
\set g_long  '10000000-0000-0000-0000-000000008328'
\set e_ok    '10000000-0000-0000-0000-000000008329'
\set e_block '10000000-0000-0000-0000-000000008330'

select plan(21);

-- ===========================================================================
-- A) GOOGLE -- ad `full_name` / `name` alanindan gelir
-- ===========================================================================
-- Supabase'in Google kimliginden yazdigi metadata bicimi (display_name YOK).
select lives_ok(
  $sql$
    insert into auth.users (id, email, raw_user_meta_data)
    values (
      '10000000-0000-0000-0000-000000008321',
      'fixture-wp832-google@example.invalid',
      '{"iss":"https://accounts.google.com","sub":"832001","name":"Ayse Yilmaz",
        "full_name":"Ayse Yilmaz","email":"fixture-wp832-google@example.invalid",
        "avatar_url":"https://example.invalid/a.png","email_verified":true}'::jsonb
    )
  $sql$,
  'A1 Google metadata ile kullanici insert edilir'
);
select is(
  (select display_name from public.profiles where id = :'g_full'),
  'Ayse Yilmaz',
  'A2 Google kullanicisinin adi full_name alanindan gelir (bos degil)'
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  :'g_both', 'fixture-wp832-both@example.invalid',
  '{"display_name":"Secilen Ad","full_name":"Google Tam Ad","name":"Google Ad"}'::jsonb
);
select is(
  (select display_name from public.profiles where id = :'g_both'),
  'Secilen Ad',
  'A3 display_name varsa full_name/name uzerinde kazanir'
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  :'g_name', 'fixture-wp832-name@example.invalid',
  '{"name":"Yalniz Name"}'::jsonb
);
select is(
  (select display_name from public.profiles where id = :'g_name'),
  'Yalniz Name',
  'A4 full_name yoksa name kullanilir'
);

-- ===========================================================================
-- B) FILTRE -- yasakli terim kaydi DUSURMEZ, ad bos acilir
-- ===========================================================================
-- "Hamka" normalize edilince `amk` icerir (`0094` alt-dizi arar): masum bir
-- soyad filtreye takilir. Kullanici Google adini degistiremez.
select is(
  (select count(*)::integer from public.public_name_blocked_terms
    where normalized_term = 'amk'),
  1,
  'B0 on kosul: amk yasakli terim listesinde'
);
select lives_ok(
  $sql$
    insert into auth.users (id, email, raw_user_meta_data)
    values (
      '10000000-0000-0000-0000-000000008324',
      'fixture-wp832-blocked@example.invalid',
      '{"full_name":"Deniz Hamka","name":"Deniz Hamka"}'::jsonb
    )
  $sql$,
  'B1 filtreye takilan Google adiyla kullanici insert edilir (hata firlamaz)'
);
select ok(
  exists(select 1 from auth.users where id = :'g_block'),
  'B2 auth.users satiri gercekten yazildi (kayit geri alinmadi)'
);
select is(
  (select display_name from public.profiles where id = :'g_block'),
  '',
  'B3 filtreye takilan adla profil bos adla acilir'
);

select lives_ok(
  $sql$
    insert into auth.users (id, email, raw_user_meta_data)
    values (
      '10000000-0000-0000-0000-000000008330',
      'fixture-wp832-email-blocked@example.invalid',
      '{"display_name":"f.u.c.k"}'::jsonb
    )
  $sql$,
  'B4 e-posta yolunda yasakli display_name de kaydi dusurmez'
);
select is(
  (select display_name from public.profiles where id = :'e_block'),
  '',
  'B5 yasakli display_name ile profil bos adla acilir'
);

-- Filtrenin kendisi GEVSEMEDI: profil ekranindan yasakli ad hala reddedilir.
select throws_ok(
  format(
    $sql$update public.profiles set display_name = 'Deniz Hamka' where id = %L$sql$,
    :'g_block'
  ),
  'P0001', 'public_name_not_allowed',
  'B6 filtre profil guncellemesinde hala acik hata verir'
);

-- ===========================================================================
-- C) BOS / BOSLUK / UZUN
-- ===========================================================================
insert into auth.users (id, email, raw_user_meta_data)
values (:'g_empty', 'fixture-wp832-empty@example.invalid', '{}'::jsonb);
select is(
  (select display_name from public.profiles where id = :'g_empty'),
  '',
  'C1 bos metadata -> bos ad'
);

select lives_ok(
  $sql$
    insert into auth.users (id, email, raw_user_meta_data)
    values ('10000000-0000-0000-0000-000000008326',
            'fixture-wp832-null@example.invalid', null)
  $sql$,
  'C2 null metadata ile kullanici insert edilir'
);
select is(
  (select display_name from public.profiles where id = :'g_null'),
  '',
  'C3 null metadata -> bos ad'
);

-- Yalniz bosluk/tab olan display_name dolu SAYILMAZ; full_name'e dusulur ve
-- ic bosluklar tek bosluga iner.
insert into auth.users (id, email, raw_user_meta_data)
values (
  :'g_space', 'fixture-wp832-space@example.invalid',
  jsonb_build_object(
    'display_name', E'  \t ',
    'full_name', E'  Mehmet \t  Kaya  '
  )
);
select is(
  (select display_name from public.profiles where id = :'g_space'),
  'Mehmet Kaya',
  'C4 bosluk-only display_name atlanir; full_name bosluklari normalize edilir'
);

-- 24'ten uzun Google adi `0122` kisitinda kaydi dusurmez; 24'e kesilir ve
-- kesim bir bosluga denk gelirse sonda bosluk kalmaz.
select lives_ok(
  $sql$
    insert into auth.users (id, email, raw_user_meta_data)
    values (
      '10000000-0000-0000-0000-000000008328',
      'fixture-wp832-long@example.invalid',
      '{"full_name":"Abdulkadir Mehmet Ahmet Yilmaz"}'::jsonb
    )
  $sql$,
  'C5 24 karakterden uzun Google adiyla kullanici insert edilir'
);
select is(
  (select display_name from public.profiles where id = :'g_long'),
  'Abdulkadir Mehmet Ahmet',
  'C6 uzun ad 24 sinirinda kesilir ve sondaki bosluk kirpilir'
);

-- ===========================================================================
-- D) DEGISMEYENLER
-- ===========================================================================
insert into auth.users (id, email, raw_user_meta_data)
values (
  :'e_ok', 'fixture-wp832-email@example.invalid',
  '{"display_name":"WP832 Email"}'::jsonb
);
select is(
  (select display_name from public.profiles where id = :'e_ok'),
  'WP832 Email',
  'D1 e-posta/sifre yolu: filtreden gecen ad aynen yazilir'
);
select is(
  (select count(*)::integer from public.gamification_profiles
    where user_id in (:'g_full', :'g_block', :'g_null', :'g_long')),
  4,
  'D2 0017 gamification tetikleyicisi hala her yeni kullanicida calisir'
);
select ok(
  (select prosecdef from pg_proc
    where oid = 'public.handle_new_user()'::regprocedure)
  and exists(
    select 1 from pg_proc
     where oid = 'public.handle_new_user()'::regprocedure
       and proconfig @> array['search_path=public']
  ),
  'D3 handle_new_user security definer ve search_path=public olarak kalir'
);
select ok(
  exists(
    select 1 from pg_trigger
     where tgname = 'on_auth_user_created'
       and tgrelid = 'auth.users'::regclass
       and tgfoid = 'public.handle_new_user()'::regprocedure
       and not tgisinternal
  ),
  'D4 on_auth_user_created tetikleyicisi handle_new_user ile bagli kalir'
);

select * from finish();
rollback;
