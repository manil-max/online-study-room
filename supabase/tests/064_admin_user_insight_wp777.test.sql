-- 064_admin_user_insight_wp777.test.sql
-- WP-777: `admin_user_insight(uuid)` hedef COZUMLEMESI ve super-admin kapisi.
--
-- Bu dosyanin tek isi, Dart tarafinin OLCEMEDIGI seyi olcmektir. Dart testi
-- yalnizca "sunucu bu anahtari uretiyor mu" sorusunu yanitlar; sayilarin DOGRU
-- olup olmadigini yalniz gercek Postgres soyleyebilir.
--
-- 🔴 Olculen zor kisim: `ugc_reports` tablosunda `target_user_id` YOKTUR.
-- "Bu kullanici hakkinda kac sikayet var" sorusu `target_type` + `target_id`
-- uzerinden cozumlenir. Bu dosya cozumlemenin dort dalini da ayri ayri
-- tuzaklar:
--   * `user` / `profile` -> hedef zaten kullanici kimligi (SAYILIR),
--   * `message`          -> `class_messages.user_id` ile yazara baglanir
--                           (yalniz YAZARINA sayilir, raporlayana degil),
--   * `group`/`group_name` -> kullaniciya baglanmaz (SAYILMAZ) — hatta
--     `target_id` bir kullanici kimligine BENZESE bile sayilmaz,
--   * bozuk `target_id`  -> fonksiyon patlamaz, o rapor sayim disi kalir.
--
-- Ayrica "hakli cikan" tanimi olculur: yalniz `resolved` sayilir. `open` ve
-- `rejected` sayilmaz — bunlari karistirmak `0105`teki `rejected` tabanli
-- `admin_reporter_abuse_score` ile bu sozlesmeyi ayni sanmaktan gelir.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set gamma '10000000-0000-0000-0000-000000000003'
\set grp   '20000000-0000-0000-0000-000000000001'
\set grp2  '20000000-0000-0000-0000-000000000002'
\set msgb  '40000000-0000-0000-0000-000000000077'
\set msga  '40000000-0000-0000-0000-000000000078'
\set ghost '19999999-9999-9999-9999-999999999999'

insert into auth.users (id, email, raw_user_meta_data)
values (:'gamma', 'wp777-gamma@example.invalid', '{"display_name":"WP777 Gamma"}'::jsonb)
on conflict (id) do nothing;

-- alpha yonetici; beta BILEREK degil (kapi iddiasi onun kimligiyle kosar).
insert into public.app_admins (user_id)
values (:'alpha'::uuid)
on conflict (user_id) do nothing;

-- Ikinci grup: beta buradan AYRILDI. `group_names` yalnizca aktif uyeligi
-- gostermeli (`left_at is null`), yoksa moderator kullaniciyi hic olmadigi bir
-- yerde saniyor.
insert into public.groups (id, name, invite_code, created_by)
values (:'grp2'::uuid, 'Ayrilan Grup', 'WP777GRP', :'alpha'::uuid)
on conflict (id) do nothing;
insert into public.group_members (group_id, user_id, role, joined_at, left_at)
values (:'grp2'::uuid, :'beta'::uuid, 'member', now() - interval '9 days',
        now() - interval '2 days')
on conflict (group_id, user_id) do nothing;
insert into public.group_members (group_id, user_id, role, joined_at)
values (:'grp'::uuid, :'gamma'::uuid, 'member', now() - interval '1 day')
on conflict (group_id, user_id) do nothing;

-- Iki mesaj: biri BETA'nin, biri ALPHA'nin. Ikisi de raporlanir; yalniz
-- birincisi beta'ya yazilmalidir.
insert into public.class_messages (id, group_id, user_id, body)
values
  (:'msgb'::uuid, :'grp'::uuid, :'beta'::uuid,  'Beta''nin mesaji'),
  (:'msga'::uuid, :'grp'::uuid, :'alpha'::uuid, 'Alpha''nin mesaji')
on conflict (id) do nothing;

