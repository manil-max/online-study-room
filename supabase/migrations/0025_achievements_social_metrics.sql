-- =====================================================================
-- 0025_achievements_social_metrics.sql — WP polish (Grok)
-- inspiration (nudge gönderim sayısı) + team_player (grup günlük katkı günü)
-- _achievement_metrics çıktısına eklenir; process_achievement_event kullanır.
-- Geri alma: 0024 metrik fonksiyonuna dön / bu alanları 0 say.
-- =====================================================================

create or replace function public._achievement_metrics(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_goal_minutes integer;
  v_total_seconds bigint;
  v_max_session_minutes integer;
  v_max_day_hours integer := 0;
  v_streak integer := 0;
  v_weekend_goal_days integer := 0;
  v_perfect_months integer := 0;
  v_nudge_starts integer := 0;
  v_group_goal_days integer := 0;
  v_secret_night boolean := false;
  v_secret_dawn boolean := false;
  v_secret_404 boolean := false;
  v_secret_pi boolean := false;
  v_secret_matrix boolean := false;
  v_secret_1337 boolean := false;
  v_secret_nye boolean := false;
  v_secret_last_second boolean := false;
  v_secret_no_limits boolean := false;
  r record;
  day_secs integer;
  goal_secs integer;
  cursor_day date;
  run integer;
  months_ok integer := 0;
  v_day_map jsonb := '{}'::jsonb;
  v_day_key text;
  v_day_val integer;
begin
  select coalesce(daily_goal_minutes, 360)
    into v_goal_minutes
  from public.profiles
  where id = p_user_id;
  v_goal_minutes := coalesce(v_goal_minutes, 360);
  goal_secs := v_goal_minutes * 60;

  select
    coalesce(sum(duration_seconds), 0),
    coalesce(max(duration_seconds / 60), 0)
  into v_total_seconds, v_max_session_minutes
  from public.study_sessions
  where user_id = p_user_id;

  for r in
    select
      ((start_time at time zone 'Europe/Istanbul')::date) as day,
      sum(duration_seconds)::integer as total_seconds
    from public.study_sessions
    where user_id = p_user_id
    group by 1
  loop
    v_day_map := v_day_map || jsonb_build_object(r.day::text, r.total_seconds);
    if (r.total_seconds / 3600) > coalesce(v_max_day_hours, 0) then
      v_max_day_hours := r.total_seconds / 3600;
    end if;
    if r.total_seconds >= goal_secs
       and extract(isodow from r.day) in (6, 7) then
      v_weekend_goal_days := v_weekend_goal_days + 1;
    end if;
    if r.total_seconds >= goal_secs * 3 then
      v_secret_no_limits := true;
    end if;
  end loop;
  v_max_day_hours := coalesce(v_max_day_hours, 0);

  for r in
    select
      duration_seconds,
      (start_time at time zone 'Europe/Istanbul') as start_local,
      (end_time at time zone 'Europe/Istanbul') as end_local
    from public.study_sessions
    where user_id = p_user_id
  loop
    if (r.duration_seconds / 60) = 404 then v_secret_404 := true; end if;
    if (r.duration_seconds / 60) = 194 then v_secret_pi := true; end if;
    if (r.duration_seconds / 60) in (111, 222, 333, 555) then
      v_secret_matrix := true;
    end if;
    if r.duration_seconds >= 7200
       and extract(hour from r.start_local) >= 0
       and extract(hour from r.start_local) < 4 then
      v_secret_night := true;
    end if;
    if r.duration_seconds >= 3600
       and extract(hour from r.start_local) >= 5
       and extract(hour from r.start_local) < 7 then
      v_secret_dawn := true;
    end if;
    if extract(hour from r.start_local) = 13
       and extract(minute from r.start_local) = 37
       and r.duration_seconds >= 3600 then
      v_secret_1337 := true;
    end if;
    if (extract(month from r.start_local) = 12
        and extract(day from r.start_local) = 31
        and (extract(hour from r.start_local) * 60
             + extract(minute from r.start_local)) >= (23 * 60 + 50)
        and r.end_local::date > r.start_local::date)
       or (extract(month from r.end_local) = 1
           and extract(day from r.end_local) = 1
           and (extract(hour from r.end_local) * 60
                + extract(minute from r.end_local)) <= 10
           and r.start_local::date < r.end_local::date) then
      v_secret_nye := true;
    end if;
    if extract(hour from r.end_local) = 23
       and extract(minute from r.end_local) between 55 and 59 then
      v_day_key := (r.end_local::date)::text;
      v_day_val := coalesce((v_day_map->>v_day_key)::integer, 0);
      if v_day_val >= goal_secs then
        v_secret_last_second := true;
      end if;
    end if;
  end loop;

  cursor_day := (now() at time zone 'Europe/Istanbul')::date;
  day_secs := coalesce((v_day_map->>cursor_day::text)::integer, 0);
  if day_secs < goal_secs then
    cursor_day := cursor_day - 1;
  end if;
  run := 0;
  loop
    day_secs := coalesce((v_day_map->>cursor_day::text)::integer, 0);
    exit when day_secs < goal_secs;
    run := run + 1;
    cursor_day := cursor_day - 1;
  end loop;
  v_streak := run;

  if v_day_map <> '{}'::jsonb then
    for r in
      select mk, count(*) as goal_days
      from (
        select to_char(k::date, 'YYYY-MM') as mk
        from jsonb_object_keys(v_day_map) as k
        where coalesce((v_day_map->>k)::integer, 0) >= goal_secs
      ) s
      group by mk
    loop
      if r.goal_days >= 28 then
        months_ok := months_ok + 1;
      end if;
    end loop;
  end if;
  v_perfect_months := months_ok;

  -- İlham Kaynağı: gönderilen dürtme sayısı (anti-spam ayrı RPC'de)
  select count(*)::integer into v_nudge_starts
  from public.nudges
  where sender_id = p_user_id;
  v_nudge_starts := coalesce(v_nudge_starts, 0);

  -- Takım oyuncusu: aktif grup üyeliği varken oturum yapılan gün sayısı
  select count(distinct ((s.start_time at time zone 'Europe/Istanbul')::date))::integer
    into v_group_goal_days
  from public.study_sessions s
  where s.user_id = p_user_id
    and s.duration_seconds > 0
    and exists (
      select 1 from public.group_members gm
      where gm.user_id = p_user_id
        and gm.left_at is null
        and s.start_time >= gm.joined_at
    );
  v_group_goal_days := coalesce(v_group_goal_days, 0);

  return jsonb_build_object(
    'total_hours', (v_total_seconds / 3600)::integer,
    'max_session_minutes', v_max_session_minutes,
    'max_day_hours', v_max_day_hours,
    'streak_days', v_streak,
    'weekend_goal_days', v_weekend_goal_days,
    'perfect_months', v_perfect_months,
    'goal_minutes', v_goal_minutes,
    'nudge_starts', v_nudge_starts,
    'group_goal_contrib', v_group_goal_days,
    'secrets', jsonb_build_object(
      'night_owl', v_secret_night,
      'dawn', v_secret_dawn,
      'm404', v_secret_404,
      'pi', v_secret_pi,
      'matrix', v_secret_matrix,
      'leet', v_secret_1337,
      'nye', v_secret_nye,
      'last_second', v_secret_last_second,
      'no_limits', v_secret_no_limits
    )
  );
end;
$$;

create or replace function public.process_achievement_event(
  p_event_type text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
  v_ok boolean;
  v_total_xp integer := 0;
  v_rank text := 'wood_novice';
  v_secrets jsonb;
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
    order by id
  loop
    v_progress := case v_def.id
      when 'marathon_total' then (v_metrics->>'total_hours')::integer
      when 'steel_will' then (v_metrics->>'max_session_minutes')::integer
      when 'day_hero' then (v_metrics->>'max_day_hours')::integer
      when 'fire_streak' then (v_metrics->>'streak_days')::integer
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
      when 'secret_1337' then case when (v_secrets->>'leet')::boolean then 1 else 0 end
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
        v_ok := public._award_achievement_tier(
          v_uid,
          v_def.id,
          v_tier_n,
          v_xp,
          format('%s progress=%s %s', v_def.id, v_progress, coalesce(v_unit, ''))
        );
        if v_ok then
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

  select coalesce(xp, 0), coalesce(crown_rank, 'wood_novice')
    into v_total_xp, v_rank
  from public.gamification_profiles
  where user_id = v_uid;

  return jsonb_build_object(
    'event_type', p_event_type,
    'awarded', v_awarded,
    'total_xp', coalesce(v_total_xp, 0),
    'crown_rank', coalesce(v_rank, 'wood_novice'),
    'metrics', v_metrics
  );
end;
$$;
