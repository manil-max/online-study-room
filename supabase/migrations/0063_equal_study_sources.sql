-- 0063_equal_study_sources.sql
-- WP-229 — Manuel giriş, uygulama kronometresi, geri sayım/Pomodoro ve
-- native/widget sayacı için tek kazanım kuralı.
--
-- `study_sessions` uygulamanın tek çalışma gerçeğidir: source veya eski
-- live_run bağı, XP/başarım/grup metriği bakımından fark yaratmaz. Önceden
-- uygulanmış verified tabloları denetim geçmişi olarak tutulur; kullanıcı
-- oturumları, XP ledger'ı, rozetler ve pending ödüller silinmez.
--
-- Bu dosyanın önceki taslağı hiçbir remote'a uygulanmadı (WP-225/226 sentinel
-- audit'i: production'da verified_seconds var, total_seconds yok). Bu nedenle
-- yayımlanmamış 0063 aynı numarada güvenle yeniden tasarlandı. Geri alma yeni bir
-- ileri migration ile yalnız trigger/fonksiyon/cron yönünü değiştirir; session,
-- live_run bağı, ledger, claimed/pending reward veya kazanılmış progress silinmez.

-- ---------------------------------------------------------------------------
-- 1) Eşit kazanım, audit bağını veya server-created satır korumasını kaldırmaz.
-- ---------------------------------------------------------------------------
-- 0051'in sessions_* policy'leri ve study_sessions_guard_verified_update trigger'ı
-- bilinçli olarak korunur. Manuel/client satırları (live_run_id null) owner DML'ine
-- açık; server-finalized satırlar immutable ve live_run_id audit bağıyla kalır.

create or replace function public._equal_source_effective_end(
  p_start timestamptz,
  p_end timestamptz,
  p_duration_seconds integer
)
returns timestamptz
language sql
immutable
set search_path = public
as $$
  select case
    when p_duration_seconds > 0 then p_start + make_interval(secs => p_duration_seconds)
    else greatest(p_end, p_start)
  end;
$$;

-- Candidate -> pending -> claim zincirinin tek server-authoritative geçidi.
-- Canonical reward unique(user, achievement, tier) ve ledger event key'i retry'da
-- çift XP'yi engeller. Candidate audit satırı pending/ledger mevcutsa consumed olur.
create or replace function public._sync_equal_source_rewards(
  p_user_id uuid,
  p_achievement_id text,
  p_progress bigint,
  p_source_version text,
  p_evidence jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier record;
  v_candidate_status text;
  v_created integer := 0;
begin
  if p_user_id is null or p_achievement_id is null or p_progress is null then
    raise exception 'equal_source_reward_input_required';
  end if;

  for v_tier in
    select (tier_def->>'tier')::integer as tier,
      (tier_def->>'threshold')::bigint as threshold,
      (tier_def->>'xp')::integer as xp
    from public.achievements_dict d
    cross join lateral jsonb_array_elements(d.tiers) tier_def
    where d.id = p_achievement_id
    order by (tier_def->>'tier')::integer
  loop
    continue when p_progress < v_tier.threshold;

    insert into public.achievement_reward_candidates(
      user_id, achievement_id, tier, source_version, event_key, status, evidence
    ) values (
      p_user_id, p_achievement_id, v_tier.tier, p_source_version,
      format('%s|%s|equal-source|tier-%s', p_user_id, p_achievement_id, v_tier.tier),
      'ready',
      coalesce(p_evidence, '{}'::jsonb) || jsonb_build_object(
        'progress', p_progress, 'threshold', v_tier.threshold, 'xp', v_tier.xp
      )
    ) on conflict do nothing;

    perform public._create_pending_achievement_reward(
      p_user_id, p_achievement_id, v_tier.tier, v_tier.xp,
      format('%s progress=%s', p_achievement_id, p_progress)
    );

    select case
      when exists (
        select 1 from public.achievement_rewards ar
        where ar.user_id = p_user_id and ar.achievement_id = p_achievement_id
          and ar.tier = v_tier.tier
      ) or exists (
        select 1 from public.xp_ledger xl
        where xl.event_key = format('%s|%s|tier_%s', p_user_id, p_achievement_id, v_tier.tier)
      ) then 'consumed' else 'ready' end
      into v_candidate_status;

    update public.achievement_reward_candidates
    set status = v_candidate_status,
        evidence = achievement_reward_candidates.evidence ||
          jsonb_build_object('routed_at', clock_timestamp())
    where user_id = p_user_id and achievement_id = p_achievement_id
      and tier = v_tier.tier and source_version = p_source_version;
    v_created := v_created + 1;
  end loop;
  return v_created;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) Mola Düşmanı: tüm çalışma oturumlarını aynı kaynak kabul et.
