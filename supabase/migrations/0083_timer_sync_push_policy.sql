-- 0083_timer_sync_push_policy.sql
-- WP-344: Timer-sync push için ayrı, kapalı rollout policy sınıfı.
--
-- Normal kullanıcı bildirimlerinin preference/quiet-hours davranışı korunur.
-- timer_sync yalnız V2 state değişim sinyalidir; gerçek timer doğruluğu değildir.
--
-- Geri alma (Rollback): `timer_sync_push_runtime_config.enabled=false` yap;
-- yeni timer_sync enqueue çağrıları fail-closed olur. Mevcut outbox/delivery audit
-- satırları silinmez; gerekirse ileri migration ile handler/RPC execute izni kaldırılır.

alter table public.notification_outbox
  add column if not exists expires_at timestamptz,
  add column if not exists collapse_key text,
  add column if not exists origin_device_id uuid references public.push_devices(id) on delete set null;

do $migration$
declare v_constraint record;
begin
  for v_constraint in
    select conname from pg_constraint
    where conrelid = 'public.notification_outbox'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%notification_type%'
  loop
    execute format('alter table public.notification_outbox drop constraint %I', v_constraint.conname);
  end loop;
end
$migration$;
alter table public.notification_outbox
  add constraint notification_outbox_notification_type_check
  check (notification_type in ('nudge', 'announcement', 'update', 'self_test', 'timer_sync'));
create index if not exists notification_outbox_timer_expiry_idx
  on public.notification_outbox(expires_at)
  where notification_type = 'timer_sync' and status in ('queued', 'dispatching');

create table if not exists public.timer_sync_push_runtime_config (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false,
  updated_at timestamptz not null default clock_timestamp()
);
insert into public.timer_sync_push_runtime_config(singleton, enabled)
values (true, false) on conflict (singleton) do nothing;
alter table public.timer_sync_push_runtime_config enable row level security;
revoke all on table public.timer_sync_push_runtime_config from public, anon, authenticated;

create or replace function public._push_type_enabled(
  p_device public.push_devices,
  p_notification_type text
)
returns boolean
language plpgsql
stable
set search_path = public
as $$
begin
  case p_notification_type
    when 'nudge' then return p_device.nudge_enabled;
    when 'announcement' then return p_device.announcement_enabled;
    when 'update' then return p_device.update_enabled;
    when 'self_test', 'timer_sync' then return true;
    else raise exception 'invalid_push_notification_type';
  end case;
end;
$$;

create or replace function public._create_push_deliveries()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_count integer;
begin
  insert into public.notification_deliveries (outbox_id, device_id)
  select new.id, d.id
  from public.push_devices d
  where d.user_id = new.recipient_id
    and d.disabled_at is null
    and (new.origin_device_id is null or d.id <> new.origin_device_id)
    and public._push_type_enabled(d, new.notification_type)
    and (new.notification_type <> 'update'
      or d.app_channel = coalesce(new.payload ->> 'target_channel', d.app_channel))
  on conflict (outbox_id, device_id) do nothing;
  get diagnostics v_count = row_count;
  if v_count = 0 then
    update public.notification_outbox set status = 'no_devices', completed_at = now()
    where id = new.id;
  end if;
  return new;
end;
$$;

