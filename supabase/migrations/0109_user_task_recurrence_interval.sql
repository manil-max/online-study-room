-- 0109_user_task_recurrence_interval.sql
-- WP-472: Sabit fazlı görev tekrarını sunucu sözleşmesine taşır.
--
-- WP-449/450 istemciye `intervalDays` + `anchorDate` alanlarını ve sabit faz
-- motorunu getirdi; `supabase_user_task_repository` de `p_interval_days`,
-- `p_anchor_date` ve `p_occurrence_day` göndermeye başladı. Sunucuda bu
-- parametreler **hiç yoktu** (`0048` tek tanım): saha istemcisi PostgREST'ten
-- `PGRST202`/`42883` alırdı. Boşluk yalnız `InMemoryUserTaskRepository` test
-- edildiği için görünmedi. Bu migration eksik ucu kapatır ve doğrulamayı
-- istemciye değil sunucuya bağlar.
--
-- Sözleşme (istemcideki `task_recurrence.dart` ile bire bir):
--   occurrence günleri = anchor_date + k * interval_days, k >= 0
--   completion zamanı fazı DEĞİŞTİRMEZ; geç/çevrimdışı tamamlama döngüyü
--   kaydırmaz. Döngü dışı gün `task_occurrence_not_scheduled` ile reddedilir.
--
-- Saha uyumu: yeni parametrelerin hepsi **varsayılanlıdır**. v56 istemcisi
-- eskisi gibi çağırır; `p_occurrence_day` verilmezse olayın İstanbul gününden
-- türetilir ve `interval_days = 1` geriye dönük davranışla aynı sonucu verir.
--
-- Geri alma (Rollback): Kolonlar veri taşıdığı için drop edilmez. İleri bir
-- migration `interval_days`i 1'e sabitleyip `p_interval_days`i yok sayabilir;
-- tablo ve completion geçmişi bozulmadan kalır.

alter table public.user_tasks
  add column if not exists interval_days integer not null default 1,
  add column if not exists anchor_date date;

-- Geriye dönük faz: istemci `taskRecurrenceAnchorDay` ile `dueAt ?? createdAt`
-- gününü kullanır; sunucu aynı kaynaktan türetir ki iki uç aynı occurrence
-- takvimini görsün.
update public.user_tasks
set anchor_date = public._istanbul_task_day(coalesce(due_at, created_at))
where recurrence = 'daily' and anchor_date is null;

update public.user_tasks
set interval_days = 1, anchor_date = null
where recurrence = 'once' and (interval_days <> 1 or anchor_date is not null);

alter table public.user_tasks
  drop constraint if exists user_tasks_interval_days_range;
alter table public.user_tasks
  add constraint user_tasks_interval_days_range
  check (interval_days between 1 and 365);

-- Tekrar etmeyen görev faz taşımaz; tekrarlayan görev fazsız kalamaz. Kolon
-- kombinasyonu tabloda kilitlenir ki RPC dışından gelen bir düzeltme bile
-- occurrence motorunu belirsiz bırakamasın.
alter table public.user_tasks
  drop constraint if exists user_tasks_recurrence_phase_consistent;
alter table public.user_tasks
  add constraint user_tasks_recurrence_phase_consistent
  check (
    case recurrence
      when 'daily' then anchor_date is not null
      else interval_days = 1 and anchor_date is null
    end
  );

-- `0048`in imzaları yerinde bırakılamaz: PostgREST adlandırılmış parametreyle
-- çağırır ve eski 7/4 parametreli sürüm ile yeni varsayılanlı sürüm aynı çağrıya
-- birlikte aday olurdu (`42725 function is not unique`). Eski imzalar düşürülür.
drop function if exists public.upsert_user_task(uuid, text, timestamptz, text, integer, boolean, uuid);
drop function if exists public.set_user_task_completion(uuid, boolean, timestamptz, uuid);
drop function if exists public.list_user_tasks();

create or replace function public._user_task_anchor_day(
  p_task public.user_tasks
)
-- `stable`, `immutable` değil: `_istanbul_task_day` de stable ve daha katı bir
-- volatilite sözü planlayıcıyı yanıltır.
returns date language sql stable set search_path = public as $$
  select coalesce(
    p_task.anchor_date,
    public._istanbul_task_day(coalesce(p_task.due_at, p_task.created_at))
  );
$$;