-- ---------------------------------------------------------------------------
create or replace function public.break_enemy_metric(p_user_id uuid)
returns bigint
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_starts timestamptz[];
  v_ends timestamptz[];
  v_count integer;
  v_left integer := 1;
  v_right integer;
  v_total double precision := 0;
  v_covered double precision;
  v_window_start timestamptz;
begin
  select array_agg(lower(r) order by lower(r)), array_agg(upper(r) order by lower(r))
    into v_starts, v_ends
  from unnest((
    select range_agg(tstzrange(
      s.start_time,
      public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds),
      '[)'
    ))
    from public.study_sessions s
    where s.user_id = p_user_id
      and s.duration_seconds > 0
      and public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) > s.start_time
  )) as r;

  v_count := coalesce(array_length(v_starts, 1), 0);
  if v_count = 0 then return 0; end if;

  for v_right in 1..v_count loop
    v_total := v_total + extract(epoch from (v_ends[v_right] - v_starts[v_right]));
    v_window_start := v_ends[v_right] - interval '5 hours';
    while v_left <= v_right and v_ends[v_left] <= v_window_start loop
      v_total := v_total - extract(epoch from (v_ends[v_left] - v_starts[v_left]));
      v_left := v_left + 1;
    end loop;
    v_covered := v_total;
    if v_left <= v_right and v_starts[v_left] < v_window_start then
      v_covered := v_covered - extract(epoch from (v_window_start - v_starts[v_left]));
    end if;
    if v_covered >= 16200 then return 1; end if;
  end loop;
  return 0;
end;
$$;

create or replace function public.project_break_enemy_metric(p_user_id uuid)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare v_metric bigint;
begin
  v_metric := public.break_enemy_metric(p_user_id);
  insert into public.achievement_metric_progress(
    user_id, achievement_id, metric_value, source_version, updated_at
  ) values (
    p_user_id, 'secret_break_enemy', v_metric, 'break_all_sessions_v2', clock_timestamp()
  ) on conflict(user_id, achievement_id) do update set
    metric_value = greatest(public.achievement_metric_progress.metric_value, excluded.metric_value),
    source_version = excluded.source_version,
    updated_at = clock_timestamp();

  perform public._sync_equal_source_rewards(
    p_user_id, 'secret_break_enemy', v_metric, 'break_all_sessions_v2',
    jsonb_build_object(
      'all_session_sources', true, 'window_minutes', 300, 'focus_minutes', 270
    )
  );
  return v_metric;
end;
$$;

create or replace function public._study_session_project_break_enemy()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op <> 'DELETE' then
    perform public.project_break_enemy_metric(new.user_id);
  end if;
  if tg_op = 'DELETE' or (tg_op = 'UPDATE' and old.user_id is distinct from new.user_id) then
    perform public.project_break_enemy_metric(old.user_id);
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists live_segments_project_break_enemy on public.live_study_segments;
drop trigger if exists study_sessions_project_break_enemy on public.study_sessions;
create trigger study_sessions_project_break_enemy
  after insert or update or delete on public.study_sessions
  for each row execute function public._study_session_project_break_enemy();

-- ---------------------------------------------------------------------------
-- 3) Grup metrikleri: üyelik penceresindeki bütün study_sessions eşittir.
-- ---------------------------------------------------------------------------
alter table public.group_achievement_daily
  alter column source_version set default 'group_all_sessions_v2';

update public.achievement_metric_definitions
set source_version = 'group_all_sessions_v2', updated_at = clock_timestamp()
where achievement_id in ('alpha_wolf', 'campfire_hours', 'locomotive', 'secret_break_enemy');

do $migration$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'group_achievement_weekly'
      and column_name = 'verified_seconds'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'group_achievement_weekly'
      and column_name = 'total_seconds'
  ) then
    alter table public.group_achievement_weekly
      rename column verified_seconds to total_seconds;
  end if;
end
$migration$;

update public.achievements_dict
set description = 'ISO haftasında grubunda toplam sürede tek başına birinci olma sayısı'
where id = 'alpha_wolf_weekly';

insert into public.achievement_metric_definitions
  (achievement_id, metric_key, projection_kind, source_version)
values ('alpha_wolf_weekly', 'weekly_alpha_wins', 'cumulative', 'weekly_alpha_all_sessions_v2')
on conflict (achievement_id) do update set
  metric_key = excluded.metric_key,
  projection_kind = excluded.projection_kind,
  source_version = excluded.source_version,
  updated_at = clock_timestamp();

