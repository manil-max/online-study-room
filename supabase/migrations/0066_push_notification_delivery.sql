-- 0066_push_notification_delivery.sql
-- WP-266: Android remote push için cihaz kaydı + transactional outbox +
-- cihaz-bazlı teslim kuyruğu. FCM service credential yalnız Edge secret'tadır;
-- istemci bu tablolara doğrudan erişemez.

create table public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  installation_id text not null check (char_length(installation_id) between 16 and 128),
  fcm_token text not null check (char_length(fcm_token) between 20 and 4096),
  platform text not null default 'android' check (platform = 'android'),
  app_channel text not null check (app_channel in ('local', 'beta', 'stable')),
  app_version text not null check (char_length(app_version) between 1 and 64),
  build_number integer not null default 0 check (build_number >= 0),
  locale text not null default 'en' check (char_length(locale) between 2 and 16),
  time_zone text not null default 'UTC' check (char_length(time_zone) between 1 and 64),
  nudge_enabled boolean not null default true,
  announcement_enabled boolean not null default true,
  update_enabled boolean not null default true,
  quiet_hours_enabled boolean not null default false,
  quiet_start_minutes integer not null default 1320 check (quiet_start_minutes between 0 and 1439),
  quiet_end_minutes integer not null default 420 check (quiet_end_minutes between 0 and 1439),
  registered_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  disabled_at timestamptz,
  last_error_code text check (last_error_code is null or char_length(last_error_code) <= 120),
  unique (user_id, installation_id),
  unique (fcm_token)
);

create index push_devices_active_user_idx
  on public.push_devices (user_id, last_seen_at desc)
  where disabled_at is null;

alter table public.push_devices enable row level security;
revoke all on table public.push_devices from anon, authenticated;
grant all on table public.push_devices to service_role;

create table public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique check (char_length(event_key) between 3 and 180),
  recipient_id uuid not null references auth.users (id) on delete cascade,
  notification_type text not null
    check (notification_type in ('nudge', 'announcement', 'update', 'self_test')),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  status text not null default 'queued'
    check (status in ('queued', 'dispatching', 'sent', 'failed', 'no_devices')),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create index notification_outbox_recipient_created_idx
  on public.notification_outbox (recipient_id, created_at desc);

alter table public.notification_outbox enable row level security;
revoke all on table public.notification_outbox from anon, authenticated;
grant all on table public.notification_outbox to service_role;

create table public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  outbox_id uuid not null references public.notification_outbox (id) on delete cascade,
  device_id uuid not null references public.push_devices (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'retry', 'sent', 'failed_permanent', 'skipped')),
  attempts integer not null default 0 check (attempts between 0 and 20),
  available_at timestamptz not null default now(),
  lease_until timestamptz,
  claimed_by uuid,
  provider_message_id text check (
    provider_message_id is null or char_length(provider_message_id) <= 512
  ),
  last_error_code text check (last_error_code is null or char_length(last_error_code) <= 120),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (outbox_id, device_id)
);

create index notification_deliveries_claim_idx
  on public.notification_deliveries (available_at, created_at)
  where status in ('pending', 'retry', 'processing');

alter table public.notification_deliveries enable row level security;
revoke all on table public.notification_deliveries from anon, authenticated;
grant all on table public.notification_deliveries to service_role;