create or replace function public.enqueue_timer_sync_push(
  p_event_key text,
  p_recipient_id uuid,
  p_run_id uuid,
  p_state_version bigint,
  p_run_revision bigint,
  p_origin_device_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_outbox_id uuid;
begin
  if auth.role() is distinct from 'service_role' and current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  if not (select enabled from public.timer_sync_push_runtime_config where singleton) then
    raise exception 'timer_sync_push_disabled';
  end if;
  if coalesce(trim(p_event_key), '') = '' or p_recipient_id is null or p_run_id is null
     or p_state_version is null or p_state_version < 1
     or p_run_revision is null or p_run_revision < 1 then
    raise exception 'invalid_timer_sync_push';
  end if;
  if not exists (select 1 from public.live_study_runs where id = p_run_id and user_id = p_recipient_id and protocol_version = 2) then
    raise exception 'timer_sync_run_ownership_required';
  end if;
  if p_origin_device_id is not null and not exists (
    select 1 from public.push_devices where id = p_origin_device_id and user_id = p_recipient_id
  ) then raise exception 'timer_sync_origin_device_required'; end if;
  insert into public.notification_outbox(
    event_key, recipient_id, notification_type, payload, expires_at, collapse_key, origin_device_id
  ) values (
    'timer_sync:' || left(trim(p_event_key), 120) || ':' || p_recipient_id::text,
    p_recipient_id, 'timer_sync',
    jsonb_build_object('schema_version', '1', 'kind', 'timer_sync',
      'run_id', p_run_id::text, 'state_version', p_state_version,
      'run_revision', p_run_revision),
    clock_timestamp() + interval '120 seconds', 'timer_sync:' || p_recipient_id::text, p_origin_device_id
  ) on conflict (event_key) do update set
    expires_at = greatest(notification_outbox.expires_at, excluded.expires_at),
    payload = excluded.payload
  returning id into v_outbox_id;
  return v_outbox_id;
end;
$$;

create or replace function public.claim_push_deliveries(
  p_worker_id uuid, p_limit integer default 50, p_lease_seconds integer default 60
)
returns table (delivery_id uuid, outbox_id uuid, device_id uuid, fcm_token text,
  notification_type text, payload jsonb, locale text, time_zone text,
  quiet_hours_enabled boolean, quiet_start_minutes integer, quiet_end_minutes integer, attempt integer)
language plpgsql security definer set search_path = public
as $$
begin
  if auth.role() is distinct from 'service_role' and current_user not in ('postgres', 'service_role') then raise exception 'service_role_required'; end if;
  if p_worker_id is null or p_limit not between 1 and 100 or p_lease_seconds not between 15 and 300 then raise exception 'invalid_claim_parameters'; end if;
  update public.notification_deliveries d set status = 'skipped', updated_at = now(), last_error_code = 'expired'
  from public.notification_outbox o
  where d.outbox_id = o.id and d.status in ('pending', 'retry')
    and o.expires_at is not null and o.expires_at <= clock_timestamp();
  update public.notification_deliveries d set status = 'skipped', updated_at = now(), last_error_code = 'device_disabled'
  from public.push_devices pd, public.notification_outbox o
  where d.device_id = pd.id and d.outbox_id = o.id and d.status in ('pending', 'retry')
    and (pd.disabled_at is not null or not public._push_type_enabled(pd, o.notification_type));
  update public.notification_deliveries set status = 'failed_permanent', updated_at = now(), last_error_code = 'attempts_exhausted'
  where status in ('pending', 'retry', 'processing') and attempts >= 6;
  return query with candidates as (
    select d.id from public.notification_deliveries d join public.notification_outbox o on o.id = d.outbox_id
    where ((d.status in ('pending', 'retry') and d.available_at <= now()) or (d.status = 'processing' and d.lease_until < now()))
      and d.attempts < 6 and (o.expires_at is null or o.expires_at > clock_timestamp())
    order by d.available_at, d.created_at for update skip locked limit p_limit
  ), claimed as (
    update public.notification_deliveries d set status = 'processing', attempts = d.attempts + 1,
      claimed_by = p_worker_id, lease_until = now() + make_interval(secs => p_lease_seconds), updated_at = now()
    from candidates c where d.id = c.id returning d.*
  ) select c.id, c.outbox_id, c.device_id, pd.fcm_token, o.notification_type, o.payload,
    pd.locale, pd.time_zone, pd.quiet_hours_enabled, pd.quiet_start_minutes, pd.quiet_end_minutes, c.attempts
  from claimed c join public.push_devices pd on pd.id = c.device_id join public.notification_outbox o on o.id = c.outbox_id;
end;
$$;

revoke all on function public.enqueue_timer_sync_push(text, uuid, uuid, bigint, bigint, uuid) from public, anon, authenticated;
revoke all on function public._push_type_enabled(public.push_devices, text) from public, anon, authenticated;
revoke all on function public.claim_push_deliveries(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.enqueue_timer_sync_push(text, uuid, uuid, bigint, bigint, uuid) to service_role;
grant execute on function public.claim_push_deliveries(uuid, integer, integer) to service_role;
notify pgrst, 'reload schema';
