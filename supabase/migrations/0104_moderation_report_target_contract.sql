-- 0104_moderation_report_target_contract.sql
-- WP-439: hedefi sunucuda doğrulanmış, kanıtı kanonik ve açık vaka tekil UGC raporları.
--
-- İstemci hedef/ipucu gönderebilir; kanıtı asla istemci belirlemez. RPC hedefi
-- gerçek mesaj/profil/gruptan yeniden okur, mesajda aktif ortak grup bağlamını
-- doğrular ve aynı açık hedef için tek moderation_cases satırına bağlar.
--
-- Geri alma (Rollback): Uygulanmış migration geri yazılmaz. Acil degrade için
-- report_ugc çağrılarını kapatın; düzeltme yeni ileri migration ile yapılır.

alter table public.ugc_reports
  add column if not exists context_group_id uuid references public.groups(id) on delete restrict,
  add column if not exists client_hint text,
  add column if not exists canonical_snapshot jsonb,
  add column if not exists evidence_retention_until timestamptz not null
    default (now() + interval '365 days');

alter table public.ugc_reports
  drop constraint if exists ugc_reports_target_type_check;
alter table public.ugc_reports
  add constraint ugc_reports_target_type_check
  check (target_type in ('message', 'user', 'profile', 'group', 'group_name'));
alter table public.ugc_reports
  drop constraint if exists ugc_reports_context_group_only_for_message;
alter table public.ugc_reports
  add constraint ugc_reports_context_group_only_for_message
  check (
    (target_type = 'message' and context_group_id is not null)
    or (target_type <> 'message' and context_group_id is null)
    -- 0104 öncesi mesaj satırları bağlam sütununu hiç taşımıyordu. Onların
    -- kanonik snapshot'ı da yoktur; yeni RPC bu istisnayı üretemez.
    or (target_type = 'message' and canonical_snapshot is null)
  ) not valid;
alter table public.ugc_reports
  validate constraint ugc_reports_context_group_only_for_message;

create table if not exists public.moderation_cases (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('message', 'profile', 'group', 'group_name')),
  target_id text not null,
  status text not null default 'open'
    check (status in ('open', 'in_review', 'resolved', 'rejected')),
  opened_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  evidence_retention_until timestamptz not null default (now() + interval '365 days')
);

create unique index if not exists moderation_cases_one_open_target_idx
  on public.moderation_cases (target_type, target_id)
  where status in ('open', 'in_review');

alter table public.ugc_reports
  add column if not exists case_id uuid references public.moderation_cases(id) on delete restrict;
create index if not exists ugc_reports_case_idx on public.ugc_reports (case_id, created_at desc);

-- Tarihsel satırları yalnız açık kuyruk için vakaya bağla. Kapanmış geçmiş yeni
-- bir raporda yeni vaka açılabilsin diye zorla tek vakaya taşınmaz.
insert into public.moderation_cases (target_type, target_id, status, opened_at, updated_at)
select
  case when r.target_type = 'user' then 'profile' else r.target_type end,
  r.target_id,
  case when bool_or(r.status = 'in_review') then 'in_review' else 'open' end,
  min(r.created_at),
  max(r.updated_at)
from public.ugc_reports r
where r.status in ('open', 'in_review')
group by case when r.target_type = 'user' then 'profile' else r.target_type end, r.target_id
on conflict (target_type, target_id) where status in ('open', 'in_review')
do update set updated_at = greatest(public.moderation_cases.updated_at, excluded.updated_at);

update public.ugc_reports r
set case_id = c.id
from public.moderation_cases c
where r.case_id is null
  and r.status in ('open', 'in_review')
  and c.status in ('open', 'in_review')
  and c.target_type = case when r.target_type = 'user' then 'profile' else r.target_type end
  and c.target_id = r.target_id;

alter table public.moderation_cases enable row level security;
drop policy if exists moderation_cases_select_admin on public.moderation_cases;
create policy moderation_cases_select_admin on public.moderation_cases
  for select to authenticated using (public.is_super_admin());
revoke all on table public.moderation_cases from anon, authenticated;
grant select on table public.moderation_cases to authenticated;

create or replace function public._prevent_ugc_report_evidence_mutation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.reporter_id is distinct from old.reporter_id
    or new.target_type is distinct from old.target_type
    or new.target_id is distinct from old.target_id
    or new.context_group_id is distinct from old.context_group_id
    or new.client_hint is distinct from old.client_hint
    or new.content_snapshot is distinct from old.content_snapshot
    or new.canonical_snapshot is distinct from old.canonical_snapshot
    or new.evidence_retention_until is distinct from old.evidence_retention_until then
    raise exception 'ugc_report_evidence_immutable' using errcode = '42501';
  end if;
  -- Vaka bagi yalniz kapanmis vakadan yeni vakaya tasinabilir. Acik vakadaki
  -- bir raporu baska vakaya kaydirmak kuyrugu bozardi.
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
$$;
drop trigger if exists ugc_reports_prevent_evidence_mutation on public.ugc_reports;
create trigger ugc_reports_prevent_evidence_mutation
before update on public.ugc_reports
for each row execute function public._prevent_ugc_report_evidence_mutation();

-- Eski altı-parametreli fonksiyon kaldırılır. Yeni son parametre varsayımlı
-- olduğundan eski istemciler altı parametreyle çağrısını sürdürebilir.
drop function if exists public.report_ugc(text, text, text, text, text, text);

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
    if v_target_id = auth.uid() or not public.can_see_user_sessions(v_target_id) then
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

create or replace function public.admin_set_ugc_report_group_status(
  p_target_type text, p_target_id text, p_status text
) returns bigint language plpgsql security definer set search_path = public as $$
declare v_count bigint;
begin
  if not public.is_super_admin() then raise exception 'not_super_admin' using errcode = '42501'; end if;
  if p_status not in ('in_review', 'resolved', 'rejected') then raise exception 'invalid_ugc_status'; end if;
  update public.moderation_cases set status = p_status, updated_at = now()
  where target_type = case when p_target_type = 'user' then 'profile' else p_target_type end
    and target_id = p_target_id and status in ('open', 'in_review');
  update public.ugc_reports set status = p_status, updated_at = now()
  where case_id in (
    select id from public.moderation_cases
    where target_type = case when p_target_type = 'user' then 'profile' else p_target_type end
      and target_id = p_target_id and status = p_status
  );
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public._enqueue_ugc_report_admin_push()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.case_id is null or new.id <> (
       select r.id from public.ugc_reports r where r.case_id = new.case_id
       order by r.created_at, r.id limit 1
     ) then return new; end if;
  insert into public.notification_outbox (event_key, recipient_id, notification_type, payload)
  select 'ugc-case:' || new.case_id::text || ':' || admin.user_id::text,
    admin.user_id, 'announcement', jsonb_build_object(
      'schema_version', '1', 'event_id', new.id::text, 'route', 'admin_moderation',
      'ugc_report_id', new.id::text, 'title', 'Yeni içerik şikâyeti',
      'body', left(new.target_type || ' · ' || new.reason, 120)
    ) from public.app_admins admin on conflict (event_key) do nothing;
  return new;
end;
$$;

comment on table public.moderation_cases is
  'WP-439: one active target case, immutable server-generated evidence retained for at least 365 days.';
