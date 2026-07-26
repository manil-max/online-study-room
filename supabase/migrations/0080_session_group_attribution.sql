-- 0080_session_group_attribution.sql
-- WP-336: Grup progression için bir oturum en fazla bir gruba yazılır. Cutover
-- öncesi geçmiş oturumlar legacy_multi_group olarak korunur; cutover sonrası
-- preference-history çözülemezse session hiçbir grup projeksiyonuna girmez.

create table if not exists public.group_progression_attribution_config (
  singleton boolean primary key default true check (singleton),
  cutover_at timestamptz not null default clock_timestamp(),
  mode text not null default 'primary_v1' check (mode = 'primary_v1'),
  created_at timestamptz not null default clock_timestamp()
);
insert into public.group_progression_attribution_config (singleton)
values (true) on conflict (singleton) do nothing;

create table if not exists public.study_session_group_attribution (
  session_id uuid primary key,
  group_id uuid references public.groups(id) on delete set null,
  group_id_snapshot uuid,
  attribution_kind text not null check (attribution_kind in ('primary_v1')),
  preference_revision bigint,
  session_started_at timestamptz not null,
  attributed_at timestamptz not null default clock_timestamp(),
  check ((group_id is null and group_id_snapshot is null) or group_id_snapshot is not null)
);
create index if not exists study_session_group_attribution_group_idx
  on public.study_session_group_attribution (group_id, session_started_at);
alter table public.study_session_group_attribution enable row level security;
revoke all on table public.group_progression_attribution_config from public, anon, authenticated;
revoke all on table public.study_session_group_attribution from public, anon, authenticated;

create or replace function public.primary_group_at(
  p_user_id uuid,
  p_occurred_at timestamptz
)
returns table (primary_group_id uuid, selection_revision bigint)
language sql
security definer
set search_path = public
stable
as $$
  select h.primary_group_id, h.selection_revision
  from public.user_group_preference_history h
  where h.user_id = p_user_id
    and h.changed_at <= p_occurred_at
  order by h.changed_at desc, h.id desc
  limit 1;
$$;

create or replace function public.capture_study_session_group_attribution()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  config_cutover timestamptz;
  resolved record;
begin
  select cutover_at into config_cutover
  from public.group_progression_attribution_config
  where singleton;
  if config_cutover is null or new.start_time < config_cutover then
    return new;
  end if;

  select * into resolved
  from public.primary_group_at(new.user_id, new.start_time);

  insert into public.study_session_group_attribution (
    session_id, group_id, group_id_snapshot, attribution_kind,
    preference_revision, session_started_at
  ) values (
    new.id,
    resolved.primary_group_id,
    resolved.primary_group_id,
    'primary_v1',
    resolved.selection_revision,
    new.start_time
  ) on conflict (session_id) do nothing;
  return new;
end;
$$;

-- Alphabetically before the existing study-session projector: attribution must
-- exist before the projector reads the just-written session.
drop trigger if exists a_study_sessions_capture_group_attribution on public.study_sessions;
create trigger a_study_sessions_capture_group_attribution
  after insert on public.study_sessions
  for each row execute function public.capture_study_session_group_attribution();

-- Legacy sessions retain the historical membership-window semantics. Primary-v1
-- sessions return precisely one immutable snapshot window, or no row at all.
create or replace function public.session_group_progression_windows(
  p_session_id uuid,
  p_group_id uuid,
  p_user_id uuid,
  p_start timestamptz,
  p_end timestamptz
)
returns table (joined_at timestamptz, left_at timestamptz)
language plpgsql
security definer
set search_path = public, pg_catalog
stable
as $$
declare config_cutover timestamptz;
begin
  select cutover_at into config_cutover
  from public.group_progression_attribution_config where singleton;
  if config_cutover is null or p_start < config_cutover then
    return query
    select gm.joined_at, gm.left_at
    from public.group_members gm
    where gm.group_id = p_group_id and gm.user_id = p_user_id
      and p_end > gm.joined_at
      and (gm.left_at is null or p_start < gm.left_at);
    return;
  end if;

  return query
  select '-infinity'::timestamptz, null::timestamptz
  from public.study_session_group_attribution a
  where a.session_id = p_session_id
    and a.attribution_kind = 'primary_v1'
    and a.group_id = p_group_id;
end;
$$;

create or replace function public.groups_for_session_progression(
  p_session_id uuid,
  p_user_id uuid,
  p_start timestamptz,
  p_end timestamptz
)
returns table (group_id uuid)
language plpgsql
security definer
set search_path = public, pg_catalog
stable
as $$
declare config_cutover timestamptz;
begin
  select cutover_at into config_cutover
  from public.group_progression_attribution_config where singleton;
  if config_cutover is null or p_start < config_cutover then
    return query
    select gm.group_id
    from public.group_members gm
    where gm.user_id = p_user_id and p_end > gm.joined_at
      and (gm.left_at is null or p_start < gm.left_at);
    return;
  end if;
  return query
  select a.group_id
  from public.study_session_group_attribution a
  where a.session_id = p_session_id
    and a.attribution_kind = 'primary_v1'
    and a.group_id is not null;
