-- 0093_group_bans.sql
-- WP-391: Grup yöneticisinin üyeyi gruptan kalıcı olarak yasaklaması ve davet kodunu sunucuda yenilemesi.
--
-- Yasak kararları RLS ile yalnız grup yöneticisine görünür. Katılımın iki yolu
-- (davet kodu ve açık grup) SECURITY DEFINER RPC'lerinde aynı kayıtla zorlanır.
--
-- Geri alma (Rollback): DROP FUNCTION public.regenerate_group_invite_code(uuid),
-- public.list_group_bans(uuid), public.unban_group_member(uuid,uuid),
-- public.ban_group_member(uuid,uuid); DROP TABLE public.group_bans; Önceki
-- join fonksiyonlarını geri yüklemek yerine ileri bir migration yazılır.

create table public.group_bans (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  banned_by uuid not null references auth.users(id) on delete restrict,
  banned_at timestamptz not null default now(),
  primary key (group_id, user_id),
  check (user_id <> banned_by)
);

create index group_bans_group_banned_at_idx
  on public.group_bans (group_id, banned_at desc);

alter table public.group_bans enable row level security;

create policy group_bans_admin_read on public.group_bans
  for select to authenticated
  using (public.is_group_admin(group_id));

revoke all on table public.group_bans from anon, authenticated;

create or replace function public.ban_group_member(
  p_group_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
begin
  if v_admin is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_group_admin(p_group_id) then
    raise exception 'not_group_admin';
  end if;
  if p_user_id = v_admin then
    raise exception 'cannot_ban_self';
  end if;
  if exists (
    select 1 from public.groups
    where id = p_group_id and created_by = p_user_id
  ) then
    raise exception 'cannot_ban_group_owner';
  end if;
  if not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = p_user_id and left_at is null
  ) then
    raise exception 'not_active_group_member';
  end if;

  insert into public.group_bans (group_id, user_id, banned_by)
  values (p_group_id, p_user_id, v_admin)
  on conflict (group_id, user_id) do nothing;

  -- Aynı transaction'da aktif üyeliği kapat: yasaklı kişi listede veya sohbet/presence
  -- yüzeylerinde aktif kalmaz; geçmiş üyelik kaydı korunur.
  update public.group_members
  set left_at = now()
  where group_id = p_group_id
    and user_id = p_user_id
    and left_at is null;
end;
$$;

create or replace function public.unban_group_member(
  p_group_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_group_admin(p_group_id) then
    raise exception 'not_group_admin';
  end if;

  delete from public.group_bans
  where group_id = p_group_id and user_id = p_user_id;
end;
$$;

create or replace function public.list_group_bans(p_group_id uuid)
returns table (
  id uuid,
  display_name text,
  avatar_url text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_group_admin(p_group_id) then
    raise exception 'not_group_admin';
  end if;

  return query
  select p.id, p.display_name, p.avatar_url, p.created_at
  from public.group_bans b
  join public.profiles p on p.id = b.user_id
  where b.group_id = p_group_id
  order by b.banned_at desc, b.user_id;
end;
$$;

create or replace function public.regenerate_group_invite_code(p_group_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_attempt integer;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_group_admin(p_group_id) then
    raise exception 'not_group_admin';
  end if;

  for v_attempt in 1..8 loop
    v_code := public.gen_invite_code();
    begin
      update public.groups
      set invite_code = v_code
      where id = p_group_id;
      if not found then
        raise exception 'group_not_found';
      end if;
      return v_code;
    exception when unique_violation then
      -- Davet kodu tekildir; olağan dışı çakışmada aynı işlem içinde tekrar üret.
      continue;
    end;
  end loop;
  raise exception 'invite_code_regeneration_failed';
end;
$$;

create or replace function public.join_group(p_code text)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
  uid uuid := auth.uid();
  is_active boolean;
  active_count integer;
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;
  select * into g from public.groups
  where invite_code = upper(btrim(p_code)) limit 1 for update;
  if g.id is null then return null; end if;
  if exists (select 1 from public.group_bans where group_id = g.id and user_id = uid) then
    raise exception 'group_banned';
  end if;
  select exists (select 1 from public.group_members where group_id = g.id and user_id = uid and left_at is null) into is_active;
  if is_active then return g; end if;
  select count(*)::integer into active_count from public.group_members where group_id = g.id and left_at is null;
  if active_count >= g.member_limit then raise exception 'Grup dolu.'; end if;
  insert into public.group_members (group_id, user_id, role, joined_at, left_at)
  values (g.id, uid, 'member', now(), null)
  on conflict (group_id, user_id) do update set left_at = null, joined_at = now();
  return g;
end;
$$;

create or replace function public.join_public_group(p_group_id uuid)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
  uid uuid := auth.uid();
  is_active boolean;
  active_count integer;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into g from public.groups where id = p_group_id for update;
  if g.id is null or g.visibility <> 'public' then raise exception 'Bu grup açık değil.'; end if;
  if exists (select 1 from public.group_bans where group_id = g.id and user_id = uid) then
    raise exception 'group_banned';
  end if;
  select exists (select 1 from public.group_members where group_id = g.id and user_id = uid and left_at is null) into is_active;
  if is_active then return g; end if;
  select count(*)::integer into active_count from public.group_members where group_id = g.id and left_at is null;
  if active_count >= g.member_limit then raise exception 'Grup dolu.'; end if;
  insert into public.group_members (group_id, user_id, role, joined_at, left_at)
  values (g.id, uid, 'member', now(), null)
  on conflict (group_id, user_id) do update set left_at = null, joined_at = now();
  return g;
end;
$$;

grant execute on function public.ban_group_member(uuid, uuid),
  public.unban_group_member(uuid, uuid), public.list_group_bans(uuid),
  public.regenerate_group_invite_code(uuid), public.join_group(text),
  public.join_public_group(uuid) to authenticated;
