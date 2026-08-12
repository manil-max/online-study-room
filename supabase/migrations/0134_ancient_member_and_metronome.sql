-- 0134_ancient_member_and_metronome.sql
-- WP-721 — iki yeni basarim: "Kadim Uye" (uyelik suresi) ve "Metronom"
-- (haftalik ritim).
--
-- KADIM UYE (ancient_member) — kaynak: `group_members.joined_at`.
--   Deger = TEK bir gruptaki en uzun uyelik (gun). Gruplar TOPLANMAZ;
--   "ayni grupta gecirilen gun" oldugu icin satir basina hesaplanip `max`
--   alinir. Ayrilmis uyelikte sure `left_at`te durur.
--
--   🔴 Yeniden katilma karari: `join_group` (0012) ayni satiri gunceller ve
--   `joined_at = now()` yazar. Ham deger boylece SIFIRLANIR. Uc yil uye olup
--   bir gun ayrilan kullanicinin rozetini geri almak kabul edilemez, bu yuzden
--   projeksiyon `greatest(mevcut, yeni)` ile yazilir: sayac sifirlanmaz,
--   TARIHTEKI EN UZUN uyelik korunur. Bu, `achievement_metric_progress`
--   sozlesmesindeki `cumulative` turuyle de birebir ayni davranistir.
--
-- METRONOM (metronome) — kaynak: `goal_progress_events` (`goal_completed`).
--   Deger = haftada EN AZ 5 hedef gunu tutturulan ARDISIK haftalarin en uzun
--   serisi (ISO pazartesi sinirinda).
--
--   🔴 Tasarim amaci: bu, gunluk serinin (`fire_streak`) SAGLIKLI
--   ALTERNATIFIDIR. Bir hafta icinde iki gun kacirmak zinciri KIRMAZ; 7 gunun
--   5'i yeter. Zincir yalniz bir hafta 5 gunun ALTINA dustugunde kopar. Gunluk
--   seri mantigini haftaya kopyalamak (her gunu sart kosmak) basarimi anlamsiz
--   kilardi. Istemci esi: `metronomeWeekChain` (achievement_ledger_engine.dart).
--
-- GERIYE DOLDURMA. Iki metrik de mevcut kullanicilar icin gecmise donuk
-- hesaplanir; aksi halde iki yildir calisan kullanici sifirdan baslardi.
-- Backfill `where ... is null` gibi bir kalintiya DEGIL, dogrudan kaynak
-- tablolara bakar (`group_members`, `goal_progress_events`), yani tazede sifir
-- satira dokunup yesil yanan bir ifade degildir. Yine de bos bir veritabaninda
-- hicbir sey KANITLAMAZ; davranis kaniti `supabase/tests/061_*_wp721.test.sql`
-- icindeki DOLU fiksturdedir.
--
-- Odul yolu: `process_achievement_event` (0057) ilerlemeyi sabit bir `case
-- v_def.id` listesinden okur ve bilmedigi kimlige `0` verir. Bu iki basarim,
-- `alpha_wolf_weekly` (0062) ile ayni desende KENDI projeksiyonundan
-- `_create_pending_achievement_reward` cagirir; buyuk RPC'nin govdesi
-- degistirilmez.
--
-- Geri alma (Rollback):
--   drop function if exists public.backfill_wp721_metrics();
--   drop function if exists public.project_wp721_metrics(uuid);
--   drop function if exists public._metronome_week_chain(uuid);
--   drop function if exists public._ancient_member_days(uuid);
--   `_achievement_metrics(uuid)` govdesini 0116'daki haline `create or replace`
--   ile dondur. Uretilmis `achievement_metric_progress` satirlari ve pending
--   oduller SILINMEZ (kazanilmis kademe geri alinmaz);
--   `achievement_metric_definitions` / `achievements_dict` satirlari kalabilir,
--   sozluk disinda kalan kimlik istemcide gorunmez.

