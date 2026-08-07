-- 046_group_scoped_progress.test.sql
-- WP-501: grup basarimlari (grup x gun/hafta) sayiliyordu (migration 0121).
--
-- 🔴 Sahibin sikayeti: iki grupta ayni hafta birinci olan kullanici Lider Kurt
-- ilerlemesinde 2 aliyordu. Sebep uc projeksiyonun da rollup tablosunu
-- `group by user_id` ile toplamasiydi; `achievement_metric_progress` birincil
-- anahtari `(user_id, achievement_id)` oldugu icin grup boyutu kayboluyordu.
--
-- Bu dosya ucunu birden sabitler:
--   1. grup kirilimli tablo VAR ve RLS'i kullaniciyi kendi satirina kilitler;
--   2. iki grupta ayni hafta birincilik ILERLEMEYI 2 YAPMAZ;
--   3. duzeltme kazanilmis kademeyi geri ALMAZ (odul satiri duruyor).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp1  '20000000-0000-0000-0000-000000000001'
\set grp2  '20000000-0000-0000-0000-000000000002'

select plan(16);

-- ===========================================================================
-- Sema
-- ===========================================================================
select has_table(
  'public', 'group_achievement_metric_progress',
  '0121 grup kirilimli ilerleme tablosunu ekler'
);

select col_is_pk(
  'public', 'group_achievement_metric_progress',
  array['user_id', 'group_id', 'achievement_id'],
  'birincil anahtar grup boyutunu TASIR (kayip tam buradaydi)'
);

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.group_achievement_metric_progress'::regclass),
  'RLS acik'
);

select ok(
  exists(
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'group_achievement_metric_progress'
      and policyname = 'group_achievement_metric_progress_self_select'
      and cmd = 'SELECT'
  ),
  'kullanici yalniz kendi satirini okur'
);

-- Grup kirilimi baskasinin verisini acmamali: yazma yetkisi hic verilmez.
select ok(
  not has_table_privilege(
    'authenticated', 'public.group_achievement_metric_progress', 'INSERT'
  ),
  'authenticated bu tabloya yazamaz'
);

select ok(
  exists(
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'group_achievement_metric_progress'
  ),
  'rozet canli guncellensin diye realtime yayinina eklenir'
);

-- 🔴 Kural uc ayri fonksiyonda kopyalanmisti ve uculde birden kayabiliyordu.
-- Kirilim artik tek yerde; uc projeksiyon da onu cagirmali.
-- 🔴 `project_verified_group_day` BU LISTEDE YOK ve olmamali: 0063 onu
-- kaldirdi (`drop function if exists`), yerini `project_group_day` aldi.
-- 0121'in ilk taslagi govdesini 0059'dan alip yeniden yaratmisti ve
-- `001_schema_contract` "stale verified-only projectors are removed"
-- iddiasi bunu yakaladi. Olu fonksiyonun geri gelmedigi burada da sabitlenir.
select ok(
  to_regprocedure('public.project_verified_group_day(uuid,date)') is null,
  '0063 kaldirdigi olu projektor geri dirilmedi'
);

select ok(
  pg_get_functiondef('public.project_group_day(uuid, date)'::regprocedure)
    like '%_project_group_scoped_metrics%',
  'project_group_day kirilim fonksiyonunu cagirir'
);

select ok(
  pg_get_functiondef('public.project_group_week(uuid, date)'::regprocedure)
    like '%_project_group_scoped_metrics%',
  'project_group_week kirilim fonksiyonunu cagirir'
);

-- ===========================================================================
-- Sahibin senaryosu: ayni hafta IKI grupta birincilik
-- ===========================================================================
insert into public.groups (id, name, invite_code, created_by, created_at)
values (:'grp2', 'Ikinci Grup', 'FIXTURE2', :'alpha', now())
on conflict (id) do nothing;

insert into public.group_members (group_id, user_id, role, joined_at)
values (:'grp2', :'alpha', 'admin', now() - interval '1 day')
on conflict (group_id, user_id) do nothing;

