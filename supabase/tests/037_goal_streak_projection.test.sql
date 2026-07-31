-- 037_goal_streak_projection.test.sql
-- WP-453 Faz 2: seri motorunun sunucu ucu, Faz 1 ile AYNI fixture uzerinde.
--
-- Fixture: `app/test/fixtures/goal_streak_parity_v1.json`. Buradaki dort vaka
-- adi birebir oradan gelir ve `app/test/data/goal_streak_parity_wp453_test.dart`
-- iki ucu birbirine baglar: fixture'a yeni vaka eklenip buraya eklenmezse o
-- test kirmizi duser. Tek uctan yasayan sozlesme WP-373'te bir ozelligi
-- aylarca olu birakti.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

select plan(25);

-- ===========================================================================
-- Kurulum kontrolu
-- ===========================================================================
select ok(
  to_regclass('public.goal_progress_events') is not null,
  '0112 kanonik hedef olayi tablosunu acar'
);
select ok(
  not has_table_privilege('authenticated', 'public.goal_progress_events', 'insert')
    and not has_table_privilege('authenticated', 'public.goal_progress_events', 'update')
    and not has_table_privilege('authenticated', 'public.goal_progress_events', 'delete'),
  'istemci olay yazamaz: seri yalniz sunucudan ilerler'
);
select ok(
  to_regprocedure('public.goal_streak_projection(text,uuid,date)') is not null
    and has_function_privilege(
      'authenticated', 'public.goal_streak_projection(text,uuid,date)', 'execute'
    ),
  'projeksiyon RPC istemciye acik ve tek imzali'
);

-- ===========================================================================
-- Fixture vakalari (goal_streak_parity_v1.json ile ayni adlar)
-- ===========================================================================

-- [tamamla-bos-tamamla-bos-tamamla] tek kacirma seriyi surdurur.
insert into public.goal_progress_events
  (event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at)
values
  ('p-a-01', 'personal', :'alpha', 'Europe/Istanbul', 'goal_completed', '2026-07-01', now()),
  ('p-a-03', 'personal', :'alpha', 'Europe/Istanbul', 'goal_completed', '2026-07-03', now()),
  ('p-a-05', 'personal', :'alpha', 'Europe/Istanbul', 'goal_completed', '2026-07-05', now());

select is(
  (select current_streak from public.goal_streak_projection('personal', :'alpha', '2026-07-05')),
  3,
  'tamamla-bos-tamamla-bos-tamamla = seri 3'
);
select is(
  (select completion_count from public.goal_streak_projection('personal', :'alpha', '2026-07-05')),
  3,
  'tamamla-bos-tamamla-bos-tamamla: tamamlama sayisi 3'
);
select is(
  (select state from public.goal_streak_projection('personal', :'alpha', '2026-07-05')),
  'completed_today',
  'tamamla-bos-tamamla-bos-tamamla: bugun tamamlandi'
);

-- Grace tek seferlik joker DEGIL: her tek kacirmada tekrar uygulanir. Yukarida
-- iki ayri bosluk var ve ikisi de seriyi kirmadi; bu iddia onu acikca soyluyor.
select is(
  (select state from public.goal_streak_projection('personal', :'alpha', '2026-07-06')),
  'pending_today',
  'ertesi gun henuz sure var: seri beklemede'
);
select is(
  (select current_streak from public.goal_streak_projection('personal', :'alpha', '2026-07-07')),
  3,
  'tek kacirmada seri korunur (otomatik grace)'
);
select is(
  (select state from public.goal_streak_projection('personal', :'alpha', '2026-07-07')),
  'at_risk',
  'bugun tamamlanmazsa seri bitecek: at_risk'
);

-- [iki-ardisik-bos-gun-seriyi-sifirlar]
select is(
  (select current_streak from public.goal_streak_projection('personal', :'alpha', '2026-07-08')),
  0,
  'iki-ardisik-bos-gun-seriyi-sifirlar'
);
select is(
  (select state from public.goal_streak_projection('personal', :'alpha', '2026-07-08')),
  'expired',
  'iki ardisik kacirma sonrasi durum expired'
);
select is(
  (select completion_count from public.goal_streak_projection('personal', :'alpha', '2026-07-08')),
  3,
  'seri sifirlansa da toplam tamamlama sayisi kaybolmaz'
);

-- [uygulama-sayac-ve-kismi-ilerleme-seri-degildir]
insert into public.goal_progress_events
  (event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at)
