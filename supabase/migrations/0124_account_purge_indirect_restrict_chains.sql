-- 0124_account_purge_indirect_restrict_chains.sql
-- WP-549: hesap silmeyi bloklayan DOLAYLI `restrict` FK zincirlerini cozer.
--
-- 🔴 Sorun sinifi (`0114`un BAKMADIGI sinif). `0114` yalniz `public` semasindan
-- `auth.users`'a DOGRUDAN giden yedi `restrict` FK'yi cozdu. Ama
-- `auth.admin.deleteUser`'in calistirdigi tek `delete from auth.users` once
-- CASCADE cocuklarini siler; o cascade silmeleri de kendi `restrict`
-- cocuklarini atesler. `restrict` ertelenemez ve ayni ifade icinde daha sonra
-- silinecek satirlari BEKLEMEZ (`no action`tan farki tam olarak budur), yani
-- zincir FK ihlaliyle duser, is 5 denemeyi yakar ve hesap terminal `failed`
-- olur -- yani HIC silinmez.
--
-- `docs/legal/ACCOUNT-DELETION.en.md` kosulsuz "kalici olarak silinir" diyor ve
-- `docs/play-store/DATA-SAFETY.md` Play formuna "Users can request that data be
-- deleted -> Yes" yazdiriyor. Asagidaki zincirler acikken o beyan fiilen
-- yanlisti. Play'de hesap silme zorunludur.
--
-- Kodda dogrulanan DORT zincir (dosya:satir ile):
--
--   A1. `live_study_runs.user_id -> auth.users` CASCADE (`0051:8`)
--       -> `live_study_segments.run_id -> live_study_runs` RESTRICT (`0051:36`)
--       Blast radius: sayaci bir kez calistirmis HER kullanici.
--       `live_study_segments` hicbir yerde silinmiyor (`0051` yalniz insert +
--       `ended_at` update yapar), yani satir her zaman orada duruyor.
--
--   A2. Ayni cascade -> `study_sessions.live_run_id -> live_study_runs`
--       RESTRICT (`0051:63`). Blast radius: dogrulanmis (verified) tek bir
--       oturum finalize etmis HER kullanici.
--
--   A3. `push_devices.user_id -> auth.users` CASCADE (`0066:7`)
--       -> `global_timer_commands.device_id -> push_devices` RESTRICT
--       (`0082:95`). Blast radius: push kaydi olan HER kullanici.
--
--   B.  `groups.created_by -> auth.users` CASCADE (`0001:27`)
--       -> `ugc_reports.context_group_id -> groups` RESTRICT (`0104:12`).
--       Iki ayri yerden vurur: (a) `deleteUser` grup sahibini silerken,
--       (b) `purge-accounts/index.ts` uyesiz grubu `must(...)` ile silerken.
--       Raporu yazan kullanici silinen kullanicidan FARKLI olabilir, yani
--       `ugc_reports` satiri hicbir cascade ile gitmez; o grupta bir kez rapor
--       acilmissa grup ASLA silinemez.
--
--   C.  🔴 BU TURDA BULUNDU, gorev metninde YOKTU:
--       `moderation_sanctions.target_user_id -> auth.users` CASCADE (`0105:86`)
--       -> `moderation_appeals.sanction_id -> moderation_sanctions` RESTRICT
--       (`0106:146`). Blast radius: hakkinda yaptirim uygulanmis ve o yaptirima
--       itiraz edilmis HER kullanici.
--
-- Ayrica olculdu: kalan iki `restrict` FK (`ugc_reports.case_id` ve
-- `moderation_sanctions.case_id`, ikisi de `-> moderation_cases`) blokaj
-- DEGILDIR: `moderation_cases` tablosunun `auth.users`'a hicbir FK'si yoktur,
-- yani hicbir cascade oraya ulasmaz. Bilerek dokunulmadi; `050` bu envanteri
-- dondurur ki yeni bir `restrict` sessizce eklenemesin.
--
-- ---------------------------------------------------------------------------
-- KARAR: `0114`un ILKESI aynen uygulanir, yeni ilke icat EDILMEZ.
-- ---------------------------------------------------------------------------
-- `0114` + retention karari §5.6 kapsam notu su ikili ayrimi koyar:
--   * kullanicinin KENDI icerigi -> `cascade` (silinir),
--   * BASKASININ kaydindaki aktor/kanit izi -> satir kalir, ham kimlik kopar.
--
-- Bu turda her tablo o olcute vuruldu:
--
--   A1 `live_study_segments` -> CASCADE. Bu tablo kullanicinin KENDI calisma
--      verisidir (durakla/devam et araliklari); zaten `user_id -> auth.users`
--      CASCADE'dir, yani semanin kendisi "bu silinir" diyor. `run_id`
--      uzerindeki `restrict` bir saklama karari degil, kosunun butunlugunu
--      koruyan bir guard'di; kosu gidince segment de gitmelidir. Moderasyon
--      ya da denetim delili DEGILDIR.
--
--   A2 `study_sessions.live_run_id` -> CASCADE. Oturum kullanicinin kendi
--      calisma kaydidir ve `user_id -> auth.users` zaten CASCADE.
--      🔴 `set null` BURADA CALISMAZ: `0051:109`daki
--      `study_sessions_guard_verified_update` BEFORE UPDATE tetikleyicisi
--      `old.live_run_id is not null` iken `verified_session_immutable` atar.
--      RI'nin `set null` aksiyonu bir UPDATE'tir, yani o tetikleyiciyi
--      atesler ve silmeyi YINE dusururdu. Olculdu, varsayilmadi.
--
--   A3 `global_timer_commands` -> CASCADE. Cihaz-bazli sayac komut kaydi:
--      `request_fingerprint`, `payload`, `result_snapshot`. Kullanicinin kendi
--      cihaz telemetrisi, moderasyon delili degil; `user_id -> auth.users`
--      zaten CASCADE. Cihaz gidince komut gecmisi de gider.
--
--   C  `moderation_appeals.sanction_id` -> CASCADE. Yaptirim satirinin kendisi
--      `target_user_id -> auth.users` CASCADE'dir; bu `0105`in kararidir ve
--      `0114` ona DOKUNMADI (`0114` yalniz `actor_id`yi, yani BASKASININ
--      kaydindaki aktor izini takma-adlastirdi). Yaptirim hedefiyle birlikte
--      gidiyorsa, o yaptirima yazilan itiraz da gitmelidir; itiraz zaten
--      `appellant_id -> auth.users` CASCADE'dir. Denetim izi KAYBOLMAZ:
--      `moderation_audit_events` yaptirim/itiraz olaylarini `entity_id uuid`
--      olarak FK'siz tutar (`0106:22`) ve `actor_id`si `set null`'dur, yani
--      "bu yaptirim verildi / buna itiraz edildi" izi PII'siz yerinde kalir.
--
--   B  `ugc_reports.context_group_id` -> SET NULL + DEGISMEZ SNAPSHOT.
--      Bu tek istisna, cunku `ugc_reports` BASKA bir kullanicinin yazdigi
--      MODERASYON DELILIDIR; grup silindi diye kaybolmamalidir. `0114`un
--      deseni birebir: kanit satiri kalir, ham bag kopar, atfedilebilirlik
--      ayri bir degismez sutunda korunur.
--      Takma kimlik (hash) yerine ham UUID snapshot'i tutuluyor, cunku burada
--      gizlenmesi gereken sey silinen kullanicinin kimligi DEGIL, artik var
--      olmayan bir grubun id'sidir. `0051:23-24` ayni gerekceyi zaten yaziyor:
--      "A group UUID is an immutable audit/metric snapshot. Deliberately no FK:
--      deleting a group must not erase or cascade the context captured at run
--      start." Yani bu da yeni ilke degil, repodaki mevcut ilkedir.
--
--      🔴 Iki gizli tuzak burada olculdu; ikisi de bu migration'da cozuldu:
--      1. `ugc_reports_context_group_only_for_message` CHECK'i (`0104:24`)
--         `target_type = 'message'` satirlarinda `context_group_id`in dolu
--         olmasini sart kosuyor. Duz `set null` bu CHECK'i ihlal ederdi.
--         -> CHECK degismez snapshot sutununa tasindi; satir kumesi
--            semantigi AYNI kalir.
--      2. `_prevent_ugc_report_evidence_mutation` (`0104:113`, son hali
--         `0106:341`) `new.context_group_id is distinct from
--         old.context_group_id` gorunce `ugc_report_evidence_immutable`
--         (42501) atiyor. RI'nin `set null` UPDATE'i bu tetikleyiciyi atesler
--         ve silmeyi YINE dusururdu.
--         -> Tetikleyiciye TEK bir gecise izin verildi: dolu -> NULL (grup
--            silindi). Baska her degisiklik hala atar, snapshot sutunu ise
--            tamamen degismezdir.
--
-- Geri alma (Rollback): uygulanmis migration geri YAZILMAZ. Bu migration veri
-- kaybettirmez (yalniz FK aksiyonlarini gevsetir ve bir snapshot sutunu ekler).
-- Geri almak gerekirse FK'leri `restrict`e cevirmek yerine ileri bir migration
-- yazin; `restrict`e donmek hesap silmeyi tekrar kirar.
--
-- Sozlesme: `supabase/tests/050_account_purge_indirect_restrict_chains.test.sql`.

