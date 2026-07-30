-- 0106_moderation_appeal_evidence_audit.sql
-- WP-442: İtiraz yolu, kanıt saklama/imhası ve değiştirilemez denetim zinciri.
--
-- İşleyiş: yaptırım gören kullanıcı kendi kaydını okur ve **bir kez** itiraz
-- eder. İtirazı, yaptırımı uygulayan yöneticinin kendisi karara bağlayamaz.
-- Karar `overturned` ise yaptırım idempotent biçimde kaldırılır; `upheld` ise
-- olduğu gibi kalır. Vaka/yaptırım/itiraz üzerindeki her durum değişikliği
-- `moderation_audit_events` içine actor/zaman/eski/yeni/gerekçe ile düşer ve o
-- satırlar bir daha güncellenemez, silinemez.
--
-- Kanıt artık süresiz durmaz: `evidence_retention_until` dolduğunda içerik
-- redakte edilir, `evidence_hash` kalır — kaydın değişmediği sonradan
-- kanıtlanabilir. Açık itirazı olan kanıt imha edilmez.
--
-- Geri alma (Rollback): Uygulanmış migration geri yazılmaz. Acil degrade için
-- `submit_moderation_appeal` yetkisi geri alınır; denetim zinciri korunur.

-- ---------------------------------------------------------------------------
-- 1) Değiştirilemez denetim zinciri
-- ---------------------------------------------------------------------------

create table if not exists public.moderation_audit_events (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  actor_id uuid references auth.users(id) on delete set null,
  entity_type text not null check (entity_type in ('case', 'sanction', 'appeal')),
  entity_id uuid not null,
  action text not null check (char_length(action) between 1 and 80),
  old_value jsonb,
  new_value jsonb,
  reason text
);

create index if not exists moderation_audit_events_entity_idx
  on public.moderation_audit_events (entity_type, entity_id, occurred_at desc);

alter table public.moderation_audit_events enable row level security;
revoke all on table public.moderation_audit_events from anon, authenticated;
grant select on table public.moderation_audit_events to authenticated;

drop policy if exists moderation_audit_events_select_admin on public.moderation_audit_events;
create policy moderation_audit_events_select_admin on public.moderation_audit_events
  for select to authenticated using (public.is_super_admin());

-- Append-only: satır yazıldıktan sonra hiç kimse (super-admin dahil, tablo
-- sahibi dahil) değiştiremez ya da silemez. Tetikleyici tablo sahibinde de
-- çalışır; yalnız `revoke` yeterli olmazdı.
create or replace function public._moderation_audit_append_only()
returns trigger language plpgsql as $$
begin
  raise exception 'moderation_audit_append_only' using errcode = '42501';
end;
$$;

drop trigger if exists moderation_audit_events_immutable on public.moderation_audit_events;
create trigger moderation_audit_events_immutable
before update or delete on public.moderation_audit_events
for each row execute function public._moderation_audit_append_only();

-- `truncate` satır tetikleyicisine düşmez; zinciri tek komutla silmenin yolu
-- açık kalmasın diye ayrıca kapatılıyor.
drop trigger if exists moderation_audit_events_no_truncate on public.moderation_audit_events;
create trigger moderation_audit_events_no_truncate
before truncate on public.moderation_audit_events
for each statement execute function public._moderation_audit_append_only();

create or replace function public.moderation_audit_record(
  p_entity_type text,
  p_entity_id uuid,
  p_action text,
  p_old jsonb,
  p_new jsonb,
  p_reason text
) returns void language sql security definer set search_path = public as $$
  insert into public.moderation_audit_events (
    actor_id, entity_type, entity_id, action, old_value, new_value, reason
  ) values (auth.uid(), p_entity_type, p_entity_id, p_action, p_old, p_new, p_reason);
$$;

-- Vaka: durum, önem ve karantina değişimleri.
create or replace function public._moderation_cases_audit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb;
  v_new jsonb := jsonb_build_object(
    'status', new.status, 'severity', new.severity,
    'quarantined', new.quarantined_at is not null and new.quarantine_released_at is null
  );
