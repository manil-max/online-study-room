-- 049_account_purge_storage_scope.test.sql
-- WP-545: hesap silme purge zincirinin STORAGE kapsam sozlesmesi.
--
-- Olculdu (bagimsiz denetim, 2026-08-08): `purge-accounts` dort storage
-- bucket'indan yalnizca birini (`avatars`) temizliyordu. Kullanicinin
-- yukledigi geri bildirim ve sikayet fotograflari hesap silindikten sonra
-- HAM UID'li klasorlerinde duruyordu, oysa magazada gosterilen silme sayfasi
-- yalniz "avatar dosyalari" diyordu. Silinen gruplarin avatar nesneleri de
-- sahipsiz kaliyordu: `0049` bunu bir tetikleyiciyle temizliyordu ama `0054`
-- o tetikleyiciyi KALDIRDI ve yerine soz verilen "periyodik storage-audit"
-- hicbir zaman yazilmadi.
--
-- Bu dosya iki soruyu sabitler:
--
--   A. KAC bucket var? (§1) Envanter dondurulur. Yeni bir bucket eklendiginde
--      bu iddia KIRMIZI duser ve dosyayi guncelleyen kisi o bucket'i purge
--      kapsamina sokmak zorunda kalir. Sessizce eklenen bucket = sessizce
--      silinmeyen veri; tam da bu turda olan buydu.
--
--   B. Her bucket'in yol ANAHTARI ne? (§2-§3) Purge `list(<klasor>)` ile
--      calisir. Klasor anahtari uid ise kullanici dongusunden, `groups.id`
--      ise grup dongusunden temizlenir. Anahtar degisirse silme sessizce
--      SIFIR nesne bulur -- hata bile vermez. Burada davranissal olarak
--      olculur: hangi bucket uid klasoru kabul ediyor, hangisi etmiyor.
--
-- 🔴 OLCEMEDIGI SEY (durust sinir): pgTAP veritabaninin ICINDE kosar,
-- `supabase/functions/purge-accounts/index.ts` dosyasini OKUYAMAZ. Yani bu
-- dosya "Edge function su bucket'i gercekten siliyor" iddiasini kanitlamaz;
-- "su bucket'lar var ve anahtarlari sunlar" iddiasini kanitlar. Edge tarafi
-- `USER_OWNED_STORAGE_BUCKETS` listesinde tek yerde durur ve o listenin
-- yorumu bu dosyaya isaret eder. Iki ucu tek testte baglayan bir kapi
-- (migration + TypeScript'i birlikte tarayan statik denetim) BU TURDA
-- YAZILMADI; SAHIP yollari `scripts/` altini kapsamiyordu.
--
-- ---------------------------------------------------------------------------
-- WP-778/2 (2026-09-05) — kapi ATESLENDI
-- ---------------------------------------------------------------------------
-- §1 kirmizi dustu: `0138` besinci bucket'i (`ticket_message_attachments`)
-- acti. Kapi tam olarak isini yapti — bucket, icindeki fotograflarin hesap
-- silindiginde ne olacagina dair karar verilmeden gecemedi.
--
-- Karar `0138` KARAR 4'te yazili: bucket KALIR ve purge'un KULLANICI
-- dongusune girer (elenen yol, eki `feedback_attachments`e tasimakti; o
-- bucket'in ne boyut/MIME siniri var ne de karsi tarafa okuma izni, yani
-- PRODUCTION'da duran bir bucket'in iki sozlesmesini birden degistirirdi).
--
-- Envanter 5'e cikarilirken iddia ZAYIFLATILMADI: hala esitliktir ve yanina
-- §2b eklendi — yeni bucket'in purge yolunun gercekten VAR OLDUGUNU olcen
-- uc iddia. "Sayiyi buyutup gecmek" artik yetmez; alti bucket'a cikaran
-- kisi ayni sekilde o bucket'in klasor anahtarini da olcmek zorunda.
--
-- 🔴 §2b'nin OLCMEDIGI sey (yukaridaki durust sinirin aynisi): "bucket adi
-- `USER_OWNED_STORAGE_BUCKETS` icinde YAZILI" iddiasi. O tek satir
-- `purge-accounts/index.ts:129-133`te durur ve pgTAP onu goremez. §2b bunun
-- yerine listeye girme OLCUTUNU olcer (`index.ts:96-98`): klasor anahtari
-- ham `auth.uid()` mi? Olcut saglanmazsa satiri yazmak zaten fayda etmez,
-- cunku `list(uid)` sessizce sifir nesne dondururdu.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
\ir _fixtures/base_seed.psql

-- base_seed: alpha grubun kurucusu (created_by), beta uye.
\set alpha '10000000-0000-0000-0000-000000000001'
\set beta  '10000000-0000-0000-0000-000000000002'
\set grp   '20000000-0000-0000-0000-000000000001'

select plan(15);

-- ===========================================================================
-- 1. ENVANTER DONDURULUR
-- ===========================================================================
-- Bu iddia bilerek "esitlik"tir, "icerir" degil. Yeni bir bucket eklemek
-- testi kirmizi dusurur; kirmiziyi gormeden kimse bucket ekleyemez ve
-- eklerken purge kapsamina karar vermek zorunda kalir.
--
-- Bes eleman, dortten "buyutuldugu" icin degil, besincisinin purge yolu
-- §2b'de olculdugu icin buradadir. Listeyi uzatan herkesin borcu ayni:
-- yeni satirin yanina o bucket'in klasor anahtarini olcen bir iddia.
select is(
  (select array_agg(id order by id) from storage.buckets),
  array[
    'avatars',
    'feedback_attachments',
    'group-avatars',
    'report_attachments',
    'ticket_message_attachments'  -- `0138` / WP-778, karar: KARAR 4
  ],
  'storage bucket envanteri tam olarak bu bes tanedir (yeni bucket = kirmizi = purge karari)'
);

-- ===========================================================================
-- 2. KULLANICI UZAYI: klasor anahtari ham auth.uid()
-- ===========================================================================
-- Bu ucu purge kullanici dongusunde `list(uid)` ile temizler.
-- (`USER_OWNED_STORAGE_BUCKETS`)
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true
);

