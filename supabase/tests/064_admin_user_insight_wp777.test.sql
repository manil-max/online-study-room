-- 064_admin_user_insight_wp777.test.sql
-- WP-777: `admin_user_insight(uuid)` hedef COZUMLEMESI ve super-admin kapisi.
--
-- Bu dosyanin tek isi, Dart tarafinin OLCEMEDIGI seyi olcmektir. Dart testi
-- yalnizca "sunucu bu anahtari uretiyor mu" sorusunu yanitlar; sayilarin DOGRU
-- olup olmadigini yalniz gercek Postgres soyleyebilir.
--
-- ===========================================================================
-- 🔴 IZOLASYON SOZLESMESI (WP-777/2 — ilk gercek kosu KIRMIZI dondu)
-- ===========================================================================
-- Bu dosyanin ilk surumu `_fixtures/base_seed.psql` uzerinden SABIT kimlikler
-- kullaniyordu: `1000...0001`, `1000...0002`, `2000...0001`. Ayni kimlikler
-- `supabase/seed.sql` icinde ZATEN vardir ve iki fikstur de satirlarini
-- `on conflict (id) do nothing` ile yazar. Tohum once davrandigi icin fikstur
-- satiri HIC uygulanmaz: test kendi kurdugunu sandigi veriyi degil TOHUMU okur.
-- CI (`database-gates.yml` -> `staging-dry-run`, kosu 33974652010) tam bunu
-- gosterdi:
--   * `email`       -> `local-beta@example.invalid` geldi (tohum), fikstur degil,
--   * `group_names` -> `["Local Recovery Group"]` geldi (tohum), fikstur degil.
-- Iki kirmizinin da kok nedeni FONKSIYON DEGIL, testin izole olmamasiydi.
--
-- Bu yuzden burada HICBIR sabit kimlik yoktur: her kimlik `gen_random_uuid()`
-- ile URETILIR ve `\gset` ile psql degiskenine alinir (bu depoda ayni desen
-- `005_push_delivery` ve `013_global_timer_v2` dosyalarinda kullanilir; yeni
-- bir desen icat edilmedi). Fiksturun her satiri bu dosyada eklenir ve
-- `base_seed.psql` HIC okunmaz — ki tohumla carpisma imkansiz olsun.
--
-- 🔴 RAPOR SAYIMLARI MUTLAK DEGIL, FARKLA olculur. Raporlar eklenmeden ONCE
-- fonksiyon bir kez okunur (taban), raporlar eklendikten SONRA tekrar okunur ve
-- alti sayim iddiasi FARKA bakar. Uretilmis kimliklerde taban bugun zaten
-- sifirdir; fark olcumu testin, ileride tohum ya da bir tetikleyici bu
-- kimliklere rapor satiri yazsa bile anlamli kalmasini saglar. Geri kalan
-- iddialar (e-posta, grup adi, toplam sure, seri, is_deleted) mutlaktir cunku
-- o satirlarin TAMAMI bu dosyada uretilmis kimliklere aittir ve baska hicbir
-- yerden yazilamaz.
--
-- ===========================================================================
-- 🔴 DUZELTILEN IKINCI KUSUR: iddia kendi fiksturuyle celisiyordu
-- ===========================================================================
-- CI'daki ucuncu kirmizi ("mesaj raporu raporlayana degil YAZARINA yazilir",
-- have 2 / want 1) tohumdan GELMIYOR — `seed.sql` hic `ugc_reports` satiri
-- yazmaz. Kok neden testin kendi fiksturuydu: iddia `alpha` uzerinden
-- olculuyordu, ama ayni fikstur `beta -> ('user', alpha)` raporunu da
-- yaziyordu. O rapor da alpha'nin HAKKINDA sayilir; dogru cevap 1 degil 2'ydi.
-- Yani fonksiyon dogruydu, iddia yanlisti.
--
-- Yeni kurgu dugumu ayirir ve iddiayi tek yon yerine IKI yonden olcer:
--   * `author` -> hakkindaki TEK rapor kendi mesaji hakkinda acilmistir
--                 (mesaj dali calismazsa 0 duser),
--   * `admin`  -> o raporu ACAN kisidir ve hakkinda HIC rapor yoktur
--                 (cozumleme yanlislikla raporlayana yazarsa 1'e cikar).
--
-- ===========================================================================
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

-- ---------------------------------------------------------------------------
-- 0) Kimlikler URETILIR. Tek bir tahmin edilmis kimlik bile yok.
-- ---------------------------------------------------------------------------
select
  gen_random_uuid()                              as u_admin,
  gen_random_uuid()                              as u_subject,
  gen_random_uuid()                              as u_peer,
  gen_random_uuid()                              as u_author,
  gen_random_uuid()                              as u_gone,
  gen_random_uuid()                              as u_ghost,
  gen_random_uuid()                              as g_active,
  gen_random_uuid()                              as g_left,
  gen_random_uuid()                              as m_subject,
  gen_random_uuid()                              as m_author,
  gen_random_uuid()                              as c_against_resolved,
  gen_random_uuid()                              as c_against_open,
  gen_random_uuid()                              as c_msg_subject,
  gen_random_uuid()                              as c_msg_author,
  gen_random_uuid()                              as c_filed_resolved_1,
  gen_random_uuid()                              as c_filed_resolved_2,
  gen_random_uuid()                              as c_filed_rejected,
  gen_random_uuid()                              as c_filed_open,
  gen_random_uuid()                              as s_first,
  gen_random_uuid()                              as s_second,
  upper(substr(md5(random()::text), 1, 8))       as code_active,
  upper(substr(md5(random()::text), 1, 8))       as code_left,
  'WP777A ' || substr(md5(random()::text), 1, 8) as name_active,
  'WP777L ' || substr(md5(random()::text), 1, 8) as name_left
