-- 0079_primary_group_preference.sql
-- WP-329: Hesap-geneli birincil grup tercihi. Bu tercih, cihazdaki
-- active_group_id (yalnız gezinti) değildir ve timer/presence durumunu yazmaz.
-- Geri alma: istemci yeni tercihi okumayı bırakır; tablolar/hareket geçmişi
-- korunur ve ileri bir migration ile yeni-okuma bayrağı kapatılır.

create table if not exists public.user_group_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  primary_group_id uuid references public.groups(id) on delete set null,
  selection_revision bigint not null default 0 check (selection_revision >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_group_preference_history (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  previous_group_id uuid,
  primary_group_id uuid,
  selection_revision bigint not null check (selection_revision >= 0),
  reason text not null check (reason in ('explicit', 'automatic_single', 'membership_reconcile')),
  changed_at timestamptz not null default now()
);

create index if not exists user_group_preference_history_user_changed_idx
  on public.user_group_preference_history (user_id, changed_at desc, id desc);

alter table public.user_group_preferences enable row level security;
alter table public.user_group_preference_history enable row level security;

-- Tercih, yalnız sahibinin hesabına ait özel bir read-modeldir. Başka üye veya
-- profil/sosyal yüzey okuyamaz; yazma her zaman aşağıdaki SECURITY DEFINER RPC'dir.
drop policy if exists user_group_preferences_select_own on public.user_group_preferences;
create policy user_group_preferences_select_own on public.user_group_preferences
  for select to authenticated using (user_id = auth.uid());

revoke all on table public.user_group_preferences from public, anon, authenticated;
grant select on table public.user_group_preferences to authenticated;
revoke all on table public.user_group_preference_history from public, anon, authenticated;

create or replace function public.primary_group_preference_before_write()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
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
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.primary_group_preference_append_history()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_op = 'INSERT' or new.primary_group_id is distinct from old.primary_group_id then
    insert into public.user_group_preference_history (
      user_id, previous_group_id, primary_group_id, selection_revision, reason
    ) values (
      new.user_id,
      case when tg_op = 'INSERT' then null else old.primary_group_id end,
      new.primary_group_id,
      new.selection_revision,
      coalesce(nullif(current_setting('app.primary_group_change_reason', true), ''), 'membership_reconcile')
    );
  end if;
  return null;
end;
$$;

drop trigger if exists user_group_preferences_before_write on public.user_group_preferences;
create trigger user_group_preferences_before_write
  before insert or update on public.user_group_preferences
  for each row execute function public.primary_group_preference_before_write();

drop trigger if exists user_group_preferences_append_history on public.user_group_preferences;
create trigger user_group_preferences_append_history
  after insert or update on public.user_group_preferences
  for each row execute function public.primary_group_preference_append_history();

create or replace function public.reconcile_user_primary_group(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  active_group_ids uuid[];
  desired_group_id uuid;
  current_group_id uuid;
begin
  if p_user_id is null then
    return;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 329));

  select array_agg(group_id order by group_id)
    into active_group_ids
  from public.group_members
  where user_id = p_user_id and left_at is null;

  select primary_group_id into current_group_id
  from public.user_group_preferences
  where user_id = p_user_id
  for update;

  if coalesce(array_length(active_group_ids, 1), 0) = 0 then
    desired_group_id := null;
  elsif array_length(active_group_ids, 1) = 1 then
    desired_group_id := active_group_ids[1];
  elsif current_group_id = any(active_group_ids) then
    desired_group_id := current_group_id;
  else
    -- Çoklu üyelikte seçim yoksa rastgele birincil atama yapılmaz.
    desired_group_id := null;
  end if;

  if current_group_id is distinct from desired_group_id then
    perform set_config(
      'app.primary_group_change_reason',
      case when array_length(active_group_ids, 1) = 1 then 'automatic_single' else 'membership_reconcile' end,
      true
    );
    insert into public.user_group_preferences (user_id, primary_group_id)
    values (p_user_id, desired_group_id)
    on conflict (user_id) do update
      set primary_group_id = excluded.primary_group_id;
  end if;
end;
$$;

create or replace function public.reconcile_primary_group_on_membership_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if tg_op = 'DELETE' then
    perform public.reconcile_user_primary_group(old.user_id);
    return old;
  end if;
  perform public.reconcile_user_primary_group(new.user_id);
  return new;
end;
$$;

drop trigger if exists group_members_primary_group_reconcile on public.group_members;
create trigger group_members_primary_group_reconcile
  after insert or update of left_at or delete on public.group_members
  for each row execute function public.reconcile_primary_group_on_membership_change();

create or replace function public.set_primary_group(
  p_group_id uuid,
  p_expected_revision bigint
)
returns table (primary_group_id uuid, selection_revision bigint)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  uid uuid := auth.uid();
  current_revision bigint := 0;
  is_active_member boolean;
begin
  if uid is null then
    raise exception 'authentication_required';
  end if;
  if p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'invalid_primary_group_revision';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(uid::text, 329));
  perform public.reconcile_user_primary_group(uid);

  select p.selection_revision into current_revision
  from public.user_group_preferences p
  where p.user_id = uid
  for update;
  if not found then
    current_revision := 0;
  end if;
  if current_revision <> p_expected_revision then
    raise exception 'primary_group_stale_selection';
  end if;
  if p_group_id is null then
    raise exception 'primary_group_required';
  end if;

  select exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = uid and left_at is null
  ) into is_active_member;
  if not is_active_member then
    raise exception 'primary_group_not_active_member';
  end if;

  perform set_config('app.primary_group_change_reason', 'explicit', true);
  insert into public.user_group_preferences (user_id, primary_group_id)
  values (uid, p_group_id)
  on conflict (user_id) do update
    set primary_group_id = excluded.primary_group_id;

  return query
  select p.primary_group_id, p.selection_revision
  from public.user_group_preferences p
  where p.user_id = uid;
end;
$$;

revoke all on function public.reconcile_user_primary_group(uuid) from public, anon, authenticated;
revoke all on function public.set_primary_group(uuid, bigint) from public, anon;
grant execute on function public.set_primary_group(uuid, bigint) to authenticated;

-- Canlı veride tek aktif üyelik deterministik olarak seçilir; çoklu üyelikte
-- seçim yapılmaz. Trigger, leave/delete dahil aynı kullanıcı lock sınırındadır.
do $$
declare
  user_record record;
begin
  for user_record in
    select distinct user_id from public.group_members
  loop
    perform public.reconcile_user_primary_group(user_record.user_id);
  end loop;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'user_group_preferences'
  ) then
    alter publication supabase_realtime add table public.user_group_preferences;
  end if;
end;
$$;

notify pgrst, 'reload schema';
