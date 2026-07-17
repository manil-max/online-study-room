--0038_ugc_moderation.sql
-- UGC rapor / engel / moderasyon (WP-115)
--
-- Geri alma:
--   drop table if exists public.user_blocks, public.ugc_reports, public.community_terms_acceptances;
--   drop function if exists public.report_ugc(...), public.block_user(...), public.unblock_user(...);

create table if not exists public.community_terms_acceptances (
  user_id uuid primary key references auth.users (id) on delete cascade,
  version text not null,
  accepted_at timestamptz not null default now()
);

alter table public.community_terms_acceptances enable row level security;
drop policy if exists terms_select_own on public.community_terms_acceptances;
create policy terms_select_own on public.community_terms_acceptances
  for select to authenticated using (user_id = auth.uid());
drop policy if exists terms_insert_own on public.community_terms_acceptances;
create policy terms_insert_own on public.community_terms_acceptances
  for insert to authenticated with check (user_id = auth.uid());

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx on public.user_blocks (blocked_id);
alter table public.user_blocks enable row level security;
drop policy if exists blocks_select_own on public.user_blocks;
create policy blocks_select_own on public.user_blocks
  for select to authenticated using (blocker_id = auth.uid());
-- yazım yalnız RPC
revoke insert, update, delete on public.user_blocks from authenticated, anon;

create table if not exists public.ugc_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  target_type text not null check (target_type in ('message', 'user', 'group', 'profile')),
  target_id text not null,
  reason text not null check (char_length(reason) between 1 and 40),
  details text check (details is null or char_length(details) <= 500),
  status text not null default 'open'
    check (status in ('open', 'in_review', 'resolved', 'rejected')),
  content_snapshot text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (reporter_id, target_type, target_id, reason)
);

create index if not exists ugc_reports_status_idx
  on public.ugc_reports (status, created_at desc);

alter table public.ugc_reports enable row level security;
drop policy if exists ugc_reports_select_own on public.ugc_reports;
create policy ugc_reports_select_own on public.ugc_reports
  for select to authenticated
  using (reporter_id = auth.uid() or public.is_super_admin());
-- Super-admin status güncellemesi (WP-117 kuyruk)
drop policy if exists ugc_reports_update_admin on public.ugc_reports;
create policy ugc_reports_update_admin on public.ugc_reports
  for update to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());
revoke insert, delete on public.ugc_reports from authenticated, anon;

create or replace function public.accept_community_terms(p_version text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if coalesce(btrim(p_version), '') = '' then
    raise exception 'invalid_version';
  end if;
  insert into public.community_terms_acceptances (user_id, version, accepted_at)
  values (auth.uid(), btrim(p_version), now())
  on conflict (user_id) do update
    set version = excluded.version,
        accepted_at = now();
end;
$$;

create or replace function public.block_user(p_blocked_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_blocked_id is null or p_blocked_id = auth.uid() then
    raise exception 'invalid_target';
  end if;
  insert into public.user_blocks (blocker_id, blocked_id)
  values (auth.uid(), p_blocked_id)
  on conflict do nothing;
end;
$$;

create or replace function public.unblock_user(p_blocked_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  delete from public.user_blocks
  where blocker_id = auth.uid() and blocked_id = p_blocked_id;
end;
$$;

create or replace function public.report_ugc(
  p_target_type text,
  p_target_id text,
  p_reason text,
  p_details text default null,
  p_snapshot text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  rid uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_target_type not in ('message', 'user', 'group', 'profile') then
    raise exception 'invalid_type';
  end if;

  insert into public.ugc_reports (
    reporter_id, target_type, target_id, reason, details, content_snapshot
  ) values (
    auth.uid(),
    p_target_type,
    btrim(p_target_id),
    btrim(p_reason),
    nullif(btrim(coalesce(p_details, '')), ''),
    nullif(left(coalesce(p_snapshot, ''), 2000), '')
  )
  on conflict (reporter_id, target_type, target_id, reason) do update
    set updated_at = now(),
        details = coalesce(excluded.details, public.ugc_reports.details)
  returning id into rid;

  return rid;
end;
$$;

grant execute on function public.accept_community_terms(text) to authenticated;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.report_ugc(text, text, text, text, text) to authenticated;
