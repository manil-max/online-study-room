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
-- 🔴 FK ZINCIRLERI TEK BASINA YETMIYOR. Bu dosyanin ilk hali yalniz §1-§4'tu
-- ve CI'da (`database-gates.yml` -> `staging-dry-run`, run 31276032801) HALA
-- KIRMIZI dondu. Ayni ifadeyi dusuren IKI SINIF daha var ve ikisi de FK
-- aksiyonu degil TETIKLEYICI:
--
--   §5 YAZ-GERI (write-back on delete): cascade ile silinen `study_sessions` /
--      `group_members` satirlarinin AFTER DELETE tetikleyicileri metrigi
--      yeniden hesaplayip ARTIK VAR OLMAYAN kullanici icin geri yazmaya
--      calisiyor -> `23503`. CI'nin dusurdugu tam olarak buydu
--      (`achievement_metric_progress_user_id_fkey`).
--
--   §6 DEGISMEZLIK GUARD'I: RI'nin urettigi `set null` UPDATE'ini kosulsuz
--      reddeden append-only/immutability tetikleyicileri. Ikisi bulundu:
--      `moderation_audit_events` (her admin/moderator hesabini silinemez
--      yapiyordu) ve `study_sessions` verified guard'i (konu secmis her
--      dogrulanmis oturumu bozuyordu).
--
-- Uc sinif da ayni ifadede birlikte cozulmezse hesap silme calismaz.
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

