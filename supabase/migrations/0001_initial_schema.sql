-- =====================================================================
-- 0001_initial_schema.sql — Online Çalışma Sınıfı — ilk şema
-- Bkz. project.md §6 (Veri Modeli) ve §7 (Güvenlik).
--
-- Bu dosyayı Supabase panelinde:  SQL Editor → New query → yapıştır → Run
-- ile bir kez çalıştırın. Tablolar, ilişkiler, otomatik profil oluşturma
-- ve RLS (satır seviyesi güvenlik) politikalarını kurar.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLOLAR
-- ---------------------------------------------------------------------

-- profiles: auth.users ile bire bir. Kayıt olunca trigger ile otomatik dolar.
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  avatar_url   text,
  created_at   timestamptz not null default now()
);

-- groups (sınıf): davet koduyla katılınır.
create table if not exists public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  invite_code text not null unique,
  created_by  uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

-- group_members: kim hangi sınıfta.
create table if not exists public.group_members (
  group_id  uuid not null references public.groups (id) on delete cascade,
  user_id   uuid not null references auth.users (id) on delete cascade,
  role      text not null default 'member' check (role in ('admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

-- subjects (ders/kategori) — opsiyonel; ileride kullanılabilir (project.md §9).
create table if not exists public.subjects (
  id      uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name    text not null,
  color   text
);

-- study_sessions: tüm çalışma kayıtları (istatistik bunlardan üretilir).
create table if not exists public.study_sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  group_id         uuid not null references public.groups (id) on delete cascade,
  subject_id       uuid references public.subjects (id) on delete set null,
  start_time       timestamptz not null,
  end_time         timestamptz not null,
  duration_seconds integer not null check (duration_seconds >= 0),
  -- 'live' | 'manual' — sadece kayıt amaçlı; istatistikte/UI'da ayrım yapılmaz.
  source           text not null default 'live' check (source in ('live', 'manual')),
  created_at       timestamptz not null default now()
);

create index if not exists idx_sessions_user  on public.study_sessions (user_id, start_time desc);
create index if not exists idx_sessions_group on public.study_sessions (group_id, start_time desc);

-- presence: canlı "kim çalışıyor". Tek satır/kullanıcı; upsert ile güncellenir.
create table if not exists public.presence (
  user_id       uuid primary key references auth.users (id) on delete cascade,
  group_id      uuid references public.groups (id) on delete cascade,
  status        text not null default 'offline' check (status in ('studying', 'onBreak', 'offline')),
  started_at    timestamptz,
  today_seconds integer not null default 0,
  subject_id    uuid references public.subjects (id) on delete set null,
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- OTOMATİK PROFİL OLUŞTURMA
-- Kullanıcı kayıt olunca auth.users'a satır eklenir; bu trigger ona
-- karşılık gelen profiles satırını (kayıt sırasında verilen display_name ile) açar.
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- YARDIMCI: kullanıcı bir sınıfın üyesi mi?
-- SECURITY DEFINER → group_members RLS'ini atlar, böylece politikalar
-- birbirini tetikleyip sonsuz döngüye girmez.
-- ---------------------------------------------------------------------
create or replace function public.is_group_member(gid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid and user_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------
-- RLS — satır seviyesi güvenlik
-- Kapalı bir güven grubu olduğundan sınıf içi veri TAM ŞEFFAFTIR
-- (project.md §3.4): aynı sınıfın üyeleri birbirinin verisini görür.
-- ---------------------------------------------------------------------
alter table public.profiles       enable row level security;
alter table public.groups         enable row level security;
alter table public.group_members  enable row level security;
alter table public.subjects       enable row level security;
alter table public.study_sessions enable row level security;
alter table public.presence       enable row level security;

-- profiles: giriş yapan herkes profilleri okuyabilir; kişi sadece kendi profilini yazar.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);

drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles
  for insert to authenticated with check (id = auth.uid());

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- groups: davet kodu aranabilsin diye giriş yapan herkes okur; oluşturan kendi adına ekler.
drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups
  for select to authenticated using (true);

drop policy if exists groups_insert on public.groups;
create policy groups_insert on public.groups
  for insert to authenticated with check (created_by = auth.uid());

-- group_members: aynı sınıfın üyeleri üye listesini görür; kişi kendini ekler/çıkarır.
drop policy if exists members_select on public.group_members;
create policy members_select on public.group_members
  for select to authenticated using (public.is_group_member(group_id));

drop policy if exists members_insert on public.group_members;
create policy members_insert on public.group_members
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists members_delete on public.group_members;
create policy members_delete on public.group_members
  for delete to authenticated using (user_id = auth.uid());

-- subjects: kişi yalnızca kendi derslerini yönetir.
drop policy if exists subjects_all on public.subjects;
create policy subjects_all on public.subjects
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- study_sessions: sınıf üyeleri herkesin oturumlarını GÖRÜR (şeffaflık);
-- kişi sadece kendi oturumlarını ekler/günceller/siler.
drop policy if exists sessions_select on public.study_sessions;
create policy sessions_select on public.study_sessions
  for select to authenticated using (public.is_group_member(group_id));

drop policy if exists sessions_insert on public.study_sessions;
create policy sessions_insert on public.study_sessions
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists sessions_update on public.study_sessions;
create policy sessions_update on public.study_sessions
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists sessions_delete on public.study_sessions;
create policy sessions_delete on public.study_sessions
  for delete to authenticated using (user_id = auth.uid());

-- presence: sınıf üyeleri birbirinin durumunu görür; kişi sadece kendi satırını yazar.
drop policy if exists presence_select on public.presence;
create policy presence_select on public.presence
  for select to authenticated using (public.is_group_member(group_id));

drop policy if exists presence_upsert on public.presence;
create policy presence_upsert on public.presence
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists presence_update on public.presence;
create policy presence_update on public.presence
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- REALTIME — canlı yayın için tabloları publication'a ekle
-- (presence + study_sessions + group_members anlık güncellenir).
-- ---------------------------------------------------------------------
alter publication supabase_realtime add table public.presence;
alter publication supabase_realtime add table public.study_sessions;
alter publication supabase_realtime add table public.group_members;
alter publication supabase_realtime add table public.groups;