create or replace function public.project_group_day(p_group_id uuid, p_day date)
returns integer language plpgsql security definer set search_path = public as $$
declare v_affected integer; r record;
begin
  with bounds as (
    select (p_day::timestamp at time zone 'Europe/Istanbul') as lo,
      ((p_day + 1)::timestamp at time zone 'Europe/Istanbul') as hi
  ), raw as (
    select s.user_id, tstzrange(
      greatest(s.start_time, b.lo, gm.joined_at),
      least(
        public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds),
        b.hi,
        coalesce(gm.left_at, b.hi)
      ),
      '[)'
    ) as period
    from public.study_sessions s
    join public.group_members gm on gm.user_id = s.user_id
      and gm.group_id = p_group_id
      and public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) > gm.joined_at
      and (gm.left_at is null or s.start_time < gm.left_at)
    cross join bounds b
    where s.duration_seconds > 0
      and public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) > b.lo
      and s.start_time < b.hi
  ), seg as (
    select merged.user_id, lower(range_piece.period) as a, upper(range_piece.period) as z
    from (
      select user_id, range_agg(period) as periods
      from raw where not isempty(period) group by user_id
    ) merged
    cross join lateral unnest(merged.periods) as range_piece(period)
  ), thr as (
    select greatest(2, ceil(count(distinct user_id) / 2.0))::int as t from seg
  ), events as (
    select a t, 1 delta from seg union all select z, -1 from seg
  ), points as (
    select t, sum(delta) over(order by t, delta rows unbounded preceding) active,
      lead(t) over(order by t, delta) next_t from events
  ), camp as (
    select s.user_id,
      floor(sum(extract(epoch from (least(s.z, p.next_t) - greatest(s.a, p.t)))))::bigint seconds
    from seg s join points p on p.active >= (select t from thr) and p.next_t > p.t
      and s.a < p.next_t and s.z > p.t
    group by s.user_id
  ), totals as (
    select user_id, floor(sum(extract(epoch from (z - a))))::bigint seconds
    from seg group by user_id
  ), alpha as (
    select user_id, case when count(*) over(partition by seconds) = 1
      and dense_rank() over(order by seconds desc) = 1 then 1 else 0 end wins
    from totals
  ), loco as (
    select leader.user_id, count(distinct follower.user_id)::integer events
    from seg leader join seg follower on follower.user_id <> leader.user_id
      and follower.a between leader.a and least(leader.z, leader.a + interval '15 minutes')
    group by leader.user_id
  ), users as (select user_id from seg group by user_id)
  insert into public.group_achievement_daily(
    group_id, istanbul_day, user_id, alpha_wins, campfire_seconds, locomotive_events,
    source_version, updated_at
  ) select p_group_id, p_day, u.user_id, coalesce(a.wins, 0), coalesce(c.seconds, 0),
      coalesce(l.events, 0), 'group_all_sessions_v2', clock_timestamp()
    from users u left join alpha a using(user_id) left join camp c using(user_id)
      left join loco l using(user_id)
  on conflict(group_id, istanbul_day, user_id) do update set
    alpha_wins = excluded.alpha_wins,
    campfire_seconds = excluded.campfire_seconds,
    locomotive_events = excluded.locomotive_events,
    source_version = excluded.source_version,
    updated_at = clock_timestamp();
  get diagnostics v_affected = row_count;

  -- Silinen/düzenlenen session sonrası eski kazanan satırı hayalet kalmasın.
  update public.group_achievement_daily d
  set alpha_wins = 0, campfire_seconds = 0, locomotive_events = 0,
      source_version = 'group_all_sessions_v2', updated_at = clock_timestamp()
  where d.group_id = p_group_id and d.istanbul_day = p_day
    and not exists (
      select 1 from public.study_sessions s
      join public.group_members gm on gm.user_id = s.user_id
        and gm.group_id = p_group_id
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > gm.joined_at
        and (gm.left_at is null or s.start_time < gm.left_at)
      where s.user_id = d.user_id and s.duration_seconds > 0
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > (p_day::timestamp at time zone 'Europe/Istanbul')
        and s.start_time < ((p_day + 1)::timestamp at time zone 'Europe/Istanbul')
    );

  insert into public.achievement_metric_progress(user_id, achievement_id, metric_value, source_version, updated_at)
  select user_id, metric, value, 'group_all_sessions_v2', clock_timestamp() from (
    select user_id, 'alpha_wolf' metric, sum(alpha_wins)::bigint value
      from public.group_achievement_daily where finalized_at is not null group by user_id
    union all
    select user_id, 'campfire_hours', sum(campfire_seconds) / 3600
      from public.group_achievement_daily group by user_id
    union all
    select user_id, 'locomotive', sum(locomotive_events)
      from public.group_achievement_daily group by user_id
  ) m on conflict(user_id, achievement_id) do update set
    metric_value = excluded.metric_value,
    source_version = excluded.source_version,
    updated_at = clock_timestamp();
  for r in
    select p.user_id, p.achievement_id, p.metric_value
    from public.achievement_metric_progress p
    where p.achievement_id in ('alpha_wolf', 'campfire_hours', 'locomotive')
      and exists (
        select 1 from public.group_achievement_daily d
        where d.group_id = p_group_id and d.istanbul_day = p_day
          and d.user_id = p.user_id
      )
  loop
    perform public._sync_equal_source_rewards(
      r.user_id, r.achievement_id, r.metric_value, 'group_all_sessions_v2',
      jsonb_build_object('group_id', p_group_id, 'istanbul_day', p_day)
    );
  end loop;
  return v_affected;