create or replace function public.register_push_device(
  p_installation_id text,
  p_fcm_token text,
  p_app_channel text,
  p_app_version text,
  p_build_number integer,
  p_locale text,
  p_time_zone text,
  p_nudge_enabled boolean,
  p_announcement_enabled boolean,
  p_update_enabled boolean,
  p_quiet_hours_enabled boolean,
  p_quiet_start_minutes integer,
  p_quiet_end_minutes integer
)
returns table (device_id uuid, registered_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_installation_id text := trim(coalesce(p_installation_id, ''));
  v_token text := trim(coalesce(p_fcm_token, ''));
  v_row public.push_devices;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;
  if char_length(v_installation_id) not between 16 and 128 then
    raise exception 'invalid_installation_id';
  end if;
  if char_length(v_token) not between 20 and 4096 then
    raise exception 'invalid_fcm_token';
  end if;
  if p_app_channel not in ('local', 'beta', 'stable') then
    raise exception 'invalid_app_channel';
  end if;
  if char_length(trim(coalesce(p_app_version, ''))) not between 1 and 64
    or p_build_number < 0
    or char_length(trim(coalesce(p_locale, ''))) not between 2 and 16
    or char_length(trim(coalesce(p_time_zone, ''))) not between 1 and 64
    or p_quiet_start_minutes not between 0 and 1439
    or p_quiet_end_minutes not between 0 and 1439 then
    raise exception 'invalid_device_metadata';
  end if;

  -- Aynı FCM token reinstall/logout sonrası başka kullanıcıya geçtiyse eski
  -- bağlantıyı sil. Token yüksek entropilidir; caller yalnız kendi aldığı tokenı
  -- gönderebilir ve sonuç tablosunu doğrudan okuyamaz.
  delete from public.push_devices
  where fcm_token = v_token
    and (user_id <> v_user_id or installation_id <> v_installation_id);

  insert into public.push_devices (
    user_id, installation_id, fcm_token, platform, app_channel, app_version,
    build_number, locale, time_zone, nudge_enabled, announcement_enabled,
    update_enabled, quiet_hours_enabled, quiet_start_minutes,
    quiet_end_minutes, registered_at, last_seen_at, disabled_at, last_error_code
  ) values (
    v_user_id, v_installation_id, v_token, 'android', p_app_channel,
    trim(p_app_version), p_build_number, lower(trim(p_locale)), trim(p_time_zone),
    p_nudge_enabled, p_announcement_enabled, p_update_enabled,
    p_quiet_hours_enabled, p_quiet_start_minutes, p_quiet_end_minutes,
    now(), now(), null, null
  )
  on conflict (user_id, installation_id) do update set
    fcm_token = excluded.fcm_token,
    platform = excluded.platform,
    app_channel = excluded.app_channel,
    app_version = excluded.app_version,
    build_number = excluded.build_number,
    locale = excluded.locale,
    time_zone = excluded.time_zone,
    nudge_enabled = excluded.nudge_enabled,
    announcement_enabled = excluded.announcement_enabled,
    update_enabled = excluded.update_enabled,
    quiet_hours_enabled = excluded.quiet_hours_enabled,
    quiet_start_minutes = excluded.quiet_start_minutes,
    quiet_end_minutes = excluded.quiet_end_minutes,
    registered_at = now(),
    last_seen_at = now(),
    disabled_at = null,
    last_error_code = null
  returning * into v_row;

  return query select v_row.id, v_row.registered_at;
end;
$$;

create or replace function public.unregister_push_device(p_installation_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  update public.push_devices
  set disabled_at = now(), last_seen_at = now(), last_error_code = 'user_unregistered'
  where user_id = auth.uid()
    and installation_id = trim(coalesce(p_installation_id, ''));
end;
$$;

create or replace function public._push_type_enabled(
  p_device public.push_devices,
  p_notification_type text
)
returns boolean
language sql
immutable
set search_path = public
as $$
  select case p_notification_type
    when 'nudge' then p_device.nudge_enabled
    when 'announcement' then p_device.announcement_enabled
    when 'update' then p_device.update_enabled
    when 'self_test' then true
    else false
  end;
$$;

create or replace function public._create_push_deliveries()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  insert into public.notification_deliveries (outbox_id, device_id)
  select new.id, d.id
  from public.push_devices d
  where d.user_id = new.recipient_id
    and d.disabled_at is null
    and public._push_type_enabled(d, new.notification_type)
    and (
      new.notification_type <> 'update'
      or d.app_channel = coalesce(new.payload ->> 'target_channel', d.app_channel)
    )
  on conflict (outbox_id, device_id) do nothing;

  get diagnostics v_count = row_count;
  if v_count = 0 then
    update public.notification_outbox
    set status = 'no_devices', completed_at = now()
    where id = new.id;
  end if;
  return new;
end;
$$;

create trigger a_push_outbox_create_deliveries
after insert on public.notification_outbox
for each row execute function public._create_push_deliveries();

create or replace function public._request_push_dispatch()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_base_url text := coalesce(
    nullif(current_setting('app.settings.supabase_url', true), ''),
    nullif(current_setting('app.settings.functions_base_url', true), '')
  );
  v_service_key text := nullif(current_setting('app.settings.service_role_key', true), '');
  v_secret text := nullif(current_setting('app.settings.push_dispatch_secret', true), '');
begin
  -- Local baseline ve henüz aktive edilmemiş ortamda outbox kalır; sahte HTTP
  -- başarısı üretilmez. Ops health check eksik setting'i görünür kılar.
  if v_base_url is null or v_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := rtrim(v_base_url, '/') || '/functions/v1/dispatch-push',
    headers := jsonb_strip_nulls(jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', case when v_service_key is null then null else 'Bearer ' || v_service_key end,
      'x-push-dispatch-secret', v_secret
    )),
    body := jsonb_build_object('source', 'database', 'outbox_id', new.id)
  );
  return new;