begin
  if tg_op = 'INSERT' then
    perform public.moderation_audit_record('case', new.id, 'opened', null, v_new, null);
    return new;
  end if;
  v_old := jsonb_build_object(
    'status', old.status, 'severity', old.severity,
    'quarantined', old.quarantined_at is not null and old.quarantine_released_at is null
  );
  if v_old = v_new then return new; end if;
  perform public.moderation_audit_record('case', new.id, 'updated', v_old, v_new, null);
  return new;
end;
$$;

drop trigger if exists moderation_cases_audit on public.moderation_cases;
create trigger moderation_cases_audit
after insert or update on public.moderation_cases
for each row execute function public._moderation_cases_audit();

-- Yaptırım: durum ve süre değişimleri.
create or replace function public._moderation_sanctions_audit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb;
  v_new jsonb := jsonb_build_object(
    'state', new.state, 'action', new.action, 'expires_at', new.expires_at
  );
begin
  if tg_op = 'INSERT' then
    perform public.moderation_audit_record(
      'sanction', new.id, 'opened', null, v_new, new.reason
    );
    return new;
  end if;
  v_old := jsonb_build_object(
    'state', old.state, 'action', old.action, 'expires_at', old.expires_at
  );
  if v_old = v_new then return new; end if;
  perform public.moderation_audit_record(
    'sanction', new.id, 'state_changed', v_old, v_new, new.failure_reason
  );
  return new;
end;
$$;

drop trigger if exists moderation_sanctions_audit on public.moderation_sanctions;
create trigger moderation_sanctions_audit
after insert or update on public.moderation_sanctions
for each row execute function public._moderation_sanctions_audit();

-- ---------------------------------------------------------------------------
-- 2) İtiraz
-- ---------------------------------------------------------------------------

create table if not exists public.moderation_appeals (
  id uuid primary key default gen_random_uuid(),
  sanction_id uuid not null unique
    references public.moderation_sanctions(id) on delete restrict,
  appellant_id uuid not null references auth.users(id) on delete cascade,
  statement text not null check (char_length(btrim(statement)) between 10 and 2000),
  status text not null default 'open'
    check (status in ('open', 'upheld', 'overturned')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id) on delete set null,
  decision_note text
);

create index if not exists moderation_appeals_open_idx
  on public.moderation_appeals (created_at desc) where status = 'open';

alter table public.moderation_appeals enable row level security;
revoke all on table public.moderation_appeals from anon, authenticated;
grant select on table public.moderation_appeals to authenticated;

-- İtiraz eden yalnız kendi itirazını görür; karşı tarafın ya da raporlayanın
-- kimliği bu tabloda hiç yoktur.
drop policy if exists moderation_appeals_select_own on public.moderation_appeals;
create policy moderation_appeals_select_own on public.moderation_appeals
  for select to authenticated
  using (appellant_id = auth.uid() or public.is_super_admin());

create or replace function public._moderation_appeals_audit()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.moderation_audit_record(
      'appeal', new.id, 'submitted', null,
      jsonb_build_object('status', new.status, 'sanction_id', new.sanction_id), null
    );
    return new;
  end if;
  if old.status is not distinct from new.status then return new; end if;
  perform public.moderation_audit_record(
    'appeal', new.id, 'decided',
    jsonb_build_object('status', old.status),
    jsonb_build_object('status', new.status),
    new.decision_note
  );
  return new;
end;
$$;

drop trigger if exists moderation_appeals_audit on public.moderation_appeals;
create trigger moderation_appeals_audit
after insert or update on public.moderation_appeals
for each row execute function public._moderation_appeals_audit();