\gset

-- ---------------------------------------------------------------------------
-- 1) Kullanicilar. `handle_new_user` (0001) tetikleyicisi `profiles` satirini
--    ve `display_name`i bu insert'ten uretir; ayrica profil eklemek gerekmez.
--    `created_at` ACIKCA yazilir: hesap acilis ani iddiasi profil tablosuna
--    dusen yedek yola degil, `auth.users` satirina dayansin.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data, created_at, updated_at)
values
  (:'u_admin',   'wp777-admin-'   || :'u_admin'::text   || '@example.invalid',
   '{"display_name":"WP777 Admin"}'::jsonb,   now() - interval '30 days', now()),
  (:'u_subject', 'wp777-subject-' || :'u_subject'::text || '@example.invalid',
   '{"display_name":"WP777 Subject"}'::jsonb, now() - interval '30 days', now()),
  (:'u_peer',    'wp777-peer-'    || :'u_peer'::text    || '@example.invalid',
   '{"display_name":"WP777 Peer"}'::jsonb,    now() - interval '30 days', now()),
  (:'u_author',  'wp777-author-'  || :'u_author'::text  || '@example.invalid',
   '{"display_name":"WP777 Author"}'::jsonb,  now() - interval '30 days', now()),
  (:'u_gone',    'wp777-gone-'    || :'u_gone'::text    || '@example.invalid',
   '{"display_name":"WP777 Gone"}'::jsonb,    now() - interval '30 days', now());

-- admin yonetici; subject BILEREK degil (kapi iddiasi onun kimligiyle kosar).
insert into public.app_admins (user_id) values (:'u_admin'::uuid);

-- ---------------------------------------------------------------------------
-- 2) Gruplar. Ikinci gruptan subject AYRILDI. `group_names` yalnizca aktif
--    uyeligi gostermeli (`left_at is null`), yoksa moderator kullaniciyi hic
--    olmadigi bir yerde saniyor.
-- ---------------------------------------------------------------------------
insert into public.groups (id, name, invite_code, created_by)
values
  (:'g_active'::uuid, :'name_active', :'code_active', :'u_admin'::uuid),
  (:'g_left'::uuid,   :'name_left',   :'code_left',   :'u_admin'::uuid);

insert into public.group_members (group_id, user_id, role, joined_at)
values
  (:'g_active'::uuid, :'u_admin'::uuid,   'admin',  now() - interval '3 days'),
  (:'g_active'::uuid, :'u_subject'::uuid, 'member', now() - interval '3 days'),
  (:'g_active'::uuid, :'u_author'::uuid,  'member', now() - interval '3 days');

insert into public.group_members (group_id, user_id, role, joined_at, left_at)
values (:'g_left'::uuid, :'u_subject'::uuid, 'member',
        now() - interval '9 days', now() - interval '2 days');