-- ---------------------------------------------------------------------------
-- 1. FK aksiyon degistirici
-- ---------------------------------------------------------------------------
-- `0114`teki desen: kisitlamayi ADIYLA DEGIL YAPISIYLA bul. Isimler uretilmis
-- olabilir ve `0082:49` `live_study_runs` uzerinde zaten isimsiz drop/add
-- yapmis durumda, yani ada guvenmek sessizce yanlis yapardi.
create or replace function public._wp549_reset_fk_action(
  p_table text,
  p_column text,
  p_ref_table text,
  p_action text
)
returns void
language plpgsql
as $wp549$
declare
  v_attnum smallint;
  v_fk text;
  v_current char;
begin
  if to_regclass('public.' || quote_ident(p_table)) is null then
    raise exception 'wp549_missing_table_%', p_table;
  end if;

  select a.attnum into v_attnum
  from pg_attribute a
  where a.attrelid = ('public.' || quote_ident(p_table))::regclass
    and a.attname = p_column
    and not a.attisdropped;
  if v_attnum is null then
    raise exception 'wp549_missing_column_%_%', p_table, p_column;
  end if;

  select con.conname, con.confdeltype into v_fk, v_current
  from pg_constraint con
  where con.conrelid = ('public.' || quote_ident(p_table))::regclass
    and con.contype = 'f'
    and con.confrelid = p_ref_table::regclass
    and con.conkey = array[v_attnum];
  if v_fk is null then
    raise exception 'wp549_fk_not_found_%_%', p_table, p_column;
  end if;

  -- Idempotent: zaten dogru aksiyondaysa dokunma.
  if v_current = p_action then
    return;
  end if;

  execute format('alter table public.%I drop constraint %I', p_table, v_fk);
  execute format(
    'alter table public.%I add constraint %I foreign key (%I) '
    'references %s(id) on delete %s',
    p_table, v_fk, p_column, p_ref_table,
    case p_action
      when 'c' then 'cascade'
      when 'n' then 'set null'
      else 'restrict'
    end
  );
