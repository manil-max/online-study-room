-- 0103_feedback_thread_single_truth.sql
-- WP-435: Geri bildirim konuşmalarını tek, sıralı ve idempotent sunucu gerçeğine taşır.
--
-- İlk bilet metni bir kez kanonik mesaja alınır. Yeni iletiler istemci komut
-- kimliğiyle tekrar güvenli eklenir; sıra ve okundu imleci sunucu tarafındadır.
--
-- Geri alma (Rollback): Yeni kolonlar/projeksiyon tablosu ve bu RPC gövdesi ileri
-- migration ile kaldırılabilir; backfill edilmiş mesajlar ve mevcut biletler silinmez.

alter table public.feedback_tickets
  add column if not exists latest_message_seq bigint not null default 0;

alter table public.feedback_ticket_messages
  add column if not exists client_message_id uuid,
  add column if not exists message_seq bigint;

-- İlk metin daha önce yalnız ticket satırındaydı. Bu ekleme idempotenttir:
-- bilet için herhangi bir mesaj varsa ikinci bir ilk-mesaj yazılmaz.
insert into public.feedback_ticket_messages (
  ticket_id, sender_id, sender_role, message, created_at, client_message_id
)
select
  ticket.id,
  ticket.user_id,
  'user',
  ticket.message,
  ticket.created_at,
  gen_random_uuid()
from public.feedback_tickets ticket
where not exists (
  select 1
  from public.feedback_ticket_messages message
  where message.ticket_id = ticket.id
);

with ranked as (
  select
    id,
    row_number() over (
      partition by ticket_id
      order by created_at asc, id asc
    )::bigint as next_seq
  from public.feedback_ticket_messages
)
update public.feedback_ticket_messages message
set
  message_seq = ranked.next_seq,
  client_message_id = coalesce(message.client_message_id, gen_random_uuid())
from ranked
where message.id = ranked.id;

alter table public.feedback_ticket_messages
  alter column client_message_id set not null,
  alter column message_seq set not null;

create unique index if not exists uq_feedback_ticket_messages_ticket_seq
  on public.feedback_ticket_messages (ticket_id, message_seq);
create unique index if not exists uq_feedback_ticket_messages_ticket_client_message
  on public.feedback_ticket_messages (ticket_id, client_message_id);
create index if not exists idx_feedback_ticket_messages_ticket_seq
  on public.feedback_ticket_messages (ticket_id, message_seq);

update public.feedback_tickets ticket
set latest_message_seq = coalesce((
  select max(message.message_seq)
  from public.feedback_ticket_messages message
  where message.ticket_id = ticket.id
), 0);

create or replace function public._seed_feedback_ticket_initial_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.feedback_ticket_messages (
    ticket_id, sender_id, sender_role, message, created_at,
    client_message_id, message_seq
  ) values (
    new.id, new.user_id, 'user', new.message, new.created_at,
    gen_random_uuid(), 1
  );
  update public.feedback_tickets
  set latest_message_seq = 1
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists seed_feedback_ticket_initial_message on public.feedback_tickets;
create trigger seed_feedback_ticket_initial_message
after insert on public.feedback_tickets
for each row execute function public._seed_feedback_ticket_initial_message();

create table if not exists public.feedback_ticket_read_watermarks (
  ticket_id uuid not null references public.feedback_tickets (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  last_read_message_seq bigint not null default 0 check (last_read_message_seq >= 0),
  updated_at timestamptz not null default now(),
  primary key (ticket_id, user_id)
);

alter table public.feedback_ticket_read_watermarks enable row level security;
revoke all on public.feedback_ticket_read_watermarks from anon, authenticated;
grant select on public.feedback_ticket_read_watermarks to authenticated;
drop policy if exists feedback_ticket_read_watermarks_select_participant
  on public.feedback_ticket_read_watermarks;
create policy feedback_ticket_read_watermarks_select_participant
  on public.feedback_ticket_read_watermarks
  for select to authenticated
  using (user_id = auth.uid() or public.is_super_admin());

create or replace function public.send_feedback_ticket_message(
  p_ticket_id uuid,
  p_message text,
  p_client_message_id uuid
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
  if p_client_message_id is null then
    raise exception 'client_message_id_required';
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

  select * into v_message
  from public.feedback_ticket_messages
  where ticket_id = v_ticket.id
    and client_message_id = p_client_message_id;
  if found then
    return v_message;
  end if;

  update public.feedback_tickets
  set latest_message_seq = latest_message_seq + 1,
      status = 'in_progress',
      updated_at = now()
  where id = v_ticket.id
  returning * into v_ticket;

  insert into public.feedback_ticket_messages (
    ticket_id, sender_id, sender_role, message, client_message_id, message_seq
  ) values (
    v_ticket.id,
    auth.uid(),
    v_sender_role,
    v_normalized_message,
    p_client_message_id,
    v_ticket.latest_message_seq
  ) returning * into v_message;

  -- ℹ️ `0074`'teki admin-yanıtı duyurusu burada **bilerek yoktur.** Duyuru
  -- satırı aynı mesajın ikinci bir gerçeğiydi; WP-435 tek gerçek olarak konuşma
  -- dizisini seçti, okunmamış sinyali `feedback_ticket_read_watermarks` +
  -- WP-436 rozet zinciri üzerinden yürüyor. `021_feedback_thread_single_truth`
  -- bunu açıkça kilitliyor ("admin replies no longer create a second
  -- announcement truth"), o yüzden blok geri getirilmemelidir.
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

  insert into public.feedback_ticket_read_watermarks (
    ticket_id, user_id, last_read_message_seq, updated_at
  ) values (
    v_ticket.id, auth.uid(), v_ticket.latest_message_seq, now()
  ) on conflict (ticket_id, user_id) do update
  set last_read_message_seq = greatest(
        feedback_ticket_read_watermarks.last_read_message_seq,
        excluded.last_read_message_seq
      ),
      updated_at = excluded.updated_at;

  update public.feedback_ticket_messages
  set read_at = now()
  where ticket_id = v_ticket.id
    and sender_role <> v_reader_role
    and read_at is null;
end;
$$;

revoke all on function public.send_feedback_ticket_message(uuid, text, uuid) from public;
revoke all on function public.mark_feedback_ticket_messages_read(uuid) from public;
grant execute on function public.send_feedback_ticket_message(uuid, text, uuid) to authenticated;
grant execute on function public.mark_feedback_ticket_messages_read(uuid) to authenticated;

-- Eski istemciler iki parametreli RPC imzasını kullanır. Bunlar da yeni tek
-- gerçek yolundan geçer; yalnız tekrar komut kimliği taşıyamadıkları için
-- idempotent yeniden deneme garantisi yeni istemci sürümüne aittir.
create or replace function public.send_feedback_ticket_message(
  p_ticket_id uuid,
  p_message text
)
returns public.feedback_ticket_messages
language sql
security definer
set search_path = public
as $$
  select public.send_feedback_ticket_message(
    p_ticket_id, p_message, gen_random_uuid()
  );
$$;
