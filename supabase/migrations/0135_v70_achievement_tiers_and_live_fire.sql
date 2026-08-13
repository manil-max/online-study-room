-- 0135_v70_achievement_tiers_and_live_fire.sql
-- WP-732 / v70: Kadim Uye ve Metronom alti kademeye cikar; Kusursuz Ay
-- odullerini esikleri degistirmeden 2x yapar; Alevli Seri ilerlemesini
-- Europe/Istanbul gunlerinde guncel, kesintisiz hedef serisine baglar.
--
-- Canli seri geri cekilebilir; kazanilmis achievement_rewards, xp_ledger ve
-- user_achievements satirlari silinmez. Eski kullanicilarin yeni kademe ve XP
-- haklari ileri yonlu, idempotent backfill ile tamamlanir.
--
-- Geri alma (Rollback): sozluk tuple'larini yeni bir ileri migration ile onceki
-- degerlere dondur; `_achievement_metrics` govdesini 0134'e dondur ve
-- `fire_streak` source_version'ini `metric_v2` yap; sonra
-- `goal_progress_events_sync_fire_streak` tetikleyicisini kaldir. Verilmis/pending odulleri ve
-- ledger satirlarini SILME; XP azaltmak tac kaybettirecegi icin urun karari ve
-- ayri uzlastirma gerektirir. `_current_fire_streak_days` ile
-- `backfill_v70_achievement_progress` ancak kullanan wrapper kaldirildiktan
-- sonra drop edilebilir.

-- ---------------------------------------------------------------------------
-- 1) Kanonik alti kademe katalogu ve Kusursuz Ay 2x odul dengesi
-- ---------------------------------------------------------------------------
update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":30,"unit":"membership_days","xp":500},{"tier":2,"threshold":100,"unit":"membership_days","xp":1500},{"tier":3,"threshold":365,"unit":"membership_days","xp":5000},{"tier":4,"threshold":730,"unit":"membership_days","xp":12000},{"tier":5,"threshold":1095,"unit":"membership_days","xp":25000},{"tier":6,"threshold":1825,"unit":"membership_days","xp":50000}]'::jsonb
 where id = 'ancient_member';

update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":4,"unit":"metronome_weeks","xp":1000},{"tier":2,"threshold":12,"unit":"metronome_weeks","xp":3000},{"tier":3,"threshold":26,"unit":"metronome_weeks","xp":8000},{"tier":4,"threshold":52,"unit":"metronome_weeks","xp":20000},{"tier":5,"threshold":104,"unit":"metronome_weeks","xp":45000},{"tier":6,"threshold":156,"unit":"metronome_weeks","xp":90000}]'::jsonb
 where id = 'metronome';

-- Esikler ayni kalir. Yalniz XP, 0134 oncesi kanonik degerlerin tam 2 katidir.
update public.achievements_dict set max_tier = 6, tiers =
  '[{"tier":1,"threshold":1,"unit":"perfect_months","xp":4000},{"tier":2,"threshold":3,"unit":"perfect_months","xp":8000},{"tier":3,"threshold":6,"unit":"perfect_months","xp":16000},{"tier":4,"threshold":12,"unit":"perfect_months","xp":32000},{"tier":5,"threshold":24,"unit":"perfect_months","xp":64000},{"tier":6,"threshold":36,"unit":"perfect_months","xp":128000}]'::jsonb
 where id = 'perfect_month';