create or replace function public.upsert_user_task(
  p_task_id uuid,
  p_title text,
  p_due_at timestamptz,
  p_recurrence text,
  p_sort_order integer,
  p_archived boolean,
  p_client_operation_id uuid,
  p_interval_days integer default 1,
  p_anchor_date date default null
)
returns public.user_tasks
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_existing public.user_tasks%rowtype;
  v_row public.user_tasks%rowtype;
  v_interval integer;
  v_anchor date;
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

  v_interval := coalesce(p_interval_days, 1);
  if v_interval not between 1 and 365 then
    raise exception 'invalid_task_interval_days';
  end if;

  select * into v_existing from public.user_tasks where id = p_task_id for update;
  if found and v_existing.user_id <> v_uid then raise exception 'task_not_found'; end if;
  if not found and (select count(*) from public.user_tasks
                    where user_id = v_uid and archived_at is null) >= 100 then
    raise exception 'task_limit_reached';
  end if;

  if p_recurrence = 'daily' then
    -- Faz sırası: istemcinin açık gönderdiği anchor > satırın mevcut fazı >
    -- `due_at ?? created_at`. Ortadaki adım kritiktir: `p_anchor_date`
    -- göndermeyen v56 istemcisi bir başlığı düzenlediğinde döngü kaymamalı.
    v_anchor := coalesce(
      p_anchor_date,
      v_existing.anchor_date,
      public._istanbul_task_day(coalesce(p_due_at, v_existing.created_at, now()))
    );
  else
    v_interval := 1;
    v_anchor := null;
  end if;

  insert into public.user_tasks (
    id, user_id, title, due_at, recurrence, sort_order, archived_at,
    last_operation_id, interval_days, anchor_date
  ) values (
    p_task_id, v_uid, btrim(p_title), p_due_at, p_recurrence,
    greatest(0, p_sort_order), case when p_archived then now() else null end,
    p_client_operation_id, v_interval, v_anchor
  ) on conflict (id) do update set
    title = excluded.title,
    due_at = excluded.due_at,
    recurrence = excluded.recurrence,
    sort_order = excluded.sort_order,
    archived_at = case when p_archived then coalesce(public.user_tasks.archived_at, now()) else null end,
    last_operation_id = excluded.last_operation_id,
    interval_days = excluded.interval_days,
    anchor_date = excluded.anchor_date,
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
  p_client_operation_id uuid,
  p_occurrence_day date default null
)
returns public.user_task_completions
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_task public.user_tasks%rowtype;
  v_event_day date;
  v_day date;
  v_anchor date;
  v_row public.user_task_completions%rowtype;
  v_replay public.user_task_completions%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_client_operation_id is null then raise exception 'task_operation_required'; end if;
  if p_occurred_at is null or p_occurred_at < now() - interval '48 hours'
      or p_occurred_at > now() + interval '5 minutes' then
    raise exception 'task_occurred_at_out_of_range';
  end if;

  -- Tekrar teslim (offline retry, çift dokunuş) sözleşmesi: aynı komut kimliği
  -- aynı mutasyonla gelirse mevcut satır döner, farklı mutasyonla gelirse
  -- `(user_id, client_operation_id)` tekilliğinden ham `23505` almak yerine
  -- adlandırılmış hata verilir. `InMemoryUserTaskRepository` ile aynı davranış.
  select * into v_replay from public.user_task_completions
  where user_id = v_uid and client_operation_id = p_client_operation_id;

  select * into v_task from public.user_tasks
  where id = p_task_id and user_id = v_uid and archived_at is null for update;
  if not found then raise exception 'task_not_found'; end if;

  v_event_day := public._istanbul_task_day(p_occurred_at);
  v_day := coalesce(p_occurrence_day, v_event_day);
  if v_day <> v_event_day then
    raise exception 'task_occurrence_day_mismatch';
  end if;

  if v_task.recurrence = 'daily' then
    v_anchor := public._user_task_anchor_day(v_task);
    if v_day < v_anchor or ((v_day - v_anchor) % v_task.interval_days) <> 0 then
      raise exception 'task_occurrence_not_scheduled';
    end if;
  end if;

  if v_replay.id is not null then
    if v_replay.task_id = p_task_id
       and v_replay.is_completed = p_is_completed
       and v_replay.completion_day = v_day
       and v_replay.occurred_at = p_occurred_at then
      return v_replay;
    end if;
    raise exception 'task_operation_conflict';
  end if;

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
  completion_day date, interval_days integer, anchor_date date
)
language sql security definer stable set search_path = public as $$
  select t.id, t.user_id, t.title, t.due_at, t.recurrence, t.sort_order,
    t.archived_at, t.created_at, t.updated_at,
    coalesce(c.is_completed, false),
    case when c.is_completed then c.updated_at else null end,
    c.completion_day,
    t.interval_days,
    -- Faz projeksiyonu satırdaki ham `anchor_date` değil türetilmiş değerdir;
    -- böylece backfill öncesi yazılmış bir satır bile istemciye sunucunun
    -- kullandığı fazın aynısını söyler.
    case when t.recurrence = 'daily' then public._user_task_anchor_day(t) end
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

revoke all on function public._user_task_anchor_day(public.user_tasks) from public;
revoke all on function public.upsert_user_task(uuid, text, timestamptz, text, integer, boolean, uuid, integer, date) from public;
revoke all on function public.set_user_task_completion(uuid, boolean, timestamptz, uuid, date) from public;
revoke all on function public.list_user_tasks() from public;
grant execute on function public.upsert_user_task(uuid, text, timestamptz, text, integer, boolean, uuid, integer, date) to authenticated;
grant execute on function public.set_user_task_completion(uuid, boolean, timestamptz, uuid, date) to authenticated;
grant execute on function public.list_user_tasks() to authenticated;
