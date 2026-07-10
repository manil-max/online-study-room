-- 0016_nudges.sql
-- Dürtme sistemi: bir grup üyesi başka bir aktif grup üyesini çalışmaya
-- çağırabilir. Spam önleme ve üyelik doğrulaması istemcide değil RPC'dedir.

create table if not exists public.nudges (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  recipient_id uuid not null references auth.users (id) on delete cascade,
  message text check (message is null or char_length(message) <= 120),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check (sender_id <> recipient_id)
);

create index if not exists idx_nudges_recipient_created
  on public.nudges (recipient_id, created_at desc);

create index if not exists idx_nudges_sender_recipient_cooldown
  on public.nudges (group_id, sender_id, recipient_id, created_at desc);

alter table public.nudges enable row level security;

drop policy if exists nudges_select on public.nudges;
create policy nudges_select on public.nudges
  for select to authenticated
  using (
    public.is_group_member(group_id)
    and (sender_id = auth.uid() or recipient_id = auth.uid())
  );

-- Doğrudan insert/update yok: yazma işlemleri aşağıdaki SECURITY DEFINER
-- RPC'lerinden geçer. Böylece cooldown ve üyelik kontrolü atlanamaz.
drop policy if exists nudges_insert on public.nudges;
drop policy if exists nudges_update on public.nudges;

create or replace function public.send_nudge(
  p_group_id uuid,
  p_recipient_id uuid,
  p_message text default null
)
returns public.nudges
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender uuid := auth.uid();
  v_message text := nullif(trim(coalesce(p_message, '')), '');
  v_row public.nudges;
begin
  if v_sender is null then
    raise exception 'not_authenticated';
  end if;

  if v_sender = p_recipient_id then
    raise exception 'cannot_nudge_self';
  end if;

  if char_length(coalesce(v_message, '')) > 120 then
    raise exception 'message_too_long';
  end if;

  if not exists (
    select 1
    from public.group_members
    where group_id = p_group_id
      and user_id = v_sender
      and left_at is null
  ) or not exists (
    select 1
    from public.group_members
    where group_id = p_group_id
      and user_id = p_recipient_id
      and left_at is null
  ) then
    raise exception 'not_group_member';
  end if;

  if exists (
    select 1
    from public.nudges
    where group_id = p_group_id
      and sender_id = v_sender
      and recipient_id = p_recipient_id
      and created_at > now() - interval '10 minutes'
  ) then
    raise exception 'nudge_cooldown';
  end if;

  insert into public.nudges (group_id, sender_id, recipient_id, message)
  values (p_group_id, v_sender, p_recipient_id, v_message)
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.mark_nudge_read(p_nudge_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.nudges
  set read_at = coalesce(read_at, now())
  where id = p_nudge_id
    and recipient_id = auth.uid();
end;
$$;

grant execute on function public.send_nudge(uuid, uuid, text) to authenticated;
grant execute on function public.mark_nudge_read(uuid) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.nudges;
exception
  when duplicate_object then null;
end $$;
