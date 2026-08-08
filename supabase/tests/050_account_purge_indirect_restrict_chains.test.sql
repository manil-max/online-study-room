-- 050_account_purge_indirect_restrict_chains.test.sql
-- WP-549: hesap silmeyi bloklayan DOLAYLI `restrict` FK zincirleri.
--
-- 🔴 Neden `040` bunu yakalamadi (sozlesme boslugu, olculdu): `040`
-- `delete from auth.users` yapiyor ama o kullanicinin YALNIZ bir feedback
-- mesaji var. Grubu, canli kosusu, push cihazi, yaptirimi YOK. Yani `040`
-- `0114`un cozdugu DOGRUDAN sinifi kanitliyor ve DOLAYLI sinifa hic
-- dokunmuyor: `auth.users` cascade ile bir ara tabloyu silerken o ara
-- tablonun kendi `restrict` cocuklarinin zinciri dusurmesi.
--
-- Bu dosya GERCEKCI bir kullanici kurar -- grup sahibi + o grupta BASKA
-- birinin actigi rapor + canli kosu + segment + verified oturum + push cihazi
-- + sayac komutu + hakkinda yaptirim + o yaptirima itiraz -- ve sonra tek bir
-- `delete from auth.users` calistirip GECTIGINI olcer.
--
-- `0124` ONCESI bu dosya KIRMIZIDIR. Iki ayri sekilde kirmizi duser ve ikisi
-- de kabul edilebilir kirmizidir:
--   * §1 yapisal iddialar `restrict` gorup fail eder,
--   * `context_group_id_snapshot` sutunu HENUZ YOKTUR, yani ona dokunan ilk
--     ifade "column does not exist" ile islemi abort eder.
--
-- 🔴 OLCEMEDIGI SEY (durust sinir): bu dosya veritabaninin ICINDE kosar.
-- `supabase/functions/purge-accounts/index.ts` dosyasini OKUYAMAZ. §2 o
-- fonksiyonun `group_delete` adimini SQL olarak taklit eder (ayni ifade:
-- uyesiz grubun satirini sil), fonksiyonun kendisini kositurmaz.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

-- base_seed: alpha grubun kurucusu (`groups.created_by`), beta uye.
\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

-- gamma: RAPORU YAZAN ucuncu kisi. Kritik: raporlayan silinen kullanicidan
-- FARKLI, yani `ugc_reports` satiri hicbir cascade ile GITMEZ. Zinciri
-- bloklayan tam olarak budur.
\set gamma '10000000-0000-0000-0000-0000000000c1'
insert into auth.users (id, email, raw_user_meta_data)
values (:'gamma', 'fixture-gamma@example.invalid', '{}'::jsonb)
on conflict (id) do nothing;

-- grp2: alpha'nin sahibi oldugu ve BASKA AKTIF UYESI OLMAYAN grup. Purge'un
-- `group_delete` dali tam olarak bu grubu siler.
\set grp2 '20000000-0000-0000-0000-000000000002'
insert into public.groups (id, name, invite_code, created_by, created_at)
values (:'grp2', 'WP549 Solo Group', 'FIXTUR49', :'alpha', now())
on conflict (id) do nothing;

\set run     '40000000-0000-0000-0000-000000000001'
\set segment '41000000-0000-0000-0000-000000000001'
\set session '42000000-0000-0000-0000-000000000001'
\set device  '43000000-0000-0000-0000-000000000001'
\set command '44000000-0000-0000-0000-000000000001'
\set sanction '45000000-0000-0000-0000-000000000001'
\set appeal   '46000000-0000-0000-0000-000000000001'
\set report1  '47000000-0000-0000-0000-000000000001'
\set report2  '47000000-0000-0000-0000-000000000002'

select plan(22);

-- ===========================================================================
-- 1. Yapisal: dolayli zincirlerin FK aksiyonlari
-- ===========================================================================
-- `confdeltype`: 'c' = cascade, 'n' = set null, 'r' = restrict, 'a' = no action.
create or replace function pg_temp.fk_action(
  p_table text, p_column text, p_ref text
) returns text language sql stable as $fn$
  select con.confdeltype::text
  from pg_constraint con
  join pg_attribute a
    on a.attrelid = con.conrelid and a.attnum = con.conkey[1]
  where con.conrelid = ('public.' || p_table)::regclass
    and con.contype = 'f'
    and con.confrelid = p_ref::regclass
    and array_length(con.conkey, 1) = 1
    and a.attname = p_column;
$fn$;

