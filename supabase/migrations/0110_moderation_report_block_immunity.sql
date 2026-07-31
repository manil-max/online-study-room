-- 0110_moderation_report_block_immunity.sql
-- WP-443: Engellemek raporlanmaya karşı bağışıklık VERMEZ.
--
-- Bulgu (WP-443 abuse matrisi): `report_ugc`'nin profil dalı hedefin
-- görünürlüğünü `can_see_user_sessions` ile ölçüyordu. O yardımcı `0095`ten
-- beri `is_blocked_pair` içeriyor ve engel **simetriktir**. Sonuç: taciz eden
-- kişi kurbanını engellediği anda kendi profilini/adını raporlanamaz hâle
-- getiriyordu — saldırganın tek tıkla kurabildiği bir moderasyon muafiyeti.
-- Mesaj dalı bu delikten etkilenmiyordu (`is_group_member` bakar), yani hata
-- yalnız uygunsuz görünen ad/avatar şikâyetlerini yutuyordu; tam olarak
-- engellemenin en olası sebebini.
--
-- Karar: bildirim hakkı, bildirilen kişi tarafından geri alınamaz. Görünürlük
-- kapısı korunur (yalnız ortak gruptaki biri raporlanabilir), engel kontrolü
-- rapor yolundan çıkarılır. `can_see_user_sessions` DEĞİŞTİRİLMEZ: oturum,
-- profil ve istatistik yüzeylerinde engel görünürlüğü kesmeye devam eder.
--
-- Geri alma (Rollback): `report_ugc`'nin `0104` gövdesi geri yazılır ve
-- `moderation_can_report_profile` düşürülür; veri kaybı olmaz.

