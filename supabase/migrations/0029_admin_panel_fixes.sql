-- 1. Adminler tüm grupları görebilir (RLS)
drop policy if exists groups_admin_all on public.groups;
create policy groups_admin_all on public.groups
  for select
  using ( is_super_admin() );

-- 2. admin_notifications tablosu
create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  message text not null,
  is_read boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.admin_notifications enable row level security;

drop policy if exists admin_notifications_select on public.admin_notifications;
create policy admin_notifications_select on public.admin_notifications
  for select using ( auth.uid() = admin_id );

drop policy if exists admin_notifications_update on public.admin_notifications;
create policy admin_notifications_update on public.admin_notifications
  for update using ( auth.uid() = admin_id );

-- 3. Feedback eklendiğinde admin_notifications tablosuna trigger ile kayıt atma
create or replace function public.notify_admins_on_feedback()
returns trigger as $$
begin
  -- Tüm super adminleri bul ve bildirim ekle
  insert into public.admin_notifications (admin_id, title, message)
  select user_id, 'Yeni Geri Bildirim: ' || NEW.subject, left(NEW.message, 100)
  from public.app_admins
  where role = 'super_admin';
  return NEW;
end;
$$ language plpgsql security definer;

drop trigger if exists on_new_feedback on public.feedback_tickets;
create trigger on_new_feedback
  after insert on public.feedback_tickets
  for each row execute function public.notify_admins_on_feedback();