end;
$$;

create or replace function public.finalize_group_day(p_group_id uuid, p_day date)
returns integer language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  if p_day >= (timezone('Europe/Istanbul', clock_timestamp()))::date then
    raise exception 'group_day_not_closed';
  end if;
  perform public.project_group_day(p_group_id, p_day);
  update public.group_achievement_daily
  set finalized_at = coalesce(finalized_at, clock_timestamp())
  where group_id = p_group_id and istanbul_day = p_day;
  get diagnostics v_count = row_count;
  perform public.project_group_day(p_group_id, p_day);
  return v_count;
end;
$$;

create or replace function public.catch_up_group_days()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in
    select distinct gm.group_id, d.day
    from public.study_sessions s
    join public.group_members gm on gm.user_id = s.user_id
      and public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) > gm.joined_at
      and (gm.left_at is null or s.start_time < gm.left_at)
    cross join lateral generate_series(
      (timezone('Europe/Istanbul', greatest(s.start_time, gm.joined_at)))::date,
      (timezone('Europe/Istanbul', least(
        public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds),
        coalesce(gm.left_at, public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ))
      ) - interval '1 microsecond'))::date,
      interval '1 day'
    ) as d(day)
    where s.duration_seconds > 0
  loop
    perform public.project_group_day(r.group_id, r.day::date);
    if r.day::date < (timezone('Europe/Istanbul', clock_timestamp()))::date then
      perform public.finalize_group_day(r.group_id, r.day::date);
    end if;
    n := n + 1;
  end loop;
  return n;
end;
$$;

create or replace function public.refresh_group_metrics_for_session(
  p_user_id uuid,
  p_start timestamptz,
  p_end timestamptz
)
returns void language plpgsql security definer set search_path = public as $$
declare r record; v_day date; v_week date;
begin
  if p_user_id is null or p_start is null or p_end is null or p_end <= p_start then
    return;
  end if;
  for r in
    select gm.group_id from public.group_members gm
    where gm.user_id = p_user_id
      and p_end > gm.joined_at
      and (gm.left_at is null or p_start < gm.left_at)
  loop
    for v_day in select generate_series(
      (timezone('Europe/Istanbul', p_start))::date,
      (timezone('Europe/Istanbul', p_end - interval '1 microsecond'))::date,
      interval '1 day'
    )::date
    loop
      perform public.project_group_day(r.group_id, v_day);
    end loop;
    for v_week in select generate_series(
      date_trunc('week', timezone('Europe/Istanbul', p_start))::date,
      date_trunc('week', timezone(
        'Europe/Istanbul', p_end - interval '1 microsecond'
      ))::date,
      interval '7 days'
    )::date
    loop
      perform public.project_group_week(r.group_id, v_week);
    end loop;
  end loop;
end;
$$;

create or replace function public._study_session_project_group_metrics()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op <> 'DELETE' then
    perform public.refresh_group_metrics_for_session(
      new.user_id,
      new.start_time,
      public._equal_source_effective_end(new.start_time, new.end_time, new.duration_seconds)
    );
  end if;
  if tg_op <> 'INSERT' then
    perform public.refresh_group_metrics_for_session(
      old.user_id,
      old.start_time,
      public._equal_source_effective_end(old.start_time, old.end_time, old.duration_seconds)
    );
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists live_runs_project_group_metrics on public.live_study_runs;
drop trigger if exists live_segments_project_group_metrics on public.live_study_segments;
drop trigger if exists study_sessions_project_group_metrics on public.study_sessions;
create trigger study_sessions_project_group_metrics
  after insert or update or delete on public.study_sessions
  for each row execute function public._study_session_project_group_metrics();

