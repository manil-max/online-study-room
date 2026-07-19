-- WP-217: Mola Düşmanı verified interval motoru. Backfill tanımlıdır, çalışmaz.

create table if not exists public.achievement_reward_candidates (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null references public.achievements_dict(id),
  tier integer not null check (tier > 0),
  source_version text not null,
  event_key text not null unique,
  status text not null default 'dormant'
    check (status in ('dormant', 'ready', 'consumed', 'excluded')),
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp(),
  primary key(user_id, achievement_id, tier, source_version)
);
alter table public.achievement_reward_candidates enable row level security;
revoke all on table public.achievement_reward_candidates from public, anon, authenticated;

create or replace function public.break_enemy_verified_metric(p_user_id uuid)
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
    select range_agg(tstzrange(s.started_at, s.ended_at, '[)'))
    from public.live_study_segments s
    join public.live_study_runs run on run.id = s.run_id
    where s.user_id = p_user_id and s.ended_at is not null
      and run.status = 'finalized'
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
    if v_covered >= 16200 then return 1; end if; -- exact 270 minutes
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
  v_metric := public.break_enemy_verified_metric(p_user_id);
  insert into public.achievement_metric_progress(
    user_id, achievement_id, metric_value, source_version, updated_at
  ) values (
    p_user_id, 'secret_break_enemy', v_metric, 'break_verified_v1', clock_timestamp()
  ) on conflict(user_id, achievement_id) do update set
    metric_value = greatest(public.achievement_metric_progress.metric_value, excluded.metric_value),
    source_version = excluded.source_version,
    updated_at = case
      when public.achievement_metric_progress.metric_value < excluded.metric_value
        or public.achievement_metric_progress.source_version <> excluded.source_version
      then clock_timestamp() else public.achievement_metric_progress.updated_at end;
  if v_metric >= 1 then
    insert into public.achievement_reward_candidates(
      user_id, achievement_id, tier, source_version, event_key, evidence
    ) values (
      p_user_id, 'secret_break_enemy', 1, 'break_verified_v1',
      p_user_id::text || '|secret_break_enemy|tier_1',
      jsonb_build_object('verified_only', true, 'window_minutes', 300, 'focus_minutes', 270)
    ) on conflict do nothing;
  end if;
  return v_metric;
end;
$$;

create or replace function public._break_enemy_segment_projector()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.achievement_metric_dirty(
    scope_type, scope_id, istanbul_day, source_version, reason
  ) values (
    'user', new.user_id, (timezone('Europe/Istanbul', new.started_at))::date,
    'break_verified_v1', 'verified_segment_closed'
  ) on conflict(scope_type, scope_id, istanbul_day, source_version) do update set
    reason = excluded.reason, dirtied_at = clock_timestamp(), processed_at = null;
  perform public.project_break_enemy_metric(new.user_id);
  return new;
end;
$$;
drop trigger if exists live_segments_project_break_enemy on public.live_study_segments;
create trigger live_segments_project_break_enemy
  after update of ended_at on public.live_study_segments
  for each row when (old.ended_at is null and new.ended_at is not null)
  execute function public._break_enemy_segment_projector();

create or replace view public.break_enemy_legacy_proxy_audit as
select s.user_id,
  count(*) filter(where s.source = 'live' and s.live_run_id is null
    and s.duration_seconds between 1 and 18000
    and s.end_time >= s.start_time) as plausible_unverified_rows,
  count(*) filter(where s.live_run_id is null) as excluded_from_reward_rows
from public.study_sessions s group by s.user_id;
revoke all on public.break_enemy_legacy_proxy_audit from public, anon, authenticated;

create or replace function public.run_break_enemy_backfill_batch(
  p_job_id uuid, p_batch_limit integer default 100
)
returns integer language plpgsql security definer set search_path = public as $$
declare v_user uuid; v_count integer := 0; v_cursor uuid;
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  if p_batch_limit not between 1 and 500 then raise exception 'invalid_batch_limit'; end if;
  select cursor_user_id into v_cursor from public.achievement_backfill_jobs
    where id = p_job_id and job_type = 'break_enemy_verified_v1' for update;
  if not found then raise exception 'backfill_job_not_found'; end if;
  for v_user in select id from auth.users
    where v_cursor is null or id > v_cursor order by id limit p_batch_limit
  loop
    perform public.project_break_enemy_metric(v_user);
    v_cursor := v_user; v_count := v_count + 1;
  end loop;
  update public.achievement_backfill_jobs set cursor_user_id = v_cursor,
    scanned_count = scanned_count + v_count, updated_at = clock_timestamp()
    where id = p_job_id;
  return v_count;
end;
$$;

revoke all on function public.break_enemy_verified_metric(uuid) from public;
revoke all on function public.project_break_enemy_metric(uuid) from public;
revoke all on function public.run_break_enemy_backfill_batch(uuid, integer) from public;
-- No job row is inserted and no backfill is scheduled by this migration.
