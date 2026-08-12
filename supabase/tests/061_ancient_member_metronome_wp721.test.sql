-- 061_ancient_member_metronome_wp721.test.sql
-- WP-721 — "Kadim Uye" ve "Metronom" basarimlarinin sunucu ucu.
--
-- 🔴 Bu dosyanin varlik sebebi geri doldurmadir. Depoda kayitli ders (0124,
-- 2026-08-09): BOS bir veritabaninda backfill SINANMAZ -- sifir satira dokunan
-- ifade yesil yanar, kusur uretimde patlar. Bu yuzden fikstur DOLU: gecmis
-- tarihli uyelikleri olan bir kullanici, iki gun kacirarak calisan bir
-- kullanici ve 14 hafta kesintisiz calisan bir kullanici kurulur; iddialar
-- "hata vermedi" degil GERCEK SAYI olcer (600 gun, 3 hafta, 14 hafta).
--
-- Ikinci amac: Metronom'un tasarim amacini korumak. Gunluk seri iki gun
-- kacirinca kirilir; Metronom KIRILMAZ. Ayni fikstur uzerinde iki motor da
-- okunur ve fark iddiaya baglanir (5 gunluk seri <-> 3 haftalik zincir).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set veteran '10000000-0000-0000-0000-000000000001'
\set rhythm  '10000000-0000-0000-0000-000000000002'
\set steady  '10000000-0000-0000-0000-000000000003'
\set grp_a   '20000000-0000-0000-0000-000000000001'
\set grp_b   '20000000-0000-0000-0000-000000000002'

select plan(26);

-- ===========================================================================
-- Sozluk ve metrik sozlesmesi
-- ===========================================================================
select is(
  (select max_tier from public.achievements_dict where id = 'ancient_member'),
  4,
  'Kadim Uye sozlukte 4 kademeli'
);
select is(
  (select array_agg((t->>'threshold')::int order by (t->>'tier')::int)
   from public.achievements_dict d
   cross join lateral jsonb_array_elements(d.tiers) t
   where d.id = 'ancient_member'),
  array[30, 100, 365, 730],
  'Kadim Uye kademeleri 30/100/365/730 gun'
);
select is(
  (select array_agg((t->>'threshold')::int order by (t->>'tier')::int)
   from public.achievements_dict d
   cross join lateral jsonb_array_elements(d.tiers) t
   where d.id = 'metronome'),
  array[4, 12, 26, 52],
  'Metronom kademeleri 4/12/26/52 hafta'
);
select is(
  (select count(*)::int from public.achievement_metric_definitions
   where achievement_id in ('ancient_member', 'metronome')
     and projection_kind = 'cumulative'
     and source_version in ('membership_tenure_v1', 'weekly_cadence_v1')),
  2,
  'iki metrik de cumulative: kazanilmis deger dusmez'
);

-- Mevcut katalog bozulmadi: 21 eski + 2 yeni.
select is(
  (select count(*)::int from public.achievements_dict),
  23,
  'mevcut 21 basarim duruyor, uzerine 2 yeni geldi'
);
select is(
  (select count(*)::int from public.achievements_dict where is_secret),
  9,
  'dokuz gizli basarim bozulmadi'
);
select is(
  (select max((t->>'threshold')::int)
   from public.achievements_dict d
   cross join lateral jsonb_array_elements(d.tiers) t
   where d.id = 'alpha_wolf_weekly'),
  104,
  'komsu basarimin (Lider Kurt) esikleri degismedi'
);

-- ===========================================================================
-- DOLU FIKSTUR
-- ===========================================================================

-- (1) Kidemli uye: bir grupta 400 gun aktif, baska bir grupta 900-300 = 600 gun
--     uye kalip ayrilmis. "Ayni grupta" oldugu icin deger TOPLAM degil MAX'tir.
update public.group_members
set joined_at = now() - interval '400 days'
where group_id = :'grp_a' and user_id = :'veteran';

insert into public.groups (id, name, invite_code, created_by, created_at)
values (
  :'grp_b', 'WP721 Kadim Grup', 'WP721AAA', :'veteran', now() - interval '900 days'
) on conflict (id) do nothing;

insert into public.group_members (group_id, user_id, role, joined_at, left_at)
values (
  :'grp_b', :'veteran', 'member',
  now() - interval '900 days', now() - interval '300 days'
) on conflict (group_id, user_id) do update
  set joined_at = excluded.joined_at, left_at = excluded.left_at;

select is(
  public._ancient_member_days(:'veteran'),
  600,
  'Kadim Uye = TEK gruptaki en uzun uyelik (600 gun), gruplarin toplami degil'
);

-- (2) Ritim kullanicisi: her hafta hafta sonu iki gun kacirir. 01-26 haftasinda
--     bir gun daha kacirir (4 gun) ve zincir ORADA kopar.
insert into public.goal_progress_events (
  event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
)
select
  'wp721-r-' || d::date::text, 'personal', :'rhythm', 'Europe/Istanbul',
  'goal_completed', d::date, now()
from generate_series('2026-01-05'::date, '2026-02-20'::date, interval '1 day') g(d)
where extract(isodow from d) between 1 and 5
  and d::date <> '2026-01-30'::date;

select is(
  (select count(*)::int from (
     select date_trunc('week', goal_day)::date as w
     from public.goal_progress_events
     where scope_id = :'rhythm' and event_kind = 'goal_completed'
     group by 1 having count(*) >= 5
   ) q),
  6,
  'fikstur 6 uygun hafta uretir (iddianin bos dusmedigini gosterir)'
);
select is(
  public._metronome_week_chain(:'rhythm'),
  3,
  'Metronom ARDISIK zinciri olcer: 6 uygun hafta var ama en uzun zincir 3'
);