-- ---------------------------------------------------------------------------
-- 4) Lider Kurt: haftalık toplam da bütün oturum kaynaklarından gelir.
-- ---------------------------------------------------------------------------
create or replace function public.project_group_week(p_group_id uuid, p_week_start date)
returns integer language plpgsql security definer set search_path = public as $$
declare v_affected integer; r record;
begin
  if extract(isodow from p_week_start) <> 1 then
    raise exception 'iso_week_start_must_be_monday';
  end if;
  with bounds as (
    select (p_week_start::timestamp at time zone 'Europe/Istanbul') as lo,
      ((p_week_start + 7)::timestamp at time zone 'Europe/Istanbul') as hi
  ), raw as (
    select s.user_id, tstzrange(
      greatest(s.start_time, b.lo, gm.joined_at),
      least(
        public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds),
        b.hi,
        coalesce(gm.left_at, b.hi)
      ),
      '[)'
    ) as period
    from public.study_sessions s
    join public.group_members gm on gm.user_id = s.user_id
      and gm.group_id = p_group_id
      and public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) > gm.joined_at
      and (gm.left_at is null or s.start_time < gm.left_at)
    cross join bounds b
    where s.duration_seconds > 0
      and public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) > b.lo
      and s.start_time < b.hi
  ), sessions as (
    select merged.user_id, lower(range_piece.period) as started_at,
      upper(range_piece.period) as ended_at
    from (
      select user_id, range_agg(period) as periods
      from raw where not isempty(period) group by user_id
    ) merged
    cross join lateral unnest(merged.periods) as range_piece(period)
  ), totals as (
    select user_id, floor(sum(extract(epoch from ended_at - started_at)))::bigint as seconds
    from sessions group by user_id
  ), leaders as (
    select user_id from totals where seconds = (select max(seconds) from totals)
  ), winner as (
    select user_id from leaders where (select count(*) from leaders) = 1
  )
  insert into public.group_achievement_weekly(
    group_id, iso_week_start, user_id, total_seconds, weekly_alpha_wins, updated_at
  ) select p_group_id, p_week_start, t.user_id, t.seconds,
      case when w.user_id is null then 0 else 1 end, clock_timestamp()
    from totals t left join winner w using(user_id)
  on conflict(group_id, iso_week_start, user_id) do update set
    total_seconds = excluded.total_seconds,
    weekly_alpha_wins = excluded.weekly_alpha_wins,
    updated_at = clock_timestamp();
  get diagnostics v_affected = row_count;

  update public.group_achievement_weekly w
  set total_seconds = 0, weekly_alpha_wins = 0, updated_at = clock_timestamp()
  where w.group_id = p_group_id and w.iso_week_start = p_week_start
    and not exists (
      select 1 from public.study_sessions s
      join public.group_members gm on gm.user_id = s.user_id
        and gm.group_id = p_group_id
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > gm.joined_at
        and (gm.left_at is null or s.start_time < gm.left_at)
      where s.user_id = w.user_id and s.duration_seconds > 0
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > (p_week_start::timestamp at time zone 'Europe/Istanbul')
        and s.start_time < ((p_week_start + 7)::timestamp at time zone 'Europe/Istanbul')
    );

  insert into public.achievement_metric_progress(user_id, achievement_id, metric_value, source_version, updated_at)
  select user_id, 'alpha_wolf_weekly', sum(weekly_alpha_wins)::bigint,
    'weekly_alpha_all_sessions_v2', clock_timestamp()
  from public.group_achievement_weekly where finalized_at is not null group by user_id
  on conflict(user_id, achievement_id) do update set
    metric_value = greatest(public.achievement_metric_progress.metric_value, excluded.metric_value),
    source_version = excluded.source_version,
    updated_at = clock_timestamp();

  for r in
    select p.user_id, p.metric_value
    from public.achievement_metric_progress p
    where p.achievement_id = 'alpha_wolf_weekly'
      and exists (
        select 1 from public.group_achievement_weekly w
        where w.group_id = p_group_id and w.iso_week_start = p_week_start
          and w.user_id = p.user_id
      )
  loop
    perform public._sync_equal_source_rewards(
      r.user_id, 'alpha_wolf_weekly', r.metric_value,
      'weekly_alpha_all_sessions_v2',
      jsonb_build_object('group_id', p_group_id, 'week_start', p_week_start)
    );
  end loop;
  return v_affected;
end;
$$;

create or replace function public.finalize_group_week(p_group_id uuid, p_week_start date)
returns integer language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  if p_week_start + 7 > date_trunc('week', timezone('Europe/Istanbul', clock_timestamp()))::date then
    raise exception 'group_week_not_closed';
  end if;
  perform public.project_group_week(p_group_id, p_week_start);
  update public.group_achievement_weekly
  set finalized_at = coalesce(finalized_at, clock_timestamp())
  where group_id = p_group_id and iso_week_start = p_week_start;
  get diagnostics v_count = row_count;
  -- İkinci proje finalized toplamı günceller ve candidate -> pending zincirini
  -- idempotent biçimde çalıştırır.
  perform public.project_group_week(p_group_id, p_week_start);
  return v_count;
