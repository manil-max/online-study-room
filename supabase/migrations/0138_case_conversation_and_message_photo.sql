-- 0138_case_conversation_and_message_photo.sql
-- WP-778: vakada IKI TARAFLA ayri yazisma + mesaj basina tek fotograf.
--
-- Sahip: *"yanit ve geri bildirim kismi yenilensin. iki taraflara ayri chat
-- sohbeti olsun, direkt gecmis konusmalarida gorebileyim ben sormak istersem
-- diye. ek olarak bu sohbet ve sikayetlerde foto yuklenebilsin 1 tane."*
--
-- Bugune kadar yalniz **sikayet EDENle** kanal vardi: `report_ugc` her sikayet
-- icin bir `feedback_tickets` satiri aciyor (0090 sozlesmesi), vaka sayfasi onu
-- "ayna bilet" olarak buluyordu. Sikayet EDILENe yonetici hicbir sey
-- yazamiyordu; tek yol tek yonlu duyuruydu.
--
-- ---------------------------------------------------------------------------
-- KARAR 1 — neden YENI TABLO YOK
-- ---------------------------------------------------------------------------
-- Yazisma altyapisi (mesaj tablosu, sira/`message_seq`, idempotent istemci
-- komut kimligi, okundu imleci, realtime yayini `0117`, iki yonlu push) zaten
-- `feedback_tickets` + `feedback_ticket_messages` uzerinde kurulu. Ikinci bir
-- konusma tablosu bunlarin hepsini bastan yazmak demekti. Bu yuzden sikayet
-- edilenle kanal da **ayni mekanizmada ikinci bir destek kaydidir**; yalnizca
-- hangi vakaya ve hangi tarafa ait oldugunu soyleyen iki kolon eklenir.
--
-- ---------------------------------------------------------------------------
-- KARAR 2 — neden `ugc_report_id` yeniden kullanilmadi
-- ---------------------------------------------------------------------------
-- `feedback_tickets_ugc_report_id_unique` (0090) rapor basina TEK bilete
-- izin verir ve `report_ugc` (0104) tam olarak o indeksi arbiter alarak
-- `on conflict (ugc_report_id) where ugc_report_id is not null` yazar. Indeksi
-- genisletmek/parcalamak o cikarimi (inference) bozar ve `report_ugc`'yi
-- calisma aninda dusururdu. Bu yuzden ikinci kanal ayri bir kolonla
-- (`case_report_id` + `case_party`) baglanir; `report_ugc` HIC ELLENMEZ.
--
-- Bedeli: sikayet edilen kanalinin `ugc_report_id`'si NULL kalir ve kuyruk
-- (`admin_queue_entry.dart:128`) `ugcReportId == null` biletleri bagimsiz
-- destek kaydi sayip listeler. Bu yuzden `admin_feedback_tickets` ileri
-- tasinip `case_party = 'reported'` satirlarini eler: bu kanal bir gelen kutusu
-- ogesi degil, vaka sayfasindan acilan bir konusmadir. Kullanicinin yaniti
-- kaybolmaz — `0117` push tetikleyicisi yoneticilere bildirimi yine gonderir.
--
-- ---------------------------------------------------------------------------
-- KARAR 3 — foto icin neden AYRI bucket
-- ---------------------------------------------------------------------------
-- Boyut/MIME/yol sahipligi kapisi `0096_report_attachments.sql` desenidir ve
-- birebir taklit edilir (private bucket + 5 MB + jpeg/png/webp + sunucu tarafi
-- ikinci kapi). Ama `report_attachments` bucket'inin okuma politikasi bilerek
-- YALNIZ super-admin'dir ("ek moderasyon delilidir, paylasim yuzeyi degildir").
-- Yazisma fotografi iki yonludur: yoneticinin gonderdigi fotografi karsi taraf
-- da gorebilmelidir. Delil bucket'ina ikinci bir okuma politikasi eklemek
-- `0096`'nin kuralini zayiflatirdi; bu yuzden ayri `ticket_message_attachments`
-- bucket'i acilir ve okumasi **biletin taraflarina** acilir.
--
-- ---------------------------------------------------------------------------
-- KARAR 4 — hesap silinince bu fotograflara ne olur (PURGE KAPSAMI)
-- ---------------------------------------------------------------------------
-- Yeni bir bucket acmak `supabase/tests/049_account_purge_storage_scope.test.sql`
-- §1'deki dondurulmus envanter iddiasini KIRMIZI dusurur. Iddia bilerek
-- boyledir: bir bucket, icindeki dosyalarin HESAP SILINDIGINDE ne olacagina
-- dair bir karar verilmeden eklenemez. Karar ve gerekcesi burada.
--
-- ELENEN YOL — eki `feedback_attachments` icinde tasimak (sifir yeni bucket):
--   • O bucket yalnizca `(id, name, public)` ile aciliyor (`0045:84`,
--     `0072:17`); `file_size_limit` ve `allowed_mime_types` YOK. Foto oraya
--     tasinsaydi `0096`nin bucket duzeyindeki 5 MB / jpeg-png-webp kapisi
--     kaybolurdu. Geri kazanmanin tek yolu, halihazirda dosya tutan bir
--     bucket'in sozlesmesini geriye donuk daraltmakti.
--   • Okuma politikasi `kullanici_ve_admin_ekleri_okuyabilir` (`0045:97-105`,
--     `0072:36-46`) "kendi klasorun VEYA super-admin" der. Yoneticinin
--     gonderdigi fotograf yoneticinin klasorunde durur; yani KULLANICI
--     OKUYAMAZDI. Duzeltmek, eski nesneleri tasiyan bir bucket'in okuma
--     sinirini genisletmek demekti.
--   Ozet: (b) "yeni yuzey acmiyor" gibi gorunur ama PRODUCTION'da duran bir
--   bucket'in IKI sozlesmesini birden degistirir.
--
-- SECILEN YOL (a) — bucket kalir, purge KULLANICI dongusune girer:
--   • Yeni bucket hicbir mevcut nesneye dokunmaz; kendi dar sinirlariyla
--     dogar ve `0096` desenini birebir tasir.
--   • Acilan tek yeni yuzey `USER_OWNED_STORAGE_BUCKETS` listesine eklenen
--     tek satirdir — zaten kirmizi testin yazdirmak istedigi karar.
--
-- PURGE BU BUCKET'A NASIL ERISIR (taklit edilen desen):
--   `purge-accounts/index.ts:96-98` listeye girme olcutunu tek cumleyle
--   yaziyor: nesne yolunun ilk klasoru ham `auth.uid()` mi? Burada evet ve
--   UC yerde birden zorlanir:
--     - yukleme politikasi `ticket_message_attachments_insert_own` (asagida)
--     - sunucu kapisi `assert_ticket_message_attachment_allowed` (asagida)
--     - istemci yolu `<uid>/<uuid>.<ext>`
--       (`app/lib/data/repositories/supabase/report_attachment_upload.dart:56`)
--   Yani uzay `feedback_attachments` / `report_attachments` ile birebir ayni
--   (`index.ts:100-102`); mevcut kullanici dongusu (`index.ts:193-195` ->
--   `purgeStorageFolder`) bucket adi listeye yazilir yazilmaz her nesneyi
--   sayfalayarak siler. Silmenin bedeli yok: dosyayi isaret eden satir
--   (`feedback_ticket_messages` -> `feedback_tickets.user_id` -> `auth.users`
--   cascade) zaten gidiyor; birakmak "delil saklamak" degil, hicbir satirin
--   isaret etmedigi bir fotograf birakmak olurdu (`index.ts:104-109`).
--
-- 🔴 Temizlik BU MIGRATION'DA yapilamaz: `0054` DB'den dogrudan
-- `storage.objects` silmeyi kaldirdi ("Direct deletions from storage tables
-- is not allowed, use the storage API"). Purge yolu yalniz Edge function
-- listesinde yasayabilir; bu dosya o listenin dayanagini (uid anahtarli uzay)
-- kurar ve test onu olcer.
--
-- 🔴 BILINEN ARTIK (bilerek birakildi, kapsam disi): yoneticinin gonderdigi
-- fotograf yoneticinin klasorundedir. Karsi taraf hesabini silince bilet
-- satirlari cascade ile gider, o fotograf yoneticinin klasorunde oksuz kalir;
-- ancak yoneticinin KENDI hesabi silindiginde temizlenir. Diger uc bucket'ta
-- bu durum yok, cunku oralara yalniz biletin/raporun sahibi yukluyor.
-- Kapatmak `deleteUser`dan ONCE `attachment_path` toplayan ayri bir purge
-- adimi gerektirir — ayri WP.
--
-- Geri alma (Rollback):
--   drop function if exists public.admin_send_case_message(uuid, text, text, uuid, text);
--   drop function if exists public.admin_case_conversation_channels(uuid);
--   drop function if exists public.send_feedback_ticket_message(uuid, text, uuid, text);
--   -- `0103`teki uc parametreli govdeyi geri kur.
--   drop function if exists public.admin_feedback_tickets(text, text, boolean);
--   -- `0090`daki govdeyi geri kur.
--   drop trigger if exists feedback_tickets_stamp_case_party on public.feedback_tickets;
--   drop function if exists public._stamp_feedback_ticket_case_party();
--   drop function if exists public.case_report_reported_user(uuid);
--   drop function if exists public.assert_ticket_message_attachment_allowed(text);
--   drop policy if exists ticket_message_attachments_insert_own on storage.objects;
--   drop policy if exists ticket_message_attachments_select_participant on storage.objects;
--   alter table public.feedback_ticket_messages drop column if exists attachment_path;
--   alter table public.feedback_tickets drop column if exists case_report_id;
--   alter table public.feedback_tickets drop column if exists case_party;
--   -- (uq_feedback_tickets_reported_channel ve idx_feedback_tickets_case_report
--   --  bu iki kolonla birlikte dusar; ayrica drop gerekmez.)
--   -- `_seed_feedback_ticket_initial_message` ve
--   -- `_enqueue_support_ticket_admin_push` govdelerini `0103`/`0090` haline dondur.
--   -- Bucket ve objeler otomatik silinmez; konusma kaniti oldugu icin elle
--   -- degerlendirilir: delete from storage.buckets where id='ticket_message_attachments';
--   -- Geri alirken `supabase/functions/purge-accounts/index.ts` icindeki
--   -- `USER_OWNED_STORAGE_BUCKETS` listesinden de 'ticket_message_attachments'
--   -- satiri cikarilir (KARAR 4); aksi halde purge var olmayan bir bucket'i
--   -- listelemeye calisir ve is retry kuyruguna duser.

-- ---------------------------------------------------------------------------
-- 1. Mesaj basina tek foto eki
-- ---------------------------------------------------------------------------
alter table public.feedback_ticket_messages
  add column if not exists attachment_path text;

-- 🔴 PURGE KAPSAMI (KARAR 4): bu bucket'in adi
-- `supabase/functions/purge-accounts/index.ts` icindeki
-- `USER_OWNED_STORAGE_BUCKETS` listesinde BULUNMAK ZORUNDADIR. Bulunmazsa
-- hesap silindiginde fotograflar ham uid klasorunde oksuz kalir ve hata bile
-- vermez. Sozlesme: `supabase/tests/049_account_purge_storage_scope.test.sql`.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ticket_message_attachments',
  'ticket_message_attachments',
  false,
  5242880, -- 5 MB — `0096` ile ayni sinir
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Yukleme sahipligi `0096` ile ayni: yalniz kendi `auth.uid()` klasorune.
-- Istemci yolu `<uid>/<uuid>.<ext>` uretir (report_attachment_upload.dart).
drop policy if exists ticket_message_attachments_insert_own on storage.objects;
create policy ticket_message_attachments_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'ticket_message_attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- 🔴 `0096`dan AYRILAN tek nokta: okuma super-admin'e kilitli degil, biletin
-- taraflarina acik. Bir obje ancak GERCEKTEN bir mesaja eklendikten sonra
-- okunabilir; yuklenmis ama eklenmemis obje karsi tarafa gorunmez.
drop policy if exists ticket_message_attachments_select_participant on storage.objects;
create policy ticket_message_attachments_select_participant
on storage.objects for select to authenticated
using (
  bucket_id = 'ticket_message_attachments'
  and (
    public.is_super_admin()
    or exists (
      select 1
      from public.feedback_ticket_messages message
      join public.feedback_tickets ticket on ticket.id = message.ticket_id
      where message.attachment_path = storage.objects.name
        and ticket.user_id = auth.uid()
    )
  )
);

-- `0096`nin `assert_report_attachment_allowed` kapisiyla ayni govde; tek fark
-- bucket adi. Bucket ayari atlansa bile boyut/MIME/sahiplik burada kapanir.
create or replace function public.assert_ticket_message_attachment_allowed(
  p_path text
)
returns text
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_path text := nullif(btrim(coalesce(p_path, '')), '');
  v_metadata jsonb;
  v_size bigint;
  v_mime text;
begin
  if v_path is null then
    return null; -- ek opsiyoneldir
  end if;
  if auth.uid() is null then
    raise exception 'session_required';
  end if;
  if (string_to_array(v_path, '/'))[1] is distinct from auth.uid()::text then
    raise exception 'attachment_not_owned';
  end if;

  select o.metadata into v_metadata
  from storage.objects o
  where o.bucket_id = 'ticket_message_attachments' and o.name = v_path;

  if not found then
    raise exception 'attachment_missing';
  end if;

  v_size := nullif(v_metadata ->> 'size', '')::bigint;
  v_mime := lower(coalesce(v_metadata ->> 'mimetype', ''));

  if v_size is null or v_size > 5242880 then
    raise exception 'attachment_too_large';
  end if;
  if v_mime not in ('image/jpeg', 'image/png', 'image/webp') then
    raise exception 'attachment_type_not_allowed';
  end if;

  return v_path;
end;
$$;

revoke all on function public.assert_ticket_message_attachment_allowed(text)
  from public, anon;
grant execute on function public.assert_ticket_message_attachment_allowed(text)
  to authenticated;

comment on function public.assert_ticket_message_attachment_allowed(text) is
  'WP-778: server gate for a single per-message photo — ownership, existence, 5MB size and image MIME.';

-- ---------------------------------------------------------------------------
-- 2. Vakaya bagli taraf kanallari
-- ---------------------------------------------------------------------------
alter table public.feedback_tickets
  add column if not exists case_report_id uuid
    references public.ugc_reports (id) on delete set null,
  add column if not exists case_party text;

alter table public.feedback_tickets
  drop constraint if exists feedback_tickets_case_party_check;
alter table public.feedback_tickets
  add constraint feedback_tickets_case_party_check
  check (case_party is null or case_party in ('reporter', 'reported'));

-- Gecmis ayna biletleri sikayet EDEN kanalidir; tek gercek olarak isaretlenir.
update public.feedback_tickets
set case_report_id = ugc_report_id,
    case_party = 'reporter'
where ugc_report_id is not null
  and case_party is null;

-- `report_ugc` ellenmedigi icin YENI ayna biletler bu kolonlari tasimaz.
-- Damgayi tetikleyici vurur; boylece 0104'un buyuk govdesi kopyalanmaz.
create or replace function public._stamp_feedback_ticket_case_party()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.ugc_report_id is not null and new.case_party is null then
    new.case_report_id := new.ugc_report_id;
    new.case_party := 'reporter';
  end if;
  return new;
end;
$$;

drop trigger if exists feedback_tickets_stamp_case_party on public.feedback_tickets;
create trigger feedback_tickets_stamp_case_party
before insert on public.feedback_tickets
for each row execute function public._stamp_feedback_ticket_case_party();

-- Vaka basina sikayet edilen tarafa TEK kanal. Sikayet eden tarafi zaten
-- `feedback_tickets_ugc_report_id_unique` tekilliyor; bu indeks bilerek yalniz
-- 'reported' satirlarini kapsar, boylece `report_ugc`'nin upsert'i bu indekse
-- hic dokunmaz.
create unique index if not exists uq_feedback_tickets_reported_channel
  on public.feedback_tickets (case_report_id)
  where case_party = 'reported';

create index if not exists idx_feedback_tickets_case_report
  on public.feedback_tickets (case_report_id, case_party)
  where case_report_id is not null;

-- ---------------------------------------------------------------------------
-- 3. Kanali yonetici actiysa ilk mesaj YONETICININDIR
-- ---------------------------------------------------------------------------
-- `0103`un tohum tetikleyicisi ilk mesaji her zaman 'user' rolune yaziyordu;
-- dogruydu, cunku bileti hep kullanici aciyordu. Sikayet edilen kanalini
-- yonetici acar: o satir kullanicinin yazdigi bir sey degildir.
create or replace function public._seed_feedback_ticket_initial_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_opened boolean := new.case_party is not distinct from 'reported';
begin
  insert into public.feedback_ticket_messages (
    ticket_id, sender_id, sender_role, message, created_at,
    client_message_id, message_seq
  ) values (
    new.id,
    case when v_admin_opened then auth.uid() else new.user_id end,
    case when v_admin_opened then 'admin' else 'user' end,
    new.message,
    new.created_at,
    gen_random_uuid(),
    1
  );
  update public.feedback_tickets
  set latest_message_seq = 1
  where id = new.id;
  return new;
end;
$$;

-- Yoneticinin kendi actigi kanal, yoneticilere "yeni destek bileti" push'u
-- dogurmaz: bu bir kullanici basvurusu degil, yoneticinin kendi eylemidir.
create or replace function public._enqueue_support_ticket_admin_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.case_party is not distinct from 'reported' then
    return new;
  end if;
  insert into public.notification_outbox (
    event_key, recipient_id, notification_type, payload
  )
  select
    'support-ticket:' || new.id::text || ':' || admin.user_id::text,
    admin.user_id,
    'announcement',
    jsonb_build_object(
      'schema_version', '1',
      'event_id', new.id::text,
      'route', 'admin_support',
      'feedback_ticket_id', new.id::text,
      'ticket_type', new.ticket_type,
      'title', 'Yeni destek bileti',
      'body', left(new.subject, 120)
    )
  from public.app_admins admin
  on conflict (event_key) do nothing;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Mesaj gonderme — opsiyonel tek foto
-- ---------------------------------------------------------------------------
-- `0096` deseni: eski imza `drop` edilir, yerine varsayilan parametreli yenisi
-- kurulur. Iki imza birden dursaydi uc argumanli cagri belirsizlesirdi. Eski
-- istemciler (v78) eki hic gondermez; varsayilan `null` ile aynen calisir.
drop function if exists public.send_feedback_ticket_message(uuid, text, uuid);

create or replace function public.send_feedback_ticket_message(
  p_ticket_id uuid,
  p_message text,
  p_client_message_id uuid,
  p_attachment_path text default null
)
returns public.feedback_ticket_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket public.feedback_tickets%rowtype;
  v_sender_role text;
  v_message public.feedback_ticket_messages%rowtype;
  v_normalized_message text;
  v_attachment text;
begin
  if auth.uid() is null then
    raise exception 'session_required';
  end if;
  if p_client_message_id is null then
    raise exception 'client_message_id_required';
  end if;

  v_normalized_message := trim(coalesce(p_message, ''));
  if char_length(v_normalized_message) not between 1 and 1200 then
    raise exception 'invalid_feedback_message';
  end if;

  select * into v_ticket
  from public.feedback_tickets
  where id = p_ticket_id
  for update;
  if not found then
    raise exception 'feedback_ticket_not_found';
  end if;

  if public.is_super_admin() then
    v_sender_role := 'admin';
  elsif v_ticket.user_id = auth.uid() then
    v_sender_role := 'user';
  else
    raise exception 'feedback_ticket_access_denied';
  end if;

  select * into v_message
  from public.feedback_ticket_messages
  where ticket_id = v_ticket.id
    and client_message_id = p_client_message_id;
  if found then
    return v_message;
  end if;

  v_attachment := public.assert_ticket_message_attachment_allowed(
    p_attachment_path
  );

  update public.feedback_tickets
  set latest_message_seq = latest_message_seq + 1,
      status = 'in_progress',
      updated_at = now()
  where id = v_ticket.id
  returning * into v_ticket;

  insert into public.feedback_ticket_messages (
    ticket_id, sender_id, sender_role, message, client_message_id, message_seq,
    attachment_path
  ) values (
    v_ticket.id,
    auth.uid(),
    v_sender_role,
    v_normalized_message,
    p_client_message_id,
    v_ticket.latest_message_seq,
    v_attachment
  ) returning * into v_message;

  -- ℹ️ `0074`teki admin-yaniti duyurusu burada hala **bilerek yoktur**
  -- (`0103` gerekcesi degismedi).
  return v_message;
end;
$$;

revoke all on function
  public.send_feedback_ticket_message(uuid, text, uuid, text) from public, anon;
grant execute on function
  public.send_feedback_ticket_message(uuid, text, uuid, text) to authenticated;

-- Iki parametreli eski sarmalayici yeni govdeye baglanir.
create or replace function public.send_feedback_ticket_message(
  p_ticket_id uuid,
  p_message text
)
returns public.feedback_ticket_messages
language sql
security definer
set search_path = public
as $$
  select public.send_feedback_ticket_message(
    p_ticket_id, p_message, gen_random_uuid(), null::text
  );
$$;

revoke all on function public.send_feedback_ticket_message(uuid, text)
  from public, anon;
grant execute on function public.send_feedback_ticket_message(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Vakanin iki tarafi ve kanallari
-- ---------------------------------------------------------------------------
-- Sikayet edilen kisiyi ISTEMCI belirlemez: raporun kanonik kanitindan okunur
-- (`0104`). Mesaj raporunda yazar `canonical_snapshot.author_id`, profil
-- raporunda hedefin kendisidir; grup raporunda tek bir kisi yoktur -> NULL.
create or replace function public.case_report_reported_user(p_report_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_report public.ugc_reports%rowtype;
  v_author uuid;
begin
  select * into v_report from public.ugc_reports where id = p_report_id;
  if not found then
    return null;
  end if;

  if v_report.target_type in ('profile', 'user') then
    begin
      return v_report.target_id::uuid;
    exception when invalid_text_representation then
      return null;
    end;
  end if;

  if v_report.target_type = 'message' then
    v_author := nullif(v_report.canonical_snapshot ->> 'author_id', '')::uuid;
    if v_author is not null then
      return v_author;
    end if;
    -- `0104` oncesi mesaj raporlarinin kanonik kaniti yok; mesaj hala duruyorsa
    -- yazari oradan okunur.
    begin
      select message.user_id into v_author
      from public.class_messages message
      where message.id = v_report.target_id::uuid;
    exception when invalid_text_representation then
      return null;
    end;
    return v_author;
  end if;

  -- group / group_name: sikayet edilen tek bir kisi degildir.
  return null;
end;
$$;

revoke all on function public.case_report_reported_user(uuid) from public, anon;
grant execute on function public.case_report_reported_user(uuid) to authenticated;

create or replace function public.admin_case_conversation_channels(
  p_report_id uuid
)
returns table (
  party text,
  user_id uuid,
  display_name text,
  ticket_id uuid
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_report public.ugc_reports%rowtype;
  v_reported uuid;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;

  select * into v_report from public.ugc_reports where id = p_report_id;
  if not found then
    raise exception 'ugc_report_not_found';
  end if;

  v_reported := public.case_report_reported_user(p_report_id);

  return query
  select
    'reporter'::text,
    v_report.reporter_id,
    (
      select profile.display_name from public.profiles profile
      where profile.id = v_report.reporter_id
    ),
    (
      select ticket.id from public.feedback_tickets ticket
      where ticket.ugc_report_id = p_report_id
      limit 1
    );

  if v_reported is null then
    return;
  end if;

  return query
  select
    'reported'::text,
    v_reported,
    (
      select profile.display_name from public.profiles profile
      where profile.id = v_reported
    ),
    (
      select ticket.id from public.feedback_tickets ticket
      where ticket.case_report_id = p_report_id
        and ticket.case_party = 'reported'
      limit 1
    );
end;
$$;

revoke all on function public.admin_case_conversation_channels(uuid)
  from public, anon;
grant execute on function public.admin_case_conversation_channels(uuid)
  to authenticated;

comment on function public.admin_case_conversation_channels(uuid) is
  'WP-778: the two conversation channels of a case (reporter / reported) with their ticket ids.';

-- ---------------------------------------------------------------------------
-- 6. Yoneticinin taraf kanalina mesaji
-- ---------------------------------------------------------------------------
-- Kanal TEMBELDIR: sikayet edilen kisi, yonetici gercekten yazana kadar hicbir
-- destek kaydi gormez. Bileti sikayet aninda acsaydik kullanici sikayet
-- edildigini bizim haberimiz olmadan ogrenirdi.
create or replace function public.admin_send_case_message(
  p_report_id uuid,
  p_party text,
  p_message text,
  p_client_message_id uuid,
  p_attachment_path text default null
)
returns public.feedback_ticket_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket_id uuid;
  v_reported uuid;
  v_normalized text := trim(coalesce(p_message, ''));
  v_attachment text;
  v_message public.feedback_ticket_messages%rowtype;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;
  if p_party not in ('reporter', 'reported') then
    raise exception 'invalid_case_party';
  end if;
  if p_client_message_id is null then
    raise exception 'client_message_id_required';
  end if;
  if char_length(v_normalized) not between 1 and 1200 then
    raise exception 'invalid_feedback_message';
  end if;

  if p_party = 'reporter' then
    select ticket.id into v_ticket_id
    from public.feedback_tickets ticket
    where ticket.ugc_report_id = p_report_id
    limit 1;
    if v_ticket_id is null then
      -- Ayna bileti `report_ugc` acar; yoksa sikayetin kendisi yoktur.
      raise exception 'case_conversation_missing';
    end if;
  else
    select ticket.id into v_ticket_id
    from public.feedback_tickets ticket
    where ticket.case_report_id = p_report_id
      and ticket.case_party = 'reported'
    limit 1;
  end if;

  if v_ticket_id is not null then
    return public.send_feedback_ticket_message(
      v_ticket_id, v_normalized, p_client_message_id, p_attachment_path
    );
  end if;

  v_reported := public.case_report_reported_user(p_report_id);
  if v_reported is null then
    raise exception 'case_party_not_resolvable';
  end if;

  v_attachment := public.assert_ticket_message_attachment_allowed(
    p_attachment_path
  );

  -- Konu satiri notrdur: kimin sikayet ettigini ve gerekcesini SIZDIRMAZ.
  insert into public.feedback_tickets (
    user_id, kind, ticket_type, subject, message, status,
    case_report_id, case_party
  ) values (
    v_reported,
    'feedback',
    -- 'report' secilir cunku `_enforce_support_ticket_rate_limit` (0090) yalniz
    -- 'feedback'/'question' sayar; yoneticinin actigi kanal kullanicinin kendi
    -- kotasini tuketmemeli ve o kota yuzunden reddedilmemeli.
    'report',
    'Moderasyon ekibinden mesaj',
    v_normalized,
    'open',
    p_report_id,
    'reported'
  ) returning id into v_ticket_id;

  -- Tohum tetikleyicisi (bkz. §3) ilk mesaji YONETICI adina yazdi; eki ona
  -- baglariz ve istemcinin komut kimligini geri yazariz (tekrar gonderim ayni
  -- satiri bulur, ikinci kanal acmaz).
  update public.feedback_ticket_messages
  set attachment_path = v_attachment,
      client_message_id = p_client_message_id
  where ticket_id = v_ticket_id
    and message_seq = 1
  returning * into v_message;

  return v_message;
end;
$$;

revoke all on function
  public.admin_send_case_message(uuid, text, text, uuid, text)
  from public, anon;
grant execute on function
  public.admin_send_case_message(uuid, text, text, uuid, text)
  to authenticated;

comment on function public.admin_send_case_message(uuid, text, text, uuid, text) is
  'WP-778: appends an admin message to a case party channel, lazily opening the reported-party channel.';

-- ---------------------------------------------------------------------------
-- 7. Gelen kutusu sikayet edilen kanalini listelemez
-- ---------------------------------------------------------------------------
-- `0090` govdesi + tek satir eleme. Bu kanal yalniz vaka sayfasindan acilir;
-- kuyrukta bagimsiz bir destek kaydi gibi gorunmesi yanlis sinyaldir.
drop function if exists public.admin_feedback_tickets(text, text, boolean);
create function public.admin_feedback_tickets(
  p_status text default null,
  p_type text default null,
  p_include_archived boolean default false
)
returns table (
  id uuid, user_id uuid, kind text, ticket_type text, subject text, message text,
  status text, created_at timestamptz, updated_at timestamptz,
  reporter_display_name text, attachment_path text, archived_at timestamptz,
  ugc_report_id uuid
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin';
  end if;
  if p_status is not null and p_status not in ('open', 'in_progress', 'closed') then
    raise exception 'invalid_feedback_status';
  end if;
  if p_type is not null and p_type not in ('feedback', 'question', 'report') then
    raise exception 'invalid_support_ticket_type';
  end if;

  return query
  select
    ticket.id,
    ticket.user_id,
    ticket.kind,
    ticket.ticket_type,
    ticket.subject,
    ticket.message,
    ticket.status,
    ticket.created_at,
    ticket.updated_at,
    profile.display_name,
    ticket.attachment_path,
    ticket.archived_at,
    ticket.ugc_report_id
  from public.feedback_tickets ticket
  left join public.profiles profile on profile.id = ticket.user_id
  where (p_status is null or ticket.status = p_status)
    and (p_type is null or ticket.ticket_type = p_type)
    and (p_include_archived or ticket.archived_at is null)
    and ticket.case_party is distinct from 'reported'
  order by ticket.created_at desc;
end;
$$;

revoke all on function public.admin_feedback_tickets(text, text, boolean)
  from public, anon;
grant execute on function public.admin_feedback_tickets(text, text, boolean)
  to authenticated;
