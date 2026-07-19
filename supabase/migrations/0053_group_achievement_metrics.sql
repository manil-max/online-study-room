-- 0053_group_achievement_metrics.sql
-- WP-218: exact verified Alpha / Campfire / Locomotive group metrics.

create table if not exists public.group_achievement_daily (
  group_id uuid not null,
  istanbul_day date not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  alpha_wins integer not null default 0 check(alpha_wins >= 0),
  campfire_seconds bigint not null default 0 check(campfire_seconds >= 0),
  locomotive_events integer not null default 0 check(locomotive_events >= 0),
  source_version text not null default 'group_verified_v1',
  finalized_at timestamptz,
  updated_at timestamptz not null default clock_timestamp(),
  primary key(group_id, istanbul_day, user_id)
);
create index if not exists group_achievement_daily_user
  on public.group_achievement_daily(user_id, istanbul_day desc);
alter table public.group_achievement_daily enable row level security;
revoke all on table public.group_achievement_daily from public, anon, authenticated;

create or replace function public.project_verified_group_day(p_group_id uuid, p_day date)
returns integer language plpgsql security definer set search_path = public as $$
declare v_affected integer;
begin
  -- Exact group context exists only through live_run_id -> immutable snapshot.
  with bounds as (
    select (p_day::timestamp at time zone 'Europe/Istanbul') as lo,
      ((p_day + 1)::timestamp at time zone 'Europe/Istanbul') as hi
  ), seg as (
    select s.user_id, greatest(s.started_at,b.lo) a, least(s.ended_at,b.hi) z
    from public.live_study_segments s
    join public.live_study_runs r on r.id=s.run_id
    cross join bounds b
    where r.group_id_snapshot=p_group_id and r.status='finalized'
      and s.ended_at>b.lo and s.started_at<b.hi
  ), events as (
    select a t, 1 delta from seg union all select z, -1 from seg
  ), points as (
    select t, sum(delta) over(order by t, delta rows unbounded preceding) active,
      lead(t) over(order by t, delta) next_t from events
  ), camp as (
    select s.user_id, floor(sum(extract(epoch from (least(s.z,p.next_t)-greatest(s.a,p.t)))))::bigint seconds
    from seg s join points p on p.active>=3 and p.next_t>p.t
      and s.a<p.next_t and s.z>p.t group by s.user_id
  ), totals as (
    select user_id, floor(sum(extract(epoch from(z-a))))::bigint seconds from seg group by user_id
  ), alpha as (
    select user_id, case when count(*) over(partition by seconds)=1
      and dense_rank() over(order by seconds desc)=1 then 1 else 0 end wins from totals
  ), loco as (
    select leader.user_id, count(distinct follower.user_id)::integer events
    from seg leader join seg follower on follower.user_id<>leader.user_id
      and follower.a between leader.a and least(leader.z, leader.a+interval '15 minutes')
    group by leader.user_id
  ), users as (
    select user_id from seg group by user_id
  )
  insert into public.group_achievement_daily(
    group_id,istanbul_day,user_id,alpha_wins,campfire_seconds,locomotive_events,updated_at
  ) select p_group_id,p_day,u.user_id,coalesce(a.wins,0),coalesce(c.seconds,0),
      coalesce(l.events,0),clock_timestamp()
    from users u left join alpha a using(user_id) left join camp c using(user_id)
    left join loco l using(user_id)
  on conflict(group_id,istanbul_day,user_id) do update set
    alpha_wins=excluded.alpha_wins,campfire_seconds=excluded.campfire_seconds,
    locomotive_events=excluded.locomotive_events,updated_at=clock_timestamp();
  get diagnostics v_affected = row_count;

  insert into public.achievement_metric_progress(user_id,achievement_id,metric_value,source_version)
  select user_id, metric, value, 'group_verified_v1' from (
    select user_id,'alpha_wolf' metric,sum(alpha_wins)::bigint value
      from public.group_achievement_daily where finalized_at is not null group by user_id
    union all select user_id,'campfire_hours',sum(campfire_seconds)/3600
      from public.group_achievement_daily group by user_id
    union all select user_id,'locomotive',sum(locomotive_events)
      from public.group_achievement_daily group by user_id
  ) m on conflict(user_id,achievement_id) do update set metric_value=excluded.metric_value,
    source_version=excluded.source_version,updated_at=clock_timestamp();
  return v_affected;
end;
$$;

