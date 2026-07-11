-- 0018_admin_feedback.sql
-- Güvenli admin ve geri bildirim temeli.
--
-- Uyguladıktan sonra ilk süper-admin elle eklenir:
-- insert into public.app_admins (user_id)
-- values ('<auth.users.id>')
-- on conflict (user_id) do nothing;
--
-- İlk admin UUID'si migration'a yazılmaz; service_role anahtarı istemciye konmaz.

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

create index if not exists idx_feedback_tickets_user_created
  on public.feedback_tickets (user_id, created_at desc);

create index if not exists idx_feedback_tickets_status_created
  on public.feedback_tickets (status, created_at desc);

alter table public.app_admins enable row level security;
alter table public.feedback_tickets enable row level security;

-- app_admins için doğrudan istemci policy'si yoktur. Okuma yalnızca
-- SECURITY DEFINER helper üzerinden yapılır.
drop policy if exists app_admins_select on public.app_admins;
drop policy if exists app_admins_insert on public.app_admins;
drop policy if exists app_admins_update on public.app_admins;
drop policy if exists app_admins_delete on public.app_admins;

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

create or replace function public.admin_dashboard_summary()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin';
  end if;

  return jsonb_build_object(
    'user_count', (select count(*) from public.profiles),
    'group_count', (select count(*) from public.groups),
    'session_count', (select count(*) from public.study_sessions),
    'open_ticket_count', (
      select count(*) from public.feedback_tickets where status = 'open'
    )
  );
end;
$$;

create or replace function public.admin_feedback_tickets(p_status text default null)
returns table (
  id uuid,
  user_id uuid,
  kind text,
  subject text,
  message text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  reporter_display_name text
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin';
  end if;

  if p_status is not null and p_status not in ('open', 'in_progress', 'closed') then
    raise exception 'invalid_feedback_status';
  end if;

  return query
  select
    ticket.id,
    ticket.user_id,
    ticket.kind,
    ticket.subject,
    ticket.message,
    ticket.status,
    ticket.created_at,
    ticket.updated_at,
    profile.display_name as reporter_display_name
  from public.feedback_tickets ticket
  left join public.profiles profile on profile.id = ticket.user_id
  where p_status is null or ticket.status = p_status
  order by ticket.created_at desc;
end;
$$;

create or replace function public.admin_update_feedback_status(
  p_ticket_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin';
  end if;

  if p_status not in ('open', 'in_progress', 'closed') then
    raise exception 'invalid_feedback_status';
  end if;

  update public.feedback_tickets
  set status = p_status,
      updated_at = now()
  where id = p_ticket_id;
end;
$$;

grant execute on function public.is_super_admin() to authenticated;
grant execute on function public.admin_dashboard_summary() to authenticated;
grant execute on function public.admin_feedback_tickets(text) to authenticated;
grant execute on function public.admin_update_feedback_status(uuid, text) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.feedback_tickets;
exception
  when duplicate_object then null;
end $$;
