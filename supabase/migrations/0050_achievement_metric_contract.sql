-- 0050: Self-only achievement metric contract and 30-day Perfect Month
--
-- Adds a private metric projection, per-metric monotonic/current semantics,
-- bounded backfill/dirty-bucket contracts, a verified-hour watermark contract,
-- and a read-only legacy quality report. Existing XP ledger rows and claimed
-- badges are never deleted or repriced. The current auto-award behavior remains.
--
-- Geri alma (Rollback): process_achievement_event davranışı korunarak yeni
-- `_achievement_metrics` wrapper kaldırılır ve `_achievement_metrics_legacy_v1`
-- tekrar `_achievement_metrics` adına alınır. Projection/job/dirty/watermark
-- tabloları veri üretmişse DROP edilmez; RLS altında salt-okunur bırakılır.
-- `achievements_dict.perfect_month` açıklaması önceki metne döndürülebilir.

create table if not exists public.achievement_metric_definitions (
  achievement_id text primary key references public.achievements_dict (id),
  metric_key text not null,
  projection_kind text not null check (projection_kind in ('cumulative', 'current')),
  source_version text not null check (btrim(source_version) <> ''),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.achievement_metric_definitions enable row level security;
drop policy if exists achievement_metric_definitions_select
  on public.achievement_metric_definitions;
create policy achievement_metric_definitions_select
  on public.achievement_metric_definitions
  for select to authenticated
  using (true);
revoke insert, update, delete on public.achievement_metric_definitions
  from authenticated, anon;
grant select on public.achievement_metric_definitions to authenticated;

insert into public.achievement_metric_definitions (
  achievement_id,
  metric_key,
  projection_kind,
  source_version
)
values
  ('marathon_total', 'total_hours', 'cumulative', 'metric_v2'),
  ('steel_will', 'max_session_minutes', 'cumulative', 'metric_v2'),
  ('day_hero', 'max_day_hours', 'cumulative', 'metric_v2'),
  ('fire_streak', 'streak_days', 'current', 'metric_v2'),
  ('weekend_goal_days', 'weekend_goal_days', 'cumulative', 'metric_v2'),
  ('perfect_month', 'perfect_months', 'cumulative', 'perfect_month_30_v1'),
  ('alpha_wolf', 'group_day_first', 'cumulative', 'group_verified_v1'),
  ('team_player', 'group_goal_contrib', 'cumulative', 'metric_v2'),
  ('campfire_hours', 'campfire_hours', 'cumulative', 'group_verified_v1'),
  ('inspiration', 'nudge_starts', 'cumulative', 'metric_v2'),
  ('locomotive', 'locomotive_events', 'cumulative', 'group_verified_v1'),
  ('secret_night_owl', 'secret_night_owl', 'cumulative', 'metric_v2'),
  ('secret_dawn', 'secret_dawn', 'cumulative', 'metric_v2'),
  ('secret_404', 'secret_404', 'cumulative', 'metric_v2'),
  ('secret_pi', 'secret_pi', 'cumulative', 'metric_v2'),
  ('secret_break_enemy', 'secret_break_enemy', 'cumulative', 'break_verified_v1'),
  ('secret_last_second', 'secret_last_second', 'cumulative', 'metric_v2'),
  ('secret_1337', 'secret_1337', 'cumulative', 'metric_v2'),
  ('secret_no_limits', 'secret_no_limits', 'cumulative', 'metric_v2'),
  ('secret_matrix', 'secret_matrix', 'cumulative', 'metric_v2'),
  ('secret_nye', 'secret_nye', 'cumulative', 'metric_v2')
on conflict (achievement_id) do update set
  metric_key = excluded.metric_key,
  projection_kind = excluded.projection_kind,
  source_version = excluded.source_version,
  updated_at = now();

create table if not exists public.achievement_metric_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  achievement_id text not null references public.achievements_dict (id),
  metric_value bigint not null default 0 check (metric_value >= 0),
  source_version text not null check (btrim(source_version) <> ''),
  updated_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

create index if not exists achievement_metric_progress_user_updated_idx
  on public.achievement_metric_progress (user_id, updated_at desc);

alter table public.achievement_metric_progress enable row level security;
drop policy if exists achievement_metric_progress_self_select
  on public.achievement_metric_progress;
create policy achievement_metric_progress_self_select
  on public.achievement_metric_progress
  for select to authenticated
  using (user_id = auth.uid());
revoke insert, update, delete on public.achievement_metric_progress
  from authenticated, anon;
grant select on public.achievement_metric_progress to authenticated;

do $$
begin
  alter publication supabase_realtime
    add table public.achievement_metric_progress;
exception
  when duplicate_object then null;
end $$;

create table if not exists public.achievement_backfill_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null,
  source_version text not null,
  status text not null default 'pending'
    check (status in ('pending', 'running', 'paused', 'completed', 'failed')),
  cursor_user_id uuid,
  batch_limit integer not null default 100 check (batch_limit between 1 and 500),
  scanned_count bigint not null default 0,
  eligible_count bigint not null default 0,
  ambiguous_count bigint not null default 0,
  excluded_count bigint not null default 0,
  error_message text,
  requested_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.achievement_backfill_jobs enable row level security;
revoke all on public.achievement_backfill_jobs from authenticated, anon;

create table if not exists public.achievement_metric_dirty (
  scope_type text not null check (scope_type in ('user', 'group')),
  scope_id uuid not null,
  istanbul_day date not null,
  source_version text not null default 'metric_v2',
  reason text not null,
  dirtied_at timestamptz not null default now(),
  processed_at timestamptz,
  primary key (scope_type, scope_id, istanbul_day, source_version)
);

create index if not exists achievement_metric_dirty_pending_idx
  on public.achievement_metric_dirty (dirtied_at, scope_type)
  where processed_at is null;

alter table public.achievement_metric_dirty enable row level security;
revoke all on public.achievement_metric_dirty from authenticated, anon;

create table if not exists public.achievement_hour_watermarks (
  user_id uuid primary key references auth.users (id) on delete cascade,
  processed_verified_hours bigint not null default 0
    check (processed_verified_hours >= 0),
  source_version text not null default 'verified_hour_v1',
  updated_at timestamptz not null default now()
);

alter table public.achievement_hour_watermarks enable row level security;
revoke all on public.achievement_hour_watermarks from authenticated, anon;

create or replace function public._mark_achievement_metric_dirty()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_day date;
  v_new_day date;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    v_old_day := (old.start_time at time zone 'Europe/Istanbul')::date;
    insert into public.achievement_metric_dirty (
      scope_type, scope_id, istanbul_day, source_version, reason
    ) values (
      'user', old.user_id, v_old_day, 'metric_v2', lower(tg_op)
    )
    on conflict (scope_type, scope_id, istanbul_day, source_version)
    do update set
      reason = excluded.reason,
      dirtied_at = now(),
      processed_at = null;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    v_new_day := (new.start_time at time zone 'Europe/Istanbul')::date;
    insert into public.achievement_metric_dirty (
      scope_type, scope_id, istanbul_day, source_version, reason
    ) values (
      'user', new.user_id, v_new_day, 'metric_v2', lower(tg_op)
    )
    on conflict (scope_type, scope_id, istanbul_day, source_version)
    do update set
      reason = excluded.reason,
      dirtied_at = now(),
      processed_at = null;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public._mark_achievement_metric_dirty()
  from public, anon, authenticated;

drop trigger if exists study_sessions_mark_achievement_dirty
  on public.study_sessions;
create trigger study_sessions_mark_achievement_dirty
  after insert or update or delete on public.study_sessions
  for each row execute function public._mark_achievement_metric_dirty();

create or replace function public._count_perfect_months_30(p_user_id uuid)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  with goal as (
    select greatest(coalesce(p.daily_goal_minutes, 360), 1) * 60 as seconds
    from public.profiles p
    where p.id = p_user_id
  ),
  day_totals as (
    select
      (s.start_time at time zone 'Europe/Istanbul')::date as day,
      sum(s.duration_seconds)::bigint as seconds
    from public.study_sessions s
    where s.user_id = p_user_id
      and s.duration_seconds > 0
    group by 1
  ),
  month_totals as (
    select date_trunc('month', d.day)::date as month_start,
           count(*) filter (where d.seconds >= coalesce(g.seconds, 21600))
             as goal_days
    from day_totals d
    cross join (select coalesce(max(seconds), 21600) as seconds from goal) g
    group by 1
  )
  select count(*)::integer
  from month_totals
  where goal_days >= 30;
$$;

revoke all on function public._count_perfect_months_30(uuid)
  from public, anon, authenticated;

create or replace function public._project_achievement_metrics(
  p_user_id uuid,
  p_metrics jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_value bigint;
  v_changed integer := 0;
begin
  if p_user_id is null then
    raise exception 'user required';
  end if;

  for r in
    select achievement_id, metric_key, projection_kind, source_version
    from public.achievement_metric_definitions
    order by achievement_id
  loop
    v_value := case r.metric_key
      when 'total_hours' then coalesce((p_metrics->>'total_hours')::bigint, 0)
      when 'max_session_minutes' then coalesce((p_metrics->>'max_session_minutes')::bigint, 0)
      when 'max_day_hours' then coalesce((p_metrics->>'max_day_hours')::bigint, 0)
      when 'streak_days' then coalesce((p_metrics->>'streak_days')::bigint, 0)
      when 'weekend_goal_days' then coalesce((p_metrics->>'weekend_goal_days')::bigint, 0)
      when 'perfect_months' then coalesce((p_metrics->>'perfect_months')::bigint, 0)
      when 'group_goal_contrib' then coalesce((p_metrics->>'group_goal_contrib')::bigint, 0)
      when 'nudge_starts' then coalesce((p_metrics->>'nudge_starts')::bigint, 0)
      when 'group_day_first' then coalesce((p_metrics->>'group_day_first')::bigint, 0)
      when 'campfire_hours' then coalesce((p_metrics->>'campfire_hours')::bigint, 0)
      when 'locomotive_events' then coalesce((p_metrics->>'locomotive_events')::bigint, 0)
      when 'secret_break_enemy' then coalesce((p_metrics->>'secret_break_enemy')::bigint, 0)
      when 'secret_night_owl' then case when coalesce((p_metrics->'secrets'->>'night_owl')::boolean, false) then 1 else 0 end
      when 'secret_dawn' then case when coalesce((p_metrics->'secrets'->>'dawn')::boolean, false) then 1 else 0 end
      when 'secret_404' then case when coalesce((p_metrics->'secrets'->>'m404')::boolean, false) then 1 else 0 end
      when 'secret_pi' then case when coalesce((p_metrics->'secrets'->>'pi')::boolean, false) then 1 else 0 end
      when 'secret_last_second' then case when coalesce((p_metrics->'secrets'->>'last_second')::boolean, false) then 1 else 0 end
      when 'secret_1337' then case when coalesce((p_metrics->'secrets'->>'leet')::boolean, false) then 1 else 0 end
      when 'secret_no_limits' then case when coalesce((p_metrics->'secrets'->>'no_limits')::boolean, false) then 1 else 0 end
      when 'secret_matrix' then case when coalesce((p_metrics->'secrets'->>'matrix')::boolean, false) then 1 else 0 end
      when 'secret_nye' then case when coalesce((p_metrics->'secrets'->>'nye')::boolean, false) then 1 else 0 end
      else 0
    end;

    insert into public.achievement_metric_progress (
      user_id, achievement_id, metric_value, source_version, updated_at
    ) values (
      p_user_id, r.achievement_id, greatest(v_value, 0), r.source_version, now()
    )
    on conflict (user_id, achievement_id) do update set
      metric_value = case
        when r.projection_kind = 'cumulative' then greatest(
          public.achievement_metric_progress.metric_value,
          excluded.metric_value
        )
        else excluded.metric_value
      end,
      source_version = excluded.source_version,
      updated_at = now()
    where public.achievement_metric_progress.metric_value is distinct from case
            when r.projection_kind = 'cumulative' then greatest(
              public.achievement_metric_progress.metric_value,
              excluded.metric_value
            )
            else excluded.metric_value
          end
       or public.achievement_metric_progress.source_version
            is distinct from excluded.source_version;

    if found then
      v_changed := v_changed + 1;
    end if;
  end loop;
  return v_changed;
end;
$$;

revoke all on function public._project_achievement_metrics(uuid, jsonb)
  from public, anon, authenticated;

-- Preserve the last deployed evaluator and wrap it. The wrapper changes only
-- Perfect Month and writes the private projection; award/XP behavior stays in
-- process_achievement_event from 0033.
do $migration$
begin
  if to_regprocedure('public._achievement_metrics_legacy_v1(uuid)') is null then
    alter function public._achievement_metrics(uuid)
      rename to _achievement_metrics_legacy_v1;
  end if;
end
$migration$;

create or replace function public._achievement_metrics(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_metrics jsonb;
  v_perfect_months integer;
begin
  v_metrics := public._achievement_metrics_legacy_v1(p_user_id);
  v_perfect_months := public._count_perfect_months_30(p_user_id);
  v_metrics := jsonb_set(
    v_metrics,
    '{perfect_months}',
    to_jsonb(coalesce(v_perfect_months, 0)),
    true
  );
  perform public._project_achievement_metrics(p_user_id, v_metrics);
  return v_metrics;
end;
$$;

revoke all on function public._achievement_metrics_legacy_v1(uuid)
  from public, anon, authenticated;
revoke all on function public._achievement_metrics(uuid)
  from public, anon, authenticated;

create or replace function public._verified_hour_catchup_window(
  p_user_id uuid,
  p_verified_total_hours bigint,
  p_limit integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_processed bigint := 0;
  v_total bigint := greatest(coalesce(p_verified_total_hours, 0), 0);
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 100);
  v_end bigint;
begin
  select processed_verified_hours into v_processed
  from public.achievement_hour_watermarks
  where user_id = p_user_id;
  v_processed := coalesce(v_processed, 0);
  v_end := least(v_total, v_processed + v_limit);
  return jsonb_build_object(
    'start_hour', case when v_total > v_processed then v_processed + 1 else null end,
    'end_hour', case when v_total > v_processed then v_end else null end,
    'count', greatest(v_end - v_processed, 0),
    'remaining', greatest(v_total - v_end, 0),
    'source_version', 'verified_hour_v1'
  );
end;
$$;

revoke all on function public._verified_hour_catchup_window(uuid, bigint, integer)
  from public, anon, authenticated;

create or replace function public.achievement_legacy_audit(
  p_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_caller uuid := auth.uid();
  v_target uuid := coalesce(p_user_id, auth.uid());
  v_sessions bigint;
  v_invalid bigint;
  v_ambiguous bigint;
  v_achievements bigint;
  v_badges bigint;
  v_unknown_badges bigint;
  v_ledger_xp bigint;
  v_profile_xp bigint;
  v_perfect_tier integer;
begin
  if v_target is null then
    raise exception 'target user required';
  end if;
  if auth.role() is distinct from 'service_role'
     and (v_caller is null or (v_target <> v_caller and not public.is_super_admin())) then
    raise exception 'forbidden';
  end if;

  select count(*),
         count(*) filter (
           where duration_seconds <= 0
              or end_time < start_time
              or duration_seconds > extract(epoch from (end_time - start_time)) + 120
         )
    into v_sessions, v_invalid
  from public.study_sessions
  where user_id = v_target;

  select count(*) into v_ambiguous
  from public.study_sessions s
  where s.user_id = v_target
    and 1 < (
      select count(*)
      from public.group_members gm
      where gm.user_id = v_target
        and gm.joined_at <= s.start_time
        and (gm.left_at is null or gm.left_at > s.start_time)
    );

  select count(*) into v_achievements
  from public.user_achievements
  where user_id = v_target;

  select coalesce(cardinality(g.selected_badges), 0),
         coalesce((
           select count(*)
           from unnest(g.selected_badges) badge
           where not exists (
             select 1 from public.achievements_dict d where d.id = badge
           )
         ), 0),
         coalesce(g.xp, 0)
    into v_badges, v_unknown_badges, v_profile_xp
  from public.gamification_profiles g
  where g.user_id = v_target;
  v_badges := coalesce(v_badges, 0);
  v_unknown_badges := coalesce(v_unknown_badges, 0);
  v_profile_xp := coalesce(v_profile_xp, 0);

  select coalesce(sum(xp_amount), 0),
         coalesce(max(tier) filter (where achievement_id = 'perfect_month'), 0)
    into v_ledger_xp, v_perfect_tier
  from public.xp_ledger
  where user_id = v_target;

  return jsonb_build_object(
    'schema_version', 'legacy_audit_v1',
    'target_user_id', v_target,
    'session_rows', coalesce(v_sessions, 0),
    'invalid_session_rows', coalesce(v_invalid, 0),
    'ambiguous_group_rows', coalesce(v_ambiguous, 0),
    'user_achievement_rows', coalesce(v_achievements, 0),
    'selected_badge_rows', v_badges,
    'unknown_selected_badges', v_unknown_badges,
    'ledger_xp', coalesce(v_ledger_xp, 0),
    'profile_xp', v_profile_xp,
    'xp_delta', v_profile_xp - coalesce(v_ledger_xp, 0),
    'claimed_perfect_month_tier', coalesce(v_perfect_tier, 0),
    'automatic_repair_applied', false
  );
end;
$$;

revoke all on function public.achievement_legacy_audit(uuid)
  from public, anon;
grant execute on function public.achievement_legacy_audit(uuid)
  to authenticated, service_role;

update public.achievements_dict
set description = 'Aynı takvim ayında en az 30 ayrı günde günlük hedefe ulaş'
where id = 'perfect_month';

notify pgrst, 'reload schema';