-- Iki mesaj: biri SUBJECT'in, biri AUTHOR'un. Ikisi de raporlanir; her biri
-- yalniz kendi yazarina yazilmalidir.
insert into public.class_messages (id, group_id, user_id, body)
values
  (:'m_subject'::uuid, :'g_active'::uuid, :'u_subject'::uuid, 'WP777 subject mesaji'),
  (:'m_author'::uuid,  :'g_active'::uuid, :'u_author'::uuid,  'WP777 author mesaji');

-- Subject'in toplam suresi tamamen bu dosyada uretilir: 3600 + 1800 = 5400.
-- Toplam 90 dk, gunluk hedefin (360 dk, 0005 varsayilani) ALTINDA kalir; seri
-- iddiasi bu yuzden 0 bekler.
insert into public.study_sessions (
  id, user_id, start_time, end_time, duration_seconds, source
)
values
  (:'s_first'::uuid,  :'u_subject'::uuid,
   now() - interval '5 hours', now() - interval '4 hours', 3600, 'live'),
  (:'s_second'::uuid, :'u_subject'::uuid,
   now() - interval '2 hours', now() - interval '90 minutes', 1800, 'manual');

-- gone silinme kuyrugunda; `is_deleted` turetimi bunu gormeli.
insert into public.account_deletion_requests
  (user_id, status, purge_after, idempotency_key)
values (:'u_gone'::uuid, 'scheduled', now() + interval '30 days',
        'wp777-' || :'u_gone'::text);

-- ---------------------------------------------------------------------------
-- 3) Vakalar. `moderation_cases` uzerindeki tekil indeks yalniz open/in_review
--    vakalari kapsar, bu yuzden ayni hedefte birden cok `resolved`/`rejected`
--    ile TEK bir `open` yasaldir. Vaka tarafinda `user` turu YOKTUR; kullanici
--    hedefi `profile` olarak yazilir (0104:37-42).
--
--    🔴 `u_peer` hedefinde IKI `resolved` var, bir tane degil. Kasitli: subject
--    dort sikayet acar ve bunlarin durum dagilimi resolved/resolved/rejected/
--    open olur. Boylece "hakli cikan = resolved" iddiasi `rejected` tabanli bir
--    uygulamadan AYIRT EDILEBILIR (resolved -> 2, rejected -> 1). Tek resolved
--    olsaydi iki tanim da 1 uretir, iddia olu kalirdi.
-- ---------------------------------------------------------------------------
insert into public.moderation_cases (id, target_type, target_id, status)
values
  (:'c_against_resolved'::uuid, 'profile', :'u_subject', 'resolved'),
  (:'c_against_open'::uuid,     'profile', :'u_subject', 'open'),
  (:'c_msg_subject'::uuid,      'message', :'m_subject', 'resolved'),
  (:'c_msg_author'::uuid,       'message', :'m_author',  'resolved'),
  (:'c_filed_resolved_1'::uuid, 'profile', :'u_peer',    'resolved'),
  (:'c_filed_resolved_2'::uuid, 'profile', :'u_peer',    'resolved'),
  (:'c_filed_rejected'::uuid,   'profile', :'u_peer',    'rejected'),
  (:'c_filed_open'::uuid,       'profile', :'u_peer',    'open');

-- ---------------------------------------------------------------------------
-- 4) TABAN OLCUM: raporlar HENUZ eklenmeden fonksiyon okunur. Iddialar bu
--    tabana gore FARK olcer (yukaridaki izolasyon sozlesmesi).
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', :'u_admin', true);
select
  coalesce((public.admin_user_insight(:'u_subject'::uuid)
    ->> 'reports_against')::int, 0)        as base_subject_against,
  coalesce((public.admin_user_insight(:'u_subject'::uuid)
    ->> 'reports_against_upheld')::int, 0) as base_subject_upheld,
  coalesce((public.admin_user_insight(:'u_subject'::uuid)
    ->> 'reports_filed')::int, 0)          as base_subject_filed,
  coalesce((public.admin_user_insight(:'u_subject'::uuid)
    ->> 'reports_filed_upheld')::int, 0)   as base_subject_filed_upheld,
  coalesce((public.admin_user_insight(:'u_author'::uuid)
    ->> 'reports_against')::int, 0)        as base_author_against,
  coalesce((public.admin_user_insight(:'u_admin'::uuid)
    ->> 'reports_against')::int, 0)        as base_admin_against
\gset
reset role;

