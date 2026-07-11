-- 0022_social_profile_progression.sql
-- Sosyal profil, XP/taç ilerlemesi ve kullanıcı başarı kayıtları.
-- Bu migration tekrar çalıştırılabilir olmalıdır; SQL Editor'da yarım kalan
-- çalıştırmalar sonraki denemeyi engellemez.

alter table public.gamification_profiles
  add column if not exists xp integer not null default 0,
  add column if not exists crown_rank text not null default 'wood_novice',
  add column if not exists selected_badges text[] not null default '{}';

alter table public.gamification_profiles
  alter column crown_rank set default 'wood_novice';

create table if not exists public.user_achievements (
  id uuid primary key default gen_random_uuid(),
  -- Eski kullanıcıların gamification_profiles satırı henüz oluşmamış olabilir.
  -- auth.users her kullanıcı için bulunduğundan ilişki doğrudan ona kurulur.
  user_id uuid not null references auth.users (id) on delete cascade,
  achievement_id text not null,
  tier integer not null default 1 check (tier between 1 and 6),
  progress integer not null default 0 check (progress >= 0),
  unlocked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, achievement_id)
);

-- Eski, yarım kalmış sürüm `uuid_generate_v4()` ve gamification_profiles
-- foreign key'i bırakmış olabilir. Her iki tanımı da hedef şemaya getir.
alter table public.user_achievements
  alter column id set default gen_random_uuid();

alter table public.user_achievements
  drop constraint if exists user_achievements_user_id_fkey;

alter table public.user_achievements
  add constraint user_achievements_user_id_fkey
  foreign key (user_id) references auth.users (id) on delete cascade;

alter table public.user_achievements enable row level security;

-- Sosyal profil vitrini için giriş yapan kullanıcılar başarıları okuyabilir.
drop policy if exists "Anyone can view user achievements" on public.user_achievements;
create policy "Anyone can view user achievements"
  on public.user_achievements for select to authenticated
  using (true);

drop policy if exists "Users can insert their own achievements" on public.user_achievements;
create policy "Users can insert their own achievements"
  on public.user_achievements for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own achievements" on public.user_achievements;
create policy "Users can update their own achievements"
  on public.user_achievements for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.touch_user_achievements_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists update_user_achievements_updated_at on public.user_achievements;
create trigger update_user_achievements_updated_at
before update on public.user_achievements
for each row execute function public.touch_user_achievements_updated_at();

-- user_achievements repository'de stream ile izlenir.
do $$
begin
  alter publication supabase_realtime add table public.user_achievements;
exception
  when duplicate_object then null;
end $$;

-- Sosyal profil vitrini için gamification profilleri giriş yapan kullanıcılara açıktır.
drop policy if exists gamification_profiles_select on public.gamification_profiles;
create policy gamification_profiles_select on public.gamification_profiles
  for select to authenticated
  using (true);