end;
$$;

-- Preserve the tested 0063 projection formulas, changing only their session
-- source from all memberships to the immutable attribution/membership window.
do $migration$
declare definition text;
declare membership_join text :=
  'join public\.group_members gm on gm\.user_id = s\.user_id[[:space:]]+'
  || 'and gm\.group_id = p_group_id[[:space:]]+'
  || 'and public\._equal_source_effective_end\([[:space:]]+'
  || 's\.start_time, s\.end_time, s\.duration_seconds[[:space:]]+\) > gm\.joined_at[[:space:]]+'
  || 'and \(gm\.left_at is null or s\.start_time < gm\.left_at\)';
declare replacement text :=
  'join lateral public.session_group_progression_windows('
  || 's.id, p_group_id, s.user_id, s.start_time, '
  || 'public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds)'
  || ') gm on true';
begin
  foreach definition in array array[
    pg_get_functiondef('public.project_group_day(uuid,date)'::regprocedure),
    pg_get_functiondef('public.project_group_week(uuid,date)'::regprocedure)
  ] loop
    definition := regexp_replace(definition, membership_join, replacement, 'g');
    if position('session_group_progression_windows' in definition) = 0 then
      raise exception 'wp336_projection_source_not_replaced';
    end if;
    execute definition;
  end loop;
end;
$migration$;

create or replace function public.refresh_group_metrics_for_session_id(
  p_session_id uuid,
  p_user_id uuid,
  p_start timestamptz,
  p_end timestamptz
)
returns void language plpgsql security definer set search_path = public as $$
declare r record; v_day date; v_week date;
begin
  if p_user_id is null or p_start is null or p_end is null or p_end <= p_start then
    return;
  end if;
  for r in select group_id from public.groups_for_session_progression(
    p_session_id, p_user_id, p_start, p_end
  ) loop
    for v_day in select generate_series(
      (timezone('Europe/Istanbul', p_start))::date,
      (timezone('Europe/Istanbul', p_end - interval '1 microsecond'))::date,
      interval '1 day'
    )::date loop
      perform public.project_group_day(r.group_id, v_day);
    end loop;
    for v_week in select generate_series(
      date_trunc('week', timezone('Europe/Istanbul', p_start))::date,
      date_trunc('week', timezone('Europe/Istanbul', p_end - interval '1 microsecond'))::date,
      interval '7 days'
    )::date loop
      perform public.project_group_week(r.group_id, v_week);
    end loop;
  end loop;
end;
$$;

create or replace function public._study_session_project_group_metrics()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op <> 'DELETE' then
    perform public.refresh_group_metrics_for_session_id(
      new.id, new.user_id, new.start_time,
      public._equal_source_effective_end(new.start_time, new.end_time, new.duration_seconds)
    );
  end if;
  if tg_op <> 'INSERT' then
    perform public.refresh_group_metrics_for_session_id(
      old.id, old.user_id, old.start_time,
      public._equal_source_effective_end(old.start_time, old.end_time, old.duration_seconds)
    );
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create or replace function public.catch_up_group_days()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in
    select distinct g.group_id, d.day::date
    from public.study_sessions s
    cross join lateral public.groups_for_session_progression(
      s.id, s.user_id, s.start_time,
      public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds)
    ) g
    cross join lateral generate_series(
      (timezone('Europe/Istanbul', s.start_time))::date,
      (timezone('Europe/Istanbul', public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) - interval '1 microsecond'))::date,
      interval '1 day'
    ) d(day)
    where s.duration_seconds > 0
  loop
    perform public.project_group_day(r.group_id, r.day);
    if r.day < (timezone('Europe/Istanbul', clock_timestamp()))::date then
      perform public.finalize_group_day(r.group_id, r.day);
    end if;
    n := n + 1;
  end loop;
  return n;
end;
$$;

create or replace function public.catch_up_group_weeks()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in
    select distinct g.group_id, date_trunc('week', timezone('Europe/Istanbul', s.start_time))::date week_start
    from public.study_sessions s
    cross join lateral public.groups_for_session_progression(
      s.id, s.user_id, s.start_time,
      public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds)
    ) g
    where s.duration_seconds > 0
  loop
    if r.week_start < date_trunc('week', timezone('Europe/Istanbul', clock_timestamp()))::date then
      perform public.finalize_group_week(r.group_id, r.week_start);
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;

revoke all on function public.primary_group_at(uuid,timestamptz) from public, anon, authenticated;
revoke all on function public.session_group_progression_windows(uuid,uuid,uuid,timestamptz,timestamptz) from public, anon, authenticated;
revoke all on function public.groups_for_session_progression(uuid,uuid,timestamptz,timestamptz) from public, anon, authenticated;
revoke all on function public.refresh_group_metrics_for_session_id(uuid,uuid,timestamptz,timestamptz) from public, anon, authenticated;

notify pgrst, 'reload schema';
