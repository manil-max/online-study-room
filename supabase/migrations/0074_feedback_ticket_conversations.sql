-- 0074_feedback_ticket_conversations.sql
-- WP-317: Kullanıcı ile süper-admin arasındaki geri bildirim yazışması.
--
-- Mesajın gönderen rolü istemciden kabul edilmez; SECURITY DEFINER RPC bunu
-- auth.uid() ve bilet sahipliğinden türetir. Admin yanıtı, mevcut duyuru/push
-- hattından yalnız ilgili kullanıcıya bildirilir.
--
-- Geri alma (Rollback): Yeni tablo/policy/RPC'ler kaldırılabilir ve
-- announcements.related_feedback_ticket_id kolonu düşürülebilir. Mevcut
-- feedback_tickets ve announcements satırları silinmez.

alter table public.announcements
  add column if not exists related_feedback_ticket_id uuid
    references public.feedback_tickets (id) on delete set null;

create index if not exists idx_announcements_related_feedback_ticket
  on public.announcements (related_feedback_ticket_id)
  where related_feedback_ticket_id is not null;

create table if not exists public.feedback_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.feedback_tickets (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete restrict,
  sender_role text not null check (sender_role in ('admin', 'user')),
  message text not null check (char_length(trim(message)) between 1 and 1200),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists idx_feedback_ticket_messages_ticket_created
  on public.feedback_ticket_messages (ticket_id, created_at);

alter table public.feedback_ticket_messages enable row level security;

revoke insert, update, delete on public.feedback_ticket_messages from anon, authenticated;
grant select on public.feedback_ticket_messages to authenticated;

drop policy if exists feedback_ticket_messages_select_participant
  on public.feedback_ticket_messages;
create policy feedback_ticket_messages_select_participant
  on public.feedback_ticket_messages
  for select to authenticated
  using (
    public.is_super_admin()
    or exists (
      select 1
      from public.feedback_tickets ticket
      where ticket.id = feedback_ticket_messages.ticket_id
        and ticket.user_id = auth.uid()
    )
  );

-- Mesaj ekleme/okundu güncelleme yalnız RPC ile yapılır. Böylece istemci
-- sender_role, sender_id veya read_at sahteciliği yapamaz.
drop policy if exists feedback_ticket_messages_insert_direct
  on public.feedback_ticket_messages;
drop policy if exists feedback_ticket_messages_update_direct
  on public.feedback_ticket_messages;
drop policy if exists feedback_ticket_messages_delete_direct
  on public.feedback_ticket_messages;

create or replace function public.send_feedback_ticket_message(
  p_ticket_id uuid,
  p_message text
)
returns public.feedback_ticket_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket public.feedback_tickets%rowtype;
  v_sender_role text;
  v_message public.feedback_ticket_messages%rowtype;
  v_normalized_message text;
begin
  if auth.uid() is null then
    raise exception 'session_required';
  end if;

  v_normalized_message := trim(coalesce(p_message, ''));
  if char_length(v_normalized_message) not between 1 and 1200 then
    raise exception 'invalid_feedback_message';
  end if;

  select * into v_ticket
  from public.feedback_tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'feedback_ticket_not_found';
  end if;

  if public.is_super_admin() then
    v_sender_role := 'admin';
  elsif v_ticket.user_id = auth.uid() then
    v_sender_role := 'user';
  else
    raise exception 'feedback_ticket_access_denied';
  end if;

  insert into public.feedback_ticket_messages (
    ticket_id, sender_id, sender_role, message
  ) values (
    v_ticket.id, auth.uid(), v_sender_role, v_normalized_message
  )
  returning * into v_message;

  update public.feedback_tickets
  set status = 'in_progress',
      updated_at = now()
  where id = v_ticket.id;

  if v_sender_role = 'admin' then
    insert into public.announcements (
      title,
      message,
      target_type,
      target_id,
      related_feedback_ticket_id,
      created_by
    ) values (
      'Geri bildiriminize yanıt verildi',
      v_normalized_message,
      'user',
      v_ticket.user_id::text,
      v_ticket.id,
      auth.uid()
    );
  end if;

  return v_message;
end;
$$;

create or replace function public.mark_feedback_ticket_messages_read(
  p_ticket_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket public.feedback_tickets%rowtype;
  v_reader_role text;
begin
  if auth.uid() is null then
    raise exception 'session_required';
  end if;

  select * into v_ticket
  from public.feedback_tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'feedback_ticket_not_found';
  end if;

  if public.is_super_admin() then
    v_reader_role := 'admin';
  elsif v_ticket.user_id = auth.uid() then
    v_reader_role := 'user';
  else
    raise exception 'feedback_ticket_access_denied';
  end if;

  update public.feedback_ticket_messages
  set read_at = now()
  where ticket_id = v_ticket.id
    and sender_role <> v_reader_role
    and read_at is null;
end;
$$;

revoke all on function public.send_feedback_ticket_message(uuid, text) from public;
revoke all on function public.mark_feedback_ticket_messages_read(uuid) from public;
grant execute on function public.send_feedback_ticket_message(uuid, text) to authenticated;
grant execute on function public.mark_feedback_ticket_messages_read(uuid) to authenticated;

-- WP-317: Mevcut duyuru/push altyapısı korunur; yazışma duyurusu açılırsa
-- istemci ilgili geri bildirim listesine yönlenebilecek kimliği de alır.
create or replace function public._enqueue_announcement_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notification_outbox (
    event_key, recipient_id, notification_type, payload
  )
  select
    'announcement:' || new.id::text || ':' || recipients.user_id::text,
    recipients.user_id,
    'announcement',
    jsonb_strip_nulls(jsonb_build_object(
      'schema_version', '1',
      'event_id', new.id::text,
      'route', case
        when new.related_feedback_ticket_id is null then 'notification_center'
        else 'feedback_ticket'
      end,
      'announcement_id', new.id::text,
      'feedback_ticket_id', new.related_feedback_ticket_id,
      'title', new.title,
      'body', new.message
    ))
  from (
    select distinct d.user_id
    from public.push_devices d
    where d.disabled_at is null
      and d.announcement_enabled
      and (
        new.target_type = 'all'
        or (new.target_type = 'user' and new.target_id = d.user_id::text)
        or (
          new.target_type = 'group'
          and exists (
            select 1
            from public.group_members gm
            where gm.user_id = d.user_id
              and gm.group_id::text = new.target_id
              and gm.left_at is null
          )
        )
      )
  ) recipients
  on conflict (event_key) do nothing;
  return new;
end;
$$;
