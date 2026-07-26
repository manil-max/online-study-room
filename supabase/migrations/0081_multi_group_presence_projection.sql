-- 0081_multi_group_presence_projection.sql
-- WP-338: Sunucu türevli çoklu grup presence projection çekirdeği.
--
-- Eski `presence` tablosu ve mevcut istemci yazma yolu fallback olarak korunur.
-- Bu additive yol, istemcinin doğrudan projection yazmasını engeller; yalnız
-- kanonik kullanıcı state'i ve aktif üyelikler projection'ı üretir.
--
-- Geri alma (Rollback): Yeni istemci okuma/yazma bayrağını kapat; eski
-- `presence` fallback'ini kullanmaya devam et. Oluşmuş state/projection satırları
-- silinmez; gerekirse ileri migration ile yeni RPC execute izni kaldırılır.

create table if not exists public.user_live_presence_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'offline'
    check (status in ('studying', 'onBreak', 'offline')),
  started_at timestamptz,
  today_seconds integer not null default 0 check (today_seconds >= 0),
  subject_id uuid references public.subjects(id) on delete set null,
  lease_expires_at timestamptz,
  state_version bigint not null default 0 check (state_version >= 0),
  updated_at timestamptz not null default clock_timestamp(),
  check (
    (status = 'offline' and lease_expires_at is null)
    or (status <> 'offline' and lease_expires_at is not null)
  )
);

create table if not exists public.group_live_presence (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('studying', 'onBreak')),
  started_at timestamptz,
  today_seconds integer not null check (today_seconds >= 0),
  subject_id uuid references public.subjects(id) on delete set null,
  lease_expires_at timestamptz not null,
  state_version bigint not null check (state_version >= 0),
  counts_for_group_progression boolean not null default false,
  projected_at timestamptz not null default clock_timestamp(),
  primary key (group_id, user_id)
);

create index if not exists group_live_presence_user_idx
  on public.group_live_presence (user_id, group_id);
create index if not exists user_live_presence_state_lease_idx
  on public.user_live_presence_state (lease_expires_at)
  where status <> 'offline';

alter table public.user_live_presence_state enable row level security;
alter table public.group_live_presence enable row level security;

revoke all on table public.user_live_presence_state from public, anon, authenticated;
revoke all on table public.group_live_presence from public, anon, authenticated;
grant select on table public.user_live_presence_state to authenticated;
grant select on table public.group_live_presence to authenticated;

drop policy if exists user_live_presence_state_select_own
  on public.user_live_presence_state;
create policy user_live_presence_state_select_own
  on public.user_live_presence_state
  for select to authenticated using (user_id = auth.uid());

drop policy if exists group_live_presence_select_active_member
  on public.group_live_presence;
create policy group_live_presence_select_active_member
  on public.group_live_presence
  for select to authenticated using (public.is_group_member(group_id));

create or replace function public.sync_multi_group_presence_projection(
  p_user_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_state public.user_live_presence_state%rowtype;
  v_primary_group_id uuid;
  v_affected integer := 0;
begin
  if p_user_id is null then
    return 0;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 338));

  select * into v_state
  from public.user_live_presence_state
  where user_id = p_user_id
  for update;

  if not found
     or v_state.status = 'offline'
     or v_state.lease_expires_at <= clock_timestamp() then
    delete from public.group_live_presence where user_id = p_user_id;
    get diagnostics v_affected = row_count;
    return v_affected;
  end if;

  select primary_group_id into v_primary_group_id
  from public.user_group_preferences
  where user_id = p_user_id;

  insert into public.group_live_presence (
    group_id, user_id, status, started_at, today_seconds, subject_id,
    lease_expires_at, state_version, counts_for_group_progression, projected_at
  )
  select
    gm.group_id,
    v_state.user_id,
    v_state.status,
    v_state.started_at,
    v_state.today_seconds,
    v_state.subject_id,
    v_state.lease_expires_at,
    v_state.state_version,
    gm.group_id = v_primary_group_id,
    clock_timestamp()
  from public.group_members gm
  where gm.user_id = p_user_id and gm.left_at is null
  on conflict (group_id, user_id) do update set
    status = excluded.status,
    started_at = excluded.started_at,
    today_seconds = excluded.today_seconds,
    subject_id = excluded.subject_id,
    lease_expires_at = excluded.lease_expires_at,
    state_version = excluded.state_version,
    counts_for_group_progression = excluded.counts_for_group_progression,
    projected_at = excluded.projected_at;
  get diagnostics v_affected = row_count;

  delete from public.group_live_presence projection
  where projection.user_id = p_user_id
    and not exists (
      select 1 from public.group_members gm
      where gm.group_id = projection.group_id
        and gm.user_id = p_user_id
        and gm.left_at is null
    );
  return v_affected;
end;
$$;

