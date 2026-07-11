-- 0021_admin_operations.sql
-- Duyurular ve rapor iç notları tabloları.

-- Duyurular tablosu
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  message text not null,
  target_type text not null check (target_type in ('all', 'group', 'user')),
  target_id text, -- Eğer 'all' ise null olabilir
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users (id) on delete restrict
);

create index if not exists idx_announcements_created_at
  on public.announcements (created_at desc);

alter table public.announcements enable row level security;

-- Adminler duyuruları yönetebilir (ekleme/silme)
drop policy if exists announcements_admin_all on public.announcements;
create policy announcements_admin_all on public.announcements
  for all to authenticated 
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- Herkes kendine ait veya genel duyuruları görebilir
drop policy if exists announcements_select_user on public.announcements;
create policy announcements_select_user on public.announcements
  for select to authenticated
  using (
    target_type = 'all' 
    or (target_type = 'user' and target_id = auth.uid()::text)
    or (target_type = 'group' and exists (
         select 1 from public.group_members sgm
         where sgm.group_id::text = target_id
           and sgm.user_id = auth.uid()
           and sgm.left_at is null
       ))
  );

-- Rapor iç notları
create table if not exists public.feedback_ticket_notes (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.feedback_tickets (id) on delete cascade,
  admin_id uuid not null references auth.users (id) on delete restrict,
  note text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_feedback_notes_ticket
  on public.feedback_ticket_notes (ticket_id);

alter table public.feedback_ticket_notes enable row level security;

-- Sadece adminler iç notları görebilir ve yazabilir
drop policy if exists ticket_notes_admin_all on public.feedback_ticket_notes;
create policy ticket_notes_admin_all on public.feedback_ticket_notes
  for all to authenticated 
  using (public.is_super_admin())
  with check (public.is_super_admin());
