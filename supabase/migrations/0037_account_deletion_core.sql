-- 0037_account_deletion_core.sql
-- Hesap silme çekirdek sözleşmesi (WP-112)
--
-- Ürün varsayılanları (HESAP-SILME-RETENTION-KARARI §0): soft istek → 14 gün
-- grace → planlı hard-delete (WP-113 worker). Soft-delete ≠ hard-delete değildir.
--
-- Geri alma (Rollback):
--   drop function if exists public.request_account_deletion();
--   drop function if exists public.cancel_account_deletion();
--   drop function if exists public.my_account_deletion_status();
--   drop table if exists public.account_deletion_requests;

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'requested'
    check (status in (
      'requested', 'scheduled', 'processing', 'completed', 'failed', 'canceled'
    )),
  requested_at timestamptz not null default now(),
  purge_after timestamptz not null,
  canceled_at timestamptz,
  completed_at timestamptz,
  attempt_count int not null default 0 check (attempt_count >= 0),
  last_error_code text,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (idempotency_key)
);

-- Aynı anda tek aktif istek (completed/canceled dışı)
create unique index if not exists account_deletion_one_active_per_user
  on public.account_deletion_requests (user_id)
  where status in ('requested', 'scheduled', 'processing', 'failed');

create index if not exists account_deletion_purge_after_idx
  on public.account_deletion_requests (purge_after)
  where status in ('scheduled', 'failed');

alter table public.account_deletion_requests enable row level security;

drop policy if exists account_deletion_select_own on public.account_deletion_requests;
create policy account_deletion_select_own on public.account_deletion_requests
  for select to authenticated
  using (user_id = auth.uid());

-- Doğrudan insert/update/delete yok; yalnız RPC (DEFINER)
drop policy if exists account_deletion_insert on public.account_deletion_requests;
drop policy if exists account_deletion_update on public.account_deletion_requests;
drop policy if exists account_deletion_delete on public.account_deletion_requests;

revoke insert, update, delete on public.account_deletion_requests from authenticated, anon;
grant select on public.account_deletion_requests to authenticated;

-- ---------------------------------------------------------------------
-- RPC: request
-- ---------------------------------------------------------------------
create or replace function public.request_account_deletion()
returns public.account_deletion_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  existing public.account_deletion_requests;
  row public.account_deletion_requests;
  day_start timestamptz;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  -- Aktif istek varsa idempotent dön
  select * into existing
  from public.account_deletion_requests
  where user_id = uid
    and status in ('requested', 'scheduled', 'processing', 'failed')
  order by requested_at desc
  limit 1;

  if existing.id is not null then
    return existing;
  end if;

  -- Günde 1 yeni istek (tamamlanmış/iptal sonrası)
  day_start := date_trunc('day', now() at time zone 'Europe/Istanbul')
    at time zone 'Europe/Istanbul';
  if exists (
    select 1 from public.account_deletion_requests
    where user_id = uid
      and requested_at >= day_start
      and status in ('canceled', 'completed')
  ) then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;

  insert into public.account_deletion_requests (
    user_id, status, requested_at, purge_after, idempotency_key
  ) values (
    uid,
    'scheduled',
    now(),
    now() + interval '14 days',
    uid::text || '|' || to_char(now() at time zone 'utc', 'YYYYMMDD"T"HH24MISS')
  )
  returning * into row;

  -- Opt-out e-posta raporları
  update public.profiles
  set monthly_report_opt_in = false
  where id = uid;

  -- Presence pasif
  update public.presence
  set status = 'offline',
      started_at = null,
      updated_at = now()
  where user_id = uid;

  return row;
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: cancel (yalnız purge_after öncesi)
-- ---------------------------------------------------------------------
create or replace function public.cancel_account_deletion()
returns public.account_deletion_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  row public.account_deletion_requests;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select * into row
  from public.account_deletion_requests
  where user_id = uid
    and status in ('requested', 'scheduled', 'failed')
  order by requested_at desc
  limit 1
  for update;

  if row.id is null then
    raise exception 'no_active_request' using errcode = 'P0002';
  end if;

  if row.purge_after <= now() then
    raise exception 'too_late' using errcode = 'P0003';
  end if;

  update public.account_deletion_requests
  set status = 'canceled',
      canceled_at = now(),
      updated_at = now()
  where id = row.id
  returning * into row;

  return row;
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: status
-- ---------------------------------------------------------------------
create or replace function public.my_account_deletion_status()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  uid uuid := auth.uid();
  row public.account_deletion_requests;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  select * into row
  from public.account_deletion_requests
  where user_id = uid
  order by requested_at desc
  limit 1;

  if row.id is null then
    return jsonb_build_object('active', false);
  end if;

  return jsonb_build_object(
    'active', row.status in ('requested', 'scheduled', 'processing', 'failed'),
    'status', row.status,
    'requested_at', row.requested_at,
    'purge_after', row.purge_after,
    'canceled_at', row.canceled_at,
    'completed_at', row.completed_at,
    'attempt_count', row.attempt_count
  );
end;
$$;

grant execute on function public.request_account_deletion() to authenticated;
grant execute on function public.cancel_account_deletion() to authenticated;
grant execute on function public.my_account_deletion_status() to authenticated;

comment on table public.account_deletion_requests is
  'WP-112: hesap silme istekleri; hard purge WP-113 Edge worker.';