select lives_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('avatars', '10000000-0000-0000-0000-000000000001/avatar.jpg')$$,
  'avatars: klasor anahtari kullanicinin kendi uid`i'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('avatars', '10000000-0000-0000-0000-000000000002/foreign.jpg')$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'avatars: baska uid klasorune yazilamaz (uzay gercekten uid ile bolunmus)'
);

select lives_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('feedback_attachments', '10000000-0000-0000-0000-000000000001/ek.png')$$,
  'feedback_attachments: klasor anahtari kullanicinin kendi uid`i -> purge kapsaminda'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('feedback_attachments', '10000000-0000-0000-0000-000000000002/foreign.png')$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'feedback_attachments: baska uid klasorune yazilamaz'
);

select lives_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('report_attachments', '10000000-0000-0000-0000-000000000001/sikayet.png')$$,
  'report_attachments: klasor anahtari kullanicinin kendi uid`i -> purge kapsaminda'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values ('report_attachments', '10000000-0000-0000-0000-000000000002/foreign.png')$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'report_attachments: baska uid klasorune yazilamaz'
);

-- ===========================================================================
-- 2b. `ticket_message_attachments` (`0138` / WP-778) — PURGE YOLU
-- ===========================================================================
-- 🔴 §1'in besinci bucket'i buraya, ucuncu bir kullanici-uzayi bucket'i
-- olarak yaziliyor. Purge `list(<klasor>)` ile calisir
-- (`purge-accounts/index.ts:147-175`); klasor anahtari ham uid degilse silme
-- SIFIR nesne bulur ve hata bile vermez. Yani "purge yolu var" iddiasinin
-- DB tarafindaki tam karsiligi sudur: uzay uid ile bolunmus mu?
--
-- Anahtar iki BAGIMSIZ kapida zorlanir; ikisi de ayri ayri olculur:
--   1-2. storage yukleme politikasi `ticket_message_attachments_insert_own`
--        (`0138`: `(storage.foldername(name))[1] = auth.uid()::text`)
--   3.   RPC kapisi `assert_ticket_message_attachment_allowed`
--        (`0138`: `(string_to_array(v_path,'/'))[1] is distinct from`
--        `auth.uid()::text` -> `attachment_not_owned`)
-- Birini kaldiran kisi kirmiziyi gorur.
select lives_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'ticket_message_attachments',
      '10000000-0000-0000-0000-000000000001/mesaj.png'
    )$$,
  'ticket_message_attachments: klasor anahtari kullanicinin kendi uid`i -> purge kapsaminda'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'ticket_message_attachments',
      '10000000-0000-0000-0000-000000000002/foreign.png'
    )$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'ticket_message_attachments: baska uid klasorune yazilamaz (uzay gercekten uid ile bolunmus)'
);

