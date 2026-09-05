-- 0137_admin_user_insight.sql
-- WP-777: `admin_user_insight(uuid)` — bir kullanicinin moderasyon dosyasi.
--
-- Isleyis: Moderasyon ekrani bir kullaniciyi acinca dort sayiyi AYNI ANDA
-- gosterir (hakkinda kac sikayet / kaci hakli cikti, kendisi kac sikayet acti /
-- kaci hakli cikti) ve yanina hesap + kullanim baglamini koyar. Parca parca
-- cagirmak yarim dolu bir panel uretirdi; bu yuzden tek RPC, tek jsonb nesnesi.
--
-- Neden ham sayi yetmiyor: "7 kez sikayet edildi" tek basina hicbir sey
-- soylemez. Anlami veren, kacinin HAKLI ciktigidir:
--   * 12 sikayet alip hicbiri tutmayan biri buyuk olasilikla hedef aliniyordur
--     — ceza degil koruma gerekir.
--   * 3 sikayet alip ucu de tutan biri gercek sorundur.
--   * Cok sikayet edip hicbiri tutmayan biri mekanizmayi kotuye kullaniyordur.
-- Bu yuzden her yon IKI sayi tasir: toplam + hakli cikan. Oranlari istemci
-- hesaplar (`AdminUserInsight.upheldAgainstRatio`), cunku "hic sikayet yok"
-- (`null`) ile "bes sikayet, hicbiri tutmadi" (`0.0`) AYRI teshislerdir ve
-- sunucuda tek bir orana ezilirlerdi.
--
-- 🔴 "Hakli cikan" = `resolved`, "reddedilen" DEGIL. `0105`teki
-- `admin_reporter_abuse_score` `rejected` sayar; bizim sozlesmemiz `resolved`
-- sayar. Ikisi ayni sey degildir: `open`/`in_review` vakalar henuz ne haklidir
-- ne haksiz, yani ucu birbirinin tumleyeni degildir. `admin_reporter_abuse_score`
-- yerinde birakildi (Dart'tan bugune kadar hic cagrilmadi); bu fonksiyon onu
-- degistirmez, yanina gecer.
--
-- 🔴 ZOR KISIM — "bu kullanici hakkinda kac sikayet var" sorusu bir COZUMLEME
-- gerektirir: `ugc_reports` tablosunda `target_user_id` YOKTUR. Yalnizca
-- `target_type` + `target_id text` vardir. Cozumleme kurali:
--   * `target_type in ('user','profile')` -> `target_id` ZATEN kullanici
--     kimligidir (0104:77 ayni esitlemeyi yapar: `user` -> vaka tarafinda
--     `profile`),
--   * `target_type = 'message'`           -> `target_id` bir mesaj kimligidir;
--     yazari `class_messages.user_id` uzerinden bulunur,
--   * `target_type in ('group','group_name')` -> kullaniciya baglanmaz, sayima
--     GIRMEZ. (Tur listesi 0104:21'de bese cikti; `group_name` de buraya
--     duser.) Eslesme hem TURE hem kimlige bakar: bir `group_name` raporunun
--     `target_id`si bir kullanici kimligine benzese bile o kullaniciya
--     yazilmaz.
--
-- 🔴 Guvenli cevrim: `target_id` `text` oldugu icin bozuk/serbest metin
-- tasiyabilir. Ciplak `::uuid` TEK bozuk satirda butun fonksiyonu dusururdu ve
-- moderasyon ekrani, en cok ihtiyac duyuldugu anda bos kalirdi. `case`
-- degerlendirme sirasini garanti ettigi icin desene uymayan metin hic cevrilmez;
-- NULL kalir ve hicbir esitligi tutturmaz.
--
-- DOGRULANAN kolonlar (tahmin edilmedi, dosyadan okundu):
--   * `ugc_reports.reporter_id|target_type|target_id|status` — 0038_ugc_moderation.sql:40-46
--   * `ugc_reports.case_id`                                  — 0104_moderation_report_target_contract.sql:53
--   * `moderation_cases.id|status`                           — 0104_moderation_report_target_contract.sql:37-42
--   * `class_messages.id|user_id`                            — 0015_class_chat.sql:6-8
--     (yazar kolonunun adi `user_id`'dir, `author_id` DEGIL)
--   * `profiles.id|display_name|created_at`                  — 0001_initial_schema.sql:16-19
--   * `groups.name`, `group_members.user_id`                 — 0001_initial_schema.sql:25,32-37
--   * `group_members.left_at`                                — 0008_membership_lifecycle.sql:22
--   * `study_sessions.user_id|duration_seconds`              — 0001_initial_schema.sql:51,56
--     (`group_id` 0010_drop_session_group_id.sql ile KALDIRILDI; join edilmez)
--   * `presence.user_id|updated_at`                          — 0001_initial_schema.sql:66-73
--   * `account_deletion_requests.user_id|status`             — 0037_account_deletion_core.sql:13-20
--   * `_current_fire_streak_days(uuid, date)`                — 0136_fire_streak_equals_paused_streak.sql:48
--   * `auth.users.email`                                     — 0105_moderation_enforcement_ladder.sql:287
--   * `auth.users.last_sign_in_at`                           — supabase/functions/admin-user-actions/index.ts:225
--
-- UYDURULMAYAN alanlar (sozlesme doldurulmasini istedi, dogrudan kaynak YOK):
--   * `is_deleted` — BOYLE BIR KOLON DEPODA HIC YOK (`profiles` dahil, tum
--     migration'larda arandi). Turetildi: `auth.users` satiri artik yoksa
--     (purge bitmis) ya da aktif bir silme talebi varsa `true`. Yeni kolon
--     eklenmedi; turetim tek yerde, burada.
--   * `current_streak_days` — profilde saklanan boyle bir kolon YOK; seri
--     hesaplanan bir degerdir. Urunun tek seri tanimi olan
--     `_current_fire_streak_days` (0136) cagrilir; ikinci bir tanim yazilmadi.
--   * `last_seen_at` — tek bir "son gorulme" kolonu YOK. `presence.updated_at`
--     ile `auth.users.last_sign_in_at` icinden gec olani alinir; `greatest`
--     Postgres'te NULL'lari yok saydigi icin ikisinden biri eksikken de dogru
--     calisir.
--
-- BILINEN SINIR: bir mesaj silinmisse (kullanici purge'unde `class_messages`
-- cascade ile gider) o mesaj hakkindaki rapor artik bir yazara baglanamaz ve
-- `reports_against` icinde gorunmez. Rapor satiri durur, kanit govdesi ayrica
-- `canonical_snapshot`ta saklidir. Bu bilincli bir sinirdir, sessiz hata degil.
--
-- Geri alma (Rollback): `drop function if exists public.admin_user_insight(uuid);`
-- Fonksiyon salt-okunurdur (`stable`; hicbir yere yazmaz), bu yuzden geri alma
-- veri kaybi uretmez — yalnizca ekran moderasyon dosyasini gosteremez olur.

create or replace function public.admin_user_insight(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $wp777$
declare
  v_against        bigint  := 0;
  v_against_upheld bigint  := 0;
  v_filed          bigint  := 0;
  v_filed_upheld   bigint  := 0;
  v_display_name   text;
  v_email          text;
  v_created_at     timestamptz;
  v_last_seen_at   timestamptz;
  v_study_seconds  bigint  := 0;
  v_streak_days    integer := 0;
  v_group_names    text[]  := '{}'::text[];
  v_is_deleted     boolean := false;
begin
  -- Tek yetkilendirme katmani sunucudur; istemci kontrolu kozmetiktir. Bu
  -- fonksiyon bir kullanicinin e-postasini ve tum sikayet gecmisini acar.
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;

  -- -------------------------------------------------------------------------
  -- 1) Iki yonun sayimi tek taramada
  -- -------------------------------------------------------------------------
  with resolved as (
    select
      r.reporter_id,
      r.target_type,
      -- Guvenli cevrim (yukaridaki nota bakiniz).
      case
        when r.target_id ~*
          '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then r.target_id::uuid
      end as target_uuid,
      -- Vaka varsa gercek odur; `case_id` tasimayan tarihsel satirlarda raporun
      -- kendi durumu kullanilir. Ikisi zaten senkron tutuluyor: vaka kapaninca
      -- 0104:259 ve 0105:524 raporun `status` kolonunu da yazar.
      coalesce(c.status, r.status) as effective_status
    from public.ugc_reports r
    left join public.moderation_cases c on c.id = r.case_id
  ), flagged as (
    select
      x.effective_status,
      (x.reporter_id = p_user_id) as is_filed,
      (
        (x.target_type in ('user', 'profile') and x.target_uuid = p_user_id)
        or (
          x.target_type = 'message'
          and exists (
            select 1
              from public.class_messages m
             where m.id = x.target_uuid
               and m.user_id = p_user_id
          )
        )
      ) as is_against
    from resolved x
  )
  select
    count(*) filter (where f.is_against),
    count(*) filter (where f.is_against and f.effective_status = 'resolved'),
    count(*) filter (where f.is_filed),
    count(*) filter (where f.is_filed and f.effective_status = 'resolved')
    into v_against, v_against_upheld, v_filed, v_filed_upheld
    from flagged f;

  -- -------------------------------------------------------------------------
  -- 2) Hesap bilgisi
  -- -------------------------------------------------------------------------
  -- 🔴 Her `select ... into` AYRI tutuldu: plpgsql'de satir bulamayan bir
  -- `into` hedeflerin HEPSINI NULL'a ceker. Tek sorguda birlestirmek, profili
  -- silinmis bir kullanicida hesap tarihini de silerdi.
  select u.email, u.created_at, u.last_sign_in_at
    into v_email, v_created_at, v_last_seen_at
    from auth.users u
   where u.id = p_user_id;

  select p.display_name
    into v_display_name
    from public.profiles p
   where p.id = p_user_id;

  -- `auth.users` satiri gitmisse profil tarihine dus. Bu dal yalnizca deger
  -- zaten bosken calistigi icin dolu bir tarihi ezmez.
  if v_created_at is null then
    select p.created_at
      into v_created_at
      from public.profiles p
     where p.id = p_user_id;
  end if;

  -- Skaler alt sorgu satir yoksa NULL doner; `greatest` NULL'lari yok sayar.
  v_last_seen_at := greatest(
    v_last_seen_at,
    (select pr.updated_at from public.presence pr where pr.user_id = p_user_id)
  );

  v_is_deleted :=
    not exists (select 1 from auth.users u where u.id = p_user_id)
    or exists (
      select 1
        from public.account_deletion_requests d
       where d.user_id = p_user_id
         and d.status in ('requested', 'scheduled', 'processing', 'failed')
    );

  -- -------------------------------------------------------------------------
  -- 3) Kullanim baglami: gercekten calisan biri mi?
  -- -------------------------------------------------------------------------
  -- Kumeleme fonksiyonlari hic satir olmasa da tek satir dondurdugu icin
  -- asagidaki iki `into` bos kullanicida da guvenlidir.
  select coalesce(sum(s.duration_seconds), 0)
    into v_study_seconds
    from public.study_sessions s
   where s.user_id = p_user_id;

  v_streak_days := coalesce(public._current_fire_streak_days(p_user_id), 0);

  select coalesce(array_agg(g.name order by g.name), '{}'::text[])
    into v_group_names
    from public.group_members gm
    join public.groups g on g.id = gm.group_id
   where gm.user_id = p_user_id
     and gm.left_at is null;

  -- 🔴 Anahtarlar `AdminUserInsight.fromWire` ile BIREBIR ayni olmak
  -- zorundadir; eslesmeyen bir anahtar ekranda sessizce sifir gosterir.
  return jsonb_build_object(
    'user_id',                p_user_id,
    'reports_against',        v_against,
    'reports_against_upheld', v_against_upheld,
    'reports_filed',          v_filed,
    'reports_filed_upheld',   v_filed_upheld,
    'display_name',           v_display_name,
    'email',                  v_email,
    'account_created_at',     v_created_at,
    'last_seen_at',           v_last_seen_at,
    'total_study_seconds',    v_study_seconds,
    'current_streak_days',    v_streak_days,
    'group_names',            to_jsonb(v_group_names),
    'is_deleted',             v_is_deleted
  );
end;
$wp777$;

revoke all on function public.admin_user_insight(uuid) from public, anon;
grant execute on function public.admin_user_insight(uuid) to authenticated;

comment on function public.admin_user_insight(uuid) is
  'WP-777: super-admin moderation dossier; resolves ugc_reports in both '
  'directions (reported/reporting), upheld = case status resolved.';
