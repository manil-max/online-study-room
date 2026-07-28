-- 0092_block_enforcement.sql
-- WP-389: Engelleme yalnız görünümde değil, dürtme mutasyonunda da iki yönlü zorlanır.

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
  v_block_exempt boolean;
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
    select 1 from public.group_members
    where group_id = p_group_id and user_id = v_sender and left_at is null
  ) or not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = p_recipient_id and left_at is null
  ) then
    raise exception 'not_group_member';
  end if;

  -- F2: grup sahibi veya platform yöneticisi, yönetim yükümlülükleri için muaf.
  select public.is_group_admin(p_group_id)
    or public.is_super_admin()
    or exists (select 1 from public.groups where id = p_group_id and created_by = p_recipient_id)
    or exists (select 1 from public.app_admins where user_id = p_recipient_id)
  into v_block_exempt;

  if not v_block_exempt and exists (
    select 1 from public.user_blocks
    where (blocker_id = v_sender and blocked_id = p_recipient_id)
       or (blocker_id = p_recipient_id and blocked_id = v_sender)
  ) then
    raise exception 'nudge_blocked';
  end if;

  if exists (
    select 1 from public.nudges
    where group_id = p_group_id and sender_id = v_sender and recipient_id = p_recipient_id
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

grant execute on function public.send_nudge(uuid, uuid, text) to authenticated;
