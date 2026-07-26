-- 0085_primary_group_change_cooldown.sql
-- WP-348: Birincil grup için server-authoritative kayan 24 saat cooldown read-modeli.
--
-- Son açık seçim, sadece SECURITY DEFINER RPC tarafından yazılır. Otomatik üyelik
-- uzlaşmaları cooldown başlatmaz; mevcut history'den deterministik backfill yapılır.
--
-- Geri alma (Rollback): Veri silmeden, ileri migration ile RPC cooldown kontrolünü
-- gevşet ve istemci kartını salt-okunur yap. 0079 ve bu additive sütunlar korunur.

alter table public.user_group_preferences
  add column if not exists last_explicit_change_at timestamptz,
  add column if not exists next_change_allowed_at timestamptz;

-- Eski append-only history, cihaz saati yerine tek kanonik backfill kaynağıdır.
with last_explicit as (
  select distinct on (user_id) user_id, changed_at
  from public.user_group_preference_history
  where reason = 'explicit'
  order by user_id, changed_at desc, id desc
)
update public.user_group_preferences preference
set last_explicit_change_at = history.changed_at,
    next_change_allowed_at = history.changed_at + interval '24 hours'
from last_explicit history
where preference.user_id = history.user_id
  and preference.last_explicit_change_at is null;

create or replace function public.primary_group_preference_before_write()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  change_reason text := coalesce(
    nullif(current_setting('app.primary_group_change_reason', true), ''),
    'membership_reconcile'
  );
begin
  if tg_op = 'INSERT' then
    if new.primary_group_id is not null and new.selection_revision = 0 then
      new.selection_revision := 1;
    end if;
  elsif new.primary_group_id is distinct from old.primary_group_id then
    new.selection_revision := old.selection_revision + 1;
  elsif new.selection_revision <> old.selection_revision then
    raise exception 'primary_group_revision_is_server_managed';
  end if;

  if change_reason = 'explicit'
      and (tg_op = 'INSERT' or new.primary_group_id is distinct from old.primary_group_id) then
    new.last_explicit_change_at := now();
    new.next_change_allowed_at := now() + interval '24 hours';
  elsif tg_op = 'UPDATE'
      and new.primary_group_id is distinct from old.primary_group_id then
    -- Automatic single-member and membership reconciliation never extend a lock.
    new.last_explicit_change_at := old.last_explicit_change_at;
    new.next_change_allowed_at := old.next_change_allowed_at;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop function if exists public.set_primary_group(uuid, bigint);
create function public.set_primary_group(
  p_group_id uuid,
  p_expected_revision bigint
)
returns table (
  primary_group_id uuid,
  selection_revision bigint,
  next_change_allowed_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  uid uuid := auth.uid();
  current_preference public.user_group_preferences%rowtype;
  is_active_member boolean;
begin
  if uid is null then
    raise exception 'authentication_required';
  end if;
  if p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'invalid_primary_group_revision';
  end if;
  if p_group_id is null then
    raise exception 'primary_group_required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(uid::text, 329));
  perform public.reconcile_user_primary_group(uid);

  select * into current_preference
  from public.user_group_preferences
  where user_id = uid
  for update;
  if not found then
    current_preference.user_id := uid;
    current_preference.selection_revision := 0;
  end if;
  if current_preference.selection_revision <> p_expected_revision then
    raise exception 'primary_group_stale_selection';
  end if;

  select exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = uid and left_at is null
  ) into is_active_member;
  if not is_active_member then
    raise exception 'primary_group_not_active_member';
  end if;

  -- A same-target retry is deliberately a no-op: no revision, history or lock changes.
  if current_preference.primary_group_id is distinct from p_group_id
      and current_preference.next_change_allowed_at is not null
      and now() < current_preference.next_change_allowed_at then
    raise exception 'primary_group_change_cooldown'
      using detail = current_preference.next_change_allowed_at::text;
  end if;

  if current_preference.primary_group_id is distinct from p_group_id then
    perform set_config('app.primary_group_change_reason', 'explicit', true);
    insert into public.user_group_preferences (user_id, primary_group_id)
    values (uid, p_group_id)
    on conflict (user_id) do update
      set primary_group_id = excluded.primary_group_id;
  end if;

  return query
  select p.primary_group_id, p.selection_revision, p.next_change_allowed_at
  from public.user_group_preferences p
  where p.user_id = uid;
end;
$$;

revoke all on function public.set_primary_group(uuid, bigint) from public, anon;
grant execute on function public.set_primary_group(uuid, bigint) to authenticated;

notify pgrst, 'reload schema';