create or replace function public.finalize_verified_group_day(p_group_id uuid,p_day date)
returns integer language plpgsql security definer set search_path=public as $$
declare v_count integer;
begin
  if p_day >= (timezone('Europe/Istanbul',clock_timestamp()))::date then
    raise exception 'group_day_not_closed';
  end if;
  perform public.project_verified_group_day(p_group_id,p_day);
  update public.group_achievement_daily set finalized_at=coalesce(finalized_at,clock_timestamp())
    where group_id=p_group_id and istanbul_day=p_day;
  get diagnostics v_count=row_count;
  -- Alpha projection yalnız finalized günleri sayar; işaretleme sonrası aynı günün
  -- toplamını progress'e geçirmek için idempotent ikinci projection gerekir.
  perform public.project_verified_group_day(p_group_id,p_day);
  insert into public.achievement_reward_candidates(user_id,achievement_id,tier,source_version,event_key,evidence)
  select user_id,'alpha_wolf',1,'group_verified_v1',
    user_id::text||'|alpha_wolf|day|'||p_day::text,
    jsonb_build_object('group_id',p_group_id,'day',p_day)
  from public.group_achievement_daily where group_id=p_group_id and istanbul_day=p_day
    and alpha_wins=1 on conflict do nothing;
  return v_count;
end;
$$;

create or replace function public.catch_up_verified_group_days()
returns integer language plpgsql security definer set search_path=public as $$
declare r record; n integer:=0;
begin
  for r in
    select candidate.snapshot_group_id, candidate.metric_day
    from (
      select distinct
        run.group_id_snapshot as snapshot_group_id,
        (timezone('Europe/Istanbul',run.started_at))::date as metric_day
      from public.live_study_runs run
      where run.group_id_snapshot is not null
        and run.status = 'finalized'
        and (timezone('Europe/Istanbul',run.started_at))::date <
          (timezone('Europe/Istanbul',clock_timestamp()))::date
    ) candidate
    where not exists (
      select 1
      from public.group_achievement_daily d
      where d.group_id = candidate.snapshot_group_id
        and d.istanbul_day = candidate.metric_day
        and d.finalized_at is not null
    )
  loop
    perform public.finalize_verified_group_day(
      r.snapshot_group_id,
      r.metric_day
    );
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- Segment kapanırken run henüz 'running' olabilir. Verified projector'u run
-- finalize transition'ında tetiklemek, başka üyenin etkisini birkaç saniye
-- içinde tüm affected-user projection'ına taşır.
create or replace function public._verified_group_run_finalized()
returns trigger language plpgsql security definer set search_path=public as $$
declare metric_day date;
begin
  if new.group_id_snapshot is null then return new; end if;
  for metric_day in
    select generate_series(
      (timezone('Europe/Istanbul',new.started_at))::date,
      (timezone('Europe/Istanbul',new.finalized_at))::date,
      interval '1 day'
    )::date
  loop
    perform public.project_verified_group_day(new.group_id_snapshot,metric_day);
  end loop;
  return new;
end;
$$;
drop trigger if exists live_runs_project_group_metrics on public.live_study_runs;
create trigger live_runs_project_group_metrics after update of status
  on public.live_study_runs for each row
  when(old.status is distinct from new.status and new.status='finalized')
  execute function public._verified_group_run_finalized();

create or replace function public._verified_group_segment_dirty()
returns trigger language plpgsql security definer set search_path=public as $$
declare gid uuid;
begin
  select group_id_snapshot into gid from public.live_study_runs where id=new.run_id;
  if gid is null then return new; end if;
  insert into public.achievement_metric_dirty(scope_type,scope_id,istanbul_day,source_version,reason)
  values('group',gid,(timezone('Europe/Istanbul',new.started_at))::date,
    'group_verified_v1','member_verified_segment')
  on conflict(scope_type,scope_id,istanbul_day,source_version) do update set
    dirtied_at=clock_timestamp(),processed_at=null,reason=excluded.reason;
  perform public.project_verified_group_day(gid,(timezone('Europe/Istanbul',new.started_at))::date);
  return new;
end;
$$;
drop trigger if exists live_segments_project_group_metrics on public.live_study_segments;
create trigger live_segments_project_group_metrics after update of ended_at
  on public.live_study_segments for each row
  when(old.ended_at is null and new.ended_at is not null)
  execute function public._verified_group_segment_dirty();

create or replace view public.group_metric_legacy_proxy_audit as
select s.id session_id,s.user_id,count(gm.group_id) candidate_groups,
  case when count(gm.group_id)=1 then 'single_current_membership_proxy'
       when count(gm.group_id)=0 then 'excluded_no_group'
       else 'excluded_ambiguous_group' end attribution
from public.study_sessions s left join public.group_members gm on gm.user_id=s.user_id
where s.live_run_id is null group by s.id,s.user_id;
revoke all on public.group_metric_legacy_proxy_audit from public,anon,authenticated;

do $migration$ begin
  if exists(select 1 from pg_namespace where nspname='cron')
     and not exists(
       select 1 from cron.job where jobname='verified-group-day-finalizer'
     ) then
    perform cron.schedule('verified-group-day-finalizer','5 21 * * *',
      'select public.catch_up_verified_group_days()');
  end if;
end $migration$;

revoke all on function public.project_verified_group_day(uuid,date) from public;
revoke all on function public.finalize_verified_group_day(uuid,date) from public;
revoke all on function public.catch_up_verified_group_days() from public;
-- team_player remains the documented group-goal contribution metric from 0050.