end;
$wp549$;

-- ---------------------------------------------------------------------------
-- 2. A1 / A2 / A3 / C -> cascade
-- ---------------------------------------------------------------------------
-- 🔴 A2'nin FK'si `0051:63`te `not valid` eklenmisti. Burada VALIDATED olarak
-- yeniden kurulur: kisitlama `0051`den beri her yazimda zaten uygulaniyordu,
-- yani tam tarama ihlal bulmamali. Bulursa apply sirasinda patlamasi DOGRUDUR:
-- oksuz bir `live_run_id` sessizce tasinmamalidir.
select public._wp549_reset_fk_action(
  'live_study_segments', 'run_id', 'public.live_study_runs', 'c');
select public._wp549_reset_fk_action(
  'study_sessions', 'live_run_id', 'public.live_study_runs', 'c');
select public._wp549_reset_fk_action(
  'global_timer_commands', 'device_id', 'public.push_devices', 'c');
select public._wp549_reset_fk_action(
  'moderation_appeals', 'sanction_id', 'public.moderation_sanctions', 'c');

-- ---------------------------------------------------------------------------
-- 3. B: degismez grup snapshot'i
-- ---------------------------------------------------------------------------
alter table public.ugc_reports
  add column if not exists context_group_id_snapshot uuid;

update public.ugc_reports
set context_group_id_snapshot = context_group_id
where context_group_id_snapshot is null and context_group_id is not null;

comment on column public.ugc_reports.context_group_id_snapshot is
  'WP-549: raporun acildigi grubun DEGISMEZ audit snapshot i. FK YOKTUR '
  '(0051:23-24 ile ayni gerekce): grup silinince kanitin baglami silinmemeli. '
  'context_group_id FK si set null a duser, bu sutun kalir.';

-- Snapshot'i canli tutan tetikleyici. `0114:133-147` ile AYNI kural: yalniz
-- kimlik doluyken yazar; `set null` satiri NULL'a duserken snapshot'i EZMEZ.
-- Ad `a_` ile baslar cunku BEFORE tetikleyiciler ad sirasiyla atesler ve bu
-- snapshot, kanit-degismezlik guard'indan ONCE dolmus olmalidir (`0080:86`
-- ayni `a_` hilesini kullaniyor).
create or replace function public._sync_ugc_report_context_group_snapshot()
returns trigger
language plpgsql
set search_path = public
as $wp549$
begin
  if new.context_group_id is not null then
    new.context_group_id_snapshot := new.context_group_id;
  end if;
  return new;
