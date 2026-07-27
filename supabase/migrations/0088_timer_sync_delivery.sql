-- 0088_timer_sync_delivery.sql
-- WP-370: V2 timer state değişimlerini güvenli outbox/FCM sinyaline bağlar.
--
-- `apply_global_timer_command` başarılı start/stop geçişinden sonra yalnız aynı
-- authenticated kullanıcı adına, origin cihazı hariç tutan kısa ömürlü bir
-- timer_sync outbox kaydı üretir. FCM yalnız reconcile tetikleyicisidir; istemci
-- her zaman auth'lu snapshot RPC'sinden güncel state'i okur.
--
-- Geri alma (Rollback): `update public.timer_sync_push_runtime_config set enabled = false
-- where singleton;` ile yeni sinyal üretimini durdur. Uygulanmış run/outbox audit
-- kayıtlarını silme; gerekirse ileri migration ile helper çağrısını kaldır.

create or replace function public._enqueue_global_timer_v2_sync(
  p_recipient_id uuid,
  p_run_id uuid,
  p_state_version bigint,
  p_run_revision bigint,
  p_origin_device_id uuid,
  p_command_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_outbox_id uuid;
begin
  -- Bu helper yalnız authenticated timer RPC'sinin kendi hesabı için çalışır.
  -- PUBLIC execute verilmez; auth.uid kontrolü security-definer ayrıcalığını
  -- başka bir kullanıcı adına outbox yazmak için kullanılamaz kılar.
  if auth.uid() is null or auth.uid() <> p_recipient_id then
    raise exception 'timer_sync_recipient_required';
  end if;
  if p_run_id is null or p_command_id is null
     or p_state_version is null or p_state_version < 1
     or p_run_revision is null or p_run_revision < 1 then
    raise exception 'invalid_global_timer_sync_event';
  end if;
  if not coalesce(
    (select enabled from public.timer_sync_push_runtime_config where singleton),
    false
  ) then
    return null;
  end if;
  if not exists (
    select 1 from public.live_study_runs
    where id = p_run_id and user_id = p_recipient_id and protocol_version = 2
  ) then
    raise exception 'timer_sync_run_ownership_required';
  end if;
  if not exists (
    select 1 from public.push_devices
    where id = p_origin_device_id and user_id = p_recipient_id and disabled_at is null
  ) then
    raise exception 'timer_sync_origin_device_required';
  end if;

  insert into public.notification_outbox(
    event_key, recipient_id, notification_type, payload,
    expires_at, collapse_key, origin_device_id
  ) values (
    'timer_sync:global_timer_v2:' || p_command_id::text || ':' || p_recipient_id::text,
    p_recipient_id,
    'timer_sync',
    jsonb_build_object(
      'schema_version', '1',
      'kind', 'timer_sync',
      'run_id', p_run_id::text,
      'state_version', p_state_version,
      'run_revision', p_run_revision
    ),
    clock_timestamp() + interval '120 seconds',
    'timer_sync:' || p_recipient_id::text,
    p_origin_device_id
  ) on conflict (event_key) do update set
    expires_at = greatest(notification_outbox.expires_at, excluded.expires_at),
    payload = excluded.payload
  returning id into v_outbox_id;
  return v_outbox_id;
end;
$$;

revoke all on function public._enqueue_global_timer_v2_sync(uuid, uuid, bigint, bigint, uuid, uuid)
  from public, anon, authenticated;

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

  -- Yalnız state geçişi oluşturan start/stop komutları B cihazlarına sinyal
  -- üretir. Adopt/stale/duplicate/heartbeat yeni bir kullanıcı state'i değildir.
  if v_result = 'applied' and p_action in ('start', 'stop') then
    perform public._enqueue_global_timer_v2_sync(
      v_uid, v_run.id, v_state.state_version, v_run.run_revision,
      p_device_id, p_command_id
    );
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

update public.timer_sync_push_runtime_config
set enabled = true, updated_at = clock_timestamp()
where singleton;
insert into public.timer_sync_push_runtime_config(singleton, enabled)
values (true, true)
on conflict (singleton) do update set
  enabled = true,
  updated_at = clock_timestamp();

notify pgrst, 'reload schema';