-- ---------------------------------------------------------------------------
-- 5) Raporlar. `report_ugc` RPC'si yerine DOGRUDAN insert: bozuk `target_id`
--    ve `group_name` gibi dallari RPC uretemez, oysa tarihsel satirlar
--    tasiyabilir.
-- ---------------------------------------------------------------------------
insert into public.ugc_reports
  (reporter_id, target_type, target_id, reason, status, case_id)
values
  -- SUBJECT HAKKINDA (sayilmasi gerekenler)
  (:'u_admin'::uuid, 'user',    :'u_subject', 'abuse', 'resolved',
   :'c_against_resolved'::uuid),
  (:'u_peer'::uuid,  'profile', :'u_subject', 'spam',  'open',
   :'c_against_open'::uuid),
  (:'u_peer'::uuid,  'message', :'m_subject', 'abuse', 'resolved',
   :'c_msg_subject'::uuid),
  -- SUBJECT HAKKINDA SAYILMAMASI gerekenler
  --   grup hedefi kullaniciya baglanmaz
  (:'u_admin'::uuid, 'group', :'g_active', 'spam', 'resolved', null),
  --   `group_name` hedefi, `target_id` bir KULLANICI kimligine benzese bile
  --   kullaniciya yazilmaz (cozumleme turu de kontrol etmeli, yalniz kimligi
  --   degil)
  (:'u_peer'::uuid, 'group_name', :'u_subject', 'abuse', 'resolved', null),
  --   bozuk `target_id`: ciplak `::uuid` burada butun RPC'yi dusururdu
  (:'u_admin'::uuid, 'user', 'bu-bir-uuid-degil', 'other', 'resolved', null),
  -- AUTHOR HAKKINDA: hakkindaki TEK rapor budur ve raporlayan ADMIN'dir.
  -- Iki iddia birden buna dayanir (yazara yazilir / raporlayana yazilmaz).
  (:'u_admin'::uuid, 'message', :'m_author', 'spam', 'resolved',
   :'c_msg_author'::uuid),
  -- SUBJECT'IN ACTIKLARI — hepsi PEER'i hedefler, boylece "actiklari" sayisi
  -- baska bir iddianin "hakkinda" sayisina karismaz. Durum dagilimi
  -- resolved/resolved/rejected/open: 2 - 1 - 1 (bkz. vaka blogundaki not).
  (:'u_subject'::uuid, 'user',    :'u_peer', 'abuse',  'resolved',
   :'c_filed_resolved_1'::uuid),
  (:'u_subject'::uuid, 'profile', :'u_peer', 'nudity', 'resolved',
   :'c_filed_resolved_2'::uuid),
  (:'u_subject'::uuid, 'user',    :'u_peer', 'spam',   'rejected',
   :'c_filed_rejected'::uuid),
  (:'u_subject'::uuid, 'profile', :'u_peer', 'other',  'open',
   :'c_filed_open'::uuid);

select plan(19);

-- ===========================================================================
-- 1) Kapi: super-admin olmayan bu dosyayi acamaz
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'u_subject', true);
select throws_ok(
  format('select public.admin_user_insight(%L::uuid)', :'u_subject'),
  '42501', 'not_super_admin',
  'super-admin olmayan moderasyon dosyasini acamaz'
);
reset role;

-- ===========================================================================
-- 2) Cozumleme ve sayimlar (admin kimligiyle, TABAN FARKI ile)
-- ===========================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', :'u_admin', true);

-- Bozuk `target_id` tasiyan bir rapor ORTAMDA VARKEN cagriliyor: bu iddia
-- guvenli cevrimin gercekten calistigini gosterir.
select lives_ok(
  format('select public.admin_user_insight(%L::uuid)', :'u_subject'),
  'bozuk target_id tasiyan rapor varken bile fonksiyon patlamaz'
);

select is(
  (public.admin_user_insight(:'u_subject'::uuid) ->> 'reports_against')::int
    - :base_subject_against,
  3,
  'subject hakkinda +3 sikayet: user + profile + kendi mesaji (grup/group_name/bozuk haric)'
);
select is(
  (public.admin_user_insight(:'u_subject'::uuid) ->> 'reports_against_upheld')::int
    - :base_subject_upheld,
  2,
  'hakli cikan yalniz `resolved` vakalar: +2 (acik olan sayilmaz)'
);
select is(
  (public.admin_user_insight(:'u_subject'::uuid) ->> 'reports_filed')::int
    - :base_subject_filed,
  4,
  'subject +4 sikayet acti'
);
-- Dagilim resolved/resolved/rejected/open oldugu icin bu sayi `rejected`
-- tabanli bir uygulamadan (o 1 uretirdi) AYIRT EDILEBILIR.
select is(
  (public.admin_user_insight(:'u_subject'::uuid) ->> 'reports_filed_upheld')::int
    - :base_subject_filed_upheld,
  2,
  'actiklarindan +2 tanesi hakli cikti (`rejected` ve `open` sayilmaz)'
);

