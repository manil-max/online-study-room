-- 0048: Cloud görev modeli, İstanbul-günü completion ve çok-cihaz RPC'leri (WP-212)
--
-- Görev tanımı tombstone ile korunur; completion tek kaynaktır. Günlük görev
-- satırı ertesi İstanbul gününde silinmeden yeniden açık görünür. Tüm mutasyonlar
-- auth.uid() kullanan RPC'lerden geçer; client zamanı yalnız makul skew içinde
-- completion gününü türetmek için kullanılır ve LWW server-varış sırasıdır.
--
-- Geri alma (Rollback): Veri oluştuysa tablolar drop edilmez. İstemci eski
-- okuma moduna alınır; tablolar/RPC'ler read-only snapshot olarak korunur.

create table if not exists public.user_tasks (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 80),
  due_at timestamptz,
  recurrence text not null default 'once' check (recurrence in ('once', 'daily')),
  sort_order integer not null default 0,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_operation_id uuid not null,
  unique (id, user_id)
);

create index if not exists user_tasks_active_order_idx
  on public.user_tasks (user_id, sort_order, created_at)
  where archived_at is null;

alter table public.user_tasks enable row level security;
drop policy if exists user_tasks_select_self on public.user_tasks;
create policy user_tasks_select_self on public.user_tasks
  for select to authenticated using (user_id = auth.uid());
revoke all on table public.user_tasks from public;
grant select on table public.user_tasks to authenticated;
revoke insert, update, delete on table public.user_tasks from authenticated, anon;

create table if not exists public.user_task_completions (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  completion_day date not null,
  recurrence text not null check (recurrence in ('once', 'daily')),
  is_completed boolean not null,
  occurred_at timestamptz not null,
  updated_at timestamptz not null default now(),
  client_operation_id uuid not null,
  foreign key (task_id, user_id)
    references public.user_tasks(id, user_id) on delete cascade,
  unique (user_id, client_operation_id)
);

create unique index if not exists user_task_daily_completion_unique_idx
  on public.user_task_completions (task_id, completion_day)
  where recurrence = 'daily';
create unique index if not exists user_task_once_completion_unique_idx
  on public.user_task_completions (task_id)
  where recurrence = 'once';
create index if not exists user_task_completions_today_idx
  on public.user_task_completions (user_id, completion_day, task_id);

alter table public.user_task_completions enable row level security;
drop policy if exists user_task_completions_select_self on public.user_task_completions;
create policy user_task_completions_select_self on public.user_task_completions
  for select to authenticated using (user_id = auth.uid());
revoke all on table public.user_task_completions from public;
grant select on table public.user_task_completions to authenticated;
revoke insert, update, delete on table public.user_task_completions from authenticated, anon;

-- Prefs→cloud aktarımının tekrar denenebilir tamamlanma işareti.
create table if not exists public.user_task_migrations (
  user_id uuid primary key references auth.users(id) on delete cascade,
  completed_at timestamptz not null default now(),
  source_version text not null check (source_version = 'prefs_v2')
);
alter table public.user_task_migrations enable row level security;
drop policy if exists user_task_migrations_select_self on public.user_task_migrations;
create policy user_task_migrations_select_self on public.user_task_migrations
  for select to authenticated using (user_id = auth.uid());
revoke all on table public.user_task_migrations from public;
grant select on table public.user_task_migrations to authenticated;
revoke insert, update, delete on table public.user_task_migrations from authenticated, anon;

create or replace function public._istanbul_task_day(p_at timestamptz)
returns date language sql stable set search_path = public as $$
  select (p_at at time zone 'Europe/Istanbul')::date;
$$;

create or replace function public.upsert_user_task(
  p_task_id uuid,
  p_title text,
  p_due_at timestamptz,
  p_recurrence text,
  p_sort_order integer,
  p_archived boolean,
  p_client_operation_id uuid
)
returns public.user_tasks
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_existing public.user_tasks%rowtype;
  v_row public.user_tasks%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_task_id is null or p_client_operation_id is null then
    raise exception 'task_operation_required';
  end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 1 and 80 then
    raise exception 'invalid_task_title';
  end if;
  if p_recurrence not in ('once', 'daily') then
    raise exception 'invalid_task_recurrence';
  end if;

  select * into v_existing from public.user_tasks where id = p_task_id for update;
  if found and v_existing.user_id <> v_uid then raise exception 'task_not_found'; end if;
  if not found and (select count(*) from public.user_tasks
                    where user_id = v_uid and archived_at is null) >= 100 then
    raise exception 'task_limit_reached';
  end if;

  insert into public.user_tasks (
    id, user_id, title, due_at, recurrence, sort_order, archived_at, last_operation_id
  ) values (
    p_task_id, v_uid, btrim(p_title), p_due_at, p_recurrence,
    greatest(0, p_sort_order), case when p_archived then now() else null end,
    p_client_operation_id
  ) on conflict (id) do update set
    title = excluded.title,
    due_at = excluded.due_at,
    recurrence = excluded.recurrence,
    sort_order = excluded.sort_order,
    archived_at = case when p_archived then coalesce(public.user_tasks.archived_at, now()) else null end,
    last_operation_id = excluded.last_operation_id,
    updated_at = now()
  where public.user_tasks.user_id = v_uid
  returning * into v_row;

  if v_row.id is null then raise exception 'task_not_found'; end if;
  return v_row;
end;
$$;