-- ---------------------------------------------------------------------------
-- 2) Alevli Seri: tarihsel en iyi degil, guncel kesintisiz hedef gunleri
-- ---------------------------------------------------------------------------
create or replace function public._current_fire_streak_days(
  p_user_id uuid,
  p_as_of_day date default (timezone('Europe/Istanbul', now()))::date
)
returns integer
language sql
security definer
set search_path = public
stable
as $wp732$
  with completed as (
    select distinct e.goal_day
      from public.goal_progress_events e
     where e.scope_type = 'personal'
       and e.scope_id = p_user_id
       and e.event_kind = 'goal_completed'
       and e.time_zone = 'Europe/Istanbul'
       and e.goal_day <= p_as_of_day
  ), anchor as (
    -- Bugun henuz tamamlanmadiysa dunun serisi gun bitene kadar canlidir.
    select case
      when exists (select 1 from completed where goal_day = p_as_of_day)
        then p_as_of_day
      when exists (select 1 from completed where goal_day = p_as_of_day - 1)
        then p_as_of_day - 1
      else null::date
    end as day
  ), numbered as (
    select c.goal_day,
           row_number() over (order by c.goal_day desc)::integer as rn
      from completed c
      join anchor a on a.day is not null and c.goal_day <= a.day
  )
  select coalesce(count(*) filter (
    where n.goal_day = a.day - (n.rn - 1)
  ), 0)::integer
    from anchor a
    left join numbered n on true;
$wp732$;

revoke all on function public._current_fire_streak_days(uuid, date)
  from public, anon, authenticated;

