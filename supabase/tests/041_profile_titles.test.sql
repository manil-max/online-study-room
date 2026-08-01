-- 041_profile_titles.test.sql
-- WP-475: profil ünvanı yalnız sunucu-otoriter ledger'da kazanılmış bir
-- başarımdan seçilebilir; grup dizini seçimi görünür ve engelde anonimleştirir.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

select plan(8);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select throws_ok(
  $$update public.profiles
      set title_achievement_id = 'marathon_total'
      where id = '10000000-0000-0000-0000-000000000001'$$,
  'title_not_earned',
  'kazanılmamış başarım doğrudan profile yazılarak ünvan yapılamaz'
);

reset role;
insert into public.xp_ledger (
  user_id, achievement_id, tier, xp_amount, reason, event_key
) values
  (:'alpha', 'marathon_total', 1, 1500, 'fixture', 'wp475-alpha-title'),
  (:'beta', 'steel_will', 1, 500, 'fixture', 'wp475-beta-title');

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select lives_ok(
  $$update public.profiles
      set title_achievement_id = 'marathon_total'
      where id = '10000000-0000-0000-0000-000000000001'$$,
  'ledgerda kazanılmış başarım ünvan yapılabilir'
);
select is(
  (select title_achievement_id from public.profiles where id = :'alpha'),
  'marathon_total',
  'seçilen ünvan profilde saklanır'
);
select lives_ok(
  $$update public.profiles
      set display_name = 'Fixture Alpha Renamed'
      where id = '10000000-0000-0000-0000-000000000001'$$,
  'ünvan değişmezken ilgisiz profil güncellemesi yeniden doğrulamada takılmaz'
);
select lives_ok(
  $$update public.profiles
      set title_achievement_id = null
      where id = '10000000-0000-0000-0000-000000000001'$$,
  'ünvan her zaman kaldırılabilir'
);

reset role;
update public.profiles
set title_achievement_id = 'steel_will'
where id = :'beta';

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select is(
  (
    select title_achievement_id
    from public.group_member_directory(:'grp'::uuid)
    where id = :'beta'
  ),
  'steel_will',
  'ortak grup üyesinin seçili ünvanı dizinde görünür'
);

reset role;
insert into public.user_blocks (blocker_id, blocked_id)
values (:'alpha', :'beta');

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select is_null(
  (
    select title_achievement_id
    from public.group_member_directory(:'grp'::uuid)
    where id = :'beta'
  ),
  'engellenen üyenin ünvanı ad ve avatarla birlikte anonimleştirilir'
);
select is(
  (
    select count(*)::int
    from public.group_member_directory(:'grp'::uuid)
    where id = :'beta'
  ),
  1,
  'ünvan anonimleştirmesi kamp ateşi katılımcısını listeden düşürmez'
);

select * from finish();
rollback;
