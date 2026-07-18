--0044_feedback_ensure.sql
-- Feedback şema/policy/bucket idempotent "ensure" (WP-177).
-- 0018 + 0019 niyetini güvenle yeniden kurar; iki kez çalıştırılabilir.
--
-- Geri alma: feedback_tickets / app_admins / bucket silmek üretimde tehlikelidir;
-- yalnız policy drop mümkün — bu dosya recreate eder, drop-all yapmaz.

-- --- Tablolar ---
create table if not exists public.app_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.feedback_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('feedback', 'bug')),
  subject text not null check (char_length(trim(subject)) between 1 and 80),
  message text not null check (char_length(trim(message)) between 1 and 1200),
  status text not null default 'open' check (status in ('open', 'in_progress', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.feedback_tickets
  add column if not exists attachment_path text;

create index if not exists idx_feedback_tickets_user_created
  on public.feedback_tickets (user_id, created_at desc);

create index if not exists idx_feedback_tickets_status_created
  on public.feedback_tickets (status, created_at desc);

alter table public.app_admins enable row level security;
alter table public.feedback_tickets enable row level security;

-- is_super_admin (0018 ile aynı niyet; zaten varsa replace)
create or replace function public.is_super_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.app_admins
      where user_id = auth.uid()
    );
$$;

grant execute on function public.is_super_admin() to authenticated;

-- Feedback policies
drop policy if exists feedback_tickets_select on public.feedback_tickets;
create policy feedback_tickets_select on public.feedback_tickets
  for select to authenticated
  using (user_id = auth.uid() or public.is_super_admin());

drop policy if exists feedback_tickets_insert on public.feedback_tickets;
create policy feedback_tickets_insert on public.feedback_tickets
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and status = 'open'
  );

drop policy if exists feedback_tickets_update_admin on public.feedback_tickets;
create policy feedback_tickets_update_admin on public.feedback_tickets
  for update to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- API grants (eksik ortamlar için)
grant select, insert on public.feedback_tickets to authenticated;

-- Storage bucket
insert into storage.buckets (id, name, public)
values ('feedback_attachments', 'feedback_attachments', false)
on conflict (id) do nothing;

drop policy if exists "kullanici_kendi_ekini_yukleyebilir" on storage.objects;
create policy "kullanici_kendi_ekini_yukleyebilir"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'feedback_attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "kullanici_ve_admin_ekleri_okuyabilir" on storage.objects;
create policy "kullanici_ve_admin_ekleri_okuyabilir"
on storage.objects for select to authenticated
using (
  bucket_id = 'feedback_attachments'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_super_admin()
  )
);
