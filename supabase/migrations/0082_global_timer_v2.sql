-- 0082_global_timer_v2.sql
-- WP-341: Global timer V2 sunucu çekirdeği ve legacy-uyumlu migration.
--
-- V1 live run/finalization yolu, native timer ve istemci DTO'ları değişmeden kalır.
-- V2 yalnız kapalı feature flag arkasında, kullanıcı-kapsamlı komut idempotency'si
-- ve tek aktif study-run invariant'ı ile additive olarak çalışır.
--
-- Geri alma (Rollback): `global_timer_v2_runtime_config.v2_enabled=false` yap;
-- istemci V2 çağrılarını durdur. Yeni tablolar/satırlar silinmez, gerekirse ileri
-- migration ile RPC izinleri kaldırılır. Uygulanmış V1/V2 run kayıtları değiştirilmez.

alter table public.live_study_runs
  add column if not exists protocol_version integer not null default 1,
  add column if not exists run_kind text not null default 'study',
  add column if not exists effective_started_at timestamptz,
  add column if not exists ended_at timestamptz,
  add column if not exists accounting_group_id_snapshot uuid,
  add column if not exists origin text,
  add column if not exists controller_device_id uuid,
  add column if not exists run_revision bigint not null default 1,
  add column if not exists user_state_version bigint not null default 1,
  add column if not exists lease_expires_at timestamptz,
  add column if not exists updated_at timestamptz not null default clock_timestamp();

update public.live_study_runs
set protocol_version = 1,
    run_kind = 'study',
    effective_started_at = coalesce(effective_started_at, started_at),
    run_revision = greatest(coalesce(run_revision, 1), 1),
    user_state_version = greatest(coalesce(user_state_version, 1), 1),
    updated_at = coalesce(updated_at, clock_timestamp())
where effective_started_at is null
   or protocol_version is null
   or run_kind is null
   or run_revision is null
   or user_state_version is null;

do $migration$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.live_study_runs'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%status%'
  loop
    execute format('alter table public.live_study_runs drop constraint %I', v_constraint.conname);
  end loop;
end
$migration$;

alter table public.live_study_runs
  add constraint live_study_runs_status_v1_v2_check
    check (status in ('running', 'paused', 'finalized', 'cancelled', 'stopped', 'abandoned')),
  add constraint live_study_runs_protocol_version_check
    check (protocol_version in (1, 2)),
  add constraint live_study_runs_run_kind_check
    check (run_kind = 'study'),
  add constraint live_study_runs_revision_check
    check (run_revision >= 1 and user_state_version >= 1),
  add constraint live_study_runs_legacy_finalized_check
    check (
      protocol_version <> 1
      or (status = 'finalized') = (finalized_at is not null and session_id is not null)
    ),
  add constraint live_study_runs_v2_terminal_check
    check (
      protocol_version = 1
      or (status in ('running', 'stopped', 'abandoned')
          and effective_started_at is not null
          and (status = 'running') = (ended_at is null))
    );

drop index if exists public.live_study_runs_one_active_user;
create unique index live_study_runs_one_active_study_user
  on public.live_study_runs(user_id)
  where run_kind = 'study' and status in ('running', 'paused');
create index if not exists live_study_runs_v2_lease_idx
  on public.live_study_runs(lease_expires_at)
  where protocol_version = 2 and status = 'running';

create table if not exists public.user_timer_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state_version bigint not null default 0 check (state_version >= 0),
  current_run_id uuid references public.live_study_runs(id) on delete set null,
  updated_at timestamptz not null default clock_timestamp()
);

