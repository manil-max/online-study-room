-- 034_user_task_recurrence_contract.test.sql
-- WP-472: Sabit fazli gorev tekrarinin SUNUCU sozlesmesi.
--
-- Bu dosyanin var olma sebebi: `interval_days`/`anchor_date` dogrulamasi
-- WP-449 ile yalniz istemciye ve `InMemoryUserTaskRepository`ye kondu. Orada
-- yasayan bir kural kuraldir sanilir; oysa cloud yolu `0048`in eski imzasina
-- carpiyordu. Faz hesabi artik sunucuda, dolayisiyla burada kilitlenir.
--
-- Tarih literali elle yazilmaz: gunler `_istanbul_task_day` ile bir kez
-- turetilir, boylece test hangi gun kosarsa kossun ayni fazi olcer. Turetme
-- ayricalikli rolde yapilir: `_istanbul_task_day` `0048`de `authenticated`a
-- KAPALIDIR (`revoke all ... from public`, grant yok) ve testin bu kapiyi
-- gevsetmek icin bir sebebi yoktur.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'

select plan(21);

-- ------------------------------------------------------- sema ve imza tekligi
select has_column('public', 'user_tasks', 'interval_days',
  'user_tasks sabit tekrar araligini tasir');
select has_column('public', 'user_tasks', 'anchor_date',
  'user_tasks sabit faz baslangicini tasir');

-- 🔴 Eski imza yerinde kalsaydi PostgREST adlandirilmis cagriyi cozemez ve
-- saha istemcisi `42725 function is not unique` alirdi. Overload sayisi 1.
select is(
  (select count(*)::int from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'upsert_user_task'),
  1,
  'upsert_user_task tek imzadir (eski 7 parametreli surum dusuruldu)'
);
select is(
  (select count(*)::int from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'set_user_task_completion'),
  1,
  'set_user_task_completion tek imzadir'
);

select
  public._istanbul_task_day(now())::text as today_txt,
  (public._istanbul_task_day(now()) - 1)::text as off_day_txt,
  public._istanbul_task_day(now() + interval '2 days')::text as due_day_txt
\gset

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

-- ------------------------------------------------------------- yazma yolu
-- A: bugun dongu gunu (anchor = bugun, N = 3)
select public.upsert_user_task(
  'aa000000-0000-4000-8000-000000000001', 'Uc gunde bir', null, 'daily', 0, false,
  'bb000000-0000-4000-8000-000000000001',
  3, :'today_txt'::date
);
-- B: bugun dongu DISI (anchor = dun, N = 3 → delta 1)
select public.upsert_user_task(
  'aa000000-0000-4000-8000-000000000002', 'Dongu disi', null, 'daily', 1, false,
  'bb000000-0000-4000-8000-000000000002',
  3, :'off_day_txt'::date
);
-- C: tek seferlik gorev; istemci yanlislikla aralik/faz gonderiyor
select public.upsert_user_task(
  'aa000000-0000-4000-8000-000000000003', 'Tek seferlik', null, 'once', 2, false,
  'bb000000-0000-4000-8000-000000000003',
  7, :'today_txt'::date
);

select is(
  (select interval_days from public.user_tasks
   where id = 'aa000000-0000-4000-8000-000000000001'),
  3,
  'tekrar araligi istemciden geldigi gibi saklanir'
);
select is(
  (select anchor_date from public.user_tasks
   where id = 'aa000000-0000-4000-8000-000000000001'),
  :'today_txt'::date,
  'faz baslangici istemciden geldigi gibi saklanir'
);
-- Tekrar etmeyen gorev faz tasimaz: istemci yanlislikla aralik gonderse bile
-- sunucu normalize eder, yoksa occurrence motoru iki uctan farkli okunur.
select ok(
  (select interval_days = 1 and anchor_date is null from public.user_tasks
   where id = 'aa000000-0000-4000-8000-000000000003'),
  'tek seferlik gorevde aralik/faz sunucuda normalize edilir'
);

select throws_ok(
  $$select public.upsert_user_task(
      'aa000000-0000-4000-8000-000000000004', 'Sifir aralik', null, 'daily', 3,
      false, 'bb000000-0000-4000-8000-000000000004', 0, null)$$,
  'P0001', 'invalid_task_interval_days',
  'sifir aralik reddedilir'
);
select throws_ok(
  $$select public.upsert_user_task(
      'aa000000-0000-4000-8000-000000000004', 'Devasa aralik', null, 'daily', 3,
      false, 'bb000000-0000-4000-8000-000000000004', 366, null)$$,
  'P0001', 'invalid_task_interval_days',
  'ust sinir disi aralik reddedilir'
);

