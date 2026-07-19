-- WP-216: server-issued live run/segment expansion.
-- Expansion only: legacy session inserts and the current XP evaluator stay active.

create table if not exists public.live_study_runs (
  id uuid primary key default gen_random_uuid(),
  run_token uuid not null unique default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_request_id uuid not null,
  group_id_snapshot uuid,
  subject_id_snapshot uuid references public.subjects(id) on delete set null,
  status text not null default 'running'
    check (status in ('running', 'paused', 'finalized', 'cancelled')),
  client_build integer not null default 0 check (client_build >= 0),
  started_at timestamptz not null default clock_timestamp(),
  finalized_at timestamptz,
  session_id uuid unique,
  created_at timestamptz not null default clock_timestamp(),
  unique (user_id, client_request_id),
  check ((status = 'finalized') = (finalized_at is not null and session_id is not null))
);

-- A group UUID is an immutable audit/metric snapshot. Deliberately no FK: deleting
-- a group must not erase or cascade the context captured at run start.
create unique index if not exists live_study_runs_one_active_user
  on public.live_study_runs(user_id)
  where status in ('running', 'paused');
create index if not exists live_study_runs_user_started
  on public.live_study_runs(user_id, started_at desc);
create index if not exists live_study_runs_group_started
  on public.live_study_runs(group_id_snapshot, started_at desc)
  where group_id_snapshot is not null;

create table if not exists public.live_study_segments (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.live_study_runs(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  ordinal integer not null check (ordinal > 0),
  started_at timestamptz not null default clock_timestamp(),
  ended_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  unique (run_id, ordinal),
  check (ended_at is null or ended_at >= started_at)
);
create unique index if not exists live_study_segments_one_open_run
  on public.live_study_segments(run_id) where ended_at is null;
create index if not exists live_study_segments_user_time
  on public.live_study_segments(user_id, started_at, ended_at);

alter table public.study_sessions
  add column if not exists live_run_id uuid;

do $migration$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'study_sessions_live_run_id_fkey'
      and conrelid = 'public.study_sessions'::regclass
  ) then
    alter table public.study_sessions
      add constraint study_sessions_live_run_id_fkey
      foreign key (live_run_id) references public.live_study_runs(id)
      on delete restrict not valid;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'study_sessions_live_run_id_key'
      and conrelid = 'public.study_sessions'::regclass
  ) then
    alter table public.study_sessions
      add constraint study_sessions_live_run_id_key unique (live_run_id);
  end if;
end
$migration$;

-- Client DML remains compatible, but it can only create/update/delete legacy
-- unverified rows. A SECURITY DEFINER lifecycle is the sole verified writer.
drop policy if exists sessions_insert on public.study_sessions;
create policy sessions_insert on public.study_sessions
  for insert to authenticated
  with check (user_id = auth.uid() and live_run_id is null);

drop policy if exists sessions_update on public.study_sessions;
create policy sessions_update on public.study_sessions
  for update to authenticated
  using (user_id = auth.uid() and live_run_id is null)
  with check (user_id = auth.uid() and live_run_id is null);

drop policy if exists sessions_delete on public.study_sessions;
create policy sessions_delete on public.study_sessions
  for delete to authenticated
  using (user_id = auth.uid() and live_run_id is null);

create or replace function public._guard_verified_session_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.live_run_id is not null
     and current_setting('app.allow_verified_session_write', true) <> 'on' then
    raise exception 'verified_session_immutable';
  end if;
  return new;
end;
$$;
drop trigger if exists study_sessions_guard_verified_update
  on public.study_sessions;
create trigger study_sessions_guard_verified_update
  before update on public.study_sessions
  for each row execute function public._guard_verified_session_update();

alter table public.live_study_runs enable row level security;
alter table public.live_study_segments enable row level security;
revoke all on table public.live_study_runs from public, anon, authenticated;
revoke all on table public.live_study_segments from public, anon, authenticated;

