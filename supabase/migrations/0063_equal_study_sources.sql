-- 0063_equal_study_sources.sql
-- beta-v42 · WP-219R — Manuel giriş, uygulama içi sayaç ve native sayaç için tek kazanım kuralı.
--
-- `study_sessions` uygulamanın tek çalışma gerçeğidir: source veya eski
-- live_run bağı, XP/başarım/grup metriği bakımından fark yaratmaz. Önceden
-- uygulanmış verified tabloları denetim geçmişi olarak tutulur; kullanıcı
-- oturumları, XP ledger'ı, rozetler ve pending ödüller silinmez.
--
-- Geri alma (Rollback): Bu migration veri silmez. Eski verified-only davranışa
-- dönmek istenirse ayrı bir ileri migration ile projector kaynakları ve istemci
-- akışı yeniden tanımlanır; bu migration geri çalıştırılmaz.

-- ---------------------------------------------------------------------------
-- 1) Eski verified ayrımını kullanıcı oturumlarından kaldır.
-- ---------------------------------------------------------------------------
drop trigger if exists study_sessions_guard_verified_update on public.study_sessions;

drop policy if exists sessions_insert on public.study_sessions;
create policy sessions_insert on public.study_sessions
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists sessions_update on public.study_sessions;
create policy sessions_update on public.study_sessions
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists sessions_delete on public.study_sessions;
create policy sessions_delete on public.study_sessions
  for delete to authenticated
  using (user_id = auth.uid());

-- Bağ yalnız eski teknik akışın iç ayrıntısıydı. Oturum satırı korunur ama
-- bundan sonra hiçbir satır kaynak ayrıcalığı taşımaz.
update public.study_sessions
set live_run_id = null
where live_run_id is not null;

update public.verified_session_runtime_config
set minimum_verified_xp_build = null,
    shadow_mode = false
where singleton;

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
    select range_agg(tstzrange(s.start_time, s.end_time, '[)'))
    from public.study_sessions s
    where s.user_id = p_user_id
      and s.duration_seconds > 0
      and s.end_time > s.start_time
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
    p_user_id, 'secret_break_enemy', v_metric, 'break_all_sessions_v1', clock_timestamp()
  ) on conflict(user_id, achievement_id) do update set
    metric_value = greatest(public.achievement_metric_progress.metric_value, excluded.metric_value),
    source_version = excluded.source_version,
    updated_at = clock_timestamp();

  if v_metric >= 1 then
    insert into public.achievement_reward_candidates(
      user_id, achievement_id, tier, source_version, event_key, evidence
    ) values (
      p_user_id, 'secret_break_enemy', 1, 'break_all_sessions_v1',
      p_user_id::text || '|secret_break_enemy|all-sessions|tier_1',
      jsonb_build_object('all_session_sources', true, 'window_minutes', 300, 'focus_minutes', 270)
    ) on conflict do nothing;
  end if;
  return v_metric;
end;
$$;

create or replace function public._study_session_project_break_enemy()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.project_break_enemy_metric(new.user_id);
  end if;
  if tg_op in ('DELETE', 'UPDATE') and old.user_id is distinct from new.user_id then
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
  alter column source_version set default 'group_all_sessions_v1';
update public.group_achievement_daily
set source_version = 'group_all_sessions_v1';

alter table public.group_achievement_weekly
  rename column verified_seconds to total_seconds;

update public.achievements_dict
set description = 'ISO haftasında grubunda toplam sürede tek başına birinci olma sayısı'
where id = 'alpha_wolf_weekly';

insert into public.achievement_metric_definitions
  (achievement_id, metric_key, projection_kind, source_version)
values ('alpha_wolf_weekly', 'weekly_alpha_wins', 'cumulative', 'weekly_alpha_all_sessions_v1')
on conflict (achievement_id) do update set
  metric_key = excluded.metric_key,
  projection_kind = excluded.projection_kind,
  source_version = excluded.source_version,
  updated_at = clock_timestamp();

