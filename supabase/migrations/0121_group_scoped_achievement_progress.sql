-- 0121_group_scoped_achievement_progress.sql
--
-- WP-501 (V58-N06 / rapor T06): grup başarımları **(grup × gün/hafta)** olarak
-- sayılıyordu. `achievement_metric_progress` birincil anahtarı
-- `(user_id, achievement_id)`; grup boyutu şemada yok. Üç projeksiyon da
-- rollup tablolarını `group by user_id` ile topluyordu, yani iki grupta aynı
-- hafta birinci olan kullanıcı **2** alıyordu.
--
-- Sahip kararı: "hangi grup seçili ise ondan sayılsın."
--
-- 🔴 Ölçülen kısıt, tasarımı belirledi: **seçili grup sunucuda yok.**
-- `activeGroupIdProvider` (`group_providers.dart:106`) seçimi yalnız cihazdaki
-- `SharedPreferences`'a yazar; aynı hesap iki cihazda farklı grup seçebilir.
-- Bu yüzden iş ikiye ayrıldı:
--
--   * **Gösterim** grup kırılımlı yeni tablodan gelir; istemci seçili grubun
--     satırını okur (sahibin kuralı birebir).
--   * **Ödül/XP** sunucuda hesaplanır ve cihaza bağlı olamaz; bu yüzden
--     kullanıcının **en iyi grubunun** değeri (gruplar arası `max`) kullanılır.
--     `max` iki özelliği birden verir: çift sayım biter (toplam değil) ve
--     kazanılmış kademe **hiçbir koşulda** geri alınmaz.
--
-- ⚠️ Kart beş metrik sayıyor; ölçüldü, bu mekanizmanın etkilediği **dört**
-- tanedir: `alpha_wolf`, `alpha_wolf_weekly`, `campfire_hours`, `locomotive`.
-- `team_player` bu rollup'lardan değil `group_goal_contrib` metriğinden gelir
-- (`0050:49`) ve grup toplamıyla çarpılmıyor; dokunulmadı.
--
-- Geri alma: `group_achievement_metric_progress` düşürülür ve üç fonksiyon
-- 0059/0063'teki hâline `create or replace` ile geri konur.

-- 1) Grup kırılımlı ilerleme. Yazma yalnız `security definer` projeksiyonlarda;
--    kullanıcı yalnız kendi satırını okur.
create table if not exists public.group_achievement_metric_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  group_id uuid not null,
  achievement_id text not null references public.achievements_dict (id),
  metric_value bigint not null default 0 check (metric_value >= 0),
  source_version text not null check (btrim(source_version) <> ''),
  updated_at timestamptz not null default clock_timestamp(),
  primary key (user_id, group_id, achievement_id)
);

create index if not exists group_achievement_metric_progress_user_idx
  on public.group_achievement_metric_progress (user_id, group_id);

alter table public.group_achievement_metric_progress enable row level security;
drop policy if exists group_achievement_metric_progress_self_select
  on public.group_achievement_metric_progress;
create policy group_achievement_metric_progress_self_select
  on public.group_achievement_metric_progress
  for select to authenticated
  using (user_id = auth.uid());
revoke insert, update, delete on public.group_achievement_metric_progress
  from authenticated, anon;
grant select on public.group_achievement_metric_progress to authenticated;

do $$
begin
  alter publication supabase_realtime
    add table public.group_achievement_metric_progress;
exception
  when duplicate_object then null;
end $$;

