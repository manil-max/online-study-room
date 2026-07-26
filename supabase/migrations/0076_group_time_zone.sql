-- 0076_group_time_zone.sql
-- WP-326: Grup gün sınırı UTC offset'iyle değil, yaz saati güvenli IANA saat
-- dilimiyle tanımlanır. Mevcut gruplar varsayılan Europe/Istanbul'da kalır;
-- bu migration geçmiş study_sessions.day damgalarını değiştirmez.
--
-- Geri alma (bakım penceresinde): update_group_time_zone RPC'sini ve trigger'ı
-- kaldır; ardından groups.time_zone kolonunu kaldır. 0076 sonrası oluşturulan
-- grupların bölge tercihi kaybolur, damgalanmış oturum verisi kaybolmaz.

alter table public.groups
  add column if not exists time_zone text not null default 'Europe/Istanbul';

-- PostgreSQL'in kendi tzdata kataloğu tek doğruluk kaynağıdır. Offset (-5 gibi)
-- kabul edilmez; America/New_York gibi IANA adı yaz/kış saati geçişini taşır.
create or replace function public.is_valid_group_time_zone(p_time_zone text)
returns boolean
language sql
stable
set search_path = pg_catalog
as $$
  select coalesce(trim(p_time_zone), '') = 'UTC'
    or exists (
      select 1
      from pg_timezone_names
      where name = trim(p_time_zone)
        and name like '%/%'
    );
$$;

create or replace function public.guard_group_time_zone()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  new.time_zone := trim(coalesce(new.time_zone, ''));
  if not public.is_valid_group_time_zone(new.time_zone) then
    raise exception 'invalid_group_time_zone';
  end if;
  return new;
end;
$$;

drop trigger if exists groups_time_zone_guard on public.groups;
create trigger groups_time_zone_guard
  before insert or update of time_zone on public.groups
  for each row execute function public.guard_group_time_zone();

-- 0071'deki üç argümanlı sürüm eski istemciler için kalır ve sütun varsayılanını
-- kullanır. Yeni dört argümanlı sürüm, seçilen bölgeyi transaction içinde yazar.
create or replace function public.create_group_with_access(
  p_name text,
  p_visibility text,
  p_member_limit integer,
  p_time_zone text
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
  normalized_time_zone text := trim(coalesce(p_time_zone, ''));
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
  if p_member_limit not between 2 and 8 then
    raise exception 'Üye sınırı 2 ile 8 arasında olmalı.';
  end if;
  if not public.is_valid_group_time_zone(normalized_time_zone) then
    raise exception 'invalid_group_time_zone';
  end if;

  for attempt in 1..8 loop
    begin
      insert into public.groups (
        name, invite_code, created_by, visibility, member_limit, time_zone
      ) values (
        normalized_name,
        public.gen_invite_code(),
        uid,
        normalized_visibility,
        p_member_limit,
        normalized_time_zone
      ) returning * into g;

      insert into public.group_members (group_id, user_id, role)
        values (g.id, uid, 'admin');
      return g;
    exception when unique_violation then
      continue;
    end;
  end loop;

  raise exception 'Grup oluşturulamadı, tekrar deneyin.';
end;
$$;

grant execute on function public.create_group_with_access(text, text, integer, text)
  to authenticated;

create or replace function public.update_group_time_zone(
  p_group_id uuid,
  p_time_zone text
)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.groups;
  normalized_time_zone text := trim(coalesce(p_time_zone, ''));
begin
  if auth.uid() is null or not public.is_group_admin(p_group_id) then
    raise exception 'not_group_admin';
  end if;
  if not public.is_valid_group_time_zone(normalized_time_zone) then
    raise exception 'invalid_group_time_zone';
  end if;

  update public.groups
  set time_zone = normalized_time_zone
  where id = p_group_id
  returning * into g;
  if g.id is null then
    raise exception 'group_not_found';
  end if;
  return g;
end;
$$;

grant execute on function public.update_group_time_zone(uuid, text) to authenticated;

comment on column public.groups.time_zone is
  'WP-326: IANA group day-boundary zone; never a fixed UTC offset.';
