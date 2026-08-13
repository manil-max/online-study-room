-- 059_fire_streak_retraction_contract.test.sql
-- WP-732: canli Alevli Seri geri cekilir; kazanilmis kademe/ledger korunur.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'

select plan(10);

select is(
  (select projection_kind from public.achievement_metric_definitions
    where achievement_id = 'fire_streak'),
  'current',
  'fire_streak current: canli deger dusebilir'
);
select is(
  (select source_version from public.achievement_metric_definitions
    where achievement_id = 'fire_streak'),
  'goal_completion_current_v2',
  'canli seri kanonik goal-completion v2 kaynagini ilan eder'
);
select is(
  (select projection_kind from public.achievement_metric_definitions
    where achievement_id = 'weekend_goal_days'),
  'cumulative',
  'karsilastirma: weekend_goal_days cumulative kalir'
);
select ok(
  public._session_derived_progress(
    jsonb_build_object('streak_days', 0), 'fire_streak'
  ) is null,
  'uzlastirma kazanilmis fire_streak ledger kademesini silmez'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public._current_fire_streak_days(uuid,date)', 'execute'
  ),
  'istemci server-authoritative seri yardimcisini dogrudan cagiramaz'
);

update public.profiles set daily_goal_minutes = 60 where id = :'alpha';

-- Base fixture bugunu kurar; yedi onceki gun eklenince sekiz kesintisiz gun.
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
select
  ('32000000-0000-0000-0000-' || lpad(g::text, 12, '0'))::uuid,
  :'alpha'::uuid,
  b.base - make_interval(days => g) + interval '9 hours',
  b.base - make_interval(days => g) + interval '10 hours',
  3600, 'live'
from generate_series(1, 7) g
cross join (
  select date_trunc('day', timezone('Europe/Istanbul', now()))
           at time zone 'Europe/Istanbul' as base
) b;

select ok(
  (public._achievement_metrics(:'alpha') ->> 'streak_days')::integer >= 7,
  'kesintisiz hedef gunleri canli metrikte en az 7 gorunur'
);
select ok(
  public._current_fire_streak_days(:'alpha') >= 7,
  'kanonik yardimci ayni kesintisiz seriyi hesaplar'
);

insert into public.xp_ledger (user_id, achievement_id, tier, xp_amount, event_key)
select :'alpha', 'fire_streak', 1, (t->>'xp')::integer,
       :'alpha' || '|fire_streak|tier_1'
  from public.achievements_dict d
  cross join lateral jsonb_array_elements(d.tiers) t
 where d.id = 'fire_streak' and (t->>'tier')::integer = 1
on conflict (event_key) do nothing;

insert into public.user_achievements (
  user_id, achievement_id, tier, progress, unlocked_at
) values (:'alpha', 'fire_streak', 1, 7, now())
on conflict (user_id, achievement_id) do update
  set tier = excluded.tier,
      progress = excluded.progress,
      unlocked_at = excluded.unlocked_at;

-- Bugun ve dun gider. 0129 dayanaksiz goal_completed olaylarini geri ceker;
-- 0128/0135 metrik projeksiyonu current degeri sifira indirir.
delete from public.study_sessions
 where id in ('30000000-0000-0000-0000-000000000001',
              '32000000-0000-0000-0000-000000000001');

select is(
  public._current_fire_streak_days(:'alpha'),
  0,
  'bugun ve dun hedef gunu kalmayinca canli seri sifirlanir'
);
select is(
  (select metric_value from public.achievement_metric_progress
    where user_id = :'alpha' and achievement_id = 'fire_streak'),
  0::bigint,
  'ekrandaki seri ilerlemesi current projeksiyonla 0 olur'
);
select is(
  (select tier from public.user_achievements
    where user_id = :'alpha' and achievement_id = 'fire_streak'),
  1,
  'kazanilmis kademe kalir; canli metrik geri cekilse de odul silinmez'
);

select * from finish();
rollback;