-- 2) Tek kırılım noktası. Üç projeksiyon da bunu çağırır; ayrı ayrı toplama
--    yapan üç kopya olduğu için kural üçünde birden kayabiliyordu.
create or replace function public._project_group_scoped_metrics()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v_rows integer;
begin
  -- 🔴 Yalniz upsert yetmez: gruptan cikilinca ya da rollup satiri silinince
  -- eski kirilim satiri oldugu yerde kalir ve kullanici artik uyesi olmadigi
  -- gruptan ilerleme gorur. Kaynagi kalmayan satirlar once dusurulur.
  -- Kosul metrige gore ayri, cunku `alpha_wolf`/`alpha_wolf_weekly` yalniz
  -- **finalize edilmis** satirlardan beslenir.
  delete from public.group_achievement_metric_progress p
  where case p.achievement_id
    when 'alpha_wolf' then not exists (
      select 1 from public.group_achievement_daily d
      where d.user_id = p.user_id and d.group_id = p.group_id
        and d.finalized_at is not null)
    when 'alpha_wolf_weekly' then not exists (
      select 1 from public.group_achievement_weekly w
      where w.user_id = p.user_id and w.group_id = p.group_id
        and w.finalized_at is not null)
    when 'campfire_hours' then not exists (
      select 1 from public.group_achievement_daily d
      where d.user_id = p.user_id and d.group_id = p.group_id)
    when 'locomotive' then not exists (
      select 1 from public.group_achievement_daily d
      where d.user_id = p.user_id and d.group_id = p.group_id)
    else false
  end;

  insert into public.group_achievement_metric_progress(
    user_id, group_id, achievement_id, metric_value, source_version, updated_at
  )
  select user_id, group_id, metric, value, 'group_scoped_v1', clock_timestamp()
  from (
    select user_id, group_id, 'alpha_wolf' as metric,
      sum(alpha_wins)::bigint as value
      from public.group_achievement_daily
      where finalized_at is not null
      group by user_id, group_id
    union all
    select user_id, group_id, 'campfire_hours', sum(campfire_seconds) / 3600
      from public.group_achievement_daily group by user_id, group_id
    union all
    select user_id, group_id, 'locomotive', sum(locomotive_events)::bigint
      from public.group_achievement_daily group by user_id, group_id
    union all
    select user_id, group_id, 'alpha_wolf_weekly',
      sum(weekly_alpha_wins)::bigint
      from public.group_achievement_weekly
      where finalized_at is not null
      group by user_id, group_id
  ) m
  on conflict (user_id, group_id, achievement_id) do update set
    -- Kırılım gerçeği: değer **düşebilir** (üyelik geçmişi düzeltildiğinde).
    metric_value = excluded.metric_value,
    source_version = excluded.source_version,
    updated_at = clock_timestamp();
  get diagnostics v_rows = row_count;

  -- Düz tablo ödül/XP tarafının tek kaynağıdır ve cihaza bağlı olamaz:
  -- kullanıcının en iyi grubunun değeri yazılır.
  --
  -- 🔴 Kartın tuzağı burada: eskiden haftalık metrik
  -- `greatest(mevcut, yeni)` ile yazılıyordu, yani **çift sayılmış eski değer
  -- kilitli kalırdı** ve düzeltme hiçbir zaman görünmezdi. Bilerek
  -- `excluded.metric_value` kullanılıyor. Kademe geri alınmaz: ödül üretimi
  -- yalnız `insert ... on conflict do nothing` yapar
  -- (`_sync_equal_source_rewards`, 0063), hiçbir yerde ödül silinmez.
  insert into public.achievement_metric_progress(
    user_id, achievement_id, metric_value, source_version, updated_at
  )
  -- Hic grup satiri kalmayan kullanici bu `group by`de gorunmez; duz tablo
  -- degeri oldugu gibi kalir. Bilincli: kademe geri alinmaz (kabul md. 2).
  select user_id, achievement_id, max(metric_value)::bigint,
    'group_scoped_v1', clock_timestamp()
  from public.group_achievement_metric_progress
  group by user_id, achievement_id
  on conflict (user_id, achievement_id) do update set
    metric_value = excluded.metric_value,
    source_version = excluded.source_version,
    updated_at = clock_timestamp();

  return v_rows;
end;
$$;

revoke all on function public._project_group_scoped_metrics()
  from public, authenticated, anon;

-- 3) Üç projeksiyon: gövdeleri 0059/0063'teki hâlleriyle **birebir**, yalnız
--    düz tabloya yazan blok kırılım çağrısıyla değiştirildi.

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

  -- 🔴 WP-501: burada `group by user_id` vardı — TÜM grupların toplamı
  -- tek satıra yazılıyor, yani (grup × gün/hafta) sayılıyordu. Kırılım
  -- artık `_project_group_scoped_metrics()` içinde, grup boyutuyla.
  perform public._project_group_scoped_metrics();
  return v_affected;
end;
$$;

