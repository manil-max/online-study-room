-- 055_goal_completion_retraction.test.sql
-- WP-641 (migration `0129`): calisma kaydi silinince GUNLUK SERI geri gider mi?
--
-- 🔴 Bu dosyanin varlik sebebi: `045` yazma yolunu uctan uca olcuyor ama
-- yalnizca EKLEME yonunde. "Oturum silinince ne oluyor?" sorusunu hicbir pgTAP
-- dosyasi sormamisti; `0120:249` tetikleyicisi `after insert or update`
-- diyordu ve DELETE listede yoktu. Sonuc uretimde gorundu: sahip 6 saatlik
-- kaydi silince XP geri gitti (`0126`), seri gitmedi.
--
-- Her iddia gercek `study_sessions` yazimindan/silinmesinden uretilir; hicbir
-- yerde `goal_progress_events`'e elle satir eklenmez (`045` deseni).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

select plan(22);

-- alpha hedefi 120 dk, grup hedefi 300 dk. base_seed bugun her ikisine de
-- 1'er saat verir.
update public.profiles set daily_goal_minutes = 120 where id = :'alpha';
update public.groups set daily_goal_minutes = 300 where id = :'grp';

-- ===========================================================================
-- Tetikleyici KABLOSU
-- ===========================================================================
select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid = 'public.study_sessions'::regclass
      and tgname = 'study_sessions_retract_goal_completion_del'
      and not tgisinternal
  ),
  '0129 silme yoluna geri alma tetikleyicisi baglar'
);

select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid = 'public.study_sessions'::regclass
      and tgname = 'study_sessions_retract_goal_completion_upd'
      and not tgisinternal
  ),
  '0129 guncelleme yoluna geri alma tetikleyicisi baglar'
);

-- Ifade seviyesi sart: 300 oturumu tek komutla silen kullanicida 300 kez tam
-- hesap kosmamali (`tgtype` bit 0 = FOR EACH ROW).
select ok(
  (select (tgtype::integer & 1) = 0 from pg_trigger
    where tgrelid = 'public.study_sessions'::regclass
      and tgname = 'study_sessions_retract_goal_completion_del'),
  'geri alma tetikleyicisi SATIR degil IFADE seviyesindedir'
);

-- ===========================================================================
-- KURULUM -- sahibin vakasi: hedefi tutturan 6 saatlik tek kayit
-- ===========================================================================
-- S1: bugun 6 saat  -> gun toplami 3600 + 21600 = 25200 >= 7200 (hedef)
-- S2: 2 gun once 2 saat -> 7200 >= 7200
-- S3: 2 gun once 1 saat -> ayni gun, olay zaten var
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  '30000000-0000-0000-0000-000000000201'::uuid, :'alpha'::uuid,
  b.base + interval '10 hours', b.base + interval '16 hours', 21600, 'manual'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b
union all
select
  '30000000-0000-0000-0000-000000000202'::uuid, :'alpha'::uuid,
  b.base - interval '2 days' + interval '9 hours',
  b.base - interval '2 days' + interval '11 hours', 7200, 'live'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b
union all
select
  '30000000-0000-0000-0000-000000000203'::uuid, :'alpha'::uuid,
  b.base - interval '2 days' + interval '13 hours',
  b.base - interval '2 days' + interval '14 hours', 3600, 'live'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b;

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'),
  2,
  'kurgu dogru: iki gun icin tamamlama olayi yazildi'
);

-- Grup toplami bugun 25200 + 3600 = 28800 >= 18000.
select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date),
  1,
  'kurgu dogru: grup hedefi de bugun tuttu'
);

select is(
  (select current_streak from public.goal_streak_projection(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date)),
  2,
  'silmeden once KULLANICININ GORDUGU seri 2'
);

select is(
  (select state from public.goal_streak_projection(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date)),
  'completed_today',
  'silmeden once alev bugun yaniyor'
);

-- ===========================================================================
-- 🔴 ASIL IDDIA: 6 saatlik kayit silinince seri AZALIR
-- ===========================================================================
delete from public.study_sessions
 where id = '30000000-0000-0000-0000-000000000201';

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date),
  0,
  'kayit silinince BUGUNUN tamamlama olayi dusurulur'
);

select is(
  (select current_streak from public.goal_streak_projection(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date)),
  1,
  '🔴 sahibin vakasi: seri 2 -> 1 geri gider'
);

select is(
  (select state from public.goal_streak_projection(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date)),
  'at_risk',
  'alev "bugun tamam" durumundan cikar'
);