values
  ('open',    'personal', :'beta', 'Europe/Istanbul', 'app_opened',       '2026-07-03', now()),
  ('timer',   'personal', :'beta', 'Europe/Istanbul', 'timer_started',    '2026-07-03', now()),
  ('partial', 'personal', :'beta', 'Europe/Istanbul', 'partial_progress', '2026-07-03', now());

select is(
  (select current_streak from public.goal_streak_projection('personal', :'beta', '2026-07-03')),
  0,
  'uygulama-sayac-ve-kismi-ilerleme-seri-degildir'
);
select is(
  (select state from public.goal_streak_projection('personal', :'beta', '2026-07-03')),
  'empty',
  'yalnizca yardimci olaylar varken durum empty'
);
-- Iddia bos dusmesin: olaylar gercekten yazildi, projeksiyon onlari eledi.
select is(
  (select count(*)::int from public.goal_progress_events
   where scope_id = :'beta' and event_kind <> 'goal_completed'),
  3,
  'yardimci olaylar kayitta durur; yalniz projeksiyona girmez'
);

-- [kisisel-ve-grup-ledger-ayridir]
insert into public.goal_progress_events
  (event_key, scope_type, scope_id, time_zone, event_kind, goal_day, occurred_at)
values
  ('personal-01', 'personal', :'grp', 'Europe/Istanbul', 'goal_completed', '2026-07-01', now()),
  ('group-01',    'group',    :'grp', 'Europe/Istanbul', 'goal_completed', '2026-07-01', now()),
  ('group-02',    'group',    :'grp', 'Europe/Istanbul', 'goal_completed', '2026-07-02', now());

select is(
  (select current_streak from public.goal_streak_projection('group', :'grp', '2026-07-02')),
  2,
  'kisisel-ve-grup-ledger-ayridir: grup serisi yalniz grup olaylarindan'
);
select is(
  (select completion_count from public.goal_streak_projection('group', :'grp', '2026-07-02')),
  2,
  'ayni kimlikte kisisel olay grup sayimina karismaz'
);
select is(
  (select current_streak from public.goal_streak_projection('personal', :'grp', '2026-07-02')),
  0,
  'ayni kimligin kisisel serisi grup olaylarindan beslenmez'
);

-- ===========================================================================
-- Cift artis ve otorite
-- ===========================================================================
select throws_ok(
  format(
    $$insert into public.goal_progress_events
        (event_key, scope_type, scope_id, time_zone, event_kind, goal_day)
      values ('dup-1', 'personal', %L, 'Europe/Istanbul', 'goal_completed', '2026-07-01')$$,
    :'alpha'
  ),
  '23505',
  null,
  'ayni kapsam+gun+tur ikinci kez yazilamaz: duplicate goal event cift artis uretmez'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

-- Baskasinin kisisel serisine yazmaya calismak.
select throws_ok(
  format($$select public.record_goal_completion('personal', %L, '2026-07-01')$$, :'beta'),
  'goal_scope_forbidden',
  'baskasinin kisisel serisi yazilamaz'
);
select throws_ok(
  format(
    $$select public.record_goal_completion('personal', %L, %L)$$,
    :'alpha', ((now() at time zone 'Europe/Istanbul')::date + 1)::text
  ),
  'goal_day_in_future',
  'gelecege seri yazilamaz: cihaz saatini ileri almak ise yaramaz'
);

-- 🔴 Otorite: base_seed alpha icin bugun 1 saatlik seans birakiyor, varsayilan
-- hedef 360 dk. Istemci "tamamladim" dese de sunucu HAYIR der.
select is(
  public.record_goal_completion(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date
  ),
  false,
  'hedefe ulasilmadan tamamlama kaydi yazilmaz (sunucu-otoriter)'
);
reset role;
select is(
  (select count(*)::int from public.goal_progress_events
   where scope_type = 'personal' and scope_id = :'alpha'
     and goal_day = (now() at time zone 'Europe/Istanbul')::date),
  0,
  'reddedilen tamamlama hicbir satir birakmaz'
);

-- Hedef gercekten karsilaninca kayit dusuyor: yukaridaki `false` iddiasinin
-- "her zaman false" olmadigini bu gosteriyor.
update public.profiles set daily_goal_minutes = 30 where id = :'alpha';
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);
select is(
  public.record_goal_completion(
    'personal', :'alpha', (now() at time zone 'Europe/Istanbul')::date
  ),
  true,
  'hedef karsilaninca tamamlama kaydi yazilir'
);
reset role;
select is(
  (select count(*)::int from public.goal_progress_events
   where scope_type = 'personal' and scope_id = :'alpha'
     and goal_day = (now() at time zone 'Europe/Istanbul')::date),
  1,
  'tamamlama tek satir birakir'
);

select * from finish();
rollback;
