-- 0075_feedback_ticket_archive.sql
-- WP-318: Biletler silinmeden admin listesinden arşivlenir.
--
-- Geri alma (Rollback): `archived_at` kolonu ve admin_set_feedback_archived
-- RPC'si kaldırılabilir; bilet satırları silinmez.

alter table public.feedback_tickets
  add column if not exists archived_at timestamptz;

create index if not exists idx_feedback_tickets_active_created
  on public.feedback_tickets (created_at desc)
  where archived_at is null;

create or replace function public.admin_feedback_tickets(
  p_status text default null,
  p_include_archived boolean default false
)
returns table (
  id uuid, user_id uuid, kind text, subject text, message text, status text,
  created_at timestamptz, updated_at timestamptz, reporter_display_name text,
  attachment_path text, archived_at timestamptz
)
language plpgsql security definer set search_path = public stable
as $$
begin
  if not public.is_super_admin() then raise exception 'not_super_admin'; end if;
  if p_status is not null and p_status not in ('open', 'in_progress', 'closed') then
    raise exception 'invalid_feedback_status';
  end if;
  return query select ticket.id, ticket.user_id, ticket.kind, ticket.subject,
    ticket.message, ticket.status, ticket.created_at, ticket.updated_at,
    profile.display_name, ticket.attachment_path, ticket.archived_at
  from public.feedback_tickets ticket
  left join public.profiles profile on profile.id = ticket.user_id
  where (p_status is null or ticket.status = p_status)
    and (p_include_archived or ticket.archived_at is null)
  order by ticket.created_at desc;
end;
$$;

create or replace function public.admin_set_feedback_archived(
  p_ticket_id uuid, p_archived boolean
)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_super_admin() then raise exception 'not_super_admin'; end if;
  update public.feedback_tickets
  set archived_at = case when p_archived then now() else null end,
      updated_at = now()
  where id = p_ticket_id;
end;
$$;

grant execute on function public.admin_feedback_tickets(text, boolean) to authenticated;
grant execute on function public.admin_set_feedback_archived(uuid, boolean) to authenticated;
