-- 071_default_daily_goal_wp922.test.sql
-- WP-922 (migration `0145`): yeni hesabin kisisel gunluk hedefi 120 dk'dir.
--
-- Hesap `auth.users` insert'i + `handle_new_user` tetikleyicisi ile acilir
-- (uygulamadaki kayit yolu). Tetikleyici hedef yazmaz; profil satiri kolon
-- varsayilanini alir. Grup hedefi bu isin kapsami disindadir ve 360 kalir.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set newbie '10000000-0000-0000-0000-000000000922'

select plan(4);

select is(
  (select column_default from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name = 'daily_goal_minutes'),
  '120',
  '00 0145 profiles.daily_goal_minutes varsayilani 120 dk'
);

insert into auth.users (id, email, raw_user_meta_data)
values (
  :'newbie',
  'fixture-newbie-wp922@example.invalid',
  '{"display_name":"Fixture Newbie"}'::jsonb
);

select is(
  (select daily_goal_minutes from public.profiles where id = :'newbie'),
  120,
  '01 kayit tetikleyicisiyle acilan yeni hesap 2 saatlik hedefle baslar'
);

-- Kullanici hedefini kendisi degistirirse varsayilan onu ezmez.
update public.profiles set daily_goal_minutes = 360 where id = :'newbie';
select is(
  (select daily_goal_minutes from public.profiles where id = :'newbie'),
  360,
  '02 acik hedef secimi korunur'
);

select is(
  (select column_default from information_schema.columns
    where table_schema = 'public' and table_name = 'groups'
      and column_name = 'daily_goal_minutes'),
  '360',
  '03 grup hedefi varsayilani degismedi (kapsam disi)'
);

select * from finish();
rollback;