-- Beta'nin toplam suresi: base_seed 3600 sn verdi, buraya 1800 eklendi.
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
values (
  '30000000-0000-0000-0000-000000000077'::uuid, :'beta'::uuid,
  now() - interval '2 hours', now() - interval '90 minutes', 1800, 'live'
)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Vakalar. `moderation_cases` uzerindeki tekil indeks yalniz open/in_review
-- vakalari kapsar, bu yuzden ayni hedefte bir `resolved` + bir `open` yasaldir.
-- ---------------------------------------------------------------------------
insert into public.moderation_cases (id, target_type, target_id, status)
values
  ('50000000-0000-0000-0000-000000000001'::uuid, 'profile', :'beta',  'resolved'),
  ('50000000-0000-0000-0000-000000000002'::uuid, 'profile', :'beta',  'open'),
  ('50000000-0000-0000-0000-000000000003'::uuid, 'message', :'msgb',  'resolved'),
  ('50000000-0000-0000-0000-000000000004'::uuid, 'message', :'msga',  'resolved'),
  ('50000000-0000-0000-0000-000000000007'::uuid, 'profile', :'alpha', 'resolved'),
  ('50000000-0000-0000-0000-000000000008'::uuid, 'profile', :'gamma', 'rejected'),
  ('50000000-0000-0000-0000-000000000009'::uuid, 'profile', :'gamma', 'open')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Raporlar. `report_ugc` RPC'si yerine DOGRUDAN insert: bozuk `target_id` ve
-- `group_name` gibi dallari RPC uretemez, oysa tarihsel satirlar tasiyabilir.
-- ---------------------------------------------------------------------------
insert into public.ugc_reports
  (reporter_id, target_type, target_id, reason, status, case_id)
values
  -- BETA HAKKINDA (sayilmasi gerekenler)
  (:'alpha'::uuid, 'user',    :'beta', 'abuse', 'resolved',
   '50000000-0000-0000-0000-000000000001'::uuid),
  (:'gamma'::uuid, 'profile', :'beta', 'spam',  'open',
   '50000000-0000-0000-0000-000000000002'::uuid),
  (:'gamma'::uuid, 'message', :'msgb', 'abuse', 'resolved',
   '50000000-0000-0000-0000-000000000003'::uuid),
  -- BETA HAKKINDA SAYILMAMASI gerekenler
  --   grup hedefi kullaniciya baglanmaz
  (:'alpha'::uuid, 'group', :'grp', 'spam', 'resolved', null),
  --   `group_name` hedefi, `target_id` bir KULLANICI kimligine benzese bile
  --   kullaniciya yazilmaz (cozumleme turu de kontrol etmeli, yalniz kimligi
  --   degil)
  (:'gamma'::uuid, 'group_name', :'beta', 'abuse', 'resolved', null),
  --   bozuk `target_id`: ciplak `::uuid` burada butun RPC'yi dusururdu
  (:'alpha'::uuid, 'user', 'bu-bir-uuid-degil', 'other', 'resolved', null),
  --   alpha'nin mesaji hakkindaki rapor beta'ya degil ALPHA'ya yazilir
  (:'gamma'::uuid, 'message', :'msga', 'spam', 'resolved',
   '50000000-0000-0000-0000-000000000004'::uuid),
  -- BETA'NIN ACTIKLARI
  (:'beta'::uuid, 'user',    :'alpha', 'abuse', 'resolved',
   '50000000-0000-0000-0000-000000000007'::uuid),
  (:'beta'::uuid, 'user',    :'gamma', 'spam',  'rejected',
   '50000000-0000-0000-0000-000000000008'::uuid),
  (:'beta'::uuid, 'profile', :'gamma', 'other', 'open',
   '50000000-0000-0000-0000-000000000009'::uuid);

-- gamma silinme kuyrugunda; `is_deleted` turetimi bunu gormeli.
insert into public.account_deletion_requests
  (user_id, status, purge_after, idempotency_key)
values (:'gamma'::uuid, 'scheduled', now() + interval '30 days', 'wp777-gamma')
on conflict (idempotency_key) do nothing;

select plan(18);

-- ===========================================================================
-- 1) Kapi: super-admin olmayan bu dosyayi acamaz
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'beta', true);
select throws_ok(
  format('select public.admin_user_insight(%L::uuid)', :'beta'),
  '42501', 'not_super_admin',
  'super-admin olmayan moderasyon dosyasini acamaz'
);
reset role;

-- ===========================================================================
-- 2) Cozumleme ve sayimlar (admin kimligiyle)
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'alpha', true);

-- Bozuk `target_id` tasiyan bir rapor ORTAMDA VARKEN cagriliyor: bu iddia
-- guvenli cevrimin gercekten calistigini gosterir.
select lives_ok(
  format('select public.admin_user_insight(%L::uuid)', :'beta'),
  'bozuk target_id tasiyan rapor varken bile fonksiyon patlamaz'
);