create or replace function public.apply_multi_group_presence_state(
  p_status text,
  p_started_at timestamptz default null,
  p_today_seconds integer default 0,
  p_subject_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_state public.user_live_presence_state%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication_required';
  end if;
  if p_status not in ('studying', 'onBreak', 'offline') then
    raise exception 'invalid_presence_status';
  end if;
  if p_today_seconds is null or p_today_seconds < 0 then
    raise exception 'invalid_presence_today_seconds';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 338));

  insert into public.user_live_presence_state (
    user_id, status, started_at, today_seconds, subject_id,
    lease_expires_at, state_version, updated_at
  ) values (
    v_uid,
    p_status,
    case when p_status = 'offline' then null else coalesce(p_started_at, clock_timestamp()) end,
    p_today_seconds,
    p_subject_id,
    case when p_status = 'offline' then null else clock_timestamp() + interval '70 seconds' end,
    1,
    clock_timestamp()
  )
  on conflict (user_id) do update set
    status = excluded.status,
    started_at = excluded.started_at,
    today_seconds = excluded.today_seconds,
    subject_id = excluded.subject_id,
    lease_expires_at = excluded.lease_expires_at,
    state_version = public.user_live_presence_state.state_version + 1,
    updated_at = excluded.updated_at
  returning * into v_state;

  perform public.sync_multi_group_presence_projection(v_uid);
  return jsonb_build_object(
    'user_id', v_state.user_id,
    'status', v_state.status,
    'state_version', v_state.state_version,
    'lease_expires_at', v_state.lease_expires_at
  );
end;
$$;

create or replace function public.heartbeat_multi_group_presence()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_state public.user_live_presence_state%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication_required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 338));
  update public.user_live_presence_state
  set lease_expires_at = clock_timestamp() + interval '70 seconds',
      updated_at = clock_timestamp()
  where user_id = v_uid and status <> 'offline'
  returning * into v_state;

  if not found then
    raise exception 'presence_state_not_active';
  end if;

  -- Projection satırları burada bilinçli olarak güncellenmez: heartbeat yalnız
  -- kanonik lease'i yeniler, fan-out state/membership geçişlerinde yapılır.
  return jsonb_build_object(
    'user_id', v_state.user_id,
    'status', v_state.status,
    'state_version', v_state.state_version,
    'lease_expires_at', v_state.lease_expires_at
  );
end;
$$;

create or replace function public.expire_multi_group_presence_leases(
  p_limit integer default 100
)
returns integer
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_user_id uuid;
  v_count integer := 0;
begin
  if p_limit is null or p_limit < 1 or p_limit > 500 then
    raise exception 'invalid_presence_sweeper_limit';
  end if;

  for v_user_id in
    select user_id
    from public.user_live_presence_state
    where status <> 'offline' and lease_expires_at <= clock_timestamp()
    order by lease_expires_at, user_id
    limit p_limit
    for update skip locked
  loop
    perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 338));
    update public.user_live_presence_state
    set status = 'offline',
        started_at = null,
        subject_id = null,
        lease_expires_at = null,
        state_version = state_version + 1,
        updated_at = clock_timestamp()
    where user_id = v_user_id
      and status <> 'offline'
      and lease_expires_at <= clock_timestamp();
    if found then
      delete from public.group_live_presence where user_id = v_user_id;
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

create or replace function public.sync_multi_group_presence_on_membership_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  perform public.sync_multi_group_presence_projection(
    case when tg_op = 'DELETE' then old.user_id else new.user_id end
  );
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.sync_multi_group_presence_on_primary_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_op = 'INSERT' or new.primary_group_id is distinct from old.primary_group_id then
    perform public.sync_multi_group_presence_projection(new.user_id);
  end if;
  return new;
end;
$$;

drop trigger if exists group_members_multi_group_presence_projection
  on public.group_members;
create trigger group_members_multi_group_presence_projection
  after insert or update of left_at or delete on public.group_members
  for each row execute function public.sync_multi_group_presence_on_membership_change();

drop trigger if exists user_group_preferences_multi_group_presence_projection
  on public.user_group_preferences;
create trigger user_group_preferences_multi_group_presence_projection
  after insert or update of primary_group_id on public.user_group_preferences
  for each row execute function public.sync_multi_group_presence_on_primary_change();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'group_live_presence'
  ) then
    alter publication supabase_realtime add table public.group_live_presence;
  end if;
end;
$$;

revoke all on function public.sync_multi_group_presence_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.sync_multi_group_presence_on_membership_change()
  from public, anon, authenticated;
revoke all on function public.sync_multi_group_presence_on_primary_change()
  from public, anon, authenticated;
revoke all on function public.apply_multi_group_presence_state(text, timestamptz, integer, uuid)
  from public, anon;
revoke all on function public.heartbeat_multi_group_presence()
  from public, anon;
revoke all on function public.expire_multi_group_presence_leases(integer)
  from public, anon, authenticated;
grant execute on function public.apply_multi_group_presence_state(text, timestamptz, integer, uuid)
  to authenticated;
grant execute on function public.heartbeat_multi_group_presence()
  to authenticated;
grant execute on function public.expire_multi_group_presence_leases(integer)
  to service_role;

notify pgrst, 'reload schema';
