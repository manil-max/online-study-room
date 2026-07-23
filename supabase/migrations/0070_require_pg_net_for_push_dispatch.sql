-- 0070_require_pg_net_for_push_dispatch.sql
-- WP-280: Push retry worker'ın kullandığı asenkron HTTP transport önkoşulunu
-- migration zincirine alır ve health sonucunun eksik transport ile yeşil
-- görünmesini engeller.
--
-- Geri alma (Rollback): pg_net başka işler tarafından da kullanılabileceği için
-- extension'ı silme. Push enqueue/cron çağrılarını durdur; health RPC'lerini yeni
-- bir ileri migration ile 0069 sözleşmesine döndür.

create extension if not exists pg_net with schema extensions;

do $migration$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_net')
     or not exists (
       select 1
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'net' and p.proname = 'http_post'
     ) then
    raise exception 'pg_net_required_before_0070';
  end if;
end
$migration$;

create or replace function public._request_scheduled_push_dispatch()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_base_url text;
  v_secret text;
begin
  select functions_base_url, dispatch_secret
  into v_base_url, v_secret
  from public.push_dispatch_runtime_config
  where singleton = true;

  if v_base_url is null or v_secret is null then
    return;
  end if;

  if not exists (select 1 from pg_extension where extname = 'pg_net')
     or not exists (
       select 1
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'net' and p.proname = 'http_post'
     ) then
    raise exception 'push_dispatch_transport_unavailable';
  end if;

  perform net.http_post(
    url := rtrim(v_base_url, '/') || '/functions/v1/dispatch-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-dispatch-secret', v_secret
    ),
    body := jsonb_build_object('source', 'scheduled_retry')
  );
end;
$$;

revoke all on function public._request_scheduled_push_dispatch() from public, anon, authenticated;
grant execute on function public._request_scheduled_push_dispatch() to service_role;

create or replace function public.get_push_dispatch_queue_health()
returns table (
  configuration_status text,
  queued_count integer,
  retry_count integer,
  processing_count integer,
  stuck_lease_count integer,
  oldest_age_seconds integer,
  max_attempt integer,
  latest_error_code text
)
language sql
security definer
set search_path = public
as $$
  with delivery_metrics as (
    select
      count(*) filter (where status = 'pending')::integer as queued_count,
      count(*) filter (where status = 'retry')::integer as retry_count,
      count(*) filter (where status = 'processing')::integer as processing_count,
      count(*) filter (
        where status = 'processing' and lease_until is not null and lease_until < now()
      )::integer as stuck_lease_count,
      coalesce(
        extract(epoch from now() - min(created_at) filter (
          where status in ('pending', 'retry', 'processing')
        ))::integer,
        0
      ) as oldest_age_seconds,
      coalesce(max(attempts), 0)::integer as max_attempt
    from public.notification_deliveries
  )
  select
    case
      when not exists (
        select 1 from public.push_dispatch_runtime_config where singleton = true
      ) then 'not_configured'
      when not exists (select 1 from pg_extension where extname = 'pg_net')
        or not exists (
          select 1
          from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'net' and p.proname = 'http_post'
        ) then 'transport_unavailable'
      else 'configured'
    end,
    m.queued_count,
    m.retry_count,
    m.processing_count,
    m.stuck_lease_count,
    m.oldest_age_seconds,
    m.max_attempt,
    (
      select d.last_error_code
      from public.notification_deliveries d
      where d.last_error_code is not null
      order by d.updated_at desc
      limit 1
    )
  from delivery_metrics m;
$$;

revoke all on function public.get_push_dispatch_queue_health() from public, anon, authenticated;
grant execute on function public.get_push_dispatch_queue_health() to service_role;

create or replace function public.get_push_self_test_status(p_outbox_id uuid)
returns table (
  outbox_status text,
  pending_count integer,
  sent_count integer,
  failed_count integer,
  requested_at timestamptz,
  completed_at timestamptz,
  attempt_count integer,
  last_error_code text,
  next_attempt_at timestamptz,
  configuration_status text
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
    o.completed_at,
    coalesce(max(d.attempts), 0)::integer,
    (
      select d2.last_error_code
      from public.notification_deliveries d2
      where d2.outbox_id = o.id and d2.last_error_code is not null
      order by d2.updated_at desc
      limit 1
    ),
    min(d.available_at) filter (where d.status = 'retry'),
    case
      when not exists (
        select 1 from public.push_dispatch_runtime_config where singleton = true
      ) then 'not_configured'
      when not exists (select 1 from pg_extension where extname = 'pg_net')
        or not exists (
          select 1
          from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'net' and p.proname = 'http_post'
        ) then 'transport_unavailable'
      else 'configured'
    end
  from public.notification_outbox o
  left join public.notification_deliveries d on d.outbox_id = o.id
  where o.id = p_outbox_id
    and o.recipient_id = auth.uid()
    and o.notification_type = 'self_test'
  group by o.id;
$$;

revoke all on function public.get_push_self_test_status(uuid) from public, anon;
grant execute on function public.get_push_self_test_status(uuid) to authenticated;

notify pgrst, 'reload schema';
