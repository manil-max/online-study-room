-- 0136_fire_streak_equals_paused_streak.sql
-- WP-739: Alevli Seri basarimi, alev rozetinin okudugu DURAKLAMALI gunluk
-- seriyle esitlenir; hak edilmis kademeler geriye donuk verilir.
--
-- 🔴 SAHIP KARARI (2026-08-19): "blazing fire basarimi full devamli gunlere
-- bakiyor ama ben onu bizim pause hakki olan gunluk seriye esitlemek
-- istiyorum. yani '7 gun ust uste ulas' degil de '7 gun alevine sahip ol'
-- gibi bir sey olmali. birde buna gore basarimlari da sagla: bende 2/7
-- gosteriyor ama 9 gunluk seriye sahibim, ilkini almam lazim."
--
-- KOK NEDEN. Ayni gecmise iki ayri "seri" tanimi bakiyordu:
--   * `goal_streak_projection` (0112) — alev rozetinin kaynagi. Iki tamamlanan
--     gun arasi fark <= 2 ise seri surer (arada TEK bos gun affedilir).
--   * `_current_fire_streak_days` (0135) — basarim metriginin kaynagi. Ilk
--     eksik gunde durur.
-- Ayrisma yeni degil; `038_progression_matrix.test.sql §6` ve
-- `progression_matrix_wp455_test.dart` bunu ACIK BULGU olarak sabitlemis,
-- "kapatilmasi XP esiklerini degistirir, karar sahibindir" demisti. Karar
-- geldi: kural artik TEK ve `goal_streak_projection` ile birebir ayni.
--
-- HAK KAYBI YOK, HAK IADESI VAR:
--   * Ekranda gorunen ilerleme hala `current` sinifi metriktir ve DUSER.
--   * Odul hakki ise ANLIK degere degil `_best_fire_streak_days`e (gecmisteki
--     en uzun duraklamali seri) bakar. Boylece eski kurala takilip alinamamis
--     kademeler bu migration ile pending odul olarak gelen kutusuna dusar.
--   * Hicbir `xp_ledger` / `achievement_rewards` / `user_achievements` satiri
--     silinmez veya yeniden fiyatlandirilmaz. XP yalniz kullanici "Topla"
--     dediginde bankalanir (0047/0057 akisi degismedi).
--
-- Geri alma (Rollback): `_current_fire_streak_days` govdesini 0135'teki
-- kesintisiz surume dondur, `source_version`i `goal_completion_current_v2`
-- yap, `_project_current_fire_streak` icindeki odul dongusunu kaldir ve
-- `process_achievement_event` govdesini 0057'deki `fire_streak` satirina
-- dondur. Uretilmis pending odulleri SILME (hak edilmis kademe geri alinmaz;
-- `docs/URUN-POLITIKALARI.md §3`). `_best_fire_streak_days` ancak onu cagiran
-- kalmayinca drop edilebilir.