-- 🔴 TASARIM AMACININ TESTI. Ayni fikstur, iki motor:
--   gunluk seri  -> iki gun kacirinca kirilir, hafta basi sifirdan baslar
--   Metronom     -> ayni iki gun zinciri KIRMAZ, hafta sayilmaya devam eder
select is(
  (select current_streak
   from public.goal_streak_projection('personal', :'rhythm', '2026-02-20')),
  5,
  'gunluk seri iki gun kacirinca kirilir: 2026-02-20 itibariyla 5'
);
select ok(
  public._metronome_week_chain(:'rhythm') > 0
    and (select current_streak
         from public.goal_streak_projection('personal', :'rhythm', '2026-02-20')) < 7,
  'iki gun kacirmak Metronom zincirini KIRMAZ: gunluk seri 7 gune hic ulasmadan '
  'zincir haftalarca surer'
);

-- (3) 14 hafta kesintisiz Mon-Fri: kademe 1 (4) ve 2 (12) hak edilir, 3 (26) hayir.
insert into auth.users (id, email, raw_user_meta_data)
values (
  :'steady', 'fixture-steady@example.invalid',
  '{"display_name":"Fixture Steady"}'::jsonb
) on conflict (id) do nothing;

insert into public.goal_progress_events (
  event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at
)
select
  'wp721-s-' || d::date::text, 'personal', :'steady', 'Europe/Istanbul',
  'goal_completed', d::date, now()
from generate_series('2026-01-05'::date, '2026-04-10'::date, interval '1 day') g(d)
where extract(isodow from d) between 1 and 5;

select is(
  public._metronome_week_chain(:'steady'),
  14,
  '14 hafta boyunca haftada 5 gun -> zincir 14'
);

-- ===========================================================================
-- GERI DOLDURMA — dolu fikstur uzerinde, gercek sayilarla
-- ===========================================================================
select ok(
  public.backfill_wp721_metrics() >= 3,
  'backfill kaynak tablolardan kullanici bulur (uyelik + hedef olayi)'
);

select is(
  (select metric_value from public.achievement_metric_progress
   where user_id = :'veteran' and achievement_id = 'ancient_member'),
  600::bigint,
  'geri doldurma kidemli uyeye 600 gun yazar (sifirdan baslatmaz)'
);
select is(
  (select metric_value from public.achievement_metric_progress
   where user_id = :'rhythm' and achievement_id = 'metronome'),
  3::bigint,
  'geri doldurma ritim kullanicisina 3 hafta yazar'
);
select is(
  (select metric_value from public.achievement_metric_progress
   where user_id = :'steady' and achievement_id = 'metronome'),
  14::bigint,
  'geri doldurma 14 haftalik zinciri oldugu gibi yazar'
);

-- Oduller de gecmise donuk olusur; esik altinda kalan olusmaz.
select is(
  (select array_agg(tier order by tier) from public.achievement_rewards
   where user_id = :'veteran' and achievement_id = 'ancient_member'),
  array[1, 2, 3],
  '600 gun -> 30/100/365 kademeleri bekleyen odul olur, 730 olmaz'
);
select is(
  (select count(*)::int from public.achievement_rewards
   where user_id = :'rhythm' and achievement_id = 'metronome'),
  0,
  '3 haftalik zincir ilk kademenin (4) altinda: odul yok'
);
select is(
  (select array_agg(tier order by tier) from public.achievement_rewards
   where user_id = :'steady' and achievement_id = 'metronome'),
  array[1, 2],
  '14 hafta -> 4 ve 12 kademeleri olusur, 26 olmaz'
);

-- Ikinci kez calistirmak cift odul uretmez.
select is(
  (select public.backfill_wp721_metrics() >= 3
     and (select count(*)::int from public.achievement_rewards
          where achievement_id in ('ancient_member', 'metronome')) = 5),
  true,
  'backfill idempotent: ikinci tur yeni odul yaratmaz (toplam 5 kalir)'
);

-- ===========================================================================
-- Yeniden katilma karari: sayac SIFIRLANMAZ
-- ===========================================================================
update public.group_members
set joined_at = now(), left_at = null
where user_id = :'veteran';

select is(
  public._ancient_member_days(:'veteran'),
  0,
  'ham deger yeniden katilinca gercekten sifirlanir (iddia bos dusmesin)'
);
select is(
  (select metric_value from public.achievement_metric_progress
   where user_id = :'veteran' and achievement_id = 'ancient_member'),
  600::bigint,
  'gruptan cikip yeniden katilmak Kadim Uye sayacini SIFIRLAMAZ: en uzun '
  'uyelik korunur'
);
select is(
  (select (public.project_wp721_metrics(:'veteran')->>'ancient_member_days')::bigint),
  600::bigint,
  'yeniden projeksiyon da kazanilmis degeri geri almaz'
);

-- ===========================================================================
-- Canli hat + yetki
-- ===========================================================================
select is(
  (select (public._achievement_metrics(:'steady')->>'metronome_weeks')::int),
  14,
  'canli metrik hatti yeni metrigi tasir (profil acilisinda guncellenir)'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.backfill_wp721_metrics()', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public.project_wp721_metrics(uuid)', 'execute'
  ),
  'istemci projeksiyonu ve backfill''i cagiramaz (server-authoritative)'
);

select * from finish();
rollback;