end;
$$;

create or replace function public.catch_up_group_weeks()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in
    select distinct gm.group_id, week_start::date
    from public.study_sessions s
    join public.group_members gm on gm.user_id = s.user_id
      and public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) > gm.joined_at
      and (gm.left_at is null or s.start_time < gm.left_at)
    cross join lateral generate_series(
      date_trunc('week', timezone('Europe/Istanbul', greatest(s.start_time, gm.joined_at)))::date,
      date_trunc('week', timezone('Europe/Istanbul', least(
        public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds),
        coalesce(gm.left_at, public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ))
      ) - interval '1 microsecond'))::date,
      interval '7 days'
    ) as weeks(week_start)
    where s.duration_seconds > 0
      and week_start::date < date_trunc('week', timezone('Europe/Istanbul', clock_timestamp()))::date
  loop
    perform public.finalize_group_week(r.group_id, r.week_start);
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- Eski cron adları çalışmasın; yeni, kaynak-nötr adlarla devam et.
do $$
declare r record;
begin
  if to_regclass('cron.job') is null then
    raise exception 'pg_cron_job_table_required';
  end if;
  for r in select jobid from cron.job where jobname in (
    'verified-group-day-finalizer', 'verified-group-week-finalizer'
  ) loop
    perform cron.unschedule(r.jobid);
  end loop;
  if not exists (select 1 from cron.job where jobname = 'group-achievement-day-finalizer') then
    perform cron.schedule('group-achievement-day-finalizer', '5 21 * * *',
      'select public.catch_up_group_days()');
  end if;
  if not exists (select 1 from cron.job where jobname = 'group-achievement-week-finalizer') then
    perform cron.schedule('group-achievement-week-finalizer', '10 21 * * 0',
      'select public.catch_up_group_weeks()');
  end if;
end;
$$;

-- Eski verified-only giriş noktaları aktif trigger/cron'dan ayrıldıktan sonra
-- kaldırılır. Böylece renamed verified_seconds kolonuna bağlı ölü fonksiyon kalmaz.
drop function if exists public._verified_group_run_finalized();
drop function if exists public._verified_group_segment_dirty();
drop function if exists public.project_verified_group_day(uuid, date);
drop function if exists public.finalize_verified_group_day(uuid, date);
drop function if exists public.catch_up_verified_group_days();
drop function if exists public.project_verified_group_week(uuid, date);
drop function if exists public.finalize_verified_group_week(uuid, date);
drop function if exists public.catch_up_verified_group_weeks();
drop function if exists public._break_enemy_segment_projector();

-- ---------------------------------------------------------------------------
-- 5) Reconciliation: önce salt-okunur shadow/diff, sonra bounded apply.
-- ---------------------------------------------------------------------------
create table if not exists public.equal_source_reconciliation_runs (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'preparing'
    check (status in ('preparing', 'prepared', 'applying', 'applied', 'cancelled')),
  after_user_id uuid,
  batch_limit integer not null check (batch_limit between 1 and 500),
  user_count integer not null default 0,
  diff_count integer not null default 0,
  baseline_session_count bigint not null,
  baseline_duration_seconds bigint not null,
  baseline_ledger_count bigint not null,
  baseline_ledger_xp bigint not null,
  baseline_claimed_reward_count bigint not null,
  baseline_xp_mismatch_count bigint not null,
  created_at timestamptz not null default clock_timestamp(),
  prepared_at timestamptz,
  applied_at timestamptz
);

create table if not exists public.equal_source_reconciliation_users (
  run_id uuid not null references public.equal_source_reconciliation_runs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  source_kinds integer not null,
  session_count bigint not null,
  duration_seconds bigint not null,
  current_break_metric bigint not null,
  shadow_break_metric bigint not null,
  affected_group_days bigint not null,
  affected_group_weeks bigint not null,
  primary key (run_id, user_id)
);

alter table public.equal_source_reconciliation_runs enable row level security;
alter table public.equal_source_reconciliation_users enable row level security;
revoke all on table public.equal_source_reconciliation_runs from public, anon, authenticated;
revoke all on table public.equal_source_reconciliation_users from public, anon, authenticated;

