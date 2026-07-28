-- 0090_support_inbox.sql
-- WP-387: Tek destek kutusu için tür sınıflandırması, rapor referansı ve admin push bildirimi.
--
-- Mevcut geri bildirim biletleri korunur ve `feedback` olarak sınıflandırılır. UGC
-- raporları ayrı tabloda kalır; her raporun destek kutusunda bir referans bileti olur.
-- Geri alma (Rollback): Yeni bilet tetikleyicileri ileri migration ile kaldırılır;
-- `ticket_type` / `ugc_report_id` ve geçmiş referans satırları veri kaybetmeden kalır.

alter table public.feedback_tickets
  add column if not exists ticket_type text default 'feedback',
  add column if not exists ugc_report_id uuid references public.ugc_reports (id)
    on delete set null;

update public.feedback_tickets
set ticket_type = 'feedback'
where ticket_type is null;

alter table public.feedback_tickets
  alter column ticket_type set not null,
  alter column ticket_type set default 'feedback';

do $migration$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.feedback_tickets'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%ticket_type%'
  loop
    execute format(
      'alter table public.feedback_tickets drop constraint %I',
      v_constraint.conname
    );
  end loop;
end
$migration$;

alter table public.feedback_tickets
  add constraint feedback_tickets_ticket_type_check
  check (ticket_type in ('feedback', 'question', 'report'));

create unique index if not exists feedback_tickets_ugc_report_id_unique
  on public.feedback_tickets (ugc_report_id)
  where ugc_report_id is not null;

create index if not exists feedback_tickets_type_created_idx
  on public.feedback_tickets (ticket_type, created_at desc)
  where archived_at is null;

-- Geçmiş raporlar da tek destek kutusunda görünür. Kaynak tablo birleşmez; bu
-- bağlantı, bir rapora ait biletin en fazla bir kez oluşturulmasını sağlar.
insert into public.feedback_tickets (
  user_id, kind, ticket_type, ugc_report_id, subject, message, status,
  created_at, updated_at
)
select
  report.reporter_id,
  'feedback',
  'report',
  report.id,
  left('Şikâyet: ' || report.target_type || ' · ' || report.reason, 80),
  left(
    coalesce(nullif(trim(report.details), ''), 'Kullanıcı şikâyet ayrıntısı girmedi.'),
    1200
  ),
  case
    when report.status = 'open' then 'open'
    when report.status = 'in_review' then 'in_progress'
    else 'closed'
  end,
  report.created_at,
  report.updated_at
from public.ugc_reports report
where not exists (
  select 1
  from public.feedback_tickets ticket
  where ticket.ugc_report_id = report.id
);

create or replace function public._enforce_support_ticket_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Raporlar `report_ugc` RPC'sinin ayrı benzersizlik sözleşmesiyle korunur.
  if new.ticket_type <> 'report'
    and (
      select count(*)
      from public.feedback_tickets ticket
      where ticket.user_id = new.user_id
        and ticket.ticket_type in ('feedback', 'question')
        and ticket.created_at >= clock_timestamp() - interval '15 minutes'
    ) >= 3 then
    raise exception 'support_ticket_rate_limited';
  end if;
  return new;
end;
$$;

drop trigger if exists feedback_tickets_support_rate_limit on public.feedback_tickets;
create trigger feedback_tickets_support_rate_limit
before insert on public.feedback_tickets
for each row execute function public._enforce_support_ticket_rate_limit();

drop function if exists public.admin_feedback_tickets(text, boolean);
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
  order by ticket.created_at desc;
end;
$$;

revoke all on function public.admin_feedback_tickets(text, text, boolean) from public;
grant execute on function public.admin_feedback_tickets(text, text, boolean)
  to authenticated;

create or replace function public._enqueue_support_ticket_admin_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
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

drop trigger if exists feedback_tickets_enqueue_admin_push on public.feedback_tickets;
create trigger feedback_tickets_enqueue_admin_push
after insert on public.feedback_tickets
for each row execute function public._enqueue_support_ticket_admin_push();

create or replace function public.report_ugc(
  p_target_type text,
  p_target_id text,
  p_reason text,
  p_details text default null,
  p_snapshot text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.ugc_reports%rowtype;
  v_subject text;
  v_message text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_target_type not in ('message', 'user', 'group', 'profile') then
    raise exception 'invalid_type';
  end if;

  insert into public.ugc_reports (
    reporter_id, target_type, target_id, reason, details, content_snapshot
  ) values (
    auth.uid(),
    p_target_type,
    btrim(p_target_id),
    btrim(p_reason),
    nullif(btrim(coalesce(p_details, '')), ''),
    nullif(left(coalesce(p_snapshot, ''), 2000), '')
  )
  on conflict (reporter_id, target_type, target_id, reason) do update
    set updated_at = now(),
        details = coalesce(excluded.details, public.ugc_reports.details)
  returning * into v_report;

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
    user_id, kind, ticket_type, ugc_report_id, subject, message, status
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
    end
  )
  on conflict (ugc_report_id) where ugc_report_id is not null do nothing;

  return v_report.id;
end;
$$;

grant execute on function public.report_ugc(text, text, text, text, text)
  to authenticated;

-- WP-390: Bilet durumu yalnız super-admin RPC'siyle değişir ve gerçek geçiş
-- append-only denetim kaydına yazılır. 0090 henüz hiçbir remote'a uygulanmadığı
-- için aynı destek kutusu migration'ında tutulur.
create or replace function public.admin_update_feedback_status(
  p_ticket_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket record;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin';
  end if;

  if p_status not in ('open', 'in_progress', 'closed') then
    raise exception 'invalid_feedback_status';
  end if;

  select
    ticket.user_id,
    ticket.status,
    ticket.ticket_type,
    ticket.ugc_report_id,
    account.email as reporter_email
  into v_ticket
  from public.feedback_tickets ticket
  left join auth.users account on account.id = ticket.user_id
  where ticket.id = p_ticket_id
  for update of ticket;

  if not found then
    raise exception 'feedback_ticket_not_found';
  end if;

  -- Aynı durum tekrar seçildiğinde bilet veya audit geçmişi şişmez.
  if v_ticket.status = p_status then
    return;
  end if;

  update public.feedback_tickets
  set status = p_status,
      updated_at = now()
  where id = p_ticket_id;

  insert into public.admin_audit_logs (
    admin_id, target_user_id, target_user_email, action, reason
  ) values (
    auth.uid(),
    v_ticket.user_id,
    v_ticket.reporter_email,
    'support_ticket_status_changed',
    format(
      'ticket=%s type=%s report=%s status=%s→%s',
      p_ticket_id,
      v_ticket.ticket_type,
      coalesce(v_ticket.ugc_report_id::text, 'none'),
      v_ticket.status,
      p_status
    )
  );
end;
$$;

grant execute on function public.admin_update_feedback_status(uuid, text)
  to authenticated;