create table if not exists public.global_timer_commands (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  command_id uuid not null,
  device_id uuid not null references public.push_devices(id) on delete restrict,
  action text not null check (action in ('start', 'stop', 'heartbeat')),
  run_id uuid references public.live_study_runs(id) on delete set null,
  expected_run_revision bigint,
  accepted_run_revision bigint,
  accepted_state_version bigint,
  client_occurred_at timestamptz,
  server_received_at timestamptz not null default clock_timestamp(),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  request_fingerprint jsonb not null check (jsonb_typeof(request_fingerprint) = 'object'),
  result_code text not null check (result_code in ('applied', 'duplicate', 'adopt_existing', 'already_stopped', 'stale')),
  result_snapshot jsonb not null check (jsonb_typeof(result_snapshot) = 'object'),
  created_at timestamptz not null default clock_timestamp(),
  unique (user_id, command_id)
);
create index if not exists global_timer_commands_user_created_idx
  on public.global_timer_commands(user_id, created_at desc);

create table if not exists public.global_timer_device_state (
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null references public.push_devices(id) on delete cascade,
  protocol_version integer not null default 2 check (protocol_version = 2),
  last_seen_state_version bigint not null default 0 check (last_seen_state_version >= 0),
  last_applied_state_version bigint not null default 0 check (last_applied_state_version >= 0),
  last_run_id uuid references public.live_study_runs(id) on delete set null,
  last_run_revision bigint,
  last_apply_status text not null default 'seen'
    check (last_apply_status in ('seen', 'native_applied', 'deferred', 'failed', 'opted_out')),
  last_apply_error_code text,
  last_seen_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  primary key (user_id, device_id)
);

create table if not exists public.global_timer_v2_runtime_config (
  singleton boolean primary key default true check (singleton),
  v2_enabled boolean not null default false,
  updated_at timestamptz not null default clock_timestamp()
);
insert into public.global_timer_v2_runtime_config(singleton, v2_enabled)
values (true, false) on conflict (singleton) do nothing;

alter table public.user_timer_state enable row level security;
alter table public.global_timer_commands enable row level security;
alter table public.global_timer_device_state enable row level security;
alter table public.global_timer_v2_runtime_config enable row level security;
revoke all on table public.user_timer_state from public, anon, authenticated;
revoke all on table public.global_timer_commands from public, anon, authenticated;
revoke all on table public.global_timer_device_state from public, anon, authenticated;
revoke all on table public.global_timer_v2_runtime_config from public, anon, authenticated;