create or replace function public._live_run_payload(p_run public.live_study_runs)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', p_run.id,
    'run_token', p_run.run_token,
    'user_id', p_run.user_id,
    'group_id_snapshot', p_run.group_id_snapshot,
    'subject_id_snapshot', p_run.subject_id_snapshot,
    'status', p_run.status,
    'client_build', p_run.client_build,
    'started_at', p_run.started_at,
    'finalized_at', p_run.finalized_at,
    'session_id', p_run.session_id
  );
$$;

create or replace function public.start_verified_live_run(
  p_client_request_id uuid,
  p_group_id uuid default null,
  p_subject_id uuid default null,
  p_client_build integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_run public.live_study_runs;
begin
  if v_uid is null then raise exception 'authentication_required'; end if;
  if p_client_request_id is null or coalesce(p_client_build, 0) < 0 then
    raise exception 'invalid_live_run_request';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 216));
  select * into v_run from public.live_study_runs
   where user_id = v_uid and client_request_id = p_client_request_id;
  if found then return public._live_run_payload(v_run); end if;

  if exists (
    select 1 from public.live_study_runs
    where user_id = v_uid and status in ('running', 'paused')
  ) then
    raise exception 'active_live_run_exists';
  end if;
  if p_group_id is not null and not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = v_uid
  ) then
    raise exception 'group_membership_required';
  end if;
  if p_subject_id is not null and not exists (
    select 1 from public.subjects where id = p_subject_id and user_id = v_uid
  ) then
    raise exception 'subject_ownership_required';
  end if;

  insert into public.live_study_runs (
    user_id, client_request_id, group_id_snapshot, subject_id_snapshot,
    client_build
  ) values (
    v_uid, p_client_request_id, p_group_id, p_subject_id,
    coalesce(p_client_build, 0)
  ) returning * into v_run;
  insert into public.live_study_segments(run_id, user_id, ordinal)
  values (v_run.id, v_uid, 1);
  return public._live_run_payload(v_run);
end;
$$;