-- Faz gondermeden acilan tekrarli gorev `due_at ?? created_at` gununu alir —
-- istemcideki `taskRecurrenceAnchorDay` ile ayni kural.
select public.upsert_user_task(
  'aa000000-0000-4000-8000-000000000005', 'Fazsiz acilis',
  (now() + interval '2 days'), 'daily', 4, false,
  'bb000000-0000-4000-8000-000000000005', 2, null
);
select is(
  (select anchor_date from public.user_tasks
   where id = 'aa000000-0000-4000-8000-000000000005'),
  :'due_day_txt'::date,
  'faz gonderilmezse due_at gununden turetilir'
);

-- ------------------------------------------------------------- tamamlama yolu
-- psql, dollar-quote edilmis govdenin icinde degisken enterpolasyonu YAPMAZ;
-- gun literalleri bu yuzden disaridan `quote_literal` ile eklenir.
select lives_ok(
  $$select public.set_user_task_completion(
      'aa000000-0000-4000-8000-000000000001', true, now(),
      'cc000000-0000-4000-8000-000000000001', $$
  || quote_literal(:'today_txt') || $$::date)$$,
  'dongu gununde tamamlama kabul edilir'
);
select is(
  (select count(*)::int from public.user_task_completions
   where task_id = 'aa000000-0000-4000-8000-000000000001'),
  1,
  'kabul edilen tamamlama tek satir yazar'
);

select throws_ok(
  $$select public.set_user_task_completion(
      'aa000000-0000-4000-8000-000000000002', true, now(),
      'cc000000-0000-4000-8000-000000000002', $$
  || quote_literal(:'today_txt') || $$::date)$$,
  'P0001', 'task_occurrence_not_scheduled',
  'dongu disi gunde tamamlama reddedilir'
);
select throws_ok(
  $$select public.set_user_task_completion(
      'aa000000-0000-4000-8000-000000000001', true, now(),
      'cc000000-0000-4000-8000-000000000003', $$
  || quote_literal(:'off_day_txt') || $$::date)$$,
  'P0001', 'task_occurrence_day_mismatch',
  'olayin gunuyle uyusmayan occurrence gunu reddedilir'
);

-- 🔴 Tekrar teslim: cevrimdisi kuyruk ayni komutu birden cok kez gonderir.
-- Ayni mutasyon sessizce mevcut satiri dondurur; farkli mutasyon ham `23505`
-- yerine adlandirilmis hata verir (`InMemoryUserTaskRepository` ile ayni).
select lives_ok(
  $$select public.set_user_task_completion(
      'aa000000-0000-4000-8000-000000000001', true, now(),
      'cc000000-0000-4000-8000-000000000001', $$
  || quote_literal(:'today_txt') || $$::date)$$,
  'ayni komut kimliginin tekrari hata vermez'
);
select is(
  (select count(*)::int from public.user_task_completions
   where task_id = 'aa000000-0000-4000-8000-000000000001'),
  1,
  'tekrar teslim ikinci satir uretmez'
);
select throws_ok(
  $$select public.set_user_task_completion(
      'aa000000-0000-4000-8000-000000000001', false, now(),
      'cc000000-0000-4000-8000-000000000001', $$
  || quote_literal(:'today_txt') || $$::date)$$,
  'P0001', 'task_operation_conflict',
  'ayni komut kimligi farkli mutasyonla geri gelemez'
);

-- 🔴 Saha uyumu: v56 istemcisi `p_occurrence_day` GONDERMEZ. Varsayilan yol
-- olayin Istanbul gununu kullanir; bu iddia dusmeden surum cikarilamaz.
select lives_ok(
  $$select public.set_user_task_completion(
      'aa000000-0000-4000-8000-000000000003', true, now(),
      'cc000000-0000-4000-8000-000000000004')$$,
  'v56 istemcisi occurrence gunu gondermeden tamamlayabilir'
);

-- --------------------------------------------------------------- okuma yolu
select is(
  (select interval_days from public.list_user_tasks()
   where id = 'aa000000-0000-4000-8000-000000000001'),
  3,
  'list_user_tasks tekrar araligini dondurur'
);
select is(
  (select anchor_date from public.list_user_tasks()
   where id = 'aa000000-0000-4000-8000-000000000001'),
  :'today_txt'::date,
  'list_user_tasks fazi dondurur'
);

-- 🔴 Sozlesmenin kalbi: completion fazi KAYDIRMAZ. Tamamlama yapildiktan ve
-- ustune faz gondermeyen bir baslik guncellemesi geldikten sonra bile anchor
-- ayni gun kalmali.
select public.upsert_user_task(
  'aa000000-0000-4000-8000-000000000001', 'Baslik degisti', null, 'daily', 0,
  false, 'bb000000-0000-4000-8000-000000000006', 3, null
);
select is(
  (select anchor_date from public.user_tasks
   where id = 'aa000000-0000-4000-8000-000000000001'),
  :'today_txt'::date,
  'tamamlama ve fazsiz guncelleme dongunun fazini kaydirmaz'
);

reset role;
select * from finish();
rollback;