-- ---------------------------------------------------------------------------
-- 1) Guncel seri: alev rozetiyle BIREBIR ayni kural
-- ---------------------------------------------------------------------------
-- `where` yan tumcesi ve kosu (run) mantigi `goal_streak_projection` (0112)
-- govdesinden birebir kopyadir. Kasitli: iki uc arasinda sozlesme testi olmadan
-- yasayan ozellikler oldu (WP-373), bu yuzden `063` her iki fonksiyonu ayni
-- gecmiste okuyup esitligi olcer. 0135'teki `time_zone = 'Europe/Istanbul'`
-- suzgeci KALDIRILDI: projeksiyonda yok, kisisel yazici (0112/0120) zaten
-- Istanbul disinda satir uretmiyor ve suzgecin kalmasi iki tanimi yine
-- ayirabilirdi.
create or replace function public._current_fire_streak_days(
  p_user_id uuid,
  p_as_of_day date default (timezone('Europe/Istanbul', now()))::date
)
returns integer
language sql
security definer
set search_path = public
stable
as $wp739$
  with completed as (
    select distinct e.goal_day
      from public.goal_progress_events e
     where e.scope_type = 'personal'
       and e.scope_id = p_user_id
       and e.event_kind = 'goal_completed'
       and e.goal_day <= p_as_of_day
  ), runs as (
    select
      goal_day,
      -- Iki ardisik bos gun (fark > 2) yeni bir seri baslatir; tek bos gun
      -- (fark = 2) seriyi surdurur.
      sum(
        case when prev_day is null or (goal_day - prev_day) > 2 then 1 else 0 end
      ) over (order by goal_day) as run_id
    from (
      select goal_day, lag(goal_day) over (order by goal_day) as prev_day
        from completed
    ) ordered
  ), summary as (
    select
      (select max(goal_day) from completed) as last_completed_day,
      (
        select count(*)::integer from runs
         where run_id = (select max(run_id) from runs)
      ) as last_run_length
  )
  select case
    when s.last_completed_day is null then 0
    -- Bugun henuz tamamlanmadiysa dunun serisi gun bitene kadar canlidir; bir
    -- gun once de kacirilmissa (fark 2) otomatik grace onu ayakta tutar.
    when (p_as_of_day - s.last_completed_day) <= 2 then s.last_run_length
    else 0
  end
  from summary s;
$wp739$;

revoke all on function public._current_fire_streak_days(uuid, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2) Rekor seri: odul hakkinin dayanagi
-- ---------------------------------------------------------------------------
-- Ekrandaki sayi duser, hak dusmez. Odul bu yuzden gecmisteki EN UZUN
-- duraklamali seriyi okur. Ayni kosu bolmesi; yalniz "sonuncusu" yerine
-- "en uzunu" alinir.
create or replace function public._best_fire_streak_days(
  p_user_id uuid,
  p_as_of_day date default (timezone('Europe/Istanbul', now()))::date
)
returns integer
language sql
security definer
set search_path = public
stable
as $wp739$
  with completed as (
    select distinct e.goal_day
      from public.goal_progress_events e
     where e.scope_type = 'personal'
       and e.scope_id = p_user_id
       and e.event_kind = 'goal_completed'
       and e.goal_day <= p_as_of_day
  ), runs as (
    select
      goal_day,
      sum(
        case when prev_day is null or (goal_day - prev_day) > 2 then 1 else 0 end
      ) over (order by goal_day) as run_id
    from (
      select goal_day, lag(goal_day) over (order by goal_day) as prev_day
        from completed
    ) ordered
  )
  select coalesce(max(run_len), 0)::integer
    from (select count(*)::integer as run_len from runs group by run_id) lengths;
$wp739$;