-- Rapor yolunun görünürlük kapısı: ortak grup şartı aynen `0095`teki gibi,
-- fakat `is_blocked_pair` olmadan.
create or replace function public.moderation_can_report_profile(p_target uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select p_target is not null
     and auth.uid() is not null
     and p_target <> auth.uid()
     and exists (
       select 1 from public.group_members me
       join public.group_members other on other.group_id = me.group_id
       where me.user_id = auth.uid() and me.left_at is null
         and other.user_id = p_target
     );
$$;

revoke all on function public.moderation_can_report_profile(uuid) from public, anon;
grant execute on function public.moderation_can_report_profile(uuid) to authenticated;

comment on function public.moderation_can_report_profile(uuid) is
  'WP-443: report visibility gate; deliberately block-agnostic so a blocker cannot grant themselves immunity.';

create or replace function public.report_ugc(
  p_target_type text,
  p_target_id text,
  p_reason text,
  p_details text default null,
  p_snapshot text default null,
  p_attachment_path text default null,
  p_context_group_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := case when btrim(p_target_type) = 'user' then 'profile' else btrim(p_target_type) end;
  v_target_id uuid;
  v_message public.class_messages%rowtype;
  v_profile public.profiles%rowtype;
  v_group public.groups%rowtype;
  v_snapshot jsonb;
  v_snapshot_text text;
  v_attachment text;
  v_case_id uuid;
  v_report public.ugc_reports%rowtype;
  v_subject text;
  v_message_text text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if v_type not in ('message', 'profile', 'group', 'group_name') then
    raise exception 'invalid_type';
  end if;
  begin
    v_target_id := btrim(p_target_id)::uuid;
  exception when invalid_text_representation then
    raise exception 'invalid_target_id';
  end;
  if nullif(btrim(p_reason), '') is null or char_length(btrim(p_reason)) > 40 then
    raise exception 'invalid_reason';
  end if;

  if v_type = 'message' then
    if p_context_group_id is null then raise exception 'context_group_required'; end if;
    select * into v_message from public.class_messages where id = v_target_id;
    if not found then raise exception 'report_target_not_found'; end if;
    if v_message.group_id <> p_context_group_id or not public.is_group_member(v_message.group_id) then
      raise exception 'report_target_not_visible' using errcode = '42501';
    end if;
    v_snapshot := jsonb_build_object(
      'target_type', 'message', 'message_id', v_message.id, 'group_id', v_message.group_id,
      'author_id', v_message.user_id, 'body', v_message.body, 'created_at', v_message.created_at
    );
  elsif v_type = 'profile' then
    if p_context_group_id is not null then raise exception 'unexpected_context_group'; end if;
    if v_target_id = auth.uid()
       or not public.moderation_can_report_profile(v_target_id) then
      raise exception 'report_target_not_visible' using errcode = '42501';
    end if;
    select * into v_profile from public.profiles where id = v_target_id;
    if not found then raise exception 'report_target_not_found'; end if;
    v_snapshot := jsonb_build_object(
      'target_type', 'profile', 'profile_id', v_profile.id,
      'display_name', v_profile.display_name, 'avatar_url', v_profile.avatar_url
    );
  else
    if p_context_group_id is not null then raise exception 'unexpected_context_group'; end if;
    select * into v_group from public.groups where id = v_target_id;
    if not found then raise exception 'report_target_not_found'; end if;
    if not public.is_group_member(v_group.id) then
      raise exception 'report_target_not_visible' using errcode = '42501';
    end if;
    v_snapshot := jsonb_build_object(
      'target_type', v_type, 'group_id', v_group.id, 'group_name', v_group.name
    );
  end if;

  v_attachment := public.assert_report_attachment_allowed(p_attachment_path);
  v_snapshot_text := left(v_snapshot::text, 2000);

  insert into public.moderation_cases (target_type, target_id)
  values (v_type, v_target_id::text)
  on conflict (target_type, target_id) where status in ('open', 'in_review')
  do update set updated_at = now()
  returning id into v_case_id;

  insert into public.ugc_reports (
    reporter_id, target_type, target_id, context_group_id, reason, details,
    client_hint, content_snapshot, canonical_snapshot, attachment_path, case_id
  ) values (
    auth.uid(), v_type, v_target_id::text,
    case when v_type = 'message' then p_context_group_id else null end,
    btrim(p_reason), nullif(btrim(coalesce(p_details, '')), ''),
    nullif(left(btrim(coalesce(p_snapshot, '')), 200), ''), v_snapshot_text,
    v_snapshot, v_attachment, v_case_id
  )
  -- Ayni raporlayan ayni sebeple tekrar rapor ederse satir tekildir; ama vaka
  -- kapandiysa yukaridaki upsert yeni bir acik vaka acmistir. Rapor o vakaya
  -- tasinir ve kuyruga geri doner, yoksa sikayet gorunmez olurdu.
  on conflict (reporter_id, target_type, target_id, reason) do update
    set updated_at = now(),
        details = coalesce(excluded.details, public.ugc_reports.details),
        attachment_path = coalesce(excluded.attachment_path, public.ugc_reports.attachment_path),
        case_id = excluded.case_id,
        status = case
          when public.ugc_reports.case_id is distinct from excluded.case_id then 'open'
          else public.ugc_reports.status
        end
  returning * into v_report;

  v_subject := left('Şikâyet: ' || v_report.target_type || ' · ' || v_report.reason, 80);
  v_message_text := left(coalesce(nullif(trim(v_report.details), ''), 'Kullanıcı şikâyet ayrıntısı girmedi.'), 1200);
  insert into public.feedback_tickets (
    user_id, kind, ticket_type, ugc_report_id, subject, message, status, attachment_path
  ) values (
    v_report.reporter_id, 'feedback', 'report', v_report.id, v_subject, v_message_text,
    case when v_report.status = 'open' then 'open' when v_report.status = 'in_review' then 'in_progress' else 'closed' end,
    v_report.attachment_path
  ) on conflict (ugc_report_id) where ugc_report_id is not null do update
    set attachment_path = coalesce(excluded.attachment_path, public.feedback_tickets.attachment_path);

  return v_report.id;
end;
$$;

revoke all on function public.report_ugc(text, text, text, text, text, text, uuid) from public, anon;
grant execute on function public.report_ugc(text, text, text, text, text, text, uuid) to authenticated;