create or replace function public.project_group_day(p_group_id uuid, p_day date)
returns integer language plpgsql security definer set search_path = public as $$
declare v_affected integer; r record;
begin
  with bounds as (
    select (p_day::timestamp at time zone 'Europe/Istanbul') as lo,
      ((p_day + 1)::timestamp at time zone 'Europe/Istanbul') as hi
  ), raw as (
    select s.user_id, tstzrange(
      greatest(s.start_time, b.lo, gm.joined_at),
      least(
        public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds),
        b.hi,
        coalesce(gm.left_at, b.hi)
      ),
      '[)'
    ) as period
    from public.study_sessions s
    join public.group_members gm on gm.user_id = s.user_id
      and gm.group_id = p_group_id
      and public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) > gm.joined_at
      and (gm.left_at is null or s.start_time < gm.left_at)
    cross join bounds b
    where s.duration_seconds > 0
      and public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) > b.lo
      and s.start_time < b.hi
  ), seg as (
    select merged.user_id, lower(range_piece.period) as a, upper(range_piece.period) as z
    from (
      select user_id, range_agg(period) as periods
      from raw where not isempty(period) group by user_id
    ) merged
    cross join lateral unnest(merged.periods) as range_piece(period)
  ), thr as (
    select greatest(2, ceil(count(distinct user_id) / 2.0))::int as t from seg
  ), events as (
    select a t, 1 delta from seg union all select z, -1 from seg
  ), points as (
    select t, sum(delta) over(order by t, delta rows unbounded preceding) active,
      lead(t) over(order by t, delta) next_t from events
  ), camp as (
    select s.user_id,
      floor(sum(extract(epoch from (least(s.z, p.next_t) - greatest(s.a, p.t)))))::bigint seconds
    from seg s join points p on p.active >= (select t from thr) and p.next_t > p.t
      and s.a < p.next_t and s.z > p.t
    group by s.user_id
  ), totals as (
    select user_id, floor(sum(extract(epoch from (z - a))))::bigint seconds
    from seg group by user_id
  ), alpha as (
    select user_id, case when count(*) over(partition by seconds) = 1
      and dense_rank() over(order by seconds desc) = 1 then 1 else 0 end wins
    from totals
  ), loco as (
    select leader.user_id, count(distinct follower.user_id)::integer events
    from seg leader join seg follower on follower.user_id <> leader.user_id
      and follower.a between leader.a and least(leader.z, leader.a + interval '15 minutes')
    group by leader.user_id
  ), users as (select user_id from seg group by user_id)
  insert into public.group_achievement_daily(
    group_id, istanbul_day, user_id, alpha_wins, campfire_seconds, locomotive_events,
    source_version, updated_at
  ) select p_group_id, p_day, u.user_id, coalesce(a.wins, 0), coalesce(c.seconds, 0),
      coalesce(l.events, 0), 'group_all_sessions_v2', clock_timestamp()
    from users u left join alpha a using(user_id) left join camp c using(user_id)
      left join loco l using(user_id)
  on conflict(group_id, istanbul_day, user_id) do update set
    alpha_wins = excluded.alpha_wins,
    campfire_seconds = excluded.campfire_seconds,
    locomotive_events = excluded.locomotive_events,
    source_version = excluded.source_version,
    updated_at = clock_timestamp();
  get diagnostics v_affected = row_count;

  -- Silinen/düzenlenen session sonrası eski kazanan satırı hayalet kalmasın.
  update public.group_achievement_daily d
  set alpha_wins = 0, campfire_seconds = 0, locomotive_events = 0,
      source_version = 'group_all_sessions_v2', updated_at = clock_timestamp()
  where d.group_id = p_group_id and d.istanbul_day = p_day
    and not exists (
      select 1 from public.study_sessions s
      join public.group_members gm on gm.user_id = s.user_id
        and gm.group_id = p_group_id
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > gm.joined_at
        and (gm.left_at is null or s.start_time < gm.left_at)
      where s.user_id = d.user_id and s.duration_seconds > 0
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > (p_day::timestamp at time zone 'Europe/Istanbul')
        and s.start_time < ((p_day + 1)::timestamp at time zone 'Europe/Istanbul')
    );

  -- 🔴 WP-501: burada `group by user_id` vardı — TÜM grupların toplamı
  -- tek satıra yazılıyor, yani (grup × gün/hafta) sayılıyordu. Kırılım
  -- artık `_project_group_scoped_metrics()` içinde, grup boyutuyla.
  perform public._project_group_scoped_metrics();
  for r in
    select p.user_id, p.achievement_id, p.metric_value
    from public.achievement_metric_progress p
    where p.achievement_id in ('alpha_wolf', 'campfire_hours', 'locomotive')
      and exists (
        select 1 from public.group_achievement_daily d
        where d.group_id = p_group_id and d.istanbul_day = p_day
          and d.user_id = p.user_id
      )
  loop
    perform public._sync_equal_source_rewards(
      r.user_id, r.achievement_id, r.metric_value, 'group_all_sessions_v2',
      jsonb_build_object('group_id', p_group_id, 'istanbul_day', p_day)
    );
  end loop;
  return v_affected;
