-- 0096_report_attachments.sql
-- WP-423: Şikâyet ve SSS/destek sorusuna tek foto eki.
--
-- Sahip "bildir kısmına foto eklenebilsin" dedi. Altyapı kısmen vardı:
-- geri bildirim bileti zaten `feedback_attachments` (private) bucket'ını
-- kullanıyor. Şikâyetin (`ugc_reports`) hiç eki yoktu.
--
-- 🔴 `avatars` bucket'ı YENİDEN KULLANILMAZ: `0002` ona public okuma politikası
-- veriyor. Şikâyet eki oraya konsaydı herkese açılırdı. Bu yüzden ayrı ve
-- **public olmayan** `report_attachments` bucket'ı kurulur.
--
-- İşleyiş:
--   • `report_attachments` bucket'ı private; boyut (5 MB) ve MIME (jpeg/png/webp)
--     sınırı **bucket üzerinde** tanımlı → Storage API sunucuda reddeder.
--   • Storage politikaları: kullanıcı yalnız kendi `auth.uid()` klasörüne
--     yazabilir; **okuma yalnız super-admin**. Şikâyet eden bile ekini geri
--     okuyamaz (ek moderasyon delilidir, paylaşım yüzeyi değildir).
--     İmzalı URL de bu SELECT politikasından geçtiği için yalnız super-admin
--     üretebilir.
--   • `ugc_reports.attachment_path` kolonu eklenir.
--   • `report_ugc` ikinci bir sunucu kapısı uygular: yol `auth.uid()/` ile
--     başlamak zorunda, obje bucket'ta gerçekten var olmalı ve
--     `storage.objects.metadata` içindeki boyut/MIME yeniden doğrulanır.
--     Yani bucket ayarı atlansa bile uydurma yol kabul edilmez.
--   • Ek **opsiyoneldir**: yol verilmezse şikâyet aynen gönderilir. Yükleme
--     istemcide başarısız olursa istemci eki `null` geçer, şikâyet düşmez.
--   • `submit_faq_question` de aynı kapıdan geçen opsiyonel ek alır ve
--     `feedback_tickets.attachment_path`e yazar.
--   • `report_ugc`, `0090`'ın destek-kutusu sözleşmesini olduğu gibi sürdürür:
--     her şikâyet `ticket_type='report'` biletine bağlanır; ek varsa bilet de
--     aynı yolu taşır (Lane B'nin WP-425 detay ekranı oradan okur).
--
-- İmza değişikliği notu: iki RPC de eski imzasıyla birlikte varsa çağrı
-- belirsizleşeceği için eski imza `drop` edilip yerine varsayılan parametreli
-- yenisi kurulur. Eski istemciler (v55) eki hiç göndermez; varsayılan `null`
-- sayesinde çağrıları aynen çalışmaya devam eder.
--
-- Geri alma (Rollback):
--   drop function if exists public.report_ugc(text, text, text, text, text, text);
--   drop function if exists public.submit_faq_question(text, text);
--   -- 0090 (report_ugc) ve 0091 (submit_faq_question) gövdelerini geri kur.
--   drop policy if exists report_attachments_insert_own on storage.objects;
--   drop policy if exists report_attachments_select_admin on storage.objects;
--   alter table public.ugc_reports drop column if exists attachment_path;
--   -- Bucket ve içindeki objeler otomatik silinmez; delil olduğu için elle
--   -- değerlendirilir: delete from storage.buckets where id='report_attachments';

-- ---------------------------------------------------------------------
-- 1. Private bucket + sunucu tarafı boyut/MIME sınırı
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'report_attachments',
  'report_attachments',
  false,
  5242880, -- 5 MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists report_attachments_insert_own on storage.objects;
create policy report_attachments_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'report_attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- 🔴 Okuma YALNIZ super-admin. Şikâyet eden dahil kimse başkasının ekini,
-- hatta kendi ekini de geri okuyamaz; ek moderasyon delilidir.
drop policy if exists report_attachments_select_admin on storage.objects;
create policy report_attachments_select_admin
on storage.objects for select to authenticated
using (
  bucket_id = 'report_attachments'
  and public.is_super_admin()
);

-- ---------------------------------------------------------------------
-- 2. Şikâyet kaydına ek yolu
-- ---------------------------------------------------------------------
alter table public.ugc_reports
  add column if not exists attachment_path text;

-- ---------------------------------------------------------------------
-- 3. Ortak sunucu kapısı: yol sahipliği + varlık + boyut/MIME
-- ---------------------------------------------------------------------
create or replace function public.assert_report_attachment_allowed(p_path text)
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
  -- Uydurma yol: başkasının klasörüne işaret eden ek kabul edilmez.
  if (string_to_array(v_path, '/'))[1] is distinct from auth.uid()::text then
    raise exception 'attachment_not_owned';
  end if;

  select o.metadata into v_metadata
  from storage.objects o
  where o.bucket_id = 'report_attachments' and o.name = v_path;

  if not found then
    raise exception 'attachment_missing';
  end if;

  v_size := nullif(v_metadata ->> 'size', '')::bigint;
  v_mime := lower(coalesce(v_metadata ->> 'mimetype', ''));

  -- Bucket sınırı atlansa bile ikinci kapı burada kapanır.
  if v_size is null or v_size > 5242880 then
    raise exception 'attachment_too_large';
  end if;
  if v_mime not in ('image/jpeg', 'image/png', 'image/webp') then
    raise exception 'attachment_type_not_allowed';
  end if;

  return v_path;
end;
$$;

revoke all on function public.assert_report_attachment_allowed(text) from public, anon;
grant execute on function public.assert_report_attachment_allowed(text) to authenticated;

comment on function public.assert_report_attachment_allowed(text) is
  'WP-423: server gate for report/support photo attachments — ownership, existence, 5MB size and image MIME.';

-- ---------------------------------------------------------------------
-- 4. report_ugc — opsiyonel ek
-- ---------------------------------------------------------------------
drop function if exists public.report_ugc(text, text, text, text, text);

create or replace function public.report_ugc(
  p_target_type text,
  p_target_id text,
  p_reason text,
  p_details text default null,
  p_snapshot text default null,
  p_attachment_path text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.ugc_reports%rowtype;
  v_attachment text;
  v_subject text;
  v_message text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_target_type not in ('message', 'user', 'group', 'profile') then
    raise exception 'invalid_type';
  end if;

  v_attachment := public.assert_report_attachment_allowed(p_attachment_path);

  insert into public.ugc_reports (
    reporter_id, target_type, target_id, reason, details, content_snapshot,
    attachment_path
  ) values (
    auth.uid(),
    p_target_type,
    btrim(p_target_id),
    btrim(p_reason),
    nullif(btrim(coalesce(p_details, '')), ''),
    nullif(left(coalesce(p_snapshot, ''), 2000), ''),
    v_attachment
  )
  on conflict (reporter_id, target_type, target_id, reason) do update
    set updated_at = now(),
        details = coalesce(excluded.details, public.ugc_reports.details),
        attachment_path =
          coalesce(excluded.attachment_path, public.ugc_reports.attachment_path)
  returning * into v_report;

  -- 0090 sözleşmesi korunur: her şikâyet destek kutusunda bir bilete bağlanır.
  v_subject := left(
    'Şikâyet: ' || v_report.target_type || ' · ' || v_report.reason,
    80
  );
  v_message := left(
    coalesce(
      nullif(trim(v_report.details), ''),
      'Kullanıcı şikâyet ayrıntısı girmedi.'
    ),
    1200
  );

  insert into public.feedback_tickets (
    user_id, kind, ticket_type, ugc_report_id, subject, message, status,
    attachment_path
  ) values (
    v_report.reporter_id,
    'feedback',
    'report',
    v_report.id,
    v_subject,
    v_message,
    case
      when v_report.status = 'open' then 'open'
      when v_report.status = 'in_review' then 'in_progress'
      else 'closed'
    end,
    v_report.attachment_path
  )
  on conflict (ugc_report_id) where ugc_report_id is not null do update
    -- Aynı şikâyet ikinci kez eklenirse (ör. önce eksiz, sonra ekli gönderildi)
    -- bilet de eki kazanır; başka alanı ezmez.
    set attachment_path =
      coalesce(excluded.attachment_path, public.feedback_tickets.attachment_path);

  return v_report.id;
end;
$$;

revoke all on function public.report_ugc(text, text, text, text, text, text)
  from public, anon;
grant execute on function public.report_ugc(text, text, text, text, text, text)
  to authenticated;

comment on function public.report_ugc(text, text, text, text, text, text) is
  'WP-423: UGC report with an optional single photo attachment validated server-side.';

-- ---------------------------------------------------------------------
-- 5. submit_faq_question — opsiyonel ek
-- ---------------------------------------------------------------------
drop function if exists public.submit_faq_question(text);

create or replace function public.submit_faq_question(
  p_question text,
  p_attachment_path text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_question text := trim(coalesce(p_question, ''));
  v_attachment text;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'session_required';
  end if;
  if char_length(v_question) < 3 or char_length(v_question) > 1200 then
    raise exception 'invalid_question';
  end if;

  v_attachment := public.assert_report_attachment_allowed(p_attachment_path);

  insert into public.feedback_tickets (
    user_id, kind, ticket_type, subject, message, status, attachment_path
  ) values (
    auth.uid(), 'feedback', 'question', left(v_question, 80), v_question, 'open',
    v_attachment
  ) returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.submit_faq_question(text, text) from public, anon;
grant execute on function public.submit_faq_question(text, text) to authenticated;

comment on function public.submit_faq_question(text, text) is
  'WP-423: support question with an optional single photo attachment validated server-side.';