-- ===========================================================================
-- 5. YAZ-GERI (write-back on delete) SINIFI
-- ===========================================================================
-- 🔴 CI'da OLCULDU (database-gates.yml -> staging-dry-run, run 31276032801).
-- Yukaridaki bes FK zinciri cozulse bile `delete from auth.users` HALA
-- dusuyordu ve sebebi FK aksiyonu DEGILDI:
--
--   died: 23503: insert or update on table "achievement_metric_progress"
--   violates foreign key constraint "achievement_metric_progress_user_id_fkey"
--   DETAIL: Key (user_id)=(...) is not present in table "users".
--   CONTEXT: SQL statement "insert into public.achievement_metric_progress(...)
--            ... 'secret_break_enemy', ... 'break_all_sessions_v2' ..."
--
-- Mekanizma: `delete from auth.users` once satiri siler, SONRA cascade
-- cocuklarini siler. `study_sessions` cascade ile silinirken uzerindeki
-- AFTER DELETE tetikleyicileri ates eder ve bu tetikleyiciler metrigi YENIDEN
-- HESAPLAYIP `old.user_id` icin geri YAZMAYA calisir. Kullanici satiri artik
-- yok, yani hedef tablonun `user_id -> auth.users` FK'si insert'i reddeder ve
-- TUM ifade geri alinir.
--
-- Bu sinif FK aksiyonu degistirerek cozulemez: hata bir DELETE kontrolu degil,
-- yeni satirin INSERT kontrolu. `cascade` yapmak da ise yaramaz (satir yine
-- yazilmaya calisilir) ve zaten silinmis bir hesaba projeksiyon satiri yazmak
-- retention karari acisindan DAHA KOTU olurdu.
--
-- KURAL (bu migration'in koydugu ilke): **var olmayan bir hesap icin
-- projeksiyon/gecmis yaz-gerisi YAPILMAZ.** Tek bir yuklem (`_account_still_exists`)
-- ve her yaz-geri girisinde tek bir kapi. Boylece davranis RI tetikleyicilerinin
-- ateslenme SIRASINDAN bagimsiz hale gelir -- ki o sira `pg_constraint` OID'lerine
-- baglidir, yani sema evrimiyle sessizce degisir.
--
-- TARANDI: `delete from auth.users` yolunda ates eden TUM tetikleyiciler
-- (`create trigger ... delete ...` = 8 adet) tek tek acildi:
--
--   | tetikleyici                                   | tablo                    | karar |
--   |-----------------------------------------------|--------------------------|-------|
--   | study_sessions_project_break_enemy (0063:214)  | study_sessions           | 🔴 YAZ-GERI -> kapi eklendi (CI kaniti) |
--   | study_sessions_project_group_metrics (0063:504)| study_sessions           | 🔴 YAZ-GERI -> kapi eklendi |
--   | group_members_primary_group_reconcile (0079:161)| group_members           | 🔴 YAZ-GERI -> kapi eklendi |
--   | group_members_multi_group_presence_... (0081:317)| group_members          | 🔴 YAZ-GERI -> kapi eklendi |
--   | user_group_preferences_append_history (0079:87)| user_group_preferences   | 🔴 YAZ-GERI -> kapi eklendi (asagida gerekce) |
--   | study_sessions_mark_achievement_dirty (0050:202)| study_sessions          | ✅ TEMIZ: DELETE dalinda hicbir yazim yok, yalniz `return old` |
--   | groups_cleanup_avatar_object (0049)            | groups                   | ✅ TEMIZ: `0054:21` bu tetikleyiciyi KALDIRDI |
--   | account_purge_audit_no_update_delete (0113:99) | account_purge_audit      | ✅ TEMIZ: tabloda `auth.users` FK'si yok (yalniz `user_hash`), cascade oraya hic ulasmaz |
--
-- `user_group_preferences_append_history` neden listede: kullanici bir grubun
-- SAHIBIYSE `groups.created_by` cascade'i grubu siler, bu da
-- `user_group_preferences.primary_group_id`yi `set null` yapar (`0079:9`), o
-- UPDATE de gecmis tetikleyicisini atesler ve
-- `user_group_preference_history`ye `user_id` ile satir INSERT eder. O sutun
-- `auth.users`'a `not null` FK'dir -- yani ayni 23503. `group_members`
-- tetikleyicisi zaten her uyelik icin bir tercih satiri yaratiyor
-- (`0079:136` reconcile), yani bu yol teorik degil, uye olan HER kullanicida
-- canli.

create or replace function public._account_still_exists(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $wp549$
  -- `auth.users` tam nitelikli: bu fonksiyon `public`ten cagriliyor ve
  -- `search_path`e guvenmek sessizce yanlis cevap uretirdi.
  select p_user_id is not null
     and exists (select 1 from auth.users u where u.id = p_user_id);
$wp549$;

comment on function public._account_still_exists(uuid) is
  'WP-549: yaz-geri kapisi. Silinmis hesap icin projeksiyon/gecmis satiri '
  'yazilmaz; `delete from auth.users` cascade`i sirasinda AFTER DELETE '
  'tetikleyicileri bu yuklemle susar.';

revoke all on function public._account_still_exists(uuid)
  from public, anon, authenticated;

-- --- 5.1 Mola Dusmani projeksiyonu (CI'nin dusurdugu tetikleyici) ----------
-- Govde `0063:205` ile birebir aynidir; TEK fark `old.user_id` dalindaki kapi.
create or replace function public._study_session_project_break_enemy()
returns trigger language plpgsql security definer set search_path = public as $wp549$
begin
  if tg_op <> 'DELETE' then
    perform public.project_break_enemy_metric(new.user_id);
  end if;
  if tg_op = 'DELETE' or (tg_op = 'UPDATE' and old.user_id is distinct from new.user_id) then
    -- 🔴 Hesap silindiyse yeniden hesaplayacak bir sey YOK; yazmaya calismak
    -- 23503 ile tum silmeyi geri alirdi.
    if public._account_still_exists(old.user_id) then
      perform public.project_break_enemy_metric(old.user_id);
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$wp549$;

-- --- 5.2 Grup metrikleri projeksiyonu -------------------------------------
-- Ayni sinif: bu zincir `achievement_metric_progress` ve
-- `group_achievement_daily`ye yazar (`0053:69`, `0062:93`, `0063:588`).
--
-- 🔴 GOVDE KAYNAGI: `0080_session_group_attribution.sql:224`, `0063:478` DEGIL.
-- Ilk yazimda govde `0063`ten kopyalanmisti ve CI bunu yakaladi:
--   011_session_group_attribution.test.sql test 6
--   "secondary daily progression remains zero after the session projector runs"
-- kirmizi dustu. Sebep: `0080` (WP-336) bu fonksiyonu YENIDEN tanimlayip
-- oturum-basina-tek-grup atfina gecirmisti
-- (`refresh_group_metrics_for_session_id`, oturum id'sini de alir). `0063`
-- govdesini geri yazmak o atfi sessizce iptal ediyor ve ilerleme kullanicinin
-- TUM gruplarina yaziliyordu. Yani duzeltme, bir baska sozlesmeyi bozuyordu.
--
-- Ders: `create or replace` ile bir tetikleyici govdesi yeniden yazilirken
-- kaynak, o fonksiyonun EN SON tanimi olmalidir; ilk tanimi degil.
create or replace function public._study_session_project_group_metrics()
returns trigger language plpgsql security definer set search_path = public as $wp549$
begin
  if tg_op <> 'DELETE' then
    perform public.refresh_group_metrics_for_session_id(
      new.id, new.user_id, new.start_time,
      public._equal_source_effective_end(new.start_time, new.end_time, new.duration_seconds)
    );
  end if;
  if tg_op <> 'INSERT' and public._account_still_exists(old.user_id) then
    perform public.refresh_group_metrics_for_session_id(
      old.id, old.user_id, old.start_time,
      public._equal_source_effective_end(old.start_time, old.end_time, old.duration_seconds)
    );
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$wp549$;

-- --- 5.3 Birincil grup mutabakati -----------------------------------------
-- `reconcile_user_primary_group` `user_group_preferences`e `insert ... on
-- conflict` yapar (`0079:136`). Satir cascade ile once silinmisse INSERT
-- daline duser ve `user_id` FK'si patlar. Hangisinin once oldugu
-- `pg_constraint` OID sirasina baglidir; kapi o sirayi ONEMSIZ kilar.
-- Govde `0079:144` ile birebir ayni.
create or replace function public.reconcile_primary_group_on_membership_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $wp549$
begin
  if tg_op = 'DELETE' then
    if public._account_still_exists(old.user_id) then
      perform public.reconcile_user_primary_group(old.user_id);
    end if;
    return old;
  end if;
  perform public.reconcile_user_primary_group(new.user_id);
  return new;
end;
$wp549$;

-- --- 5.4 Coklu grup presence projeksiyonu ---------------------------------
-- Govdeler `0081:284` ve `0081:301` ile birebir ayni.
create or replace function public.sync_multi_group_presence_on_membership_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $wp549$
declare
  v_user_id uuid := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
begin
  if public._account_still_exists(v_user_id) then
    perform public.sync_multi_group_presence_projection(v_user_id);
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$wp549$;

-- Bu tetikleyici `user_group_preferences` UPDATE'inden de ates eder; silinen
-- kullanicinin tercih satiri grup cascade'i yuzunden `set null` olurken tam
-- olarak bu yol acilir.
create or replace function public.sync_multi_group_presence_on_primary_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $wp549$
begin
  if (tg_op = 'INSERT' or new.primary_group_id is distinct from old.primary_group_id)
     and public._account_still_exists(new.user_id) then
    perform public.sync_multi_group_presence_projection(new.user_id);
  end if;
  return new;
end;
$wp549$;

-- --- 5.5 Birincil grup gecmisi --------------------------------------------
-- `user_group_preference_history.user_id` `not null` + `auth.users` cascade
-- (`0079:16`). Grup cascade'i tercihi `set null` yaparken bu tetikleyici
-- silinmis kullanici icin gecmis satiri INSERT etmeye calisirdi.
-- Govde `0079:60` ile birebir ayni.
create or replace function public.primary_group_preference_append_history()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $wp549$
begin
  if (tg_op = 'INSERT' or new.primary_group_id is distinct from old.primary_group_id)
     and public._account_still_exists(new.user_id) then
    insert into public.user_group_preference_history (
      user_id, previous_group_id, primary_group_id, selection_revision, reason
    ) values (
      new.user_id,
      case when tg_op = 'INSERT' then null else old.primary_group_id end,
      new.primary_group_id,
      new.selection_revision,
      coalesce(nullif(current_setting('app.primary_group_change_reason', true), ''), 'membership_reconcile')
    );
  end if;
  return null;
end;
$wp549$;

-- ===========================================================================
-- 6. DEGISMEZLIK GUARD'LARI RI'nin `set null` UPDATE'ini DUSURUYOR
-- ===========================================================================
-- Ayni tuzagin (`0104` kanit guard'i, §3'te cozuldu) iki ORNEGI daha var.
-- Ikisi de `restrict` degil, ikisi de tetikleyici; ikisi de silmeyi durdurur.

-- --- 6.1 moderation_audit_events (SESSIZ HARD BLOKAJ) ---------------------
-- 🔴 `moderation_audit_events.actor_id -> auth.users on delete set null`
-- (`0106:25`) bir UPDATE uretir, ama `moderation_audit_events_immutable`
-- (`0106:56`) `before update or delete` olarak KOSULSUZ
-- `moderation_audit_append_only` (42501) atar. Yani moderasyon denetim
-- olayinda AKTOR olarak gecen her hesap -- her admin/moderator -- silinemez.
--
-- Bunu `040` yakalayamazdi: pgTAP'te `auth.uid()` NULL oldugu icin
-- `moderation_audit_record` satirlari `actor_id = null` yazar ve RI hicbir
-- UPDATE uretmez. Uretim verisinde ise actor DOLUDUR.
--
-- Cozum `0114`un deseni: kanit satiri kalir, ham kimlik kopar, atfedilebilirlik
-- `actor_hash`ta (sha256(uid), `pseudonymous_user_hash` ile AYNI insa) korunur.
-- 🔴 `0114`ten TEK sapma ve gerekcesi: oradaki yedi hash sutunu `not null`
-- yapildi cunku kimlik sutunlari `not null` idi. Burada `actor_id` dogustan
-- NULLABLE'dir (`0106:25`) -- cron/service-role yazimlarinda `auth.uid()` yoktur.
-- O yuzden `actor_hash` da nullable'dir: NULL demek "kimliklendirilmis aktor
-- yoktu" demektir, "kimlik kayboldu" demek degil.
alter table public.moderation_audit_events
  add column if not exists actor_hash text;

-- 🔴 URETIMDE KIRILDI (run 31323239616, ifade 27): bu UPDATE, kendi cozumunu
-- getiren guard'dan (asagida, `_moderation_audit_append_only` yeni hali) ONCE
-- kosuyor. O anda hala `0106:48`in KOSULSUZ hali yuklu ve her UPDATE'i
-- 42501 ile atiyor. Staging'de gecmesinin sebebi kod degil VERI: orada bu
-- kosula uyan hic satir yoktu, UPDATE sifir satira dokundu, tetikleyici hic
-- atesleneMEDI. Uretimde satir var.
--
-- Yeni guard sirayi degistirse bile YETMEZDI: o guard yalniz "actor_id dolu ->
-- NULL, hash AYNI" gecisine izin verir; bu backfill tam tersini yapar
-- (actor_id ayni kalir, hash DEGISIR). Yani dogru cozum siralama degil,
-- degismezligi bu tek ifade suresince ACIKCA askiya almaktir.
--
-- `disable trigger` islem kapsamlidir: rollback'te kendiliginden geri gelir ve
-- tabloyu ACCESS EXCLUSIVE ile kilitler, yani askidayken baska kimse yazamaz.
alter table public.moderation_audit_events
  disable trigger moderation_audit_events_immutable;

update public.moderation_audit_events
set actor_hash = public.pseudonymous_user_hash(actor_id)
where actor_hash is null and actor_id is not null;

alter table public.moderation_audit_events
  enable trigger moderation_audit_events_immutable;

comment on column public.moderation_audit_events.actor_hash is
  'WP-549: aktorun takma kimligi (sha256(uid), 0113/0114 ile ayni insa). '
  'actor_id set null a duserken bu sutun kalir. NULL = kimliklendirilmis '
  'aktor hic yoktu (cron/service-role yazimi).';

-- `0114:133-147` ile AYNI kural: yalniz kimlik doluyken yazar, NULL'a duserken
-- mevcut hash'e DOKUNMAZ. Ad `a_` ile baslar ki degismezlik guard'indan ONCE
-- kossun.
create or replace function public._sync_moderation_audit_actor_hash()
returns trigger
language plpgsql
set search_path = public
as $wp549$
begin
  if new.actor_id is not null then
    new.actor_hash := public.pseudonymous_user_hash(new.actor_id);
  end if;
  return new;
end;
$wp549$;

drop trigger if exists a_moderation_audit_events_actor_hash
  on public.moderation_audit_events;
create trigger a_moderation_audit_events_actor_hash
  before insert or update on public.moderation_audit_events
  for each row execute function public._sync_moderation_audit_actor_hash();

-- Append-only KALIR; yalniz TEK bir gecise izin verilir: `actor_id` dolu ->
-- NULL, baska HICBIR sutun degismemis. DELETE ve TRUNCATE hala kosulsuz atar.
--
-- 🔴 `tg_op` kontrolu ic ice IF ile yapilir, `and` ile DEGIL: bu fonksiyon
-- ayni zamanda `moderation_audit_events_no_truncate` statement tetikleyicisine
-- de bagli ve orada `old`/`new` ATANMAMISTIR. SQL `and`i kisa devre garantisi
-- vermez; tek ifadede yazmak TRUNCATE yolunda "record old is not assigned yet"
-- uretirdi.
create or replace function public._moderation_audit_append_only()
returns trigger language plpgsql as $wp549$
begin
  if tg_op = 'UPDATE' then
    if old.actor_id is not null
       and new.actor_id is null
       and new.actor_hash is not distinct from old.actor_hash
       and to_jsonb(new) - 'actor_id' - 'actor_hash'
           = to_jsonb(old) - 'actor_id' - 'actor_hash' then
      return new;
    end if;
  end if;
  raise exception 'moderation_audit_append_only' using errcode = '42501';
end;
$wp549$;

-- --- 6.2 study_sessions dogrulanmis oturum guard'i ------------------------
-- 🔴 `subjects.user_id -> auth.users` CASCADE (`0001:42`) ve
-- `study_sessions.subject_id -> subjects on delete set null` (`0001:54`).
-- `subjects` tablosu `0001`de `study_sessions`tan ONCE yaratildigi icin
-- cascade tetikleyicisinin OID'i daha kucuktur ve ONCE ates eder: konular
-- silinir, `study_sessions.subject_id` `set null` olur, bu UPDATE de
-- `study_sessions_guard_verified_update`i (`0051:109`) atesler ve
-- `old.live_run_id is not null` olan her satirda `verified_session_immutable`
-- atar. Yani konu secmis + dogrulanmis oturumu olan kullanici silinemez.
--
-- §2'deki A2 karari (`live_run_id` -> cascade) bunu COZMEZ: oradaki sorun
-- kosunun silinmesi, buradaki sorun KONUNUN silinmesi. Ayri yollar.
--
-- Guard'in amaci "dogrulanmis oturumun ICERIGI degismez" olmaya devam eder;
-- izin verilen tek gecis, artik var olmayan bir konuya giden bagin kopmasidir.
create or replace function public._guard_verified_session_update()
returns trigger
language plpgsql
set search_path = public
as $wp549$
begin
  if old.live_run_id is not null
     and current_setting('app.allow_verified_session_write', true) <> 'on' then
    -- Tek istisna: RI `set null` konusu silinen oturumun bagini koparıyor.
    -- Baska her sutun aynı kalmalı; ters yon (NULL -> dolu) yasak.
    if new.subject_id is null
       and old.subject_id is not null
       and to_jsonb(new) - 'subject_id' = to_jsonb(old) - 'subject_id' then
      return new;
    end if;
    raise exception 'verified_session_immutable';
  end if;
  return new;
end;
$wp549$;