create or replace function public._project_current_fire_streak(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $wp732$
declare
  v_streak integer;
begin
  if p_user_id is null then return 0; end if;
  v_streak := public._current_fire_streak_days(p_user_id);
  insert into public.achievement_metric_progress(
    user_id, achievement_id, metric_value, source_version, updated_at
  ) values (
    p_user_id, 'fire_streak', v_streak, 'goal_completion_current_v2', now()
  )
  on conflict (user_id, achievement_id) do update set
    metric_value = excluded.metric_value,
    source_version = excluded.source_version,
    updated_at = now()
  where public.achievement_metric_progress.metric_value
          is distinct from excluded.metric_value
     or public.achievement_metric_progress.source_version
          is distinct from excluded.source_version;
  return v_streak;
end;
$wp732$;

revoke all on function public._project_current_fire_streak(uuid)
  from public, anon, authenticated;

create or replace function public._sync_fire_streak_after_goal_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $wp732$
declare
  v_scope_type text;
  v_scope_id uuid;
  v_event_kind text;
  v_time_zone text;
begin
  if tg_op = 'DELETE' then
    v_scope_type := old.scope_type;
    v_scope_id := old.scope_id;
    v_event_kind := old.event_kind;
    v_time_zone := old.time_zone;
  else
    v_scope_type := new.scope_type;
    v_scope_id := new.scope_id;
    v_event_kind := new.event_kind;
    v_time_zone := new.time_zone;
  end if;
  if v_scope_type = 'personal' and v_event_kind = 'goal_completed'
     and v_time_zone = 'Europe/Istanbul'
     and exists (select 1 from auth.users u where u.id = v_scope_id) then
    perform public._project_current_fire_streak(v_scope_id);
  end if;
  return null;
end;
$wp732$;

revoke all on function public._sync_fire_streak_after_goal_event()
  from public, anon, authenticated;

drop trigger if exists goal_progress_events_sync_fire_streak
  on public.goal_progress_events;
create trigger goal_progress_events_sync_fire_streak
after insert or delete on public.goal_progress_events
for each row execute function public._sync_fire_streak_after_goal_event();

update public.achievement_metric_definitions
   set projection_kind = 'current',
       metric_key = 'streak_days',
       source_version = 'goal_completion_current_v2',
       updated_at = now()
 where achievement_id = 'fire_streak';

-- 0134 wrapper'i korunur; yalniz streak_days kanonik olay projeksiyonundan
-- tekrar yazilir. `_project_achievement_metrics` current dali dususe izin verir.
create or replace function public._achievement_metrics(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
volatile
as $wp732$
declare
  v_metrics jsonb;
  v_perfect_months integer;
  v_converted_nudges integer;
  v_fire_streak integer;
  v_wp721 jsonb;
begin
  v_metrics := public._achievement_metrics_legacy_v1(p_user_id);

  v_perfect_months := public._count_perfect_months_28(p_user_id);
  v_metrics := jsonb_set(
    v_metrics, '{perfect_months}', to_jsonb(coalesce(v_perfect_months, 0)), true
  );

  v_converted_nudges := public._count_converted_nudges(p_user_id);
  v_metrics := jsonb_set(
    v_metrics, '{nudge_starts}', to_jsonb(coalesce(v_converted_nudges, 0)), true
  );

  v_fire_streak := public._current_fire_streak_days(p_user_id);
  v_metrics := jsonb_set(
    v_metrics, '{streak_days}', to_jsonb(coalesce(v_fire_streak, 0)), true
  );

  perform public._project_achievement_metrics(p_user_id, v_metrics);

  v_wp721 := public.project_wp721_metrics(p_user_id);
  v_metrics := jsonb_set(
    v_metrics, '{ancient_member_days}', v_wp721->'ancient_member_days', true
  );
  v_metrics := jsonb_set(
    v_metrics, '{metronome_weeks}', v_wp721->'metronome_weeks', true
  );
  return v_metrics;
end;
$wp732$;

revoke all on function public._achievement_metrics(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3) Mevcut kullanicilar: reprice + yeni kademeler + canli seri backfill
-- ---------------------------------------------------------------------------
create or replace function public.backfill_v70_achievement_progress()
returns integer
language plpgsql
security definer
set search_path = public
as $wp732$
declare
  v_user uuid;
  v_count integer := 0;
begin
  for v_user in select id from auth.users order by id loop
    -- `_achievement_metrics` current fire projeksiyonunu yazar;
    -- `project_wp721_metrics` yeni 5/6 kademeleri idempotent pending yapar.
    perform public._achievement_metrics(v_user);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$wp732$;

revoke all on function public.backfill_v70_achievement_progress()
  from public, anon, authenticated;

do $wp732_reprice$
declare
  v_users integer;
begin
  perform set_config('app.allow_xp_write', 'on', true);

  create temporary table _wp732_reprice_map on commit drop as
    select d.id as achievement_id,
           (t->>'tier')::integer as tier,
           (t->>'xp')::integer as xp
      from public.achievements_dict d
      cross join lateral jsonb_array_elements(d.tiers) t
     where d.id = 'perfect_month';

  create temporary table _wp732_reprice_users on commit drop as
    select distinct user_id from (
      select l.user_id
        from public.xp_ledger l
        join _wp732_reprice_map m using (achievement_id, tier)
       where l.xp_amount is distinct from m.xp
      union
      select r.user_id
        from public.achievement_rewards r
        join _wp732_reprice_map m using (achievement_id, tier)
       where r.status = 'pending' and r.xp_amount is distinct from m.xp
    ) changed;

  update public.xp_ledger l set xp_amount = m.xp
    from _wp732_reprice_map m
   where l.achievement_id = m.achievement_id and l.tier = m.tier
     and l.xp_amount is distinct from m.xp;

  update public.achievement_rewards r set xp_amount = m.xp
    from _wp732_reprice_map m
   where r.achievement_id = m.achievement_id and r.tier = m.tier
     and r.status = 'pending' and r.xp_amount is distinct from m.xp;

  update public.gamification_profiles g
     set xp = coalesce((select sum(l.xp_amount) from public.xp_ledger l
                         where l.user_id = g.user_id), 0)::integer,
         crown_rank = public._recalc_crown_rank(
           coalesce((select sum(l.xp_amount) from public.xp_ledger l
                      where l.user_id = g.user_id), 0)::integer
         ),
         updated_at = now()
   where g.user_id in (select user_id from _wp732_reprice_users);

  v_users := public.backfill_v70_achievement_progress();
  raise notice 'WP-732 backfill: % kullanici islendi', v_users;
end
$wp732_reprice$;

notify pgrst, 'reload schema';