-- ---------------------------------------------------------------------------
-- 1) Sozluk
-- ---------------------------------------------------------------------------
insert into public.achievements_dict
  (id, category, name, description, max_tier, icon_key, is_secret, tiers)
values
  (
    'ancient_member', 'group', 'Kadim Uye',
    'Ayni grupta uye olarak gecirilen gun',
    4, 'history', false,
    '[{"tier":1,"threshold":30,"unit":"membership_days","xp":500},{"tier":2,"threshold":100,"unit":"membership_days","xp":1500},{"tier":3,"threshold":365,"unit":"membership_days","xp":5000},{"tier":4,"threshold":730,"unit":"membership_days","xp":12000}]'::jsonb
  ),
  (
    'metronome', 'streak', 'Metronom',
    'Haftada en az 5 gun hedef tutturulan ust uste hafta',
    4, 'graphic_eq', false,
    '[{"tier":1,"threshold":4,"unit":"metronome_weeks","xp":1000},{"tier":2,"threshold":12,"unit":"metronome_weeks","xp":3000},{"tier":3,"threshold":26,"unit":"metronome_weeks","xp":8000},{"tier":4,"threshold":52,"unit":"metronome_weeks","xp":20000}]'::jsonb
  )
on conflict (id) do update set
  category = excluded.category,
  name = excluded.name,
  description = excluded.description,
  max_tier = excluded.max_tier,
  icon_key = excluded.icon_key,
  is_secret = excluded.is_secret,
  tiers = excluded.tiers;

-- Metrik sozlesmesi. Ikisi de `cumulative`: `_project_achievement_metrics`
-- (0050) bu iki `metric_key`i bilmez ve her calismada 0 uretir; `cumulative`
-- dali `greatest(mevcut, 0)` yazdigi icin bu 0 hicbir degeri DUSUREMEZ.
-- Gercek degeri asagidaki `project_wp721_metrics` yazar.
insert into public.achievement_metric_definitions
  (achievement_id, metric_key, projection_kind, source_version)
values
  ('ancient_member', 'ancient_member_days', 'cumulative', 'membership_tenure_v1'),
  ('metronome', 'metronome_weeks', 'cumulative', 'weekly_cadence_v1')
on conflict (achievement_id) do update set
  metric_key = excluded.metric_key,
  projection_kind = excluded.projection_kind,
  source_version = excluded.source_version,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- 2) Metrikler
-- ---------------------------------------------------------------------------

-- Tek gruptaki en uzun uyelik (gun). `group_members` birincil anahtari
-- (group_id, user_id) oldugu icin grup basina tek satir vardir.
create or replace function public._ancient_member_days(p_user_id uuid)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    max(
      floor(
        extract(epoch from (coalesce(gm.left_at, now()) - gm.joined_at)) / 86400
      )
    ),
    0
  )::integer
  from public.group_members gm
  where gm.user_id = p_user_id
    and gm.joined_at is not null
    and coalesce(gm.left_at, now()) > gm.joined_at;
$$;

revoke all on function public._ancient_member_days(uuid)
  from public, anon, authenticated;

-- Haftada >= 5 hedef gunu tutturulan ardisik haftalarin EN UZUN serisi.
--
-- 🔴 `5` bu basarimin tasarim sabitidir: haftanin 7 gununden 5'i. Bunu 6 veya 7
-- yapmak Metronom'u gunluk serinin kopyasi haline getirir.
create or replace function public._metronome_week_chain(p_user_id uuid)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  with weeks as (
    select
      date_trunc('week', e.goal_day)::date as week_start,
      count(distinct e.goal_day) as goal_days
    from public.goal_progress_events e
    where e.scope_type = 'personal'
      and e.scope_id = p_user_id
      and e.event_kind = 'goal_completed'
    group by 1
  ), qualifying as (
    -- Haftada iki gun kacirmak (5/7) yeterlidir; zincir KIRILMAZ.
    select week_start from weeks where goal_days >= 5
  ), runs as (
    select
      week_start,
      sum(
        case when prev_week is null or (week_start - prev_week) > 7 then 1 else 0 end
      ) over (order by week_start) as run_id
    from (
      select week_start, lag(week_start) over (order by week_start) as prev_week
      from qualifying
    ) ordered
  )
  select coalesce(max(chain), 0)::integer
  from (select count(*) as chain from runs group by run_id) chains;