end;
$wp549$;

drop trigger if exists a_ugc_reports_context_group_snapshot on public.ugc_reports;
create trigger a_ugc_reports_context_group_snapshot
  before insert or update on public.ugc_reports
  for each row execute function public._sync_ugc_report_context_group_snapshot();

-- CHECK'i degismez sutuna tasi. Satir kumesi semantigi `0104:24` ile AYNIDIR;
-- tek fark, artik grup silinse bile dogru kalmasidir.
alter table public.ugc_reports
  drop constraint if exists ugc_reports_context_group_only_for_message;
alter table public.ugc_reports
  add constraint ugc_reports_context_group_only_for_message
  check (
    -- Baglam sutunu yalniz mesaj raporlarinda dolabilir (`0104` ile ayni).
    (context_group_id is null or target_type = 'message')
    and (
      (target_type = 'message' and context_group_id_snapshot is not null)
      or (target_type <> 'message' and context_group_id_snapshot is null)
      -- `0104` oncesi mesaj satirlari baglam sutununu hic tasimiyordu.
      or (target_type = 'message' and canonical_snapshot is null)
    )
  ) not valid;
alter table public.ugc_reports
  validate constraint ugc_reports_context_group_only_for_message;

-- Kanit degismezlik guard'i: TEK bir gecise izin ver (dolu -> NULL, yani grup
-- silindi) ve snapshot'i tamamen dondur. Govdenin geri kalani `0106:341`deki
-- son hali ile birebir aynidir; redaksiyon ve vaka-tasima istisnalari korunur.
create or replace function public._prevent_ugc_report_evidence_mutation()
returns trigger language plpgsql security definer set search_path = public as $wp549$
declare
  v_redacting boolean := old.evidence_retention_until <= now()
    and new.canonical_snapshot is null
    and new.content_snapshot is null
    and new.client_hint is null
    and new.evidence_redacted_at is not null;
  -- 🔴 Tek izinli gecis: `on delete set null` grubun silindigini bildiriyor.
  -- Ters yon (NULL -> dolu) ve baska bir gruba kaydirma HALA yasak.
  v_group_deleted boolean :=
    old.context_group_id is not null and new.context_group_id is null;
begin
  if new.reporter_id is distinct from old.reporter_id
    or new.target_type is distinct from old.target_type
    or new.target_id is distinct from old.target_id
    or new.context_group_id_snapshot is distinct from old.context_group_id_snapshot
    or new.evidence_hash is distinct from old.evidence_hash
    or (new.context_group_id is distinct from old.context_group_id
        and not v_group_deleted) then
    raise exception 'ugc_report_evidence_immutable' using errcode = '42501';
  end if;
  if not v_redacting and (
      new.client_hint is distinct from old.client_hint
      or new.content_snapshot is distinct from old.content_snapshot
      or new.canonical_snapshot is distinct from old.canonical_snapshot
      or new.evidence_retention_until is distinct from old.evidence_retention_until
    ) then
    -- Saklama suresinin uzatilmasi yalniz itiraz akisindaki RPC'den gelir;
    -- oradaki update bu tetikleyiciyi es gecmedigi icin istisnasi burada.
    if new.evidence_retention_until > old.evidence_retention_until
      and new.client_hint is not distinct from old.client_hint
      and new.content_snapshot is not distinct from old.content_snapshot
      and new.canonical_snapshot is not distinct from old.canonical_snapshot then
      null;
    else
      raise exception 'ugc_report_evidence_immutable' using errcode = '42501';
    end if;
  end if;
  if new.case_id is distinct from old.case_id
    and (old.case_id is null
      or exists (
        select 1 from public.moderation_cases c
        where c.id = old.case_id and c.status in ('open', 'in_review')
      )) then
    raise exception 'ugc_report_evidence_immutable' using errcode = '42501';
  end if;
  return new;
end;
$wp549$;

select public._wp549_reset_fk_action(
  'ugc_reports', 'context_group_id', 'public.groups', 'n');

-- ---------------------------------------------------------------------------
-- 4. Yardimci fonksiyonu birak
-- ---------------------------------------------------------------------------
-- Tek seferlik migration araci. Semada kalmasi, baska bir turda FK aksiyonunu
-- sessizce degistirmenin kolay yolunu birakirdi.
drop function if exists public._wp549_reset_fk_action(text, text, text, text);