create or replace function public.project_group_day(p_group_id uuid, p_day date)
returns integer language plpgsql security definer set search_path = public as $$
declare v_affected integer;
begin
  with bounds as (
    select (p_day::timestamp at time zone 'Europe/Istanbul') as lo,
      ((p_day + 1)::timestamp at time zone 'Europe/Istanbul') as hi
  ), seg as (
    select s.user_id, greatest(s.start_time, b.lo) a, least(s.end_time, b.hi) z
    from public.study_sessions s
    join public.group_members gm on gm.user_id = s.user_id
      and gm.group_id = p_group_id
      and s.start_time >= gm.joined_at
      and (gm.left_at is null or s.start_time < gm.left_at)
    cross join bounds b
    where s.duration_seconds > 0 and s.end_time > b.lo and s.start_time < b.hi
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
      coalesce(l.events, 0), 'group_all_sessions_v1', clock_timestamp()
    from users u left join alpha a using(user_id) left join camp c using(user_id)
      left join loco l using(user_id)
  on conflict(group_id, istanbul_day, user_id) do update set
    alpha_wins = excluded.alpha_wins,
    campfire_seconds = excluded.campfire_seconds,
    locomotive_events = excluded.locomotive_events,
    source_version = excluded.source_version,
    updated_at = clock_timestamp();
  get diagnostics v_affected = row_count;

  insert into public.achievement_metric_progress(user_id, achievement_id, metric_value, source_version, updated_at)
  select user_id, metric, value, 'group_all_sessions_v1', clock_timestamp() from (
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
      and s.start_time >= gm.joined_at
      and (gm.left_at is null or s.start_time < gm.left_at)
    cross join lateral generate_series(
      (timezone('Europe/Istanbul', s.start_time))::date,
      (timezone('Europe/Istanbul', s.end_time))::date,
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
declare r record; v_day date;
begin
  for r in
    select gm.group_id from public.group_members gm
    where gm.user_id = p_user_id
      and p_start >= gm.joined_at
      and (gm.left_at is null or p_start < gm.left_at)
  loop
    for v_day in select generate_series(
      (timezone('Europe/Istanbul', p_start))::date,
      (timezone('Europe/Istanbul', p_end))::date,
      interval '1 day'
    )::date
    loop
      perform public.project_group_day(r.group_id, v_day);
      if v_day < (timezone('Europe/Istanbul', clock_timestamp()))::date then
        perform public.finalize_group_day(r.group_id, v_day);
      end if;
    end loop;
  end loop;
end;
$$;

create or replace function public._study_session_project_group_metrics()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op <> 'DELETE' then
    perform public.refresh_group_metrics_for_session(new.user_id, new.start_time, new.end_time);
  end if;
  if tg_op <> 'INSERT' then
    perform public.refresh_group_metrics_for_session(old.user_id, old.start_time, old.end_time);
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
declare v_affected integer;
begin
  if extract(isodow from p_week_start) <> 1 then
    raise exception 'iso_week_start_must_be_monday';
  end if;
  with bounds as (
    select (p_week_start::timestamp at time zone 'Europe/Istanbul') as lo,
      ((p_week_start + 7)::timestamp at time zone 'Europe/Istanbul') as hi
  ), sessions as (
    select s.user_id, greatest(s.start_time, b.lo) as started_at,
      least(s.end_time, b.hi) as ended_at
    from public.study_sessions s
    join public.group_members gm on gm.user_id = s.user_id
      and gm.group_id = p_group_id
      and s.start_time >= gm.joined_at
      and (gm.left_at is null or s.start_time < gm.left_at)
    cross join bounds b
    where s.duration_seconds > 0 and s.end_time > b.lo and s.start_time < b.hi
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

  insert into public.achievement_metric_progress(user_id, achievement_id, metric_value, source_version, updated_at)
  select user_id, 'alpha_wolf_weekly', sum(weekly_alpha_wins)::bigint,
    'weekly_alpha_all_sessions_v1', clock_timestamp()
  from public.group_achievement_weekly where finalized_at is not null group by user_id
  on conflict(user_id, achievement_id) do update set
    metric_value = greatest(public.achievement_metric_progress.metric_value, excluded.metric_value),
    source_version = excluded.source_version,
    updated_at = clock_timestamp();
  return v_affected;
end;
$$;

create or replace function public.finalize_group_week(p_group_id uuid, p_week_start date)
returns integer language plpgsql security definer set search_path = public as $$
declare r record; t record; v_count integer;
begin
  if p_week_start + 7 > date_trunc('week', timezone('Europe/Istanbul', clock_timestamp()))::date then
    raise exception 'group_week_not_closed';
  end if;
  perform public.project_group_week(p_group_id, p_week_start);
  update public.group_achievement_weekly
  set finalized_at = coalesce(finalized_at, clock_timestamp())
  where group_id = p_group_id and iso_week_start = p_week_start;
  get diagnostics v_count = row_count;
  perform public.project_group_week(p_group_id, p_week_start);
  for r in
    select user_id from public.group_achievement_weekly
    where group_id = p_group_id and iso_week_start = p_week_start and weekly_alpha_wins = 1
  loop
    for t in
      select (tier_def->>'tier')::integer as tier,
        (tier_def->>'threshold')::integer as threshold,
        (tier_def->>'xp')::integer as xp
      from public.achievements_dict d
      cross join lateral jsonb_array_elements(d.tiers) tier_def
      where d.id = 'alpha_wolf_weekly'
    loop
      if (select metric_value from public.achievement_metric_progress
          where user_id = r.user_id and achievement_id = 'alpha_wolf_weekly') >= t.threshold then
        perform public._create_pending_achievement_reward(
          r.user_id, 'alpha_wolf_weekly', t.tier, t.xp,
          format('Lider Kurt: %s haftalık birincilik', t.threshold)
        );
      end if;
    end loop;
  end loop;
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
      and s.start_time >= gm.joined_at
      and (gm.left_at is null or s.start_time < gm.left_at)
    cross join lateral generate_series(
      date_trunc('week', timezone('Europe/Istanbul', s.start_time))::date,
      date_trunc('week', timezone('Europe/Istanbul', s.end_time))::date,
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
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    for r in select jobid from cron.job where jobname in (
      'verified-group-day-finalizer', 'verified-group-week-finalizer', 'verified-session-rollout-retention'
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
  end if;
end;
$$;

-- Tarihsel kullanıcı verisini silmeden yalnız türetilmiş projeksiyonları yeni
-- kuralla baştan üret. Ledger, rozet, pending reward ve study_sessions aynen kalır.
delete from public.group_achievement_daily;
delete from public.group_achievement_weekly;
delete from public.achievement_metric_progress
where achievement_id in ('alpha_wolf', 'campfire_hours', 'locomotive', 'alpha_wolf_weekly', 'secret_break_enemy');

do $$
declare r record;
begin
  for r in select distinct user_id from public.study_sessions loop
    perform public.project_break_enemy_metric(r.user_id);
  end loop;
  perform public.catch_up_group_days();
  perform public.catch_up_group_weeks();
end;
$$;

revoke all on function public.break_enemy_metric(uuid) from public;
revoke all on function public.project_break_enemy_metric(uuid) from public;
revoke all on function public.project_group_day(uuid, date) from public;
revoke all on function public.finalize_group_day(uuid, date) from public;
revoke all on function public.catch_up_group_days() from public;
revoke all on function public.refresh_group_metrics_for_session(uuid, timestamptz, timestamptz) from public;
revoke all on function public.project_group_week(uuid, date) from public;
revoke all on function public.finalize_group_week(uuid, date) from public;
revoke all on function public.catch_up_group_weeks() from public;

notify pgrst, 'reload schema';