create or replace function public._global_timer_v2_snapshot(
  p_user_id uuid,
  p_device_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select jsonb_build_object(
    'user_id', p_user_id,
    'server_time', clock_timestamp(),
    'state_version', coalesce(s.state_version, 0),
    'run', case when r.id is null then null else jsonb_build_object(
      'id', r.id,
      'status', r.status,
      'protocol_version', r.protocol_version,
      'run_revision', r.run_revision,
      'user_state_version', r.user_state_version,
      'effective_started_at', r.effective_started_at,
      'lease_expires_at', r.lease_expires_at,
      'origin', r.origin
    ) end,
    'device', case when d.device_id is null then null else jsonb_build_object(
      'last_seen_state_version', d.last_seen_state_version,
      'last_applied_state_version', d.last_applied_state_version,
      'last_apply_status', d.last_apply_status
    ) end
  )
  from (select p_user_id as user_id) u
  left join public.user_timer_state s on s.user_id = u.user_id
  left join public.live_study_runs r on r.id = s.current_run_id
  left join public.global_timer_device_state d
    on d.user_id = u.user_id and d.device_id = p_device_id;
$$;

create or replace function public.apply_global_timer_command(
  p_command_id uuid,
  p_device_id uuid,
  p_action text,
  p_run_id uuid default null,
  p_expected_run_revision bigint default null,
  p_client_occurred_at timestamptz default null,
  p_payload jsonb default '{}'::jsonb,
  p_protocol_version integer default 2
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_existing public.global_timer_commands%rowtype;
  v_state public.user_timer_state%rowtype;
  v_run public.live_study_runs%rowtype;
  v_snapshot jsonb;
  v_fingerprint jsonb;
  v_result text := 'applied';
  v_now timestamptz := clock_timestamp();
  v_primary_group_id uuid;
  v_subject_id uuid;
  v_origin text;
begin
  if v_uid is null then raise exception 'authentication_required'; end if;
  if p_command_id is null or p_device_id is null or p_protocol_version <> 2
     or p_action not in ('start', 'stop', 'heartbeat')
     or p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'invalid_global_timer_command';
  end if;
  if not (select v2_enabled from public.global_timer_v2_runtime_config where singleton) then
    raise exception 'global_timer_v2_disabled';
  end if;
  if not exists (
    select 1 from public.push_devices
    where id = p_device_id and user_id = v_uid and disabled_at is null
  ) then
    raise exception 'active_device_required';
  end if;

  v_fingerprint := jsonb_build_object(
    'action', p_action, 'run_id', p_run_id,
    'expected_run_revision', p_expected_run_revision,
    'payload', p_payload, 'protocol_version', p_protocol_version
  );
  select * into v_existing from public.global_timer_commands
  where user_id = v_uid and command_id = p_command_id;
  if found then
    if v_existing.request_fingerprint <> v_fingerprint then
      raise exception 'command_id_payload_mismatch';
    end if;
    return v_existing.result_snapshot || jsonb_build_object('result_code', 'duplicate');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 216));
  insert into public.user_timer_state(user_id) values (v_uid)
  on conflict (user_id) do nothing;
  select * into v_state from public.user_timer_state where user_id = v_uid for update;

  insert into public.global_timer_device_state(user_id, device_id, last_seen_at, updated_at)
  values (v_uid, p_device_id, v_now, v_now)
  on conflict (user_id, device_id) do update set
    last_seen_at = excluded.last_seen_at, updated_at = excluded.updated_at;

  if p_action = 'start' then
    select * into v_run from public.live_study_runs
    where user_id = v_uid and run_kind = 'study' and status in ('running', 'paused')
    order by created_at desc limit 1 for update;
    if found and v_run.protocol_version = 2
       and v_run.status = 'running' and v_run.lease_expires_at <= v_now then
      update public.live_study_runs set
        status = 'abandoned', ended_at = v_now, lease_expires_at = null,
        run_revision = run_revision + 1,
        user_state_version = v_state.state_version + 1,
        updated_at = v_now
      where id = v_run.id returning * into v_run;
      update public.user_timer_state set state_version = state_version + 1,
        current_run_id = null, updated_at = v_now where user_id = v_uid
      returning * into v_state;
      perform public.apply_multi_group_presence_state('offline', null, 0, null);
      v_run := null;
    end if;

    if v_run.id is not null then
      v_result := 'adopt_existing';
    else
      v_subject_id := nullif(p_payload->>'subject_id', '')::uuid;
      if v_subject_id is not null and not exists (
        select 1 from public.subjects where id = v_subject_id and user_id = v_uid
      ) then raise exception 'subject_ownership_required'; end if;
      v_origin := coalesce(nullif(p_payload->>'origin', ''), 'app');
      if v_origin not in ('app', 'widget', 'notification', 'recovery') then
        raise exception 'invalid_global_timer_origin';
      end if;
      select p.primary_group_id into v_primary_group_id
      from public.user_group_preferences p
      join public.group_members gm on gm.group_id = p.primary_group_id
        and gm.user_id = v_uid and gm.left_at is null
      where p.user_id = v_uid;
      update public.user_timer_state set state_version = state_version + 1,
        updated_at = v_now where user_id = v_uid returning * into v_state;
      insert into public.live_study_runs(
        user_id, client_request_id, group_id_snapshot, subject_id_snapshot,
        status, protocol_version, run_kind, effective_started_at,
        accounting_group_id_snapshot, origin, controller_device_id,
        run_revision, user_state_version, lease_expires_at, updated_at
      ) values (
        v_uid, p_command_id, v_primary_group_id, v_subject_id,
        'running', 2, 'study', v_now, v_primary_group_id, v_origin, p_device_id,
        1, v_state.state_version, v_now + interval '150 seconds', v_now
      ) returning * into v_run;
      update public.user_timer_state set current_run_id = v_run.id,
        updated_at = v_now where user_id = v_uid;
      perform public.apply_multi_group_presence_state('studying', v_now, 0, v_subject_id);
    end if;
  elsif p_action = 'stop' then
    if p_run_id is null or p_expected_run_revision is null then
      raise exception 'stop_run_revision_required';
    end if;
    select * into v_run from public.live_study_runs
    where id = p_run_id and user_id = v_uid for update;
    if not found then raise exception 'global_timer_run_not_found'; end if;
    if v_run.protocol_version <> 2 then raise exception 'global_timer_v2_run_required'; end if;
    if v_run.status in ('stopped', 'abandoned') then
      v_result := 'already_stopped';
    elsif v_run.run_revision <> p_expected_run_revision then
      v_result := 'stale';
    else
      update public.user_timer_state set state_version = state_version + 1,
        current_run_id = case when current_run_id = v_run.id then null else current_run_id end,
        updated_at = v_now where user_id = v_uid returning * into v_state;
      update public.live_study_runs set status = 'stopped', ended_at = v_now,
        lease_expires_at = null, controller_device_id = p_device_id,
        run_revision = run_revision + 1, user_state_version = v_state.state_version,
        updated_at = v_now where id = v_run.id returning * into v_run;
      perform public.apply_multi_group_presence_state('offline', null, 0, null);
    end if;
  else
    if p_run_id is null then raise exception 'heartbeat_run_required'; end if;
    select * into v_run from public.live_study_runs
    where id = p_run_id and user_id = v_uid for update;
    if not found or v_run.protocol_version <> 2 or v_run.status <> 'running' then
      raise exception 'global_timer_run_not_active';
    end if;
    if p_expected_run_revision is not null and v_run.run_revision <> p_expected_run_revision then
      v_result := 'stale';
    else
      update public.live_study_runs set lease_expires_at = v_now + interval '150 seconds',
        controller_device_id = p_device_id, updated_at = v_now
      where id = v_run.id returning * into v_run;
    end if;
  end if;

  v_snapshot := public._global_timer_v2_snapshot(v_uid, p_device_id);
  insert into public.global_timer_commands(
    user_id, command_id, device_id, action, run_id, expected_run_revision,
    accepted_run_revision, accepted_state_version, client_occurred_at,
    payload, request_fingerprint, result_code, result_snapshot
  ) values (
    v_uid, p_command_id, p_device_id, p_action, coalesce(v_run.id, p_run_id),
    p_expected_run_revision, v_run.run_revision,
    coalesce(v_run.user_state_version, v_state.state_version), p_client_occurred_at,
    p_payload, v_fingerprint, v_result, v_snapshot || jsonb_build_object('result_code', v_result)
  );
  return v_snapshot || jsonb_build_object('result_code', v_result);
