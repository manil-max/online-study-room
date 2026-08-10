-- 057_goal_events_owner_cleanup.test.sql
-- WP-657 (migration `0131`): hesap ya da grup silinince hedef tamamlama
-- olaylari da gidiyor mu?
--
-- 🔴 Bu dosyanin varlik sebebi olculdu, varsayilmadi: `goal_progress_events`
-- (`0112:27`) hicbir silme yolunda GECMIYOR. `0113`, `0114`, `0124` ve
-- `supabase/functions/purge-accounts/index.ts` tarandi -- tablo adi sifir kez
-- var. Yani `deleteUser` cascade'i buraya HIC ulasmiyordu.
--
-- Iki sey birden olculur ve ikincisi en az birincisi kadar onemlidir:
--   1. silinen sahibin olaylari GIDER,
--   2. `delete from auth.users` HALA CALISIR. Bu depoda hesap silme tam bu
--      sinifta bir kez tamamen bloke olmustu (`0124` / WP-549).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

select plan(16);

-- ===========================================================================
-- KABLO
-- ===========================================================================
select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid = 'public.profiles'::regclass
      and tgname = 'profiles_purge_goal_progress_events'
      and not tgisinternal
  ),
  '0131 kisisel kapsam temizligini profiles silmesine baglar'
);

select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid = 'public.groups'::regclass
      and tgname = 'groups_purge_goal_progress_events'
      and not tgisinternal
  ),
  '0131 grup kapsami temizligini groups silmesine baglar'
);

-- 🔴 Cozumun NEDEN tetikleyici oldugunu semadan sabitler: `scope_id` cok
-- bicimlidir (personal -> auth.users, group -> groups), bu yuzden tabloda
-- yabanci anahtar OLAMAZ. Biri "eksik FK'yi ekleyelim" derse migration apply
-- aninda grup satirlarinda 23503 ile duserdi.
select is(
  (select count(*)::integer from pg_constraint
    where conrelid = 'public.goal_progress_events'::regclass
      and contype = 'f'),
  0,
  'goal_progress_events cok bicimli scope_id tasir: FK ile cozulemez'
);

-- ===========================================================================
-- KURULUM -- olaylar GERCEK oturumlardan uretilir, elle satir yazilmaz
-- ===========================================================================
update public.profiles set daily_goal_minutes = 60
 where id in (:'alpha', :'beta');
update public.groups set daily_goal_minutes = 100 where id = :'grp';

-- Seed oturumlarini 2 saate cikarmak `0120` yazicisini atesler:
--   kisisel 7200 >= 3600 (her iki kullanici icin olay)
--   grup     14400 >= 6000 (grup olayi)
update public.study_sessions
   set duration_seconds = 7200,
       end_time = start_time + interval '2 hours'
 where id in ('30000000-0000-0000-0000-000000000001',
              '30000000-0000-0000-0000-000000000002');

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'beta'
      and event_kind = 'goal_completed'),
  1,
  'kurgu dogru: beta icin kisisel tamamlama olayi var'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'
      and event_kind = 'goal_completed'),
  1,
  'kurgu dogru: grup tamamlama olayi var'
);

-- ===========================================================================
-- 1) HESAP SILME -- once "hala calisiyor mu", sonra "temizliyor mu"
-- ===========================================================================
select lives_ok(
  format($$delete from auth.users where id = %L$$, :'beta'),
  'hedef olayi olan hesap SILINEBILIYOR (yeni tetikleyici bloke etmiyor)'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'beta'),
  0,
  '🔴 silinen hesabin tamamlama olaylari veritabaninda kalmaz'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'),
  1,
  'baska hesabin serisi yanmaz (kapsam scope_id ile daralir)'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'
      and event_kind = 'goal_completed'),
  1,
  'uyenin silinmesi GRUP olayini dusurmez (grup hala var)'
);

-- ===========================================================================
-- 2) GRUP SILME -- purge aktif uyesi kalmayan grubu gercekten siler
--    (`purge-accounts/index.ts:384`)
-- ===========================================================================
delete from public.groups where id = :'grp';

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'),
  0,
  '🔴 silinen grubun tamamlama olaylari veritabaninda kalmaz'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'),
  1,
  'grup silmek kisisel seriyi yakmaz'
);

-- ===========================================================================
-- 3) GECMIS TEMIZLIGI -- 🔴 once BOZUK VERI kurulur
-- ===========================================================================
-- KALITE-PROGRAMI §5.4: taze kurulumda sifir satira dokunan bir goc
-- SINANMAMISTIR. `0131`in DO blogu replay'de bos tabloya bakar. Uretimdeki hal
-- (v58'den beri silinen her hesabin geride biraktigi satir) burada ELDE
-- kuruluyor: tetikleyici kapaliyken silmek, `0131`den ONCEKI davranistir.
alter table public.profiles disable trigger profiles_purge_goal_progress_events;
delete from auth.users where id = :'alpha';
alter table public.profiles enable trigger profiles_purge_goal_progress_events;

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'),
  1,
  '🔴 BOZUK VERI kuruldu: sahibi olmayan tamamlama olayi'
);

select is(
  public.purge_orphan_goal_progress_events(),
  1,
  'temizlik sahipsiz TEK satiri dusurur'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'),
  0,
  'sahipsiz olay temizlikle gider'
);

select is(
  public.purge_orphan_goal_progress_events(),
  0,
  'temizlik idempotent: ikinci kosum hicbir satir dusurmez'
);

-- ===========================================================================
-- Yetki: temizlik istemciye acilmaz (`0120`/`0129` deseni)
-- ===========================================================================
select ok(
  not has_function_privilege(
    'authenticated', 'public.purge_orphan_goal_progress_events()', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public._purge_orphan_goal_progress_events()', 'execute'
  ),
  'sahipsiz olay temizligi istemciye kapali'
);

select * from finish();
rollback;