select is(
  pg_temp.fk_action('live_study_segments', 'run_id', 'public.live_study_runs'),
  'c',
  'A1: live_study_segments.run_id artik cascade (0051:36 restrict idi)'
);
select is(
  pg_temp.fk_action('study_sessions', 'live_run_id', 'public.live_study_runs'),
  'c',
  'A2: study_sessions.live_run_id artik cascade (0051:63 restrict idi)'
);
select is(
  pg_temp.fk_action('global_timer_commands', 'device_id', 'public.push_devices'),
  'c',
  'A3: global_timer_commands.device_id artik cascade (0082:95 restrict idi)'
);
select is(
  pg_temp.fk_action('moderation_appeals', 'sanction_id', 'public.moderation_sanctions'),
  'c',
  'C: moderation_appeals.sanction_id artik cascade (0106:146 restrict idi)'
);
-- 🔴 B TEK ISTISNA: bu satir BASKASININ yazdigi moderasyon delilidir, grup
-- silindi diye kaybolmamali. `0114`un deseni: satir kalir, ham bag kopar.
select is(
  pg_temp.fk_action('ugc_reports', 'context_group_id', 'public.groups'),
  'n',
  'B: ugc_reports.context_group_id artik set null (0104:12 restrict idi)'
);

-- Envanteri DONDUR. `049`un §1 deseni: yeni bir `restrict` sessizce eklenirse
-- bu iddia kirmizi duser ve ekleyen kisi zinciri dusunmek zorunda kalir.
select is(
  (select count(*)::int
   from pg_constraint con
   join pg_class t on t.oid = con.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   where con.contype = 'f' and con.confdeltype = 'r' and n.nspname = 'public'),
  2,
  'public semasinda toplam iki restrict FK kaldi'
);
-- Kalan ikisi blokaj DEGILDIR: `moderation_cases` tablosunun `auth.users`'a
-- hicbir FK'si yoktur, yani oraya hicbir cascade ulasmaz.
select is(
  (select count(*)::int
   from pg_constraint con
   join pg_class t on t.oid = con.conrelid
   join pg_namespace n on n.oid = t.relnamespace
   join pg_attribute a on a.attrelid = t.oid and a.attnum = con.conkey[1]
   where con.contype = 'f' and con.confdeltype = 'r' and n.nspname = 'public'
     and con.confrelid = 'public.moderation_cases'::regclass
     and (t.relname, a.attname) in (
       ('ugc_reports', 'case_id'),
       ('moderation_sanctions', 'case_id'))),
  2,
  'kalan iki restrict tam olarak moderation_cases`e gider (ulasilamaz dal)'
);
select has_column(
  'public', 'ugc_reports', 'context_group_id_snapshot',
  'degismez grup snapshot sutunu var'
);

-- ===========================================================================
-- 2. Gercekci kullaniciyi kur
-- ===========================================================================
-- Canli kosu + segment: `live_study_segments` HICBIR YERDE silinmiyor
-- (`0051` yalniz insert + `ended_at` update yapar), yani satir hep orada.
insert into public.live_study_runs (id, user_id, client_request_id)
values (:'run', :'alpha', '48000000-0000-0000-0000-000000000001');
insert into public.live_study_segments (id, run_id, user_id, ordinal)
values (:'segment', :'run', :'alpha', 1);

-- Verified oturum: `live_run_id` DOLU. `0051:109`daki guard tetikleyicisi
-- yuzunden bu sutun `set null` ile bosaltilamaz; cozum cascade olmak zorunda.
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source, live_run_id
) values (
  :'session', :'alpha', now() - interval '1 hour', now(), 3600, 'live', :'run'
);

-- Push cihazi + o cihaza bagli sayac komutu.
insert into public.push_devices (
  id, user_id, installation_id, fcm_token, app_channel, app_version
) values (
  :'device', :'alpha', 'wp549-installation-0001',
  'wp549-fcm-token-000000000000000000', 'local', '1.0.0'
);
insert into public.global_timer_commands (
  id, user_id, command_id, device_id, action,
  request_fingerprint, result_code, result_snapshot
) values (
  :'command', :'alpha', '49000000-0000-0000-0000-000000000001', :'device',
  'start', '{}'::jsonb, 'applied', '{}'::jsonb
);

-- Yaptirim (hedef alpha, aktor beta) + alpha'nin itirazi.
insert into public.moderation_sanctions (
  id, target_user_id, action, reason, actor_id, idempotency_key
) values (
  :'sanction', :'alpha', 'warn', 'wp549 fixture gerekce', :'beta',
  'wp549-idempotency-0001'
);
insert into public.moderation_appeals (id, sanction_id, appellant_id, statement)
values (:'appeal', :'sanction', :'alpha', 'wp549 fixture itiraz metni');