-- Grup kapsami ayni yoldan geri gider: 3600 + 3600 = 7200 < 18000.
select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'group' and scope_id = :'grp'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date),
  0,
  'grup tamamlamasi da geri alinir (kapsamlar simetrik)'
);

-- Gecmis gun DOKUNULMADAN durur: hedefi hala tutuyor.
select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date - 2),
  1,
  'hedefi hala tutan gun dokunulmadan kalir'
);

-- ===========================================================================
-- ASIRI SILME OLCUSU: gun hedefi hala tutuyorsa olay DUSMEZ
-- ===========================================================================
-- 2 gun once 7200 + 3600 = 10800. 1 saatlik kaydi silince 7200 kalir = hedef.
delete from public.study_sessions
 where id = '30000000-0000-0000-0000-000000000203';

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date - 2),
  1,
  'hedefin ustunde kalan gun silme sonrasi da tamamlanmis sayilir'
);

-- ===========================================================================
-- GUNCELLEME yolu: sureyi kisaltmak da geri alir
-- ===========================================================================
-- `0120:249` UPDATE'i dinliyordu ama yalnizca EKLIYORDU; ayni bosluk.
update public.study_sessions
   set duration_seconds = 3600,
       end_time = start_time + interval '1 hour'
 where id = '30000000-0000-0000-0000-000000000202';

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date - 2),
  0,
  'sure kisaltilinca o gunun tamamlamasi geri alinir'
);

select is(
  (select current_streak from public.goal_streak_projection(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date)),
  0,
  'son tamamlama da dusunce seri 0 olur'
);

-- ===========================================================================
-- GECMIS ONARIMI -- 🔴 once BOZUK VERI kurulur
-- ===========================================================================
-- KALITE-PROGRAMI §5.4: taze kurulumda sifir satira dokunan bir goc
-- SINANMAMISTIR. `0129`un onarim DO blogu replay'de bos tabloya bakar. Bu
-- yuzden uretimdeki bozuk hal ELDE kuruluyor: geri alma tetikleyicisi kapaliyken
-- silmek, tam olarak `0129`dan ONCEKI davranistir.
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  '30000000-0000-0000-0000-000000000204'::uuid, :'alpha'::uuid,
  b.base - interval '4 days' + interval '9 hours',
  b.base - interval '4 days' + interval '12 hours', 10800, 'manual'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b
union all
select
  '30000000-0000-0000-0000-000000000205'::uuid, :'alpha'::uuid,
  b.base - interval '2 days' + interval '15 hours',
  b.base - interval '2 days' + interval '17 hours', 7200, 'live'
from (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b;

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'),
  2,
  'onarim kurgusu: 4 gun once ve 2 gun once tamamlama var'
);

alter table public.study_sessions
  disable trigger study_sessions_retract_goal_completion_del;
delete from public.study_sessions
 where id = '30000000-0000-0000-0000-000000000204';
alter table public.study_sessions
  enable trigger study_sessions_retract_goal_completion_del;

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date - 4),
  1,
  '🔴 BOZUK VERI kuruldu: arkasinda tek saniye kalmayan tamamlama olayi'
);

-- Hedefin SONRADAN yukseltilmesi: onarim gecmisi bugunku hedefle YARGILAMAMALI.
-- 2 gun once 7200 sn var; yeni hedef 36000 sn. Genis olcut bu satiri silerdi.
update public.profiles set daily_goal_minutes = 600 where id = :'alpha';

select is(
  public.repair_orphan_goal_completions(),
  1,
  'onarim yalnizca dayanaksiz TEK satiri dusurur'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date - 4),
  0,
  'dayanaksiz olay onarimla gider'
);

select is(
  (select count(*)::integer from public.goal_progress_events
    where scope_type = 'personal' and scope_id = :'alpha'
      and event_kind = 'goal_completed'
      and goal_day = (now() at time zone 'Europe/Istanbul')::date - 2),
  1,
  'hedef sonradan yukselse de calisilmis gunun serisi YANMAZ'
);

select is(
  public.repair_orphan_goal_completions(),
  0,
  'onarim idempotent: ikinci kosum hicbir satir dusurmez'
);

-- ===========================================================================
-- Yetki: onarim istemciye acilmaz (`0120` deseni)
-- ===========================================================================
select ok(
  not has_function_privilege(
    'authenticated', 'public.repair_orphan_goal_completions()', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public._repair_orphan_goal_completions()', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public._retract_goal_completion(text,uuid,date)', 'execute'
  ),
  'geri alma ve onarim istemciye kapali'
);

select * from finish();
rollback;