exception
  when others then
    -- Domain transaction push ağı yüzünden geri alınmaz. Outbox pending kalır ve
    -- cron/manual dispatcher daha sonra tekrar deneyebilir.
    raise warning 'push_dispatch_request_failed: %', sqlstate;
    return new;
end;
$$;

create trigger z_push_outbox_request_dispatch
after insert on public.notification_outbox
for each row execute function public._request_push_dispatch();

create or replace function public._enqueue_nudge_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender_name text;
begin
  select nullif(trim(display_name), '')
  into v_sender_name
  from public.profiles
  where id = new.sender_id;

  insert into public.notification_outbox (
    event_key, recipient_id, notification_type, payload
  ) values (
    'nudge:' || new.id::text,
    new.recipient_id,
    'nudge',
    jsonb_build_object(
      'schema_version', '1',
      'event_id', new.id::text,
      'route', 'nudge',
      'nudge_id', new.id::text,
      'sender_id', new.sender_id::text,
      'sender_display_name', coalesce(v_sender_name, ''),
      'message', coalesce(new.message, '')
    )
  )
  on conflict (event_key) do nothing;
  return new;
end;
$$;

create trigger nudges_enqueue_push
after insert on public.nudges
for each row execute function public._enqueue_nudge_push();

create or replace function public._enqueue_announcement_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notification_outbox (
    event_key, recipient_id, notification_type, payload
  )
  select
    'announcement:' || new.id::text || ':' || recipients.user_id::text,
    recipients.user_id,
    'announcement',
    jsonb_build_object(
      'schema_version', '1',
      'event_id', new.id::text,
      'route', 'notification_center',
      'announcement_id', new.id::text,
      'title', new.title,
      'body', new.message
    )
  from (
    select distinct d.user_id
    from public.push_devices d
    where d.disabled_at is null
      and d.announcement_enabled
      and (
        new.target_type = 'all'
        or (new.target_type = 'user' and new.target_id = d.user_id::text)
        or (
          new.target_type = 'group'
          and exists (
            select 1
            from public.group_members gm
            where gm.user_id = d.user_id
              and gm.group_id::text = new.target_id
              and gm.left_at is null
          )
        )
      )
  ) recipients
  on conflict (event_key) do nothing;
  return new;
end;
$$;

create trigger announcements_enqueue_push
after insert on public.announcements
for each row execute function public._enqueue_announcement_push();