create or replace function public.prepare_equal_source_reconciliation(
  p_batch_limit integer default 100,
  p_after_user_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_run_id uuid;
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  if p_batch_limit is null or p_batch_limit not between 1 and 500 then
    raise exception 'reconciliation_batch_limit_out_of_range';
  end if;
  if exists (
    select 1 from public.gamification_profiles gp
    where gp.xp <> (
      select coalesce(sum(xl.xp_amount), 0)::integer
      from public.xp_ledger xl where xl.user_id = gp.user_id
    )
  ) then
    raise exception 'xp_ledger_profile_invariant_failed';
  end if;

  insert into public.equal_source_reconciliation_runs(
    after_user_id, batch_limit,
    baseline_session_count, baseline_duration_seconds,
    baseline_ledger_count, baseline_ledger_xp,
    baseline_claimed_reward_count, baseline_xp_mismatch_count
  )
  select p_after_user_id, p_batch_limit,
    (select count(*) from public.study_sessions),
    (select coalesce(sum(duration_seconds), 0) from public.study_sessions),
    (select count(*) from public.xp_ledger),
    (select coalesce(sum(xp_amount), 0) from public.xp_ledger),
    (select count(*) from public.achievement_rewards where status = 'claimed'),
    0
  returning id into v_run_id;

  insert into public.equal_source_reconciliation_users(
    run_id, user_id, source_kinds, session_count, duration_seconds,
    current_break_metric, shadow_break_metric,
    affected_group_days, affected_group_weeks
  )
  select v_run_id, u.user_id,
    (select count(distinct s.source)::integer from public.study_sessions s where s.user_id = u.user_id),
    (select count(*) from public.study_sessions s where s.user_id = u.user_id),
    (select coalesce(sum(s.duration_seconds), 0) from public.study_sessions s where s.user_id = u.user_id),
    coalesce((select p.metric_value from public.achievement_metric_progress p
      where p.user_id = u.user_id and p.achievement_id = 'secret_break_enemy'), 0),
    public.break_enemy_metric(u.user_id),
    (
      select count(distinct (gm.group_id, d.day::date))
      from public.study_sessions s
      join public.group_members gm on gm.user_id = s.user_id
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > gm.joined_at
        and (gm.left_at is null or s.start_time < gm.left_at)
      cross join lateral generate_series(
        (timezone('Europe/Istanbul', greatest(s.start_time, gm.joined_at)))::date,
        (timezone('Europe/Istanbul', least(
          public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds),
          coalesce(gm.left_at, public._equal_source_effective_end(
            s.start_time, s.end_time, s.duration_seconds
          ))
        ) - interval '1 microsecond'))::date,
        interval '1 day'
      ) d(day)
      where s.user_id = u.user_id and s.duration_seconds > 0
    ),
    (
      select count(distinct (gm.group_id,
        date_trunc('week', timezone('Europe/Istanbul', d.day))::date))
      from public.study_sessions s
      join public.group_members gm on gm.user_id = s.user_id
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > gm.joined_at
        and (gm.left_at is null or s.start_time < gm.left_at)
      cross join lateral generate_series(
        greatest(s.start_time, gm.joined_at),
        least(
          public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds),
          coalesce(gm.left_at, public._equal_source_effective_end(
            s.start_time, s.end_time, s.duration_seconds
          ))
        ) - interval '1 microsecond',
        interval '7 days'
      ) d(day)
      where s.user_id = u.user_id and s.duration_seconds > 0
    )
  from (
    select distinct s.user_id from public.study_sessions s
    where p_after_user_id is null or s.user_id > p_after_user_id
    order by s.user_id limit p_batch_limit
  ) u;

  update public.equal_source_reconciliation_runs r
  set status = 'prepared', prepared_at = clock_timestamp(),
      user_count = (select count(*) from public.equal_source_reconciliation_users u where u.run_id = v_run_id),
      diff_count = (
        select count(*) from public.equal_source_reconciliation_users u
        where u.run_id = v_run_id
          and (u.current_break_metric is distinct from u.shadow_break_metric
            or u.affected_group_days > 0 or u.affected_group_weeks > 0)
      )
  where r.id = v_run_id;
  return v_run_id;
end;
$$;

