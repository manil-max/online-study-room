-- 0049_group_avatar.sql
-- Private group avatars with signed access
--
-- Adds versioned avatar object paths to groups, creates a private Storage bucket,
-- and limits reads to active members or authenticated users discovering a public
-- group. Only the creator-admin may upload/delete objects. Replacing an avatar or
-- deleting a group removes the old object in the same database transaction.
--
-- Geri alma (Rollback): Uygulama avatar alanlarını yok sayacak önceki sürüme
-- döndürülür. Bucket, kolonlar ve mevcut nesneler veri kaybını önlemek için
-- silinmez. Gerekirse yeni write politikaları kaldırılarak bucket salt-okunur
-- yapılır; discover_public_groups önceki altı sütunlu sözleşmesine döndürülür.

alter table public.groups
  add column if not exists avatar_path text,
  add column if not exists avatar_updated_at timestamptz;

alter table public.groups
  drop constraint if exists groups_avatar_path_format;
alter table public.groups
  add constraint groups_avatar_path_format check (
    avatar_path is null
    or avatar_path ~ ('^' || id::text || '/[0-9a-f-]{36}\.(jpg|jpeg|png|webp)$')
  );

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'group-avatars',
  'group-avatars',
  false,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists group_avatars_member_read on storage.objects;
create policy group_avatars_member_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'group-avatars'
    and array_length(storage.foldername(name), 1) >= 1
    and exists (
      select 1
      from public.groups g
      where g.id::text = (storage.foldername(name))[1]
        and (
          g.visibility = 'public'
          or public.is_group_member(g.id)
        )
    )
  );

drop policy if exists group_avatars_admin_insert on storage.objects;
create policy group_avatars_admin_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'group-avatars'
    and array_length(storage.foldername(name), 1) = 1
    and name ~ ('^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|jpeg|png|webp)$')
    and public.is_group_admin(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists group_avatars_admin_update on storage.objects;
create policy group_avatars_admin_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'group-avatars'
    and public.is_group_admin(((storage.foldername(name))[1])::uuid)
  )
  with check (
    bucket_id = 'group-avatars'
    and array_length(storage.foldername(name), 1) = 1
    and name ~ ('^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|jpeg|png|webp)$')
    and public.is_group_admin(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists group_avatars_admin_delete on storage.objects;
create policy group_avatars_admin_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'group-avatars'
    and public.is_group_admin(((storage.foldername(name))[1])::uuid)
  );

create or replace function public.cleanup_group_avatar_object()
returns trigger
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  old_path text;
begin
  if tg_op = 'DELETE' then
    old_path := old.avatar_path;
  elsif old.avatar_path is distinct from new.avatar_path then
    old_path := old.avatar_path;
  end if;

  if old_path is not null then
    delete from storage.objects
    where bucket_id = 'group-avatars' and name = old_path;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.cleanup_group_avatar_object() from public, anon, authenticated;

drop trigger if exists groups_cleanup_avatar_object on public.groups;
create trigger groups_cleanup_avatar_object
  after update of avatar_path or delete on public.groups
  for each row execute function public.cleanup_group_avatar_object();

-- Return the object path, never a permanent URL. The authenticated client must
-- obtain a short-lived signed URL, which re-checks the Storage SELECT policy.
drop function if exists public.discover_public_groups(text, integer, integer);
create function public.discover_public_groups(
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
  created_at timestamptz,
  avatar_path text,
  avatar_updated_at timestamptz
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
    g.created_at,
    g.avatar_path,
    g.avatar_updated_at
  from public.groups g
  left join public.group_members m
    on m.group_id = g.id and m.left_at is null
  where g.visibility = 'public'
    and (
      btrim(coalesce(p_query, '')) = ''
      or position(lower(left(btrim(p_query), 64)) in lower(g.name)) > 0
    )
  group by
    g.id,
    g.name,
    g.daily_goal_minutes,
    g.member_limit,
    g.created_at,
    g.avatar_path,
    g.avatar_updated_at
  order by g.created_at desc, g.id
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.discover_public_groups(text, integer, integer)
  from public, anon;
grant execute on function public.discover_public_groups(text, integer, integer)
  to authenticated;

notify pgrst, 'reload schema';
