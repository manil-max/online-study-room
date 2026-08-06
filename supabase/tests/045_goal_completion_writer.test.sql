-- 045_goal_completion_writer.test.sql
-- WP-492: hedef tamamlamasinin YAZMA ucu (migration 0120).
--
-- 🔴 Bu dosyanin varlik sebebi: `037` projeksiyonu dogruluyor ama olaylari
-- ELLE insert ederek. "Bu RPC'yi uretimde kim cagiriyor?" sorusunu hicbir test
-- sormadigi icin seri motoru aylarca yazicisiz kaldi (rapor T02). Buradaki her
-- iddia olayi bir `study_sessions` yazimindan ya da backfill'den uretir; hicbir
-- yerde `goal_progress_events`'e elle satir eklenmez.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

select plan(20);

-- Fixture: alpha ve beta bugun 1'er saat calisti (base_seed).
-- Hedefleri olcelebilir yapalim: alpha 120 dk, grup 300 dk.
update public.profiles set daily_goal_minutes = 120 where id = :'alpha';
update public.groups set daily_goal_minutes = 300 where id = :'grp';

select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid = 'public.study_sessions'::regclass
      and tgname = 'study_sessions_project_goal_completion'
      and not tgisinternal
  ),
  '0120 oturum yazimina tamamlama tetikleyicisi baglar'
);

-- Yazilan olayin ekrana ulasmasi realtime yayinina baglidir; istemci
-- (`SupabaseGoalStreakRepository.watchProjection`) bu tabloyu dinliyor.
select ok(
  exists(
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'goal_progress_events'
  ),
  '0120 tamamlama olaylarini realtime yayinina ekler'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where event_kind = 'goal_completed'),
  0,
  'baslangicta hicbir tamamlama olayi yok (1 saat < 120 dk hedef)'
);

-- ===========================================================================
-- Hedefi GECMEYEN gun olay uretmez
-- ===========================================================================
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  '30000000-0000-0000-0000-000000000101'::uuid,
  :'alpha'::uuid,
  b.base + interval '10 hours',
  b.base + interval '10 hours 30 minutes',
  1800,
  'manual'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b;

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'),
  0,
  '5400 sn < 7200 sn hedef: olay yazilmaz'
);

-- ===========================================================================
-- Hedefi GECEN gun tam olarak 1 olay uretir
-- ===========================================================================
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  '30000000-0000-0000-0000-000000000102'::uuid,
  :'alpha'::uuid,
  b.base + interval '11 hours',
  b.base + interval '11 hours 45 minutes',
  2700,
  'live'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b;

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'),
  1,
  'hedef gecildiginde olay sunucudan yazilir'
);

-- Ayni gunun ucuncu oturumu ikinci bir satir uretmemeli.
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  '30000000-0000-0000-0000-000000000103'::uuid,
  :'alpha'::uuid,
  b.base + interval '13 hours',
  b.base + interval '13 hours 10 minutes',
  600,
  'live'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b;

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'),
  1,
  'ayni gun ikinci kez yazilmaz (sema kisiti + erken cikis)'
);

-- ===========================================================================
-- Grup kapsami ayni yoldan beslenir (V57-N05)
-- ===========================================================================
-- Grup toplami su an alpha 8700 + beta 3600 = 12300 sn < 18000 sn.
select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'
      and event_kind = 'goal_completed'),
  0,
  'grup hedefi henuz tutmadi: grup olayi yok'
);

insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  '30000000-0000-0000-0000-000000000104'::uuid,
  :'beta'::uuid,
  b.base + interval '14 hours',
  b.base + interval '15 hours 40 minutes',
  6000,
  'live'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b;

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'
      and event_kind = 'goal_completed'),
  1,
  'grup toplami hedefi gecince grup olayi yazilir'
);

-- Beta'nin kendi hedefi (360 dk) tutmadi: kapsamlar birbirini beslemez.
select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'beta'
      and event_kind = 'goal_completed'),
  0,
  'grup tamamlamasi kisisel seriyi ilerletmez'
);

-- ===========================================================================
-- Backfill: tetikleyiciden ONCEKI gecmis
-- ===========================================================================
-- Uretimdeki gercek durum budur: v58'e kadar tetikleyici yoktu, gecmis
-- oturumlarin tamamlamasi hic yazilmadi. Tetikleyiciyi kapatarak o tarihsel
-- durumu birebir kuruyoruz.
alter table public.study_sessions disable trigger study_sessions_project_goal_completion;
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  '30000000-0000-0000-0000-000000000105'::uuid,
  :'alpha'::uuid,
  b.base - interval '2 days' + interval '9 hours',
  b.base - interval '2 days' + interval '11 hours 5 minutes',
  7500,
  'live'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b;
alter table public.study_sessions enable trigger study_sessions_project_goal_completion;

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date - 2),
  0,
  'tetikleyici kapaliyken yazilan gecmis olaysizdir'
);

select ok(
  public.backfill_goal_completions() >= 1,
  'backfill gecmis gunun tamamlamasini uretir'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date - 2),
  1,
  'backfill sonrasi gecmis gun tam olarak 1 olay tasir'
);

-- Idempotens: ikinci kosum hicbir yeni satir uretmemeli.
select is(
  public.backfill_goal_completions(),
  0,
  'backfill idempotent: ikinci kosum yeni satir yazmaz'
);

-- ===========================================================================
-- Uctan uca: yazici -> projeksiyon (seri artik gercekten ilerliyor)
-- ===========================================================================
-- alpha: 2 gun once tamam, dun bos, bugun tamam. V57-N04 kurali geregi tek
-- kacirma seriyi kirmaz.
select is(
  (select current_streak from public.goal_streak_projection(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date)),
  2,
  'yazicidan gelen olaylar seriyi 2 yapar (tek kacirma korunur)'
);

select is(
  (select state from public.goal_streak_projection(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date)),
  'completed_today',
  'bugunun hedefi tutmus: Durum 3 (renkli alev)'
);

-- V57-N04 Durum 2 (duraklatma): iki gun sonra bakildiginda seri hala yasiyor
-- ama risk altinda. Bu ayrim yazicidan uretilmis gercek olaylarla dogrulanir.
select is(
  (select state from public.goal_streak_projection(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date + 2)),
  'at_risk',
  'iki gun sonra durum duraklatma (Durum 2)'
);

select is(
  (select current_streak from public.goal_streak_projection(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date + 2)),
  2,
  'duraklatmada seri sifirlanmaz'
);

-- ===========================================================================
-- Yazma yolu istemciye acilmadi (0112 tasarim karari korunur)
-- ===========================================================================
select ok(
  not has_function_privilege(
    'authenticated', 'public._record_goal_completion(text,uuid,date)', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public.backfill_goal_completions()', 'execute'
  ),
  'ic yazici ve backfill istemciye kapali'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

select throws_ok(
  format(
    $$select public.record_goal_completion('personal', %L, %L)$$,
    :'beta', (now() at time zone 'Europe/Istanbul')::date
  ),
  'P0001',
  'goal_scope_forbidden',
  'RPC baskasinin kisisel kapsamina yazamaz (0112 sozlesmesi korunur)'
);

select is(
  (select public.record_goal_completion(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date)),
  true,
  'RPC kendi kapsaminda hedef tutmussa true doner'
);

reset role;

select * from finish();
rollback;