create or replace function public.apply_equal_source_reconciliation(p_run_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_run public.equal_source_reconciliation_runs%rowtype;
  u record;
  r record;
  v_count integer := 0;
  v_now_day date := (timezone('Europe/Istanbul', clock_timestamp()))::date;
  v_now_week date := date_trunc('week', timezone('Europe/Istanbul', clock_timestamp()))::date;
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  select * into v_run from public.equal_source_reconciliation_runs
  where id = p_run_id for update;
  if not found then raise exception 'reconciliation_run_not_found'; end if;
  if v_run.status = 'applied' then return 0; end if;
  if v_run.status <> 'prepared' then raise exception 'reconciliation_run_not_prepared'; end if;

  if v_run.baseline_session_count <> (select count(*) from public.study_sessions)
    or v_run.baseline_duration_seconds <> (select coalesce(sum(duration_seconds), 0) from public.study_sessions)
    or v_run.baseline_ledger_count <> (select count(*) from public.xp_ledger)
    or v_run.baseline_ledger_xp <> (select coalesce(sum(xp_amount), 0) from public.xp_ledger)
    or v_run.baseline_claimed_reward_count <>
      (select count(*) from public.achievement_rewards where status = 'claimed') then
    raise exception 'reconciliation_baseline_changed_reprepare_required';
  end if;

  update public.equal_source_reconciliation_runs set status = 'applying' where id = p_run_id;
  for u in
    select * from public.equal_source_reconciliation_users
    where run_id = p_run_id order by user_id
  loop
    perform public.project_break_enemy_metric(u.user_id);
    for r in
      select distinct gm.group_id, d.day::date as period_start
      from public.study_sessions s
      join public.group_members gm on gm.user_id = s.user_id
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > gm.joined_at
        and (gm.left_at is null or s.start_time < gm.left_at)
      cross join lateral generate_series(
        (timezone('Europe/Istanbul', greatest(s.start_time, gm.joined_at)))::date,
        (timezone('Europe/Istanbul', least(
          public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds),
          coalesce(gm.left_at, public._equal_source_effective_end(
            s.start_time, s.end_time, s.duration_seconds
          ))
        ) - interval '1 microsecond'))::date,
        interval '1 day'
      ) d(day)
      where s.user_id = u.user_id and s.duration_seconds > 0
    loop
      if r.period_start < v_now_day then
        perform public.finalize_group_day(r.group_id, r.period_start);
      else
        perform public.project_group_day(r.group_id, r.period_start);
      end if;
    end loop;
    for r in
      select distinct gm.group_id,
        date_trunc('week', timezone('Europe/Istanbul', d.day))::date as period_start
      from public.study_sessions s
      join public.group_members gm on gm.user_id = s.user_id
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > gm.joined_at
        and (gm.left_at is null or s.start_time < gm.left_at)
      cross join lateral generate_series(
        greatest(s.start_time, gm.joined_at),
        least(
          public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds),
          coalesce(gm.left_at, public._equal_source_effective_end(
            s.start_time, s.end_time, s.duration_seconds
          ))
        ) - interval '1 microsecond',
        interval '7 days'
      ) d(day)
      where s.user_id = u.user_id and s.duration_seconds > 0
    loop
      if r.period_start < v_now_week then
        perform public.finalize_group_week(r.group_id, r.period_start);
      else
        perform public.project_group_week(r.group_id, r.period_start);
      end if;
    end loop;
    v_count := v_count + 1;
  end loop;

  if v_run.baseline_session_count <> (select count(*) from public.study_sessions)
    or v_run.baseline_duration_seconds <> (select coalesce(sum(duration_seconds), 0) from public.study_sessions)
    or v_run.baseline_ledger_count <> (select count(*) from public.xp_ledger)
    or v_run.baseline_ledger_xp <> (select coalesce(sum(xp_amount), 0) from public.xp_ledger)
    or v_run.baseline_claimed_reward_count <>
      (select count(*) from public.achievement_rewards where status = 'claimed')
    or exists (
      select 1 from public.gamification_profiles gp
      where gp.xp <> (
        select coalesce(sum(xl.xp_amount), 0)::integer
        from public.xp_ledger xl where xl.user_id = gp.user_id
      )
    ) then
    raise exception 'reconciliation_post_apply_invariant_failed';
  end if;

  update public.equal_source_reconciliation_runs
  set status = 'applied', applied_at = clock_timestamp()
  where id = p_run_id;
  return v_count;
end;
$$;

revoke all on function public.break_enemy_metric(uuid) from public;
revoke all on function public.project_break_enemy_metric(uuid) from public;
revoke all on function public._equal_source_effective_end(timestamptz, timestamptz, integer) from public;
revoke all on function public._sync_equal_source_rewards(uuid, text, bigint, text, jsonb) from public;
revoke all on function public.project_group_day(uuid, date) from public;
revoke all on function public.finalize_group_day(uuid, date) from public;
revoke all on function public.catch_up_group_days() from public;
revoke all on function public.refresh_group_metrics_for_session(uuid, timestamptz, timestamptz) from public;
revoke all on function public.project_group_week(uuid, date) from public;
revoke all on function public.finalize_group_week(uuid, date) from public;
revoke all on function public.catch_up_group_weeks() from public;
revoke all on function public.prepare_equal_source_reconciliation(integer, uuid) from public;
revoke all on function public.apply_equal_source_reconciliation(uuid) from public;
grant execute on function public.prepare_equal_source_reconciliation(integer, uuid) to service_role;
grant execute on function public.apply_equal_source_reconciliation(uuid) to service_role;

notify pgrst, 'reload schema';