revoke all on function public._best_fire_streak_days(uuid, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3) Projeksiyon + odul: metrik anlik, odul kalici
-- ---------------------------------------------------------------------------
create or replace function public._project_current_fire_streak(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $wp739$
declare
  v_streak integer;
  v_best integer;
  r record;
begin
  if p_user_id is null then return 0; end if;
  v_streak := public._current_fire_streak_days(p_user_id);
  v_best := public._best_fire_streak_days(p_user_id);

  insert into public.achievement_metric_progress(
    user_id, achievement_id, metric_value, source_version, updated_at
  ) values (
    p_user_id, 'fire_streak', v_streak, 'goal_completion_grace_v3', now()
  )
  on conflict (user_id, achievement_id) do update set
    metric_value = excluded.metric_value,
    source_version = excluded.source_version,
    updated_at = now()
  where public.achievement_metric_progress.metric_value
          is distinct from excluded.metric_value
     or public.achievement_metric_progress.source_version
          is distinct from excluded.source_version;

  -- Hak edilmis kademe `process_achievement_event` cagrisini BEKLEMEZ.
  -- Kullanicinin profili acmasini beklemek, WP-739'un duzeltmek istedigi
  -- "hak ettim ama ekranda yok" halini bir tur daha uzatirdi.
  for r in
    select (tier_def->>'tier')::integer as tier,
           (tier_def->>'threshold')::integer as threshold,
           (tier_def->>'xp')::integer as xp
      from public.achievements_dict d
      cross join lateral jsonb_array_elements(d.tiers) tier_def
     where d.id = 'fire_streak'
     order by (tier_def->>'tier')::integer
  loop
    if coalesce(v_best, 0) >= r.threshold then
      -- Idempotent (0047): bankalanmis ya da zaten pending kademe ikinci kez
      -- olusmaz, ikinci XP yazilmaz.
      perform public._create_pending_achievement_reward(
        p_user_id, 'fire_streak', r.tier, r.xp,
        format('fire_streak best_streak=%s streak_days', coalesce(v_best, 0))
      );
    end if;
  end loop;

  return v_streak;
end;
$wp739$;

revoke all on function public._project_current_fire_streak(uuid)
  from public, anon, authenticated;

update public.achievement_metric_definitions
   set projection_kind = 'current',
       metric_key = 'streak_days',
       source_version = 'goal_completion_grace_v3',
       updated_at = now()
 where achievement_id = 'fire_streak';

-- ---------------------------------------------------------------------------
-- 4) Buyuk RPC: odul dalinda da rekor seri okunur
-- ---------------------------------------------------------------------------
-- 0057 govdesi birebir korunur; TEK degisiklik `fire_streak` satiridir.
-- `_achievement_metrics` (0135 sarmalayicisi) `streak_days`e ANLIK degeri
-- yazmaya devam eder; ekrandaki ilerleme oradan okunur.
create or replace function public.process_achievement_event(p_event_type text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $wp739$
declare
  v_uid uuid := auth.uid();
  v_metrics jsonb;
  v_awarded jsonb := '[]'::jsonb;
  v_def record;
  v_tier jsonb;
  v_progress integer;
  v_threshold integer;
  v_xp integer;
  v_tier_n integer;
  v_unit text;
  v_reward_id uuid;
  v_total_xp integer := 0;
  v_rank text := 'bronze_beginner';
  v_secrets jsonb;
  v_hours integer;
  v_h integer;
  v_hour_key text;
  v_hour_id uuid;
  v_hour_xp_total integer := 0;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_event_type not in (
    'session_completed', 'manual_refresh', 'profile_opened', 'nudge_sent'
  ) then
    raise exception 'unknown event_type: %', p_event_type;
  end if;

  v_metrics := public._achievement_metrics(v_uid);
  v_secrets := v_metrics->'secrets';

  for v_def in
    select * from public.achievements_dict
    where category is distinct from 'system'
      and id is distinct from 'study_hour_xp'
    order by id
  loop
    v_progress := case v_def.id
      when 'marathon_total' then (v_metrics->>'total_hours')::integer
      when 'steel_will' then (v_metrics->>'max_session_minutes')::integer
      when 'day_hero' then (v_metrics->>'max_day_hours')::integer
      -- 🔴 WP-739: odul anlik seriye degil, gecmisteki en uzun duraklamali
      -- seriye bakar. Anlik deger `current` sinifidir ve tatilde sifira duser;
      -- kazanilmis kademeyi geri almak yasak (`docs/URUN-POLITIKALARI.md §3`).
      when 'fire_streak' then public._best_fire_streak_days(v_uid)
      when 'weekend_goal_days' then (v_metrics->>'weekend_goal_days')::integer
      when 'perfect_month' then (v_metrics->>'perfect_months')::integer
      when 'alpha_wolf' then 0
      when 'team_player' then coalesce((v_metrics->>'group_goal_contrib')::integer, 0)
      when 'campfire_hours' then 0
      when 'inspiration' then coalesce((v_metrics->>'nudge_starts')::integer, 0)
      when 'locomotive' then 0
      when 'secret_night_owl' then case when (v_secrets->>'night_owl')::boolean then 1 else 0 end
      when 'secret_dawn' then case when (v_secrets->>'dawn')::boolean then 1 else 0 end
      when 'secret_404' then case when (v_secrets->>'m404')::boolean then 1 else 0 end
      when 'secret_pi' then case when (v_secrets->>'pi')::boolean then 1 else 0 end
      when 'secret_matrix' then case when (v_secrets->>'matrix')::boolean then 1 else 0 end
      when 'secret_nye' then case when (v_secrets->>'nye')::boolean then 1 else 0 end
      when 'secret_last_second' then case when (v_secrets->>'last_second')::boolean then 1 else 0 end
      when 'secret_no_limits' then case when (v_secrets->>'no_limits')::boolean then 1 else 0 end
      when 'secret_break_enemy' then 0
      else 0
    end;

    for v_tier in
      select * from jsonb_array_elements(v_def.tiers)
    loop
      v_tier_n := (v_tier->>'tier')::integer;
      v_threshold := (v_tier->>'threshold')::integer;
      v_xp := (v_tier->>'xp')::integer;
      v_unit := v_tier->>'unit';

      if v_progress >= v_threshold then
        -- Dogrudan XP bankalamaz: inbox'a pending odul yazar (WP-C).
        v_reward_id := public._create_pending_achievement_reward(
          v_uid,
          v_def.id,
          v_tier_n,
          v_xp,
          format('%s progress=%s %s', v_def.id, v_progress, coalesce(v_unit, ''))
        );
        if v_reward_id is not null then
          v_awarded := v_awarded || jsonb_build_array(
            jsonb_build_object(
              'achievement_id', v_def.id,
              'tier', v_tier_n,
              'xp', v_xp,
              'name', v_def.name,
              'is_secret', v_def.is_secret
            )
          );
        end if;
      end if;
    end loop;
  end loop;

  -- Saat XP: her tamamlanan tam saat -> 50 XP (pasif, dogrudan; idempotent).
  v_hours := coalesce((v_metrics->>'total_hours')::integer, 0);
  if v_hours > 0 then
    for v_h in 1..v_hours loop
      v_hour_key := v_uid::text || '|study_hour_xp|h_' || v_h::text;
      insert into public.xp_ledger (
        user_id, achievement_id, tier, xp_amount, reason, event_key
      ) values (
        v_uid,
        'study_hour_xp',
        1,
        50,
        format('Çalışma saati #%s', v_h),
        v_hour_key
      )
      on conflict (event_key) do nothing
      returning id into v_hour_id;
      if v_hour_id is not null then
        v_hour_xp_total := v_hour_xp_total + 50;
        v_hour_id := null;
      end if;
    end loop;
  end if;

  select coalesce(xp, 0), coalesce(crown_rank, 'bronze_beginner')
    into v_total_xp, v_rank
  from public.gamification_profiles
  where user_id = v_uid;

  return jsonb_build_object(
    'event_type', p_event_type,
    'awarded', v_awarded,
    'total_xp', coalesce(v_total_xp, 0),
    'crown_rank', coalesce(v_rank, 'bronze_beginner'),
    'metrics', v_metrics,
    'hour_xp_granted', v_hour_xp_total
  );
end;
$wp739$;

grant execute on function public.process_achievement_event(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Geriye donuk hak iadesi
-- ---------------------------------------------------------------------------
create or replace function public.backfill_wp739_fire_streak()
returns integer
language plpgsql
security definer
set search_path = public
as $wp739$
declare
  v_user uuid;
  v_count integer := 0;
begin
  for v_user in select id from auth.users order by id loop
    -- Metrigi yeni kurala gore yeniden yazar ve hak edilmis kademeleri
    -- gelen kutusuna dusurur; ikisi de idempotent.
    perform public._project_current_fire_streak(v_user);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$wp739$;

revoke all on function public.backfill_wp739_fire_streak()
  from public, anon, authenticated;

do $wp739_backfill$
declare
  v_users integer;
  v_rewards integer;
begin
  v_users := public.backfill_wp739_fire_streak();
  select count(*)::integer into v_rewards
    from public.achievement_rewards
   where achievement_id = 'fire_streak' and status = 'pending';
  raise notice 'WP-739 backfill: % kullanici islendi, % bekleyen Alevli Seri odulu',
    v_users, v_rewards;
end
$wp739_backfill$;

notify pgrst, 'reload schema';