create or replace function public.set_user_task_completion(
  p_task_id uuid,
  p_is_completed boolean,
  p_occurred_at timestamptz,
  p_client_operation_id uuid
)
returns public.user_task_completions
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_task public.user_tasks%rowtype;
  v_day date;
  v_row public.user_task_completions%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_client_operation_id is null then raise exception 'task_operation_required'; end if;
  if p_occurred_at is null or p_occurred_at < now() - interval '48 hours'
      or p_occurred_at > now() + interval '5 minutes' then
    raise exception 'task_occurred_at_out_of_range';
  end if;
  select * into v_task from public.user_tasks
  where id = p_task_id and user_id = v_uid and archived_at is null for update;
  if not found then raise exception 'task_not_found'; end if;
  v_day := public._istanbul_task_day(p_occurred_at);

  if v_task.recurrence = 'daily' then
    insert into public.user_task_completions (
      task_id, user_id, completion_day, recurrence, is_completed, occurred_at, client_operation_id
    ) values (
      v_task.id, v_uid, v_day, 'daily', p_is_completed, p_occurred_at, p_client_operation_id
    ) on conflict (task_id, completion_day) where recurrence = 'daily' do update set
      is_completed = excluded.is_completed,
      occurred_at = excluded.occurred_at,
      client_operation_id = excluded.client_operation_id,
      updated_at = now()
    returning * into v_row;
  else
    insert into public.user_task_completions (
      task_id, user_id, completion_day, recurrence, is_completed, occurred_at, client_operation_id
    ) values (
      v_task.id, v_uid, v_day, 'once', p_is_completed, p_occurred_at, p_client_operation_id
    ) on conflict (task_id) where recurrence = 'once' do update set
      is_completed = excluded.is_completed,
      occurred_at = excluded.occurred_at,
      client_operation_id = excluded.client_operation_id,
      updated_at = now()
    returning * into v_row;
  end if;
  return v_row;
end;
$$;

create or replace function public.list_user_tasks()
returns table (
  id uuid, user_id uuid, title text, due_at timestamptz, recurrence text,
  sort_order integer, archived_at timestamptz, created_at timestamptz,
  updated_at timestamptz, completed boolean, completed_at timestamptz,
  completion_day date
)
language sql security definer stable set search_path = public as $$
  select t.id, t.user_id, t.title, t.due_at, t.recurrence, t.sort_order,
    t.archived_at, t.created_at, t.updated_at,
    coalesce(c.is_completed, false),
    case when c.is_completed then c.updated_at else null end,
    c.completion_day
  from public.user_tasks t
  left join lateral (
    select c.* from public.user_task_completions c
    where c.task_id = t.id and c.user_id = auth.uid()
      and (t.recurrence = 'once'
        or c.completion_day = public._istanbul_task_day(now()))
    order by c.updated_at desc limit 1
  ) c on true
  where t.user_id = auth.uid() and t.archived_at is null
  order by t.sort_order asc, t.created_at asc;
$$;

create or replace function public.migrate_legacy_user_tasks(
  p_tasks jsonb,
  p_migration_id uuid
)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_task jsonb;
  v_id uuid;
  v_title text;
  v_created timestamptz;
  v_completed boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_migration_id is null or jsonb_typeof(p_tasks) <> 'array' then
    raise exception 'invalid_task_migration';
  end if;
  if exists (select 1 from public.user_task_migrations where user_id = v_uid) then
    return true;
  end if;
  if jsonb_array_length(p_tasks) > 100 then raise exception 'task_limit_reached'; end if;

  for v_task in select value from jsonb_array_elements(p_tasks) loop
    begin
      v_id := (v_task ->> 'id')::uuid;
      v_title := btrim(v_task ->> 'title');
      v_created := coalesce((v_task ->> 'createdAt')::timestamptz, now());
      v_completed := coalesce((v_task ->> 'completed')::boolean, false);
      if char_length(v_title) not between 1 and 80 then raise exception 'invalid_task_title'; end if;

      insert into public.user_tasks (
        id, user_id, title, due_at, recurrence, sort_order, created_at, updated_at, last_operation_id
      ) values (
        v_id, v_uid, v_title, (v_task ->> 'dueAt')::timestamptz, 'once',
        greatest(0, coalesce((v_task ->> 'sortOrder')::integer, 0)), v_created, now(), p_migration_id
      ) on conflict (id) do nothing;

      if v_completed then
        insert into public.user_task_completions (
          task_id, user_id, completion_day, recurrence, is_completed, occurred_at, client_operation_id
        ) values (
          v_id, v_uid, public._istanbul_task_day(v_created), 'once', true, v_created, gen_random_uuid()
        ) on conflict (task_id) where recurrence = 'once' do nothing;
      end if;
    exception when invalid_text_representation then
      raise exception 'invalid_legacy_task';
    end;
  end loop;
  insert into public.user_task_migrations (user_id, source_version)
  values (v_uid, 'prefs_v2');
  return true;
end;
$$;

revoke all on function public._istanbul_task_day(timestamptz) from public;
revoke all on function public.upsert_user_task(uuid, text, timestamptz, text, integer, boolean, uuid) from public;
revoke all on function public.set_user_task_completion(uuid, boolean, timestamptz, uuid) from public;
revoke all on function public.list_user_tasks() from public;
revoke all on function public.migrate_legacy_user_tasks(jsonb, uuid) from public;
grant execute on function public.upsert_user_task(uuid, text, timestamptz, text, integer, boolean, uuid) to authenticated;
grant execute on function public.set_user_task_completion(uuid, boolean, timestamptz, uuid) to authenticated;
grant execute on function public.list_user_tasks() to authenticated;
grant execute on function public.migrate_legacy_user_tasks(jsonb, uuid) to authenticated;
