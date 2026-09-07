-- 066_dead_rpc_grants_wp807.test.sql
-- WP-807: cagirani olmayan RPC'lerin kullaniciya acik yuzeyi daraltildi.
--
-- 🔴 Olculen sey IKI YONLU olmali. Yalniz "grant kalkti" olculseydi, gunun
-- birinde biri govdeyi de silse test yine yesil gecerdi ve `0120`nin geri
-- alma yolu sessizce kaybolurdu. O yuzden her fonksiyon icin hem yuzeyin
-- kapandigi hem GOVDENIN DURDUGU iddia ediliyor.

begin;
select plan(11);

-- ===========================================================================
-- 1. Yuzey kapandi: `authenticated` artik cagiramaz
-- ===========================================================================

select ok(
  not has_function_privilege(
    'authenticated', 'public.my_achievement_xp_reconciliation()', 'execute'
  ),
  'XP uzlastirma `authenticated`a KAPALI (cagiran ekran hic yazilmadi)'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.achievement_legacy_audit(uuid)', 'execute'
  ),
  'eski basarim denetimi `authenticated`a KAPALI (operasyon araci)'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.record_goal_completion(text, uuid, date)', 'execute'
  ),
  'hedef tamamlama RPC''si `authenticated`a KAPALI (yazici artik tetikleyici)'
);

-- ===========================================================================
-- 2. Govdeler DURUYOR — grant kaldirmak silmek degildir
-- ===========================================================================

select ok(
  to_regprocedure('public.my_achievement_xp_reconciliation()') is not null,
  'XP uzlastirma govdesi duruyor'
);
select ok(
  to_regprocedure('public.achievement_legacy_audit(uuid)') is not null,
  'eski basarim denetimi govdesi duruyor'
);
select ok(
  to_regprocedure('public.record_goal_completion(text, uuid, date)') is not null,
  '🔴 hedef tamamlama govdesi duruyor — 0120''nin geri alma yolu ona dayanir'
);

-- ===========================================================================
-- 3. Uretim yolu ETKILENMEDI
--
-- Hedef tamamlamayi artik tetikleyici yazar; genel RPC kapanirken o yol
-- bozulmus olamaz.
-- ===========================================================================

select ok(
  to_regprocedure('public._record_goal_completion(text, uuid, date)') is not null,
  'uretim yazicisi _record_goal_completion(text, uuid, date) yerinde'
);

-- ===========================================================================
-- 4. DOKUNULMAYANLAR gercekten dokunulmamis
--
-- Bu iddialar "temizlik istahi" icin bir fren: bir sonraki tur bunlari da
-- kaldirmak isterse KIRMIZI doner ve gerekceyi okumak zorunda kalir.
-- ===========================================================================

select ok(
  has_function_privilege(
    'authenticated', 'public.admin_reporter_abuse_score(uuid)', 'execute'
  ),
  '🔴 admin_reporter_abuse_score grant''i KORUNDU — olu degil, ekrani yok '
  '(0137:21-23 ayri sozlesme oldugunu yaziyor)'
);
select ok(
  has_function_privilege(
    'authenticated', 'public.create_group(text)', 'execute'
  ),
  '🔴 create_group(text) grant''i KORUNDU — 0032/0071 eski istemciler icin '
  'bilerek biraktı; kaldirmak URUN karari, temizlik karari degil'
);
select ok(
  has_function_privilege(
    'authenticated', 'public.create_group_with_access(text, text, integer)',
    'execute'
  ),
  'guncel grup kurulum yolu (create_group_with_access) acik'
);

-- Bu turda kaldirilan grant'lar `service_role`den kaldirilmadi: operasyon
-- yolu acik kalmali.
select ok(
  has_function_privilege(
    'service_role', 'public.achievement_legacy_audit(uuid)', 'execute'
  ),
  'operasyon yolu (service_role) acik kaldi'
);

select * from finish();
rollback;
