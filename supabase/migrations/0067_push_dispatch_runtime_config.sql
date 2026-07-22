-- 0067_push_dispatch_runtime_config.sql
-- WP-268: Dispatcher endpoint/secret'Ä± platform tarafÄ±ndan yazÄ±lmasÄ± yasak
-- olan database GUC'lerinden Ã§Ä±karÄ±p private runtime config'e taÅŸÄ±r.
--
-- Edge Function yalnÄ±z service_role RPC ile tekil config satÄ±rÄ±nÄ± yazar.
-- RLS/izinler istemcinin endpoint veya dispatch secret'Ä± okumasÄ±nÄ±/deÄŸiÅŸtirmesini
-- engeller; outbox trigger'Ä± security definer olarak bu satÄ±rÄ± okuyup HTTP isteÄŸi
-- baÅŸlatÄ±r. Geri alma (Rollback): public.push_dispatch_runtime_config ve
-- public.configure_push_dispatch silinir; _request_push_dispatch 0066 GUC
-- okuyan gÃ¶vdeye yeni ileri migration ile dÃ¶ndÃ¼rÃ¼lÃ¼r (uygulanmÄ±ÅŸ migration
-- deÄŸiÅŸtirilmez).

create table public.push_dispatch_runtime_config (
  singleton boolean primary key default true check (singleton),
  functions_base_url text not null check (
    functions_base_url ~ '^https://[a-z0-9]{20}\.supabase\.co$'
  ),
  dispatch_secret text not null check (
    dispatch_secret ~ '^[A-Za-z0-9_-]{48,}$'
  ),
  configured_at timestamptz not null default now()
);

alter table public.push_dispatch_runtime_config enable row level security;
revoke all on table public.push_dispatch_runtime_config from anon, authenticated;
grant select, insert, update, delete on table public.push_dispatch_runtime_config to service_role;

create or replace function public.configure_push_dispatch(
  p_functions_base_url text,
  p_dispatch_secret text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'push dispatcher configuration is service-only'
      using errcode = '42501';
  end if;

  if p_functions_base_url !~ '^https://[a-z0-9]{20}\.supabase\.co$' then
    raise exception 'invalid_push_dispatch_url'
      using errcode = '22023';
  end if;

  if p_dispatch_secret !~ '^[A-Za-z0-9_-]{48,}$' then
    raise exception 'invalid_push_dispatch_secret'
      using errcode = '22023';
  end if;

  insert into public.push_dispatch_runtime_config (
    singleton, functions_base_url, dispatch_secret, configured_at
  ) values (
    true, p_functions_base_url, p_dispatch_secret, now()
  )
  on conflict (singleton) do update
  set functions_base_url = excluded.functions_base_url,
      dispatch_secret = excluded.dispatch_secret,
      configured_at = excluded.configured_at;
end;
$$;

revoke all on function public.configure_push_dispatch(text, text) from public;
grant execute on function public.configure_push_dispatch(text, text) to service_role;

create or replace function public._request_push_dispatch()
returns trigger
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

  -- Local baseline ve henÃ¼z aktive edilmemiÅŸ ortamda outbox kalÄ±r; sahte HTTP
  -- baÅŸarÄ±sÄ± Ã¼retilmez. Ops health check eksik config'i gÃ¶rÃ¼nÃ¼r kÄ±lar.
  if v_base_url is null or v_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := rtrim(v_base_url, '/') || '/functions/v1/dispatch-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-dispatch-secret', v_secret
    ),
    body := jsonb_build_object('source', 'database', 'outbox_id', new.id)
  );
  return new;
exception
  when others then
    -- Domain transaction push aÄŸÄ± yÃ¼zÃ¼nden geri alÄ±nmaz. Outbox pending kalÄ±r ve
    -- cron/manual dispatcher daha sonra tekrar deneyebilir.
    raise warning 'push_dispatch_request_failed: %', sqlstate;
    return new;
end;
$$;
