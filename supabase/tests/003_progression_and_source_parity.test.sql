begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir _fixtures/base_seed.psql

select plan(11);

select is(
  (public._achievement_metrics('10000000-0000-0000-0000-000000000001')->>'total_hours')::integer,
  1,
  'live seed contributes one total hour'
);
select is(
  (public._achievement_metrics('10000000-0000-0000-0000-000000000002')->>'total_hours')::integer,
  1,
  'manual seed contributes one total hour'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is(
  (public.process_achievement_event('manual_refresh', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  50,
  'live source receives 50 XP for its first hour'
);
select is(
  (public.process_achievement_event('manual_refresh', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  0,
  'live source hour XP retry is idempotent'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select is(
  (public.process_achievement_event('manual_refresh', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  50,
  'manual source receives the same 50 XP for its first hour'
);
select is(
  (public.process_achievement_event('manual_refresh', '{}'::jsonb)->>'study_hour_xp_granted')::integer,
  0,
  'manual source hour XP retry is idempotent'
);

reset role;
select is(
  (select xp from public.gamification_profiles where user_id = '10000000-0000-0000-0000-000000000001'),
  (select xp from public.gamification_profiles where user_id = '10000000-0000-0000-0000-000000000002'),
  'equal durations produce equal profile XP'
);
select is(
  (
    select count(*) from public.gamification_profiles gp
    where gp.user_id in (
      '10000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000002'
    )
      and gp.xp <> (
        select coalesce(sum(xp_amount), 0)::integer
        from public.xp_ledger xl where xl.user_id = gp.user_id
      )
  ),
  0::bigint,
  'profile XP equals append-only ledger total'
);
select is(
  public.project_group_week(
    '20000000-0000-0000-0000-000000000001',
    date_trunc('week', timezone('Europe/Istanbul', now()))::date
  ),
  2,
  'weekly source-neutral projector writes both users'
);

-- WP-255: yeniden fiyatlandırılan çekirdek başarımlar. Sözlük yeni fiyatı
-- taşımalı ve KAZANILMIŞ defter satırları sözlükle aynı olmalı; ikisi
-- ayrışırsa reprice yarım uygulanmış demektir (eski kullanıcı düşük XP'de
-- kalır, yeni kullanıcı yükseği alır).
select is(
  (
    select (t->>'xp')::integer
    from public.achievements_dict d
    cross join lateral jsonb_array_elements(d.tiers) as t
    where d.id = 'marathon_total' and (t->>'tier')::integer = 1
  ),
  1500,
  'marathon_total tier 1 is repriced to 1500 XP'
);
select is(
  (
    select count(*)
    from public.xp_ledger l
    join public.achievements_dict d on d.id = l.achievement_id
    cross join lateral jsonb_array_elements(d.tiers) as t
    where d.id in ('marathon_total','steel_will','day_hero','fire_streak','locomotive')
      and (t->>'tier')::integer = l.tier
      and (t->>'xp')::integer is distinct from l.xp_amount
  ),
  0::bigint,
  'no awarded ledger row disagrees with the repriced dictionary'
);

select * from finish();
rollback;