-- Ayni ISO haftasinda iki ayri grupta birincilik.
-- Kolon adi `total_seconds`: 0062 `verified_seconds` diye acmisti, 0063:239
-- yeniden adlandirdi. Ilk taslak eski adi kullaninca pgTAP dosyayi bastan
-- dusurdu (run 31162831797).
insert into public.group_achievement_weekly (
  group_id, iso_week_start, user_id, total_seconds, weekly_alpha_wins,
  finalized_at
) values
  (:'grp1', date_trunc('week', current_date)::date, :'alpha', 7200, 1, now()),
  (:'grp2', date_trunc('week', current_date)::date, :'alpha', 7200, 1, now());

select public._project_group_scoped_metrics();

select is(
  (select count(*)::integer from public.group_achievement_metric_progress
    where user_id = :'alpha' and achievement_id = 'alpha_wolf_weekly'),
  2,
  'iki grup icin iki AYRI satir yazilir (kirilim korunur)'
);

select is(
  (select metric_value from public.group_achievement_metric_progress
    where user_id = :'alpha' and group_id = :'grp1'
      and achievement_id = 'alpha_wolf_weekly'),
  1::bigint,
  'secili grup 1. grup ise deger 1 (toplam degil)'
);

select is(
  (select metric_value from public.group_achievement_metric_progress
    where user_id = :'alpha' and group_id = :'grp2'
      and achievement_id = 'alpha_wolf_weekly'),
  1::bigint,
  'secili grup 2. grup ise deger yine 1'
);

-- 🔴 Asil regresyon: duz tablo eskiden 2 yaziyordu (iki grubun toplami).
-- Odul/XP ucu cihaza bagli olamaz, bu yuzden gruplar arasi `max` kullanilir —
-- cift sayim biter ve deger hicbir grubun gerceginin altina dusmez.
select is(
  (select metric_value from public.achievement_metric_progress
    where user_id = :'alpha' and achievement_id = 'alpha_wolf_weekly'),
  1::bigint,
  'duz tablo 2 DEGIL 1 (cift sayim bitti)'
);

-- ===========================================================================
-- Kazanilmis kademe geri ALINMAZ
-- ===========================================================================
insert into public.achievement_rewards (
  user_id, achievement_id, tier, xp_amount, event_key
) values (
  :'alpha', 'alpha_wolf_weekly', 1, 50,
  :'alpha' || '|alpha_wolf_weekly|tier_1'
) on conflict do nothing;

-- Ikinci gruptan cikildi: kirilim degeri dusurmeli ama odulu silmemeli.
delete from public.group_achievement_weekly
  where group_id = :'grp2' and user_id = :'alpha';
select public._project_group_scoped_metrics();

select is(
  (select count(*)::integer from public.group_achievement_metric_progress
    where user_id = :'alpha' and group_id = :'grp2'
      and achievement_id = 'alpha_wolf_weekly'),
  0,
  'kaynak satir gidince grup kirilimi da temizlenir'
);

select ok(
  exists(
    select 1 from public.achievement_rewards
    where user_id = :'alpha' and achievement_id = 'alpha_wolf_weekly'
      and tier = 1
  ),
  'kazanilmis kademe geri alinmaz (XP negatife donmez)'
);

-- ===========================================================================
-- Kapsam: team_player bu mekanizmadan gelmiyor
-- ===========================================================================
-- Kart bes metrik sayiyor; bu rollup'lardan yalniz dordu besleniyor.
-- `team_player` `group_goal_contrib` metriginden gelir (0050:49) ve grup
-- toplamiyla carpilmiyor — kirilim tablosunda hic satiri olmamali.
select is(
  (select count(*)::integer from public.group_achievement_metric_progress
    where achievement_id = 'team_player'),
  0,
  'team_player grup kirilimina girmez (kaynagi farkli)'
);

select * from finish();
rollback;