-- Raporlar: ikisini de GAMMA yazdi, yani alpha silinince cascade ile GITMEZLER.
-- `target_type = 'message'` zorunlu; `0104:24` CHECK'i baglam sutununu yalniz
-- mesaj raporlarinda dolu istiyor.
insert into public.ugc_reports (
  id, reporter_id, target_type, target_id, reason, context_group_id
) values (
  :'report1', :'gamma', 'message', 'wp549-message-1', 'spam', :'grp'
);
insert into public.ugc_reports (
  id, reporter_id, target_type, target_id, reason, context_group_id
) values (
  :'report2', :'gamma', 'message', 'wp549-message-2', 'spam', :'grp2'
);

select is(
  (select context_group_id_snapshot from public.ugc_reports where id = :'report1'),
  :'grp'::uuid,
  'snapshot tetikleyicisi insert aninda baglami dondurur'
);

-- ===========================================================================
-- 3. Kume B: purge'un `group_delete` adimi (uyesiz grubu sil)
-- ===========================================================================
-- 🔴 `0124` oncesi bu ifade `ugc_reports.context_group_id` RESTRICT yuzunden
-- FK ihlaliyle PATLARDI. `purge-accounts/index.ts:365` bunu `must(...)` ile
-- sardigi icin is atardi, 5 denemeyi yakardi ve hesap terminal `failed`
-- olurdu -- yani o grupta bir kez rapor acilmis olmasi hesabi SILINEMEZ
-- yapardi. Raporu baskasi yazdigi icin hicbir cascade onu temizlemez.
select lives_ok(
  format($$delete from public.groups where id = %L$$, :'grp2'),
  'uyesiz grup silinebilir (purge group_delete adimi)'
);
select is(
  (select count(*)::int from public.ugc_reports where id = :'report2'),
  1,
  'grup silinince moderasyon kaniti KALIR (cascade ile gitmez)'
);
select ok(
  (select context_group_id is null from public.ugc_reports where id = :'report2'),
  'ham grup bagi NULL olur'
);
select is(
  (select context_group_id_snapshot from public.ugc_reports where id = :'report2'),
  :'grp2'::uuid,
  'degismez snapshot silme sonrasi DEGISMEDEN durur (guard ezmez)'
);

-- ===========================================================================
-- 4. Asil sinav: tek `delete from auth.users`
-- ===========================================================================
-- 🔴 `0124` oncesi bu ifade DORT ayri FK ihlalinden biriyle patlardi. Hangisi
-- once atesler, RI tetikleyicilerinin OID sirasina baglidir; hepsi kapatilmadan
-- silme guvenilir olmaz.
select lives_ok(
  format($$delete from auth.users where id = %L$$, :'alpha'),
  'gercekci kullanici tek ifadede silinebilir (dort zincir de acik)'
);

select is(
  (select count(*)::int from public.live_study_segments where user_id = :'alpha'),
  0,
  'A1: segmentler kosuyla birlikte gitti'
);
select is(
  (select count(*)::int from public.study_sessions where id = :'session'),
  0,
  'A2: verified oturum gitti'
);
select is(
  (select count(*)::int from public.global_timer_commands where user_id = :'alpha'),
  0,
  'A3: sayac komutlari cihazla birlikte gitti'
);
select is(
  (select count(*)::int from public.push_devices where user_id = :'alpha'),
  0,
  'A3: push cihazi gitti'
);
select is(
  (select count(*)::int from public.moderation_appeals where sanction_id = :'sanction'),
  0,
  'C: itiraz yaptirimla birlikte gitti'
);

-- ===========================================================================
-- 5. Kanit korunmasi: baskasinin yazdigi hicbir sey kaybolmadi
-- ===========================================================================
-- alpha silinince `groups.created_by` cascade grubu da siler; kanit yine kalir.
select is(
  (select count(*)::int from public.ugc_reports where id = :'report1'),
  1,
  'kullanici silinince BASKASININ raporu KALIR'
);
select is(
  (select context_group_id_snapshot from public.ugc_reports where id = :'report1'),
  :'grp'::uuid,
  'raporun grup baglami takma-ad snapshot`inda korunur'
);
-- `moderation_audit_events.entity_id` FK'siz uuid'dir (`0106:22`), yani
-- yaptirim cascade ile gitse bile "bu yaptirim verildi" izi PII'siz kalir.
select ok(
  (select count(*) from public.moderation_audit_events
    where entity_type = 'sanction' and entity_id = :'sanction'::uuid) >= 1,
  'yaptirim denetim izi cascade sonrasi YERINDE kalir (FK`siz entity_id)'
);

select * from finish();
rollback;
