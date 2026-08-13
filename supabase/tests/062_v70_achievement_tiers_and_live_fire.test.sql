-- 062_v70_achievement_tiers_and_live_fire.test.sql
-- WP-732: alti kademe, Kusursuz Ay 2x XP ve geri cekilebilir canli seri.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

select plan(25);

select is((select max_tier from public.achievements_dict where id='ancient_member'), 6,
  'Kadim Uye alti kademeli');
select is((select array_agg((t->>'threshold')::int order by (t->>'tier')::int)
  from public.achievements_dict d cross join lateral jsonb_array_elements(d.tiers)t
  where d.id='ancient_member'), array[30,100,365,730,1095,1825],
  'Kadim Uye esikleri artan 30..1825 gun');
select is((select array_agg((t->>'xp')::int order by (t->>'tier')::int)
  from public.achievements_dict d cross join lateral jsonb_array_elements(d.tiers)t
  where d.id='ancient_member'), array[500,1500,5000,12000,25000,50000],
  'Kadim Uye XP ekonomisi kanonik');

select is((select max_tier from public.achievements_dict where id='metronome'), 6,
  'Metronom alti kademeli');
select is((select array_agg((t->>'threshold')::int order by (t->>'tier')::int)
  from public.achievements_dict d cross join lateral jsonb_array_elements(d.tiers)t
  where d.id='metronome'), array[4,12,26,52,104,156],
  'Metronom esikleri artan 4..156 hafta');
select is((select array_agg((t->>'xp')::int order by (t->>'tier')::int)
  from public.achievements_dict d cross join lateral jsonb_array_elements(d.tiers)t
  where d.id='metronome'), array[1000,3000,8000,20000,45000,90000],
  'Metronom XP ekonomisi kanonik');

select is((select array_agg((t->>'threshold')::int order by (t->>'tier')::int)
  from public.achievements_dict d cross join lateral jsonb_array_elements(d.tiers)t
  where d.id='perfect_month'), array[1,3,6,12,24,36],
  'Kusursuz Ay zorlugu artmadi: esikler korundu');
select is((select array_agg((t->>'xp')::int order by (t->>'tier')::int)
  from public.achievements_dict d cross join lateral jsonb_array_elements(d.tiers)t
  where d.id='perfect_month'), array[4000,8000,16000,32000,64000,128000],
  'Kusursuz Ay odulleri onceki ekonominin tam 2 katidir');

select is(
  (select count(*)::int from public.achievements_dict),
  27,
  'mevcut katalog satirlari korunur; 0135 yalniz uc tanimi ileri gunceller'
);

select is((select projection_kind || ':' || source_version
  from public.achievement_metric_definitions where achievement_id='fire_streak'),
  'current:goal_completion_current_v2',
  'Alevli Seri current ve goal-completion kaynaklidir');

-- goal_progress_events kasitli olarak polimorfiktir ve FK tasimaz. Eski
-- fixture'lar sahipsiz bir personal scope ile ayrim davranisini olcer; hesap
-- silme akisi da auth.users satiri gittikten sonra olayi temizler. Canli seri
-- trigger'i bu iki durumda FK'li metric tablosuna yeniden satir yazmamalidir.
select lives_ok(
  $$insert into public.goal_progress_events(
      event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
    ) values (
      'wp732-orphan-scope', 'personal',
      '30000000-0000-0000-0000-000000000001', 'Europe/Istanbul',
      'goal_completed', '1900-01-01', now()
    )$$,
  'sahipsiz personal olay canli seri triggerinda FK hatasi uretmez'
);
select is(
  (select count(*)::int from public.achievement_metric_progress
    where user_id = '30000000-0000-0000-0000-000000000001'),
  0,
  'sahipsiz scope icin metric satiri uretilmez'
);

-- Dort guncel, kesintisiz Istanbul hedef gunu.
insert into public.goal_progress_events(
  event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
)
select 'wp732-fire-' || d::text, 'personal', :'alpha', 'Europe/Istanbul',
       'goal_completed', d, now()