$$;

revoke all on function public._metronome_week_chain(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3) Projeksiyon + odul
-- ---------------------------------------------------------------------------
create or replace function public.project_wp721_metrics(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_days integer;
  v_weeks integer;
  v_stored_days bigint;
  v_stored_weeks bigint;
  r record;
  v_progress bigint;
begin
  if p_user_id is null then
    raise exception 'user required';
  end if;

  v_days := public._ancient_member_days(p_user_id);
  v_weeks := public._metronome_week_chain(p_user_id);

  insert into public.achievement_metric_progress (
    user_id, achievement_id, metric_value, source_version, updated_at
  ) values
    (p_user_id, 'ancient_member', greatest(v_days, 0), 'membership_tenure_v1', now()),
    (p_user_id, 'metronome', greatest(v_weeks, 0), 'weekly_cadence_v1', now())
  on conflict (user_id, achievement_id) do update set
    -- `greatest`: gruptan cikip yeniden katilan kullanicinin sayaci sifirlanmaz
    -- ve bir hafta ritim kacirmak kazanilmis kademeyi geri almaz.
    metric_value = greatest(
      public.achievement_metric_progress.metric_value,
      excluded.metric_value
    ),
    source_version = excluded.source_version,
    updated_at = now();

  -- Odul, ANLIK degere degil DEFTERDEKI (monoton) degere gore verilir.
  select metric_value into v_stored_days
  from public.achievement_metric_progress
  where user_id = p_user_id and achievement_id = 'ancient_member';
  select metric_value into v_stored_weeks
  from public.achievement_metric_progress
  where user_id = p_user_id and achievement_id = 'metronome';

  for r in
    select d.id as achievement_id,
      (tier_def->>'tier')::integer as tier,
      (tier_def->>'threshold')::integer as threshold,
      (tier_def->>'xp')::integer as xp
    from public.achievements_dict d
    cross join lateral jsonb_array_elements(d.tiers) tier_def
    where d.id in ('ancient_member', 'metronome')
    order by d.id, (tier_def->>'tier')::integer
  loop
    v_progress := case r.achievement_id
      when 'ancient_member' then coalesce(v_stored_days, 0)
      else coalesce(v_stored_weeks, 0)
    end;
    if v_progress >= r.threshold then
      -- Idempotent: ayni kademe icin ikinci pending olusmaz (0047).
      perform public._create_pending_achievement_reward(
        p_user_id, r.achievement_id, r.tier, r.xp,
        format('%s progress=%s', r.achievement_id, v_progress)
      );
    end if;
  end loop;

  return jsonb_build_object(
    'ancient_member_days', coalesce(v_stored_days, 0),
    'metronome_weeks', coalesce(v_stored_weeks, 0)
  );
end;
$$;

revoke all on function public.project_wp721_metrics(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4) Canli hat: her `process_achievement_event` turunda yeniden hesaplanir
-- ---------------------------------------------------------------------------
-- 0116 sarmalayicisinin govdesi birebir korunur; yalniz WP-721 blogu eklendi.
-- Sira onemli: `_project_achievement_metrics` ONCE calisir (bilmedigi iki
-- metrige 0 yazma denemesi `cumulative` dalinda etkisizdir), sonra gercek
-- degerler yazilir.
create or replace function public._achievement_metrics(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_metrics jsonb;
  v_perfect_months integer;
  v_converted_nudges integer;
  v_wp721 jsonb;
begin
  v_metrics := public._achievement_metrics_legacy_v1(p_user_id);

  v_perfect_months := public._count_perfect_months_28(p_user_id);
  v_metrics := jsonb_set(
    v_metrics,
    '{perfect_months}',
    to_jsonb(coalesce(v_perfect_months, 0)),
    true
  );

  v_converted_nudges := public._count_converted_nudges(p_user_id);
  v_metrics := jsonb_set(
    v_metrics,
    '{nudge_starts}',
    to_jsonb(coalesce(v_converted_nudges, 0)),
    true
  );

  perform public._project_achievement_metrics(p_user_id, v_metrics);

  v_wp721 := public.project_wp721_metrics(p_user_id);
  v_metrics := jsonb_set(
    v_metrics, '{ancient_member_days}', v_wp721->'ancient_member_days', true
  );
  v_metrics := jsonb_set(
    v_metrics, '{metronome_weeks}', v_wp721->'metronome_weeks', true
  );

  return v_metrics;
end;
$$;

revoke all on function public._achievement_metrics(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) Geriye doldurma
-- ---------------------------------------------------------------------------
-- Hedef secimi kisiye degil DURUMA bakar: uyeligi ya da hedef tamamlama olayi
-- olan herkes. Iki kaynak tablo da dogrudan taranir.
create or replace function public.backfill_wp721_metrics()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_count integer := 0;
begin
  for v_user in
    select distinct u.id
    from auth.users u
    where exists (
        select 1 from public.group_members gm
        where gm.user_id = u.id and gm.joined_at is not null
      )
      or exists (
        select 1 from public.goal_progress_events e
        where e.scope_type = 'personal'
          and e.scope_id = u.id
          and e.event_kind = 'goal_completed'
      )
    order by u.id
  loop
    perform public.project_wp721_metrics(v_user);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.backfill_wp721_metrics()
  from public, anon, authenticated;

do $wp721$
declare
  v_users integer;
  v_drift integer;
begin
  v_users := public.backfill_wp721_metrics();
  raise notice 'WP-721 backfill: % kullanici islendi', v_users;

  -- 🔴 GOC KENDINI DOGRULAR (0127 deseni). Uyeligi olan her kullanicinin
  -- defterdeki degeri, ham uyelik suresinden KUCUK olamaz. Bos bir
  -- veritabaninda bu sorgu sifir satir gorur ve hicbir sey kanitlamaz --
  -- davranis kaniti dolu fiksturlu pgTAP testindedir (`057_..._wp721`).
  select count(*) into v_drift
  from (
    select gm.user_id, public._ancient_member_days(gm.user_id) as raw_days
    from public.group_members gm
    join auth.users u on u.id = gm.user_id
    group by gm.user_id
  ) src
  left join public.achievement_metric_progress p
    on p.user_id = src.user_id and p.achievement_id = 'ancient_member'
  where coalesce(p.metric_value, 0) < src.raw_days;

  if v_drift > 0 then
    raise exception
      'WP-721 backfill dogrulamasi BASARISIZ: % kullanicinin uyelik metrigi '
      'ham uyelik suresinin altinda', v_drift;
  end if;

  select count(*) into v_drift
  from (
    select e.scope_id as user_id,
      public._metronome_week_chain(e.scope_id) as raw_weeks
    from public.goal_progress_events e
    where e.scope_type = 'personal' and e.event_kind = 'goal_completed'
    group by e.scope_id
  ) src
  join auth.users u on u.id = src.user_id
  left join public.achievement_metric_progress p
    on p.user_id = src.user_id and p.achievement_id = 'metronome'
  where coalesce(p.metric_value, 0) < src.raw_weeks;

  if v_drift > 0 then
    raise exception
      'WP-721 backfill dogrulamasi BASARISIZ: % kullanicinin metronom metrigi '
      'ham zincirin altinda', v_drift;
  end if;
end
$wp721$;

notify pgrst, 'reload schema';