end;
$$;

create or replace function public.get_global_timer_v2_snapshot(p_device_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'authentication_required'; end if;
  if p_device_id is not null and not exists (
    select 1 from public.push_devices where id = p_device_id and user_id = v_uid and disabled_at is null
  ) then raise exception 'active_device_required'; end if;
  return public._global_timer_v2_snapshot(v_uid, p_device_id);
end;
$$;

create or replace function public.ack_global_timer_v2_snapshot(
  p_device_id uuid,
  p_state_version bigint,
  p_status text,
  p_run_id uuid default null,
  p_run_revision bigint default null,
  p_error_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'authentication_required'; end if;
  if p_state_version is null or p_state_version < 0
     or p_status not in ('seen', 'native_applied', 'deferred', 'failed', 'opted_out')
     or not exists (select 1 from public.push_devices where id = p_device_id and user_id = v_uid and disabled_at is null) then
    raise exception 'invalid_global_timer_ack';
  end if;
  insert into public.global_timer_device_state(
    user_id, device_id, last_seen_state_version, last_applied_state_version,
    last_run_id, last_run_revision, last_apply_status, last_apply_error_code,
    last_seen_at, updated_at
  ) values (
    v_uid, p_device_id, p_state_version,
    case when p_status = 'native_applied' then p_state_version else 0 end,
    p_run_id, p_run_revision, p_status, left(nullif(p_error_code, ''), 120),
    clock_timestamp(), clock_timestamp()
  ) on conflict (user_id, device_id) do update set
    last_seen_state_version = greatest(global_timer_device_state.last_seen_state_version, excluded.last_seen_state_version),
    last_applied_state_version = greatest(global_timer_device_state.last_applied_state_version, excluded.last_applied_state_version),
    last_run_id = excluded.last_run_id,
    last_run_revision = excluded.last_run_revision,
    last_apply_status = excluded.last_apply_status,
    last_apply_error_code = excluded.last_apply_error_code,
    last_seen_at = excluded.last_seen_at,
    updated_at = excluded.updated_at;
  return public._global_timer_v2_snapshot(v_uid, p_device_id);
end;
$$;

create or replace function public.expire_global_timer_v2_leases(p_limit integer default 100)
returns integer
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_run public.live_study_runs%rowtype; v_state public.user_timer_state%rowtype; v_count integer := 0; v_now timestamptz := clock_timestamp();
begin
  if auth.role() is distinct from 'service_role' and current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  if p_limit is null or p_limit not between 1 and 500 then raise exception 'invalid_global_timer_sweeper_limit'; end if;
  for v_run in
    select * from public.live_study_runs
    where protocol_version = 2 and status = 'running' and lease_expires_at <= v_now
    order by lease_expires_at, id limit p_limit for update skip locked
  loop
    perform pg_advisory_xact_lock(hashtextextended(v_run.user_id::text, 216));
    select * into v_state from public.user_timer_state where user_id = v_run.user_id for update;
    update public.user_timer_state set state_version = state_version + 1,
      current_run_id = case when current_run_id = v_run.id then null else current_run_id end,
      updated_at = v_now where user_id = v_run.user_id returning * into v_state;
    update public.live_study_runs set status = 'abandoned', ended_at = v_now,
      lease_expires_at = null, run_revision = run_revision + 1,
      user_state_version = v_state.state_version, updated_at = v_now
    where id = v_run.id and status = 'running' and lease_expires_at <= v_now;
    if found then
      update public.user_live_presence_state set status = 'offline', started_at = null,
        subject_id = null, lease_expires_at = null, state_version = state_version + 1,
        updated_at = v_now where user_id = v_run.user_id and status <> 'offline';
      delete from public.group_live_presence where user_id = v_run.user_id;
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

revoke all on function public._global_timer_v2_snapshot(uuid, uuid) from public, anon, authenticated;
revoke all on function public.apply_global_timer_command(uuid, uuid, text, uuid, bigint, timestamptz, jsonb, integer) from public, anon;
revoke all on function public.get_global_timer_v2_snapshot(uuid) from public, anon;
revoke all on function public.ack_global_timer_v2_snapshot(uuid, bigint, text, uuid, bigint, text) from public, anon;
revoke all on function public.expire_global_timer_v2_leases(integer) from public, anon, authenticated;
grant execute on function public.apply_global_timer_command(uuid, uuid, text, uuid, bigint, timestamptz, jsonb, integer) to authenticated;
grant execute on function public.get_global_timer_v2_snapshot(uuid) to authenticated;
grant execute on function public.ack_global_timer_v2_snapshot(uuid, bigint, text, uuid, bigint, text) to authenticated;
grant execute on function public.expire_global_timer_v2_leases(integer) to service_role;

notify pgrst, 'reload schema';
