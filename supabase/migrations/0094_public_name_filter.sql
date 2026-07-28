-- 0094_public_name_filter.sql
-- WP-392: Görünen ad ve grup adındaki açık istismarı sunucuda, güncellenebilir veri listesiyle engeller.
--
-- Geri alma (Rollback): trigger'ları ve yardımcı fonksiyonları DROP ederek filtreyi
-- kaldıran ileri migration yazılır; yasaklı terim verisi korunur.

create table public.public_name_blocked_terms (
  normalized_term text primary key,
  created_at timestamptz not null default now(),
  check (normalized_term = lower(normalized_term)),
  check (char_length(normalized_term) >= 3)
);

alter table public.public_name_blocked_terms enable row level security;
revoke all on table public.public_name_blocked_terms from anon, authenticated;

insert into public.public_name_blocked_terms (normalized_term)
values
  ('amk'), ('amq'), ('fuck'), ('shit'), ('bitch'), ('asshole')
on conflict do nothing;

create or replace function public.normalize_public_name(p_value text)
returns text
language sql
immutable
set search_path = public
as $$
  select regexp_replace(
    translate(lower(coalesce(p_value, '')), 'çğıöşü', 'cgiosu'),
    '[^[:alnum:]]', '', 'g'
  );
$$;

create or replace function public.assert_public_name_allowed(p_value text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_normalized text := public.normalize_public_name(p_value);
begin
  if exists (
    select 1 from public.public_name_blocked_terms
    where position(normalized_term in v_normalized) > 0
  ) then
    raise exception 'public_name_not_allowed';
  end if;
end;
$$;

create or replace function public.enforce_profile_display_name_filter()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_public_name_allowed(new.display_name);
  return new;
end;
$$;

create or replace function public.enforce_group_name_filter()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_public_name_allowed(new.name);
  return new;
end;
$$;

drop trigger if exists profiles_public_name_filter on public.profiles;
create trigger profiles_public_name_filter
  before insert or update of display_name on public.profiles
  for each row execute function public.enforce_profile_display_name_filter();

drop trigger if exists groups_public_name_filter on public.groups;
create trigger groups_public_name_filter
  before insert or update of name on public.groups
  for each row execute function public.enforce_group_name_filter();