create or replace function public.submit_moderation_appeal(
  p_sanction_id uuid,
  p_statement text
) returns public.moderation_appeals
language plpgsql security definer set search_path = public as $$
declare
  v_sanction public.moderation_sanctions%rowtype;
  v_appeal public.moderation_appeals%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  select * into v_sanction from public.moderation_sanctions where id = p_sanction_id;
  if not found or v_sanction.target_user_id <> auth.uid() then
    -- Başkasının yaptırımının varlığını sızdırmamak için ikisi de aynı hata.
    raise exception 'sanction_not_found' using errcode = '42501';
  end if;
  if v_sanction.state <> 'applied' then
    raise exception 'sanction_not_appealable';
  end if;

  -- Tekrar gönderim yeni itiraz açmaz; mevcut itirazı geri verir.
  select * into v_appeal from public.moderation_appeals
  where sanction_id = p_sanction_id;
  if found then return v_appeal; end if;

  insert into public.moderation_appeals (sanction_id, appellant_id, statement)
  values (p_sanction_id, auth.uid(), btrim(p_statement))
  returning * into v_appeal;

  -- Açık itirazı olan kanıt imha edilmez: saklama süresi ileri atılır.
  update public.ugc_reports
  set evidence_retention_until = greatest(
    evidence_retention_until, now() + interval '180 days'
  )
  where case_id = v_sanction.case_id;

  return v_appeal;
end;
$$;

create or replace function public.admin_decide_moderation_appeal(
  p_appeal_id uuid,
  p_outcome text,
  p_note text
) returns public.moderation_appeals
language plpgsql security definer set search_path = public as $$
declare
  v_appeal public.moderation_appeals%rowtype;
  v_sanction public.moderation_sanctions%rowtype;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;
  if p_outcome not in ('upheld', 'overturned') then
    raise exception 'invalid_appeal_outcome';
  end if;
  if nullif(btrim(coalesce(p_note, '')), '') is null then
    raise exception 'appeal_note_required';
  end if;

  select * into v_appeal from public.moderation_appeals where id = p_appeal_id;
  if not found then raise exception 'appeal_not_found'; end if;
  -- Karar verilmiş itiraz yeniden karara bağlanmaz; çağrı idempotenttir.
  if v_appeal.status <> 'open' then return v_appeal; end if;

  select * into v_sanction from public.moderation_sanctions
  where id = v_appeal.sanction_id;
  -- Kendi kararını kendisi denetleyemez.
  if v_sanction.actor_id = auth.uid() then
    raise exception 'appeal_conflict_of_interest' using errcode = '42501';
  end if;

  update public.moderation_appeals
  set status = p_outcome, decided_at = now(), decided_by = auth.uid(),
      decision_note = btrim(p_note)
  where id = p_appeal_id returning * into v_appeal;

  if p_outcome = 'overturned' and v_sanction.state in ('pending', 'applied') then
    -- Yaptırımın kaldırılması idempotenttir: zaten geri alınmışsa dokunulmaz.
    update public.moderation_sanctions
    set state = 'revoked', revoked_at = now(), revoked_by = auth.uid()
    where id = v_sanction.id and state in ('pending', 'applied');
  end if;

  return v_appeal;
end;
$$;

create or replace function public.admin_moderation_appeals()
returns table (
  id uuid, sanction_id uuid, appellant_id uuid, statement text, status text,
  created_at timestamptz, sanction_action text, sanction_reason text,
  sanction_actor_id uuid, decidable boolean
)
language plpgsql security definer set search_path = public stable as $$
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;
  return query
  select a.id, a.sanction_id, a.appellant_id, a.statement, a.status, a.created_at,
    s.action, s.reason, s.actor_id, s.actor_id is distinct from auth.uid()
  from public.moderation_appeals a
  join public.moderation_sanctions s on s.id = a.sanction_id
  order by (a.status = 'open') desc, a.created_at desc;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Kanıt: değişmezlik imzası, redaksiyon ve okuma kısıtı
-- ---------------------------------------------------------------------------

alter table public.ugc_reports
  add column if not exists evidence_hash text,
  add column if not exists evidence_redacted_at timestamptz;

