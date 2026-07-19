-- 0062_weekly_alpha_wolf.sql
-- beta-v42 · WP-L — Lider Kurt haftalık verified grup başarımı.
--
-- ISO hafta Europe/Istanbul sınırında yalnız finalized live segmentlerden toplam
-- süre çıkarılır. En yüksek süre tek üyedeyse 1 weekly-alpha win verilir;
-- beraberlikte kimse kazanmaz. İstemci ham oturumdan hesap yapmaz.
--
-- Geri alma (Rollback): `cron.unschedule('verified-group-week-finalizer')`;
-- yeni projection/candidate üretimini durdur. Oluşmuş pending ödüller ve ledger
-- satırları silinmez, claim edilebilir/denetlenebilir kalır.

create table if not exists public.group_achievement_weekly (
  group_id uuid not null,
  iso_week_start date not null check (extract(isodow from iso_week_start) = 1),
  user_id uuid not null references auth.users(id) on delete cascade,
  verified_seconds bigint not null default 0 check (verified_seconds >= 0),
  weekly_alpha_wins integer not null default 0 check (weekly_alpha_wins between 0 and 1),
  finalized_at timestamptz,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (group_id, iso_week_start, user_id)
);
create index if not exists group_achievement_weekly_user_idx
  on public.group_achievement_weekly (user_id, iso_week_start desc);
alter table public.group_achievement_weekly enable row level security;
revoke all on table public.group_achievement_weekly from public, anon, authenticated;

insert into public.achievements_dict
  (id, category, name, description, max_tier, icon_key, is_secret, tiers)
values (
  'alpha_wolf_weekly', 'group', 'Lider Kurt',
  'ISO haftasında grubunda doğrulanmış toplam sürede tek başına birinci olma sayısı',
  6, 'pets', false,
  '[{"tier":1,"threshold":1,"unit":"weekly_alpha_wins","xp":2500},{"tier":2,"threshold":4,"unit":"weekly_alpha_wins","xp":6000},{"tier":3,"threshold":12,"unit":"weekly_alpha_wins","xp":15000},{"tier":4,"threshold":26,"unit":"weekly_alpha_wins","xp":30000},{"tier":5,"threshold":52,"unit":"weekly_alpha_wins","xp":60000},{"tier":6,"threshold":104,"unit":"weekly_alpha_wins","xp":120000}]'::jsonb
)
on conflict (id) do update set
  category = excluded.category, name = excluded.name,
  description = excluded.description, max_tier = excluded.max_tier,
  icon_key = excluded.icon_key, is_secret = excluded.is_secret,
  tiers = excluded.tiers;

insert into public.achievement_metric_definitions
  (achievement_id, metric_key, projection_kind, source_version)
values ('alpha_wolf_weekly', 'weekly_alpha_wins', 'cumulative', 'weekly_alpha_verified_v1')
on conflict (achievement_id) do update set
  metric_key = excluded.metric_key, projection_kind = excluded.projection_kind,
  source_version = excluded.source_version, updated_at = clock_timestamp();

create or replace function public.project_verified_group_week(
  p_group_id uuid,
  p_week_start date
)
returns integer language plpgsql security definer set search_path = public as $$
declare v_affected integer;
begin
  if extract(isodow from p_week_start) <> 1 then
    raise exception 'iso_week_start_must_be_monday';
  end if;

  with bounds as (
    select (p_week_start::timestamp at time zone 'Europe/Istanbul') as lo,
      ((p_week_start + 7)::timestamp at time zone 'Europe/Istanbul') as hi
  ), segments as (
    select s.user_id, greatest(s.started_at, b.lo) as started_at,
      least(s.ended_at, b.hi) as ended_at
    from public.live_study_segments s
    join public.live_study_runs r on r.id = s.run_id
    cross join bounds b
    where r.group_id_snapshot = p_group_id
      and r.status = 'finalized'
      and s.ended_at > b.lo and s.started_at < b.hi
  ), totals as (
    select user_id,
      floor(sum(extract(epoch from ended_at - started_at)))::bigint as seconds
    from segments group by user_id
  ), leaders as (
    select user_id from totals
    where seconds = (select max(seconds) from totals)
  ), winner as (
    select user_id from leaders where (select count(*) from leaders) = 1
  )
  insert into public.group_achievement_weekly(
    group_id, iso_week_start, user_id, verified_seconds, weekly_alpha_wins, updated_at
  )
  select p_group_id, p_week_start, t.user_id, t.seconds,
    case when w.user_id is null then 0 else 1 end, clock_timestamp()
  from totals t left join winner w using (user_id)
  on conflict (group_id, iso_week_start, user_id) do update set
    verified_seconds = excluded.verified_seconds,
    weekly_alpha_wins = excluded.weekly_alpha_wins,
    updated_at = clock_timestamp();
  get diagnostics v_affected = row_count;

  insert into public.achievement_metric_progress(
    user_id, achievement_id, metric_value, source_version, updated_at
  )
  select user_id, 'alpha_wolf_weekly', sum(weekly_alpha_wins)::bigint,
    'weekly_alpha_verified_v1', clock_timestamp()
  from public.group_achievement_weekly
  where finalized_at is not null
  group by user_id
  on conflict (user_id, achievement_id) do update set
    metric_value = greatest(
      public.achievement_metric_progress.metric_value, excluded.metric_value
    ),
    source_version = excluded.source_version,
    updated_at = clock_timestamp();
  return v_affected;