-- Mesaj dali gercekten YAZARA baglaniyor mu? Author'un tek "hakkinda" raporu,
-- kendi mesaji hakkinda acilan rapordur. Bu sayi 0 cikarsa mesaj cozumlemesi
-- hic calismiyor demektir.
select is(
  (public.admin_user_insight(:'u_author'::uuid) ->> 'reports_against')::int
    - :base_author_against,
  1,
  'mesaj raporu YAZARINA yazilir'
);
-- Ayni raporun OBUR ucu: raporu acan admin'dir ve hakkinda hic rapor yoktur.
-- Cozumleme yanlislikla raporlayana yazsaydi bu sayi 1 olurdu.
select is(
  (public.admin_user_insight(:'u_admin'::uuid) ->> 'reports_against')::int
    - :base_admin_against,
  0,
  'mesaj raporu RAPORLAYANA yazilmaz'
);

-- ===========================================================================
-- 3) Hesap ve kullanim baglami
-- ===========================================================================
select is(
  public.admin_user_insight(:'u_subject'::uuid) ->> 'email',
  'wp777-subject-' || :'u_subject'::text || '@example.invalid',
  'e-posta auth.users tarafindan doldurulur (fikstur kendi satirini yazdi)'
);
select ok(
  (public.admin_user_insight(:'u_subject'::uuid) ->> 'display_name') is not null,
  'display_name profiles tarafindan doldurulur'
);
select ok(
  (public.admin_user_insight(:'u_subject'::uuid) ->> 'account_created_at') is not null,
  'hesap acilis ani bos degil'
);
select is(
  (public.admin_user_insight(:'u_subject'::uuid) ->> 'total_study_seconds')::bigint,
  5400::bigint,
  'toplam sure tum oturumlarin toplamidir (3600 + 1800)'
);
select is(
  public.admin_user_insight(:'u_subject'::uuid) -> 'group_names',
  jsonb_build_array(:'name_active'::text),
  'yalniz AKTIF uyelikler listelenir; ayrilinan grup gorunmez'
);
-- Seri, urunun TEK tanimindan (`_current_fire_streak_days`, 0136) gelir; burada
-- ikinci bir tanim yazilmadi. Sifir beklenir cunku gunluk hedef 360 dk
-- (`profiles.daily_goal_minutes` varsayilani, 0005) ve subject toplam 90 dk
-- calisti — yani hic tamamlanan gun yok, tetikleyici hic olay yazmadi.
select is(
  (public.admin_user_insight(:'u_subject'::uuid) ->> 'current_streak_days')::int,
  0,
  'seri urunun tek tanimindan gelir; hic hedef tamamlamayan kullanicida 0'
);
select is(
  (public.admin_user_insight(:'u_subject'::uuid) ->> 'is_deleted')::boolean,
  false,
  'yasayan hesap silinmis gorunmez'
);

-- ===========================================================================
-- 4) `is_deleted` turetimi (depoda boyle bir kolon yok)
-- ===========================================================================
select is(
  (public.admin_user_insight(:'u_gone'::uuid) ->> 'is_deleted')::boolean,
  true,
  'aktif silme talebi olan hesap silinmis sayilir'
);
select is(
  (public.admin_user_insight(:'u_ghost'::uuid) ->> 'is_deleted')::boolean,
  true,
  'auth.users satiri hic olmayan kimlik (purge bitmis) silinmis sayilir'
);
select is(
  (public.admin_user_insight(:'u_ghost'::uuid) ->> 'reports_against')::int,
  0,
  'bilinmeyen kimlik hata degil sifir doner (ekran bos acilabilmeli)'
);

-- ===========================================================================
-- 5) Tel sozlesmesi: Dart `AdminUserInsight.fromWire` tam bu anahtarlari okur
-- ===========================================================================
select is(
  (select array_agg(k order by k)
     from jsonb_object_keys(public.admin_user_insight(:'u_subject'::uuid)) as k),
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