create or replace function public._ugc_report_evidence_hash()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.canonical_snapshot is not null and new.evidence_hash is null then
    new.evidence_hash := encode(
      sha256(convert_to(new.canonical_snapshot::text, 'UTF8')), 'hex'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists ugc_reports_evidence_hash on public.ugc_reports;
create trigger ugc_reports_evidence_hash
before insert on public.ugc_reports
for each row execute function public._ugc_report_evidence_hash();

update public.ugc_reports
set evidence_hash = encode(
  sha256(convert_to(canonical_snapshot::text, 'UTF8')), 'hex'
)
where canonical_snapshot is not null and evidence_hash is null;

-- `0104` kanıt alanlarını tamamen dondurmuştu; saklama süresi dolduğunda imha
-- edilemiyordu. Artık **yalnız** süresi dolmuş kaydın **null'a** redaksiyonuna
-- izin var: içerik silinir, `evidence_hash` yerinde kalır.
create or replace function public._prevent_ugc_report_evidence_mutation()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_redacting boolean := old.evidence_retention_until <= now()
    and new.canonical_snapshot is null
    and new.content_snapshot is null
    and new.client_hint is null
    and new.evidence_redacted_at is not null;
begin
  if new.reporter_id is distinct from old.reporter_id
    or new.target_type is distinct from old.target_type
    or new.target_id is distinct from old.target_id
    or new.context_group_id is distinct from old.context_group_id
    or new.evidence_hash is distinct from old.evidence_hash then
    raise exception 'ugc_report_evidence_immutable' using errcode = '42501';
  end if;
  if not v_redacting and (
      new.client_hint is distinct from old.client_hint
      or new.content_snapshot is distinct from old.content_snapshot
      or new.canonical_snapshot is distinct from old.canonical_snapshot
      or new.evidence_retention_until is distinct from old.evidence_retention_until
    ) then
    -- Saklama süresinin uzatılması yalnız itiraz akışındaki RPC'den gelir;
    -- oradaki update bu tetikleyiciyi es geçmediği için istisnası aşağıda.
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
$$;

-- Süresi dolan ve açık itirazı olmayan kanıtı redakte eder; kaç satırın
-- imha edildiğini döner.
create or replace function public.moderation_purge_expired_evidence()
returns integer language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;
  update public.ugc_reports r
  set canonical_snapshot = null,
      content_snapshot = null,
      client_hint = null,
      evidence_redacted_at = now()
  where r.evidence_retention_until <= now()
    and r.evidence_redacted_at is null
    and not exists (
      select 1
      from public.moderation_appeals a
      join public.moderation_sanctions s on s.id = a.sanction_id
      where a.status = 'open' and s.case_id = r.case_id
    );
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Kanıt gövdesi hiçbir normal kullanıcıya açık değildir — raporlayan kendi
-- satırını okusa bile sunucunun ürettiği kanonik snapshot'ı göremez. Admin
-- yolu security-definer RPC'lerden geçtiği için bu kısıttan etkilenmez.
--
-- Tablo düzeyi `select` grantı dururken sütun grantı **geri alınamaz** (Postgres
-- sütun izni tablo iznini gölgelemez); bu yüzden tablo grantı kaldırılıp izin
-- verilen sütunlar tek tek veriliyor.
revoke select on public.ugc_reports from authenticated;
grant select (
  id, reporter_id, target_type, target_id, context_group_id, reason, details,
  status, attachment_path, case_id, client_hint, created_at, updated_at,
  evidence_retention_until, evidence_redacted_at
) on public.ugc_reports to authenticated;

revoke all on function public.submit_moderation_appeal(uuid, text) from public, anon;
grant execute on function public.submit_moderation_appeal(uuid, text) to authenticated;
revoke all on function public.admin_decide_moderation_appeal(uuid, text, text) from public, anon;
grant execute on function public.admin_decide_moderation_appeal(uuid, text, text) to authenticated;
revoke all on function public.admin_moderation_appeals() from public, anon;
grant execute on function public.admin_moderation_appeals() to authenticated;
revoke all on function public.moderation_purge_expired_evidence() from public, anon;
grant execute on function public.moderation_purge_expired_evidence() to authenticated;
revoke all on function public.moderation_audit_record(text, uuid, text, jsonb, jsonb, text) from public, anon;

comment on table public.moderation_audit_events is
  'WP-442: append-only moderation audit chain; rows can never be updated or deleted.';
comment on table public.moderation_appeals is
  'WP-442: one appeal per sanction, decided by an admin other than the one who applied it.';
