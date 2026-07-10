-- 0017_gamification_profiles.sql
-- Kullanıcının kalıcı gamification cüzdanı. Başarımlar/taçlar oturumlardan
-- türetilir; burada sadece tüketilebilir seri koruma hakkı tutulur.

create table if not exists public.gamification_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  streak_freezes integer not null default 1 check (streak_freezes between 0 and 99),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.gamification_profiles enable row level security;

drop policy if exists gamification_profiles_select on public.gamification_profiles;
create policy gamification_profiles_select on public.gamification_profiles
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists gamification_profiles_insert on public.gamification_profiles;
create policy gamification_profiles_insert on public.gamification_profiles
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists gamification_profiles_update on public.gamification_profiles;
create policy gamification_profiles_update on public.gamification_profiles
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create or replace function public.handle_new_user_gamification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.gamification_profiles (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_gamification on auth.users;
create trigger on_auth_user_created_gamification
  after insert on auth.users
  for each row execute function public.handle_new_user_gamification();

do $$
begin
  alter publication supabase_realtime add table public.gamification_profiles;
exception
  when duplicate_object then null;
end $$;