end;
$$;

create or replace function public.finalize_verified_group_week(
  p_group_id uuid,
  p_week_start date
)
returns integer language plpgsql security definer set search_path = public as $$
declare r record; t record; v_count integer;
begin
  if p_week_start + 7 > date_trunc('week', timezone('Europe/Istanbul', clock_timestamp()))::date then
    raise exception 'group_week_not_closed';
  end if;
  perform public.project_verified_group_week(p_group_id, p_week_start);
  update public.group_achievement_weekly
  set finalized_at = coalesce(finalized_at, clock_timestamp())
  where group_id = p_group_id and iso_week_start = p_week_start;
  get diagnostics v_count = row_count;
  perform public.project_verified_group_week(p_group_id, p_week_start);

  for r in
    select user_id from public.group_achievement_weekly
    where group_id = p_group_id and iso_week_start = p_week_start
      and weekly_alpha_wins = 1
  loop
    insert into public.achievement_reward_candidates(
      user_id, achievement_id, tier, source_version, event_key, evidence
    ) values (
      r.user_id, 'alpha_wolf_weekly', 1, 'weekly_alpha_verified_v1',
      r.user_id::text || '|alpha_wolf_weekly|week|' || p_week_start::text,
      jsonb_build_object('group_id', p_group_id, 'week_start', p_week_start)
    ) on conflict do nothing;
  end loop;

  for r in
    select user_id, sum(weekly_alpha_wins)::integer as progress
    from public.group_achievement_weekly
    where finalized_at is not null group by user_id
  loop
    for t in
      select (tier_def->>'tier')::integer as tier,
        (tier_def->>'threshold')::integer as threshold,
        (tier_def->>'xp')::integer as xp
      from public.achievements_dict d
      cross join lateral jsonb_array_elements(d.tiers) tier_def
      where d.id = 'alpha_wolf_weekly'
    loop
      if r.progress >= t.threshold then
        perform public._create_pending_achievement_reward(
          r.user_id, 'alpha_wolf_weekly', t.tier, t.xp,
          format('Lider Kurt: %s haftalık birincilik', r.progress)
        );
      end if;
    end loop;
  end loop;
  return v_count;
end;
$$;

create or replace function public.catch_up_verified_group_weeks()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in
    select distinct run.group_id_snapshot as group_id, week_start::date
    from public.live_study_runs run
    cross join lateral generate_series(
      date_trunc('week', timezone('Europe/Istanbul', run.started_at))::date,
      date_trunc('week', timezone('Europe/Istanbul', run.finalized_at))::date,
      interval '7 days'
    ) as weeks(week_start)
    where run.group_id_snapshot is not null and run.status = 'finalized'
      and week_start::date < date_trunc('week', timezone('Europe/Istanbul', clock_timestamp()))::date
      and not exists (
        select 1 from public.group_achievement_weekly w
        where w.group_id = run.group_id_snapshot
          and w.iso_week_start = week_start::date and w.finalized_at is not null
      )
  loop
    perform public.finalize_verified_group_week(r.group_id, r.week_start);
    n := n + 1;
  end loop;
  return n;
end;
$$;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') and not exists (
    select 1 from cron.job where jobname = 'verified-group-week-finalizer'
  ) then
    perform cron.schedule(
      'verified-group-week-finalizer', '10 21 * * 0',
      'select public.catch_up_verified_group_weeks()'
    );
  end if;
exception when others then
  raise notice 'weekly finalizer job zamanlanamadi (%).', sqlerrm;
end;
$$;

do $$ begin
  perform public.catch_up_verified_group_weeks();
exception when others then
  raise notice 'weekly alpha catch-up basarisiz (%).', sqlerrm;
end;
$$;

revoke all on function public.project_verified_group_week(uuid, date) from public;
revoke all on function public.finalize_verified_group_week(uuid, date) from public;
revoke all on function public.catch_up_verified_group_weeks() from public;
notify pgrst, 'reload schema';