create or replace function public.pause_verified_live_run(p_run_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_run public.live_study_runs;
  v_now timestamptz := clock_timestamp();
begin
  if v_uid is null then raise exception 'authentication_required'; end if;
  select * into v_run from public.live_study_runs
   where run_token = p_run_token and user_id = v_uid for update;
  if not found then raise exception 'live_run_not_found'; end if;
  if v_run.status = 'running' then
    update public.live_study_segments set ended_at = v_now
     where run_id = v_run.id and ended_at is null;
    update public.live_study_runs set status = 'paused'
     where id = v_run.id returning * into v_run;
  elsif v_run.status <> 'paused' then
    raise exception 'live_run_not_active';
  end if;
  return public._live_run_payload(v_run);
end;
$$;

create or replace function public.resume_verified_live_run(p_run_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_run public.live_study_runs;
  v_ordinal integer;
begin
  if v_uid is null then raise exception 'authentication_required'; end if;
  select * into v_run from public.live_study_runs
   where run_token = p_run_token and user_id = v_uid for update;
  if not found then raise exception 'live_run_not_found'; end if;
  if v_run.status = 'paused' then
    select coalesce(max(ordinal), 0) + 1 into v_ordinal
      from public.live_study_segments where run_id = v_run.id;
    insert into public.live_study_segments(run_id, user_id, ordinal)
    values (v_run.id, v_uid, v_ordinal);
    update public.live_study_runs set status = 'running'
     where id = v_run.id returning * into v_run;
  elsif v_run.status <> 'running' then
    raise exception 'live_run_not_active';
  end if;
  return public._live_run_payload(v_run);
end;
$$;

create or replace function public.finalize_verified_live_run(p_run_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_run public.live_study_runs;
  v_now timestamptz := clock_timestamp();
  v_duration integer;
  v_session public.study_sessions;
begin
  if v_uid is null then raise exception 'authentication_required'; end if;
  select * into v_run from public.live_study_runs
   where run_token = p_run_token and user_id = v_uid for update;
  if not found then raise exception 'live_run_not_found'; end if;
  if v_run.status = 'finalized' then
    select * into v_session from public.study_sessions where id = v_run.session_id;
    return to_jsonb(v_session);
  end if;
  if v_run.status not in ('running', 'paused') then
    raise exception 'live_run_not_active';
  end if;

  update public.live_study_segments set ended_at = v_now
   where run_id = v_run.id and ended_at is null;
  select coalesce(sum(greatest(0, floor(extract(epoch from (ended_at - started_at)))::integer)), 0)
    into v_duration
    from public.live_study_segments where run_id = v_run.id;

  insert into public.study_sessions (
    id, user_id, subject_id, start_time, end_time, duration_seconds,
    source, live_run_id
  ) values (
    v_run.id, v_uid, v_run.subject_id_snapshot, v_run.started_at, v_now,
    v_duration, 'live', v_run.id
  ) on conflict (id) do nothing
  returning * into v_session;
  if not found then
    select * into v_session from public.study_sessions
      where id = v_run.id and live_run_id = v_run.id and user_id = v_uid;
    if not found then raise exception 'verified_session_conflict'; end if;
  end if;
  update public.live_study_runs
    set status = 'finalized', finalized_at = v_now, session_id = v_session.id
    where id = v_run.id;
  return to_jsonb(v_session);
end;
$$;

create table if not exists public.verified_session_runtime_config (
  singleton boolean primary key default true check (singleton),
  minimum_verified_xp_build integer check (minimum_verified_xp_build > 0),
  shadow_mode boolean not null default true,
  updated_at timestamptz not null default clock_timestamp()
);
insert into public.verified_session_runtime_config(singleton, minimum_verified_xp_build, shadow_mode)
values (true, null, true) on conflict (singleton) do nothing;
alter table public.verified_session_runtime_config enable row level security;
revoke all on table public.verified_session_runtime_config from public, anon, authenticated;

create table if not exists public.verified_session_rollout_daily (
  day date not null default (timezone('Europe/Istanbul', clock_timestamp()))::date,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'windows', 'web', 'other')),
  client_build integer not null check (client_build >= 0),
  capability boolean not null default false,
  dart_app_starts integer not null default 0 check (dart_app_starts >= 0),
  native_widget_starts integer not null default 0 check (native_widget_starts >= 0),
  native_notification_starts integer not null default 0 check (native_notification_starts >= 0),
  verified_finalizes integer not null default 0 check (verified_finalizes >= 0),
  unverified_fallbacks integer not null default 0 check (unverified_fallbacks >= 0),
  finalize_failures integer not null default 0 check (finalize_failures >= 0),
  updated_at timestamptz not null default clock_timestamp(),
  primary key(day, user_id, platform, client_build)
);
create index if not exists verified_session_rollout_daily_day
  on public.verified_session_rollout_daily(day);
alter table public.verified_session_rollout_daily enable row level security;
revoke all on table public.verified_session_rollout_daily from public, anon, authenticated;

create or replace function public.prune_verified_session_rollout()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  delete from public.verified_session_rollout_daily
    where day < (timezone('Europe/Istanbul', clock_timestamp()))::date - 30;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.verified_session_client_config()
returns jsonb
language sql
security definer
stable
set search_path = public
as $$
  select jsonb_build_object(
    'minimum_verified_xp_build', minimum_verified_xp_build,
    'shadow_mode', shadow_mode
  ) from public.verified_session_runtime_config where singleton;
$$;

create or replace function public.record_verified_session_rollout(
  p_platform text,
  p_client_build integer,
  p_capability boolean,
  p_origin text default null,
  p_outcome text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (timezone('Europe/Istanbul', clock_timestamp()))::date;
begin
  if v_uid is null then raise exception 'authentication_required'; end if;
  if p_platform not in ('android', 'ios', 'windows', 'web', 'other')
     or coalesce(p_client_build, -1) < 0
     or (p_origin is not null and p_origin not in ('dart_app', 'native_widget', 'native_notification'))
     or (p_outcome is not null and p_outcome not in ('verified_finalize', 'unverified_fallback', 'finalize_failure')) then
    raise exception 'invalid_rollout_event';
  end if;
  insert into public.verified_session_rollout_daily(
    day, user_id, platform, client_build, capability,
    dart_app_starts, native_widget_starts, native_notification_starts,
    verified_finalizes, unverified_fallbacks, finalize_failures
  ) values (
    v_day, v_uid, p_platform, p_client_build, coalesce(p_capability, false),
    case when p_origin = 'dart_app' then 1 else 0 end,
    case when p_origin = 'native_widget' then 1 else 0 end,
    case when p_origin = 'native_notification' then 1 else 0 end,
    case when p_outcome = 'verified_finalize' then 1 else 0 end,
    case when p_outcome = 'unverified_fallback' then 1 else 0 end,
    case when p_outcome = 'finalize_failure' then 1 else 0 end
  ) on conflict(day, user_id, platform, client_build) do update set
    capability = public.verified_session_rollout_daily.capability or excluded.capability,
    dart_app_starts = public.verified_session_rollout_daily.dart_app_starts + excluded.dart_app_starts,
    native_widget_starts = public.verified_session_rollout_daily.native_widget_starts + excluded.native_widget_starts,
    native_notification_starts = public.verified_session_rollout_daily.native_notification_starts + excluded.native_notification_starts,
    verified_finalizes = public.verified_session_rollout_daily.verified_finalizes + excluded.verified_finalizes,
    unverified_fallbacks = public.verified_session_rollout_daily.unverified_fallbacks + excluded.unverified_fallbacks,
    finalize_failures = public.verified_session_rollout_daily.finalize_failures + excluded.finalize_failures,
    updated_at = clock_timestamp();
  perform public.prune_verified_session_rollout();
end;
$$;

-- Event-time pruning is the primary path. pg_cron additionally enforces the
-- retention ceiling during periods with no client events.
do $migration$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule(
      'verified-session-rollout-retention',
      '17 1 * * *',
      'select public.prune_verified_session_rollout()'
    );
  else
    raise notice 'pg_cron yok; rollout retention her record RPC çağrısında uygulanır.';
  end if;
end
$migration$;

revoke all on function public._guard_verified_session_update() from public;
revoke all on function public._live_run_payload(public.live_study_runs) from public;
revoke all on function public.start_verified_live_run(uuid, uuid, uuid, integer) from public;
revoke all on function public.pause_verified_live_run(uuid) from public;
revoke all on function public.resume_verified_live_run(uuid) from public;
revoke all on function public.finalize_verified_live_run(uuid) from public;
revoke all on function public.verified_session_client_config() from public;
revoke all on function public.record_verified_session_rollout(text, integer, boolean, text, text) from public;
revoke all on function public.prune_verified_session_rollout() from public;
grant execute on function public.start_verified_live_run(uuid, uuid, uuid, integer) to authenticated;
grant execute on function public.pause_verified_live_run(uuid) to authenticated;
grant execute on function public.resume_verified_live_run(uuid) to authenticated;
grant execute on function public.finalize_verified_live_run(uuid) to authenticated;
grant execute on function public.verified_session_client_config() to authenticated;
grant execute on function public.record_verified_session_rollout(text, integer, boolean, text, text) to authenticated;

comment on column public.study_sessions.live_run_id is
  'Non-null only for server-finalized verified sessions; legacy client rows stay null.';
comment on table public.verified_session_rollout_daily is
  '30-day user/day aggregate only; no raw session content, email, or auth token.';