create or replace function public.enqueue_update_push(
  p_event_key text,
  p_channel text,
  p_version_name text,
  p_build_number integer,
  p_title text,
  p_body text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if auth.role() is distinct from 'service_role'
    and current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  if coalesce(trim(p_event_key), '') = ''
    or p_channel not in ('beta', 'stable')
    or coalesce(trim(p_version_name), '') = ''
    or p_build_number < 1 then
    raise exception 'invalid_update_push';
  end if;

  insert into public.notification_outbox (
    event_key, recipient_id, notification_type, payload
  )
  select
    'update:' || left(trim(p_event_key), 160) || ':' || recipients.user_id::text,
    recipients.user_id,
    'update',
    jsonb_build_object(
      'schema_version', '1',
      'event_id', left(trim(p_event_key), 160),
      'route', 'notification_center',
      'target_channel', p_channel,
      'version_name', left(trim(p_version_name), 80),
      'build_number', p_build_number,
      'title', left(coalesce(nullif(trim(p_title), ''), 'Odak Kampı'), 180),
      'body', left(coalesce(nullif(trim(p_body), ''), 'Yeni sürüm hazır.'), 500)
    )
  from (
    select distinct d.user_id
    from public.push_devices d
    where d.disabled_at is null
      and d.update_enabled
      and d.app_channel = p_channel
  ) recipients
  on conflict (event_key) do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.prune_stale_push_devices(p_days integer default 45)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if auth.role() is distinct from 'service_role'
    and current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;

  update public.push_devices
  set disabled_at = now(), last_error_code = 'stale_registration'
  where disabled_at is null
    and last_seen_at < now() - make_interval(days => least(365, greatest(7, p_days)));
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.request_push_self_test()
returns table (outbox_id uuid, requested_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_row public.notification_outbox;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;
  if exists (
    select 1 from public.notification_outbox
    where recipient_id = v_user_id
      and notification_type = 'self_test'
      and created_at > now() - interval '20 seconds'
  ) then
    raise exception 'push_test_cooldown';
  end if;

  insert into public.notification_outbox (
    event_key, recipient_id, notification_type, payload
  ) values (
    'self_test:' || v_user_id::text || ':' || gen_random_uuid()::text,
    v_user_id,
    'self_test',
    jsonb_build_object(
      'schema_version', '1',
      'event_id', gen_random_uuid()::text,
      'route', 'notification_center'
    )
  ) returning * into v_row;

  return query select v_row.id, v_row.created_at;
end;
$$;

create or replace function public.get_push_self_test_status(p_outbox_id uuid)
returns table (
  outbox_status text,
  pending_count integer,
  sent_count integer,
  failed_count integer,
  requested_at timestamptz,
  completed_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    o.status,
    count(d.id) filter (where d.status in ('pending', 'processing', 'retry'))::integer,
    count(d.id) filter (where d.status = 'sent')::integer,
    count(d.id) filter (where d.status in ('failed_permanent', 'skipped'))::integer,
    o.created_at,
    o.completed_at
  from public.notification_outbox o
  left join public.notification_deliveries d on d.outbox_id = o.id
  where o.id = p_outbox_id
    and o.recipient_id = auth.uid()
    and o.notification_type = 'self_test'
  group by o.id;
$$;

create or replace function public.claim_push_deliveries(
  p_worker_id uuid,
  p_limit integer default 50,
  p_lease_seconds integer default 60
)
returns table (
  delivery_id uuid,
  outbox_id uuid,
  device_id uuid,
  fcm_token text,
  notification_type text,
  payload jsonb,
  locale text,
  time_zone text,
  quiet_hours_enabled boolean,
  quiet_start_minutes integer,
  quiet_end_minutes integer,
  attempt integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() is distinct from 'service_role'
    and current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  if p_worker_id is null or p_limit not between 1 and 100
    or p_lease_seconds not between 15 and 300 then
    raise exception 'invalid_claim_parameters';
  end if;

  update public.notification_deliveries d
  set status = 'skipped', updated_at = now(), last_error_code = 'device_disabled'
  from public.push_devices pd, public.notification_outbox o
  where d.device_id = pd.id
    and d.outbox_id = o.id
    and d.status in ('pending', 'retry')
    and (
      pd.disabled_at is not null
      or not public._push_type_enabled(pd, o.notification_type)
    );

  update public.notification_deliveries
  set status = 'failed_permanent', updated_at = now(), last_error_code = 'attempts_exhausted'
  where status in ('pending', 'retry', 'processing')
    and attempts >= 6;

  return query
  with candidates as (
    select d.id
    from public.notification_deliveries d
    where (
      (d.status in ('pending', 'retry') and d.available_at <= now())
      or (d.status = 'processing' and d.lease_until < now())
    )
      and d.attempts < 6
    order by d.available_at, d.created_at
    for update skip locked
    limit p_limit
  ), claimed as (
    update public.notification_deliveries d
    set status = 'processing',
        attempts = d.attempts + 1,
        claimed_by = p_worker_id,
        lease_until = now() + make_interval(secs => p_lease_seconds),
        updated_at = now()
    from candidates c
    where d.id = c.id
    returning d.*
  )
  select
    c.id, c.outbox_id, c.device_id, pd.fcm_token, o.notification_type,
    o.payload, pd.locale, pd.time_zone, pd.quiet_hours_enabled,
    pd.quiet_start_minutes, pd.quiet_end_minutes, c.attempts
  from claimed c
  join public.push_devices pd on pd.id = c.device_id
  join public.notification_outbox o on o.id = c.outbox_id;
end;
$$;

create or replace function public.complete_push_delivery(
  p_delivery_id uuid,
  p_worker_id uuid,
  p_result text,
  p_provider_message_id text default null,
  p_error_code text default null,
  p_retry_after_seconds integer default 60
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_outbox_id uuid;
begin
  if auth.role() is distinct from 'service_role'
    and current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  if p_result not in ('sent', 'retry', 'failed_permanent', 'skipped') then
    raise exception 'invalid_delivery_result';
  end if;

  update public.notification_deliveries
  set status = p_result,
      provider_message_id = left(nullif(p_provider_message_id, ''), 512),
      last_error_code = left(nullif(p_error_code, ''), 120),
      available_at = case
        when p_result = 'retry' then now() + make_interval(
          secs => least(3600, greatest(15, p_retry_after_seconds))
        )
        else available_at
      end,
      sent_at = case when p_result = 'sent' then now() else sent_at end,
      lease_until = null,
      claimed_by = null,
      updated_at = now()
  where id = p_delivery_id
    and status = 'processing'
    and claimed_by = p_worker_id
  returning outbox_id into v_outbox_id;

  if v_outbox_id is null then
    raise exception 'delivery_claim_mismatch';
  end if;

  update public.notification_outbox o
  set status = case
        when exists (
          select 1 from public.notification_deliveries d
          where d.outbox_id = o.id and d.status in ('pending', 'processing', 'retry')
        ) then 'dispatching'
        when exists (
          select 1 from public.notification_deliveries d
          where d.outbox_id = o.id and d.status = 'sent'
        ) then 'sent'
        else 'failed'
      end,
      completed_at = case
        when exists (
          select 1 from public.notification_deliveries d
          where d.outbox_id = o.id and d.status in ('pending', 'processing', 'retry')
        ) then null
        else now()
      end
  where o.id = v_outbox_id;
end;
$$;

create or replace function public.disable_push_device(
  p_device_id uuid,
  p_error_code text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() is distinct from 'service_role'
    and current_user not in ('postgres', 'service_role') then
    raise exception 'service_role_required';
  end if;
  update public.push_devices
  set disabled_at = now(), last_error_code = left(coalesce(p_error_code, 'provider_unregistered'), 120)
  where id = p_device_id;
end;
$$;

revoke all on function public.register_push_device(
  text, text, text, text, integer, text, text, boolean, boolean, boolean,
  boolean, integer, integer
) from public, anon;
grant execute on function public.register_push_device(
  text, text, text, text, integer, text, text, boolean, boolean, boolean,
  boolean, integer, integer
) to authenticated;

revoke all on function public.unregister_push_device(text) from public, anon;
grant execute on function public.unregister_push_device(text) to authenticated;
revoke all on function public.request_push_self_test() from public, anon;
grant execute on function public.request_push_self_test() to authenticated;
revoke all on function public.get_push_self_test_status(uuid) from public, anon;
grant execute on function public.get_push_self_test_status(uuid) to authenticated;

revoke all on function public.claim_push_deliveries(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.claim_push_deliveries(uuid, integer, integer) to service_role;
revoke all on function public.complete_push_delivery(uuid, uuid, text, text, text, integer)
  from public, anon, authenticated;
grant execute on function public.complete_push_delivery(uuid, uuid, text, text, text, integer)
  to service_role;
revoke all on function public.disable_push_device(uuid, text) from public, anon, authenticated;
grant execute on function public.disable_push_device(uuid, text) to service_role;
revoke all on function public.enqueue_update_push(text, text, text, integer, text, text)
  from public, anon, authenticated;
grant execute on function public.enqueue_update_push(text, text, text, integer, text, text)
  to service_role;
revoke all on function public.prune_stale_push_devices(integer)
  from public, anon, authenticated;
grant execute on function public.prune_stale_push_devices(integer) to service_role;

comment on table public.push_devices is
  'WP-266 private FCM device registry; client access only through self-scoped RPCs.';
comment on table public.notification_outbox is
  'WP-266 idempotent domain notification outbox.';
comment on table public.notification_deliveries is
  'WP-266 per-device delivery/retry state; service-role only.';