from generate_series(
  (timezone('Europe/Istanbul', now()))::date - 3,
  (timezone('Europe/Istanbul', now()))::date,
  interval '1 day'
) g(d)
on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;

select is(public._current_fire_streak_days(:'alpha'), 4,
  'dort kesintisiz hedef gunu 4/7 canli ilerleme verir');
select is((public._achievement_metrics(:'alpha')->>'streak_days')::int, 4,
  'profil metrik hatti canli 4 degerini tasir');

insert into public.xp_ledger(user_id,achievement_id,tier,xp_amount,event_key)
values(:'alpha','fire_streak',1,1000,:'alpha'||'|fire_streak|tier_1')
on conflict(event_key) do nothing;
insert into public.user_achievements(user_id,achievement_id,tier,progress,unlocked_at)
values(:'alpha','fire_streak',1,7,now())
on conflict(user_id,achievement_id) do update set tier=excluded.tier;

delete from public.goal_progress_events
 where scope_type='personal' and scope_id=:'alpha'
   and event_kind='goal_completed'
   and goal_day >= (timezone('Europe/Istanbul', now()))::date - 1;

select is(public._current_fire_streak_days(:'alpha'), 0,
  'bugun ve dun bos kalinca guncel seri sifirlanir');
select is((public._achievement_metrics(:'alpha')->>'streak_days')::int, 0,
  'current metric progress sifira geri cekilir');
select is((select count(*)::int from public.xp_ledger
  where user_id=:'alpha' and achievement_id='fire_streak' and tier=1), 1,
  'kazanilmis Alevli Seri ledger satiri silinmez');
select is((select tier from public.user_achievements
  where user_id=:'alpha' and achievement_id='fire_streak'), 1,
  'kazanilmis Alevli Seri rozeti silinmez');

-- Gercek veri backfill'i: 1900 gun uyelik ve 160 hafta ritim.
update public.group_members set joined_at=now()-interval '1900 days', left_at=null
 where group_id=:'grp' and user_id=:'alpha';
insert into public.goal_progress_events(
  event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
)
select 'wp732-metro-' || d::date::text, 'personal', :'beta', 'Europe/Istanbul',
       'goal_completed', d::date, now()
from generate_series('2023-01-02'::date, '2026-01-25'::date, interval '1 day') g(d)
where extract(isodow from d) between 1 and 5
on conflict (scope_type, scope_id, event_kind, goal_day) do nothing;

select ok(public.backfill_v70_achievement_progress() >= 2,
  'backfill mevcut kullanicilari gercek kaynaklardan isler');
select ok((select metric_value from public.achievement_metric_progress
  where user_id=:'alpha' and achievement_id='ancient_member') >= 1825,
  '1900 gunluk mevcut uyelik altinci kademe ilerlemesine doldurulur');
select is((select array_agg(tier order by tier) from public.achievement_rewards
  where user_id=:'alpha' and achievement_id='ancient_member'), array[1,2,3,4,5,6],
  'Kadim Uye alti pending odulu idempotent uretilir');
select ok((select metric_value from public.achievement_metric_progress
  where user_id=:'beta' and achievement_id='metronome') >= 156,
  '160 haftalik mevcut ritim altinci kademe ilerlemesine doldurulur');
select is((select array_agg(tier order by tier) from public.achievement_rewards
  where user_id=:'beta' and achievement_id='metronome'), array[1,2,3,4,5,6],
  'Metronom alti pending odulu idempotent uretilir');
select is((select public.backfill_v70_achievement_progress() >= 2 and
  (select count(*) from public.achievement_rewards
    where achievement_id in('ancient_member','metronome')) = 12), true,
  'ikinci backfill cift odul uretmez');
select ok(not has_function_privilege(
  'authenticated','public.backfill_v70_achievement_progress()','execute'),
  'istemci backfill cagiramaz; zincir server-authoritative kalir');

select * from finish();
rollback;
