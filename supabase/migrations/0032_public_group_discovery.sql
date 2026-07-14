-- 0032: Global açık/özel grup keşfi ve atomik katılım
--
-- Yeni gruplar varsayılan olarak private kalır. Public gruplar yalnız güvenli
-- özet döndüren SECURITY DEFINER RPC ile keşfedilir; davet kodu, üye listesi,
-- oturum, presence ve sosyal profil üyelik öncesinde RLS altında kapalı kalır.
-- Katılım ve kapasite denetimi grup satırı kilitlenerek atomik yapılır.
--
-- Geri alma (Rollback): DROP FUNCTION public.discover_public_groups(text,int,int),
-- public.join_public_group(uuid), public.create_group_with_access(text,text,int),
-- public.update_group_access(uuid,text,int); DROP TRIGGER
-- groups_member_limit_guard ON public.groups; DROP FUNCTION
-- public.guard_group_member_limit(); DROP INDEX idx_groups_public_discovery;
-- Yeni sütunlar bırakılırsa uygulama bunları private/50 varsayılanıyla yok sayar.

alter table public.groups
  add column if not exists visibility text not null default 'private',
  add column if not exists member_limit integer not null default 50;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'groups_visibility_check'
  ) then
    alter table public.groups
      add constraint groups_visibility_check
      check (visibility in ('private', 'public'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'groups_member_limit_check'
  ) then
    alter table public.groups
      add constraint groups_member_limit_check
      check (member_limit between 2 and 100);
  end if;
end
$$;

create index if not exists idx_groups_public_discovery
  on public.groups (created_at desc, id)
  where visibility = 'public';

-- Bir admin üye sınırını mevcut aktif üye sayısının altına indiremez. Bu
-- koruma doğrudan tablo update'i için de geçerlidir; join RPC'leri ayrıca
-- grup satırını kilitleyerek yarış koşulunu kapatır.
create or replace function public.guard_group_member_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  active_count integer;
begin
  if new.member_limit is distinct from old.member_limit then
    select count(*)::integer into active_count
    from public.group_members
    where group_id = new.id and left_at is null;

    if new.member_limit < active_count then
      raise exception 'Üye sınırı mevcut aktif üye sayısından düşük olamaz.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists groups_member_limit_guard on public.groups;
create trigger groups_member_limit_guard
  before update of member_limit on public.groups
  for each row execute function public.guard_group_member_limit();

-- Yeni istemci sözleşmesi: grup + admin üyeliği tek transaction içinde,
-- görünürlük ve limit sunucuda doğrulanarak oluşturulur. Eski create_group(text)
-- geriye uyumluluk için private/50 varsayılanlarıyla çalışmaya devam eder.
create or replace function public.create_group_with_access(
  p_name text,
  p_visibility text default 'private',
  p_member_limit integer default 50
)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
  uid uuid := auth.uid();
  normalized_name text := btrim(coalesce(p_name, ''));
  normalized_visibility text := lower(btrim(coalesce(p_visibility, 'private')));
  attempt integer;
begin
  if uid is null then
    raise exception 'Oturum bulunamadı';
  end if;
  if normalized_name = '' or char_length(normalized_name) > 64 then
    raise exception 'Grup adı 1 ile 64 karakter arasında olmalı.';
  end if;
  if normalized_visibility not in ('private', 'public') then
    raise exception 'Geçersiz grup görünürlüğü.';
  end if;
  if p_member_limit not between 2 and 100 then
    raise exception 'Üye sınırı 2 ile 100 arasında olmalı.';
  end if;

  for attempt in 1..8 loop
    begin
      insert into public.groups (
        name, invite_code, created_by, visibility, member_limit
      ) values (
        normalized_name,
        public.gen_invite_code(),
        uid,
        normalized_visibility,
        p_member_limit
      ) returning * into g;

      insert into public.group_members (group_id, user_id, role)
        values (g.id, uid, 'admin');
      return g;
    exception when unique_violation then
      -- Davet kodu çakışırsa yeni kodla tekrar dene.
      continue;
    end;
  end loop;

  raise exception 'Grup oluşturulamadı, tekrar deneyin.';
end;
$$;

grant execute on function public.create_group_with_access(text, text, integer)
  to authenticated;

-- Public liste, yalnızca kartta güvenle gösterilebilecek alanları döndürür.
-- groups_select RLS politikası genişletilmez; böylece invite_code ve üyelik
-- öncesi grup içi veriler normal tablodan okunamaz.
create or replace function public.discover_public_groups(
  p_query text default '',
  p_offset integer default 0,
  p_limit integer default 20
)
returns table (
  id uuid,
  name text,
  daily_goal_minutes integer,
  member_count integer,
  member_limit integer,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    g.id,
    g.name,
    g.daily_goal_minutes,
    count(m.user_id)::integer as member_count,
    g.member_limit,
    g.created_at
  from public.groups g
  left join public.group_members m
    on m.group_id = g.id and m.left_at is null
  where g.visibility = 'public'
    and (
      btrim(coalesce(p_query, '')) = ''
      or position(lower(left(btrim(p_query), 64)) in lower(g.name)) > 0
    )
  group by g.id, g.name, g.daily_goal_minutes, g.member_limit, g.created_at
  order by g.created_at desc, g.id
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

grant execute on function public.discover_public_groups(text, integer, integer)
  to authenticated;

-- Private davet kodu katılımı korunur ama yeni limit için atomik hale gelir.
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
    raise exception 'Oturum bulunamadı';
  end if;

  select * into g
  from public.groups
  where invite_code = upper(btrim(p_code))
  limit 1
  for update;

  if g.id is null then
    return null;
  end if;

  select exists (
    select 1 from public.group_members
    where group_id = g.id and user_id = uid and left_at is null
  ) into is_active;
  if is_active then
    return g;
  end if;

  select count(*)::integer into active_count
  from public.group_members
  where group_id = g.id and left_at is null;
  if active_count >= g.member_limit then
    raise exception 'Grup dolu.';
  end if;

  insert into public.group_members (group_id, user_id, role, joined_at, left_at)
    values (g.id, uid, 'member', now(), null)
  on conflict (group_id, user_id) do update
    set left_at = null,
        joined_at = now();
  return g;
end;
$$;

-- Açık gruba katılım: önce görünürlük kontrolü, sonra aynı grup satırı
-- kilidi altında kapasite kontrolü. Böylece son boşluk için paralel istekler
-- 50 sınırını aşamaz; zaten aktif kullanıcı idempotent olarak başarılı döner.
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
  if uid is null then
    raise exception 'Oturum bulunamadı';
  end if;

  select * into g
  from public.groups
  where id = p_group_id
  for update;

  if g.id is null or g.visibility <> 'public' then
    raise exception 'Bu grup açık değil.';
  end if;

  select exists (
    select 1 from public.group_members
    where group_id = g.id and user_id = uid and left_at is null
  ) into is_active;
  if is_active then
    return g;
  end if;

  select count(*)::integer into active_count
  from public.group_members
  where group_id = g.id and left_at is null;
  if active_count >= g.member_limit then
    raise exception 'Grup dolu.';
  end if;

  insert into public.group_members (group_id, user_id, role, joined_at, left_at)
    values (g.id, uid, 'member', now(), null)
  on conflict (group_id, user_id) do update
    set left_at = null,
        joined_at = now();
  return g;
end;
$$;

grant execute on function public.join_public_group(uuid) to authenticated;

-- Görünürlük/limit yalnız oluşturucu-admin tarafından değiştirilebilir;
-- aktif üye sayısının altına limit indirmek sunucuda reddedilir.
create or replace function public.update_group_access(
  p_group_id uuid,
  p_visibility text,
  p_member_limit integer
)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
  normalized_visibility text := lower(btrim(coalesce(p_visibility, '')));
  active_count integer;
begin
  if auth.uid() is null or not public.is_group_admin(p_group_id) then
    raise exception 'Bu işlem için grup yöneticisi olmalısınız.';
  end if;
  if normalized_visibility not in ('private', 'public') then
    raise exception 'Geçersiz grup görünürlüğü.';
  end if;
  if p_member_limit not between 2 and 100 then
    raise exception 'Üye sınırı 2 ile 100 arasında olmalı.';
  end if;

  select * into g from public.groups where id = p_group_id for update;
  if g.id is null then
    raise exception 'Grup bulunamadı.';
  end if;

  select count(*)::integer into active_count
  from public.group_members
  where group_id = g.id and left_at is null;
  if p_member_limit < active_count then
    raise exception 'Üye sınırı mevcut aktif üye sayısından düşük olamaz.';
  end if;

  update public.groups
  set visibility = normalized_visibility,
      member_limit = p_member_limit
  where id = g.id
  returning * into g;
  return g;
end;
$$;

grant execute on function public.update_group_access(uuid, text, integer)
  to authenticated;