-- Ikinci kapi. Storage politikasi bir gun gevsetilse bile mesaja YAZILAN
-- yol hala yukleyenin kendi klasorunde olmak zorunda; yani
-- `feedback_ticket_messages.attachment_path` degerleri daima uid anahtarli
-- kalir ve kullanici dongusundeki `list(uid)` onlari bulur.
select throws_ok(
  format(
    $$select public.assert_ticket_message_attachment_allowed(%L)$$,
    :'beta' || '/baskasinin.png'
  ),
  'P0001',
  'attachment_not_owned',
  'sunucu kapisi baska uid klasorundeki yolu reddeder -> kayitli yol daima uid anahtarli'
);

-- ===========================================================================
-- 3. GRUP UZAYI: klasor anahtari groups.id, uid DEGIL
-- ===========================================================================
-- 🔴 Kapsam kararinin dayanagi burasi. `group-avatars` kullanici dongusune
-- EKLENEMEZ: `list(uid)` orada hicbir zaman bir sey bulmaz, hata da vermez --
-- yani eklemek sahte guven uretirdi. Nesne grup id'siyle, grup silinirken
-- dusurulur.
select throws_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'group-avatars',
      '10000000-0000-0000-0000-000000000001/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa.png'
    )$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'group-avatars: kendi uid klasoru bile REDDEDILIR -> bucket kullanici uzayi degil'
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name)
    values (
      'group-avatars',
      '20000000-0000-0000-0000-000000000001/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb.png'
    )$$,
  'group-avatars: klasor anahtari groups.id (yalniz grup yoneticisi yazar)'
);

reset role;

-- ===========================================================================
-- 4. VERITABANI GRUP AVATARINI GERI KAZANMAZ
-- ===========================================================================
-- `0049` bunu `groups_cleanup_avatar_object` tetikleyicisiyle yapiyordu;
-- `0054` onu kaldirdi cunku Storage `storage.objects`ten dogrudan silmeyi
-- yasakladi. Yerine soz verilen "periyodik storage-audit" repoda YOK.
-- Sonuc: nesneyi dusuren tek yer purge Edge function'idir.
--
-- Bu iddia bilerek "tetikleyici YOK" der. Biri onu geri eklerse test kirmizi
-- duser ve iki temizlik yolu ayni anda yasamadan once karar verilir.
select ok(
  not exists (
    select 1
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    where c.relname = 'groups'
      and t.tgname = 'groups_cleanup_avatar_object'
  ),
  'DB tarafinda grup avatari temizleyen tetikleyici YOK (0054) -> temizlik purge`un isi'
);

update public.groups
set avatar_path =
      '20000000-0000-0000-0000-000000000001/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb.png',
    avatar_updated_at = now()
where id = '20000000-0000-0000-0000-000000000001';

-- Purge`un DEVIR dali: sahip silinince grup en eski aktif uyeye gecer ve
-- yasamaya devam eder. Avatar nesnesi grubun malidir; bu dalda SILINMEZ.
update public.groups
set created_by = '10000000-0000-0000-0000-000000000002'
where id = '20000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from storage.objects
   where bucket_id = 'group-avatars'
     and name =
       '20000000-0000-0000-0000-000000000001/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb.png'),
  1,
  'grup devredildiginde avatar nesnesi KALIR (baskalarinin verisi silinmez)'
);

-- Purge`un SILME dali: aktif uye kalmadiysa grup silinir. Grup satiri gider
-- ama nesne DB tarafindan dusurulmez -- Edge function onu grup id'siyle
-- ayrica silmek zorundadir.
delete from public.groups
where id = '20000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from storage.objects
   where bucket_id = 'group-avatars'
     and name =
       '20000000-0000-0000-0000-000000000001/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb.png'),
  1,
  'grup satiri silinince nesne KENDILIGINDEN gitmez -> purge`un grup id`li temizligi sart'
);

select * from finish();
rollback;
