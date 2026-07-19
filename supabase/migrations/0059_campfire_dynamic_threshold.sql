-- 0059_campfire_dynamic_threshold.sql
-- beta-v42 · WP-E — Kamp Ateşi eşzamanlı aktif üye eşiği sabit 3 yerine dinamik.
--
-- Kural (saha §3): eşik = max(2, ceil(N/2)), N = o gün grupta verified segmenti olan
-- farklı üye sayısı. Tablo: N=2→2, 3→2, 4→2, 5→3, 6→3, 7→4, 8→4.
--   (çift N → N/2; tek N → floor(N/2)+1 = ceil(N/2); global min 2.)
--
-- 0053'teki `project_verified_group_day` gövdesi birebir korunur; yalnız `camp`
-- CTE'sindeki sabit `p.active >= 3` dinamik eşikle değişir (yeni `thr` CTE).
-- Diğer metrikler (alpha_wins, locomotive_events) etkilenmez.
--
-- Geri alma (Rollback): 0053'teki `p.active >= 3` sabitine dön; geçmiş
-- campfire_seconds değerleri projeksiyon tetiklenene kadar korunur.

create or replace function public.project_verified_group_day(p_group_id uuid, p_day date)
returns integer language plpgsql security definer set search_path = public as $$
declare v_affected integer;
begin
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
  ), thr as (
    -- Dinamik kamp ateşi eşiği: max(2, ceil(N/2)), N = o gün aktif farklı üye.
    select greatest(2, ceil(count(distinct user_id) / 2.0))::int as t from seg
  ), events as (
    select a t, 1 delta from seg union all select z, -1 from seg
  ), points as (
    select t, sum(delta) over(order by t, delta rows unbounded preceding) active,
      lead(t) over(order by t, delta) next_t from events
  ), camp as (
    select s.user_id, floor(sum(extract(epoch from (least(s.z,p.next_t)-greatest(s.a,p.t)))))::bigint seconds
    from seg s join points p on p.active >= (select t from thr) and p.next_t>p.t
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

revoke all on function public.project_verified_group_day(uuid,date) from public;

-- Kullanıcıya görünen açıklama dinamik ifadeye güncellenir.
update public.achievements_dict
set description = 'O günkü aktif üyelerin en az yarısı aynı anda masadayken çalışılan süre (saat)'
where id = 'campfire_hours';

notify pgrst, 'reload schema';