select is(
  (public.admin_user_insight(:'beta'::uuid) ->> 'reports_against')::int,
  3,
  'beta hakkinda 3 sikayet: user + profile + kendi mesaji (grup/group_name/bozuk haric)'
);
select is(
  (public.admin_user_insight(:'beta'::uuid) ->> 'reports_against_upheld')::int,
  2,
  'hakli cikan yalniz `resolved` vakalar: 2 (acik olan sayilmaz)'
);
select is(
  (public.admin_user_insight(:'beta'::uuid) ->> 'reports_filed')::int,
  3,
  'beta 3 sikayet acti'
);
select is(
  (public.admin_user_insight(:'beta'::uuid) ->> 'reports_filed_upheld')::int,
  1,
  'actiklarindan yalniz 1 tanesi hakli cikti (`rejected` ve `open` sayilmaz)'
);

-- Mesaj dali gercekten YAZARA baglaniyor mu? Alpha'nin tek "hakkinda" raporu,
-- kendi mesaji hakkinda acilan rapordur. Bu sayi 0 cikarsa mesaj cozumlemesi
-- hic calismiyor; 2 cikarsa beta'nin mesaji da alpha'ya yazilmis demektir.
select is(
  (public.admin_user_insight(:'alpha'::uuid) ->> 'reports_against')::int,
  1,
  'mesaj raporu raporlayana degil YAZARINA yazilir'
);

-- ===========================================================================
-- 3) Hesap ve kullanim baglami
-- ===========================================================================
select is(
  public.admin_user_insight(:'beta'::uuid) ->> 'email',
  'fixture-beta@example.invalid',
  'e-posta auth.users tarafindan doldurulur'
);
select ok(
  (public.admin_user_insight(:'beta'::uuid) ->> 'display_name') is not null,
  'display_name profiles tarafindan doldurulur'
);
select ok(
  (public.admin_user_insight(:'beta'::uuid) ->> 'account_created_at') is not null,
  'hesap acilis ani bos degil'
);
select is(
  (public.admin_user_insight(:'beta'::uuid) ->> 'total_study_seconds')::bigint,
  5400::bigint,
  'toplam sure tum oturumlarin toplamidir (3600 + 1800)'
);
select is(
  public.admin_user_insight(:'beta'::uuid) -> 'group_names',
  '["Recovery Fixture Group"]'::jsonb,
  'yalniz AKTIF uyelikler listelenir; ayrilinan grup gorunmez'
);
-- Seri, urunun TEK tanimindan (`_current_fire_streak_days`, 0136) gelir; burada
-- ikinci bir tanim yazilmadi. Sifir beklenir cunku gunluk hedef 360 dk
-- (`profiles.daily_goal_minutes` varsayilani, 0005) ve beta toplam 90 dk
-- calisti — yani hic tamamlanan gun yok, tetikleyici hic olay yazmadi.
select is(
  (public.admin_user_insight(:'beta'::uuid) ->> 'current_streak_days')::int,
  0,
  'seri urunun tek tanimindan gelir; hic hedef tamamlamayan kullanicida 0'
);
select is(
  (public.admin_user_insight(:'beta'::uuid) ->> 'is_deleted')::boolean,
  false,
  'yasayan hesap silinmis gorunmez'
);

-- ===========================================================================
-- 4) `is_deleted` turetimi (depoda boyle bir kolon yok)
-- ===========================================================================
select is(
  (public.admin_user_insight(:'gamma'::uuid) ->> 'is_deleted')::boolean,
  true,
  'aktif silme talebi olan hesap silinmis sayilir'
);
select is(
  (public.admin_user_insight(:'ghost'::uuid) ->> 'is_deleted')::boolean,
  true,
  'auth.users satiri hic olmayan kimlik (purge bitmis) silinmis sayilir'
);
select is(
  (public.admin_user_insight(:'ghost'::uuid) ->> 'reports_against')::int,
  0,
  'bilinmeyen kimlik hata degil sifir doner (ekran bos acilabilmeli)'
);

-- ===========================================================================
-- 5) Tel sozlesmesi: Dart `AdminUserInsight.fromWire` tam bu anahtarlari okur
-- ===========================================================================
select is(
  (select array_agg(k order by k)
     from jsonb_object_keys(public.admin_user_insight(:'beta'::uuid)) as k),
  array[
    'account_created_at', 'current_streak_days', 'display_name', 'email',
    'group_names', 'is_deleted', 'last_seen_at', 'reports_against',
    'reports_against_upheld', 'reports_filed', 'reports_filed_upheld',
    'total_study_seconds', 'user_id'
  ]::text[],
  'anahtar kumesi AdminUserInsight.fromWire ile birebir ayni'
);

reset role;

select * from finish();
rollback;