end;
$$;

create or replace function public.project_group_week(p_group_id uuid, p_week_start date)
returns integer language plpgsql security definer set search_path = public as $$
declare v_affected integer; r record;
begin
  if extract(isodow from p_week_start) <> 1 then
    raise exception 'iso_week_start_must_be_monday';
  end if;
  with bounds as (
    select (p_week_start::timestamp at time zone 'Europe/Istanbul') as lo,
      ((p_week_start + 7)::timestamp at time zone 'Europe/Istanbul') as hi
  ), raw as (
    select s.user_id, tstzrange(
      greatest(s.start_time, b.lo, gm.joined_at),
      least(
        public._equal_source_effective_end(s.start_time, s.end_time, s.duration_seconds),
        b.hi,
        coalesce(gm.left_at, b.hi)
      ),
      '[)'
    ) as period
    from public.study_sessions s
    join public.group_members gm on gm.user_id = s.user_id
      and gm.group_id = p_group_id
      and public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) > gm.joined_at
      and (gm.left_at is null or s.start_time < gm.left_at)
    cross join bounds b
    where s.duration_seconds > 0
      and public._equal_source_effective_end(
        s.start_time, s.end_time, s.duration_seconds
      ) > b.lo
      and s.start_time < b.hi
  ), sessions as (
    select merged.user_id, lower(range_piece.period) as started_at,
      upper(range_piece.period) as ended_at
    from (
      select user_id, range_agg(period) as periods
      from raw where not isempty(period) group by user_id
    ) merged
    cross join lateral unnest(merged.periods) as range_piece(period)
  ), totals as (
    select user_id, floor(sum(extract(epoch from ended_at - started_at)))::bigint as seconds
    from sessions group by user_id
  ), leaders as (
    select user_id from totals where seconds = (select max(seconds) from totals)
  ), winner as (
    select user_id from leaders where (select count(*) from leaders) = 1
  )
  insert into public.group_achievement_weekly(
    group_id, iso_week_start, user_id, total_seconds, weekly_alpha_wins, updated_at
  ) select p_group_id, p_week_start, t.user_id, t.seconds,
      case when w.user_id is null then 0 else 1 end, clock_timestamp()
    from totals t left join winner w using(user_id)
  on conflict(group_id, iso_week_start, user_id) do update set
    total_seconds = excluded.total_seconds,
    weekly_alpha_wins = excluded.weekly_alpha_wins,
    updated_at = clock_timestamp();
  get diagnostics v_affected = row_count;

  update public.group_achievement_weekly w
  set total_seconds = 0, weekly_alpha_wins = 0, updated_at = clock_timestamp()
  where w.group_id = p_group_id and w.iso_week_start = p_week_start
    and not exists (
      select 1 from public.study_sessions s
      join public.group_members gm on gm.user_id = s.user_id
        and gm.group_id = p_group_id
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > gm.joined_at
        and (gm.left_at is null or s.start_time < gm.left_at)
      where s.user_id = w.user_id and s.duration_seconds > 0
        and public._equal_source_effective_end(
          s.start_time, s.end_time, s.duration_seconds
        ) > (p_week_start::timestamp at time zone 'Europe/Istanbul')
        and s.start_time < ((p_week_start + 7)::timestamp at time zone 'Europe/Istanbul')
    );

  -- 🔴 WP-501: burada `group by user_id` vardı — TÜM grupların toplamı
  -- tek satıra yazılıyor, yani (grup × gün/hafta) sayılıyordu. Kırılım
  -- artık `_project_group_scoped_metrics()` içinde, grup boyutuyla.
  perform public._project_group_scoped_metrics();

  for r in
    select p.user_id, p.metric_value
    from public.achievement_metric_progress p
    where p.achievement_id = 'alpha_wolf_weekly'
      and exists (
        select 1 from public.group_achievement_weekly w
        where w.group_id = p_group_id and w.iso_week_start = p_week_start
          and w.user_id = p.user_id
      )
  loop
    perform public._sync_equal_source_rewards(
      r.user_id, 'alpha_wolf_weekly', r.metric_value,
      'weekly_alpha_all_sessions_v2',
      jsonb_build_object('group_id', p_group_id, 'week_start', p_week_start)
    );
  end loop;
  return v_affected;
end;
$$;

-- 4) Backfill. Mevcut satırlar (grup × hafta) toplamını taşıyor; kırılım bir
--    kez hesaplanıp düz tablo en iyi grubun değerine çekilir.
select public._project_group_scoped_metrics();
