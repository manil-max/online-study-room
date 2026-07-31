-- 0105_moderation_enforcement_ladder.sql
-- WP-441: Basamaklı yaptırım, geri alınabilir karantina, önem/SLA ve kötü
-- niyetli rapor sayacı.
--
-- İşleyiş: yaptırım artık Edge Function'ın "auth'u güncelle, sonra audit yaz"
-- serbest akışı değildir. Her yaptırım önce `moderation_sanctions` içinde
-- `pending` olarak açılır (idempotency anahtarıyla tekil), auth tarafı işini
-- yapar, sonra tek transaction'da `applied|failed` durumuna alınır ve audit
-- satırı yazılır. Böylece "auth başarılı / audit başarısız" yarım durumu
-- kayıtta görünür ve uzlaştırılabilir; yeniden deneme yeni yaptırım açmaz.
--
-- Mute artık auth ban değildir: kullanıcı okumaya devam eder, yalnız yazamaz.
--
-- Geri alma (Rollback): Uygulanmış migration geri yazılmaz. Acil degrade için
-- `admin_apply_moderation_sanction` yetkisi geri alınır; aktif yaptırımlar
-- `admin_revoke_moderation_sanction` ile tek tek kaldırılır.

-- ---------------------------------------------------------------------------
-- 1) Önem (severity) ve SLA — vaka açıldığında sunucuda hesaplanır.
-- ---------------------------------------------------------------------------

alter table public.moderation_cases
  add column if not exists severity text not null default 'normal'
    check (severity in ('normal', 'high')),
  add column if not exists sla_due_at timestamptz,
  add column if not exists quarantined_at timestamptz,
  add column if not exists quarantine_released_at timestamptz,
  add column if not exists quarantined_by uuid references auth.users(id) on delete set null;

-- Yüksek önem yalnız içerik türünden gelir; "rapor geldi = suçlu" değildir.
-- Severity yalnız sıralama ve SLA içindir, hiçbir yaptırımı otomatik açmaz.
create or replace function public.moderation_case_severity(p_case_id uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
    when exists (
      select 1 from public.ugc_reports r
      where r.case_id = p_case_id and r.reason in ('hate', 'illegal')
    ) then 'high'
    when (
      select count(distinct r.reporter_id) from public.ugc_reports r
      where r.case_id = p_case_id
    ) >= 3 then 'high'
    else 'normal'
  end;
$$;

create or replace function public._refresh_moderation_case_severity()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_severity text;
begin
  if new.case_id is null then
    return new;
  end if;
  v_severity := public.moderation_case_severity(new.case_id);
  update public.moderation_cases c
  set severity = v_severity,
      sla_due_at = c.opened_at + case when v_severity = 'high'
        then interval '4 hours' else interval '48 hours' end,
      updated_at = now()
  where c.id = new.case_id
    and (c.severity is distinct from v_severity or c.sla_due_at is null);
  return new;
end;
$$;

drop trigger if exists ugc_reports_refresh_case_severity on public.ugc_reports;
create trigger ugc_reports_refresh_case_severity
after insert or update of case_id, reason on public.ugc_reports
for each row execute function public._refresh_moderation_case_severity();

update public.moderation_cases c
set severity = public.moderation_case_severity(c.id),
    sla_due_at = c.opened_at + case
      when public.moderation_case_severity(c.id) = 'high'
      then interval '4 hours' else interval '48 hours' end
where c.sla_due_at is null;

-- ---------------------------------------------------------------------------
-- 2) Yaptırım defteri — iki fazlı, idempotent, tek aktif sonuç.
-- ---------------------------------------------------------------------------

create table if not exists public.moderation_sanctions (
  id uuid primary key default gen_random_uuid(),
  case_id uuid references public.moderation_cases(id) on delete restrict,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  action text not null check (action in (
    'no_action', 'warn', 'name_reset',
    'mute_24h', 'suspend_24h', 'suspend_7d', 'suspend_14d', 'suspend_30d',
    'ban_permanent'
  )),
  reason text not null check (char_length(btrim(reason)) between 1 and 500),
  actor_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key text not null unique
    check (char_length(idempotency_key) between 8 and 120),
  state text not null default 'pending'
    check (state in ('pending', 'applied', 'failed', 'revoked')),
  failure_reason text,
  created_at timestamptz not null default now(),
  applied_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null
);

create index if not exists moderation_sanctions_target_idx
  on public.moderation_sanctions (target_user_id, created_at desc);
create index if not exists moderation_sanctions_case_idx
  on public.moderation_sanctions (case_id, created_at desc);

-- Kısıtlayıcı yaptırımlarda hedef başına tek aktif satır: aynı yaptırım iki kez
-- uygulanırsa ikinci çağrı ya aynı idempotency anahtarına düşer ya da bu indeks
-- tarafından reddedilir. Süresi dolan satır indeksten kendiliğinden çıkmaz;
-- aktiflik `moderation_active_sanction` içinde `expires_at` ile ölçülür, bu
-- yüzden yeni yaptırım açmadan önce süresi dolmuş satır `expired` sayılır.
create or replace function public.moderation_is_restrictive(p_action text)
returns boolean language sql immutable as $$
  select p_action in (
    'mute_24h', 'suspend_24h', 'suspend_7d', 'suspend_14d', 'suspend_30d',
    'ban_permanent'
  );
$$;

create unique index if not exists moderation_sanctions_one_active_idx
  on public.moderation_sanctions (target_user_id)
  where state in ('pending', 'applied')
    and public.moderation_is_restrictive(action);

alter table public.moderation_sanctions enable row level security;
revoke all on table public.moderation_sanctions from anon, authenticated;
grant select on table public.moderation_sanctions to authenticated;

-- Hedef kullanıcı yalnız kendi yaptırımını görür. Tabloda raporlayan kimliği
-- yoktur; `case_id` üzerinden vakaya erişim admin politikasına bağlıdır, yani
-- yaptırım gören kişi kendisini kimin şikâyet ettiğini göremez.
drop policy if exists moderation_sanctions_select_own on public.moderation_sanctions;
create policy moderation_sanctions_select_own on public.moderation_sanctions
  for select to authenticated
  using (target_user_id = auth.uid() or public.is_super_admin());

-- İstemci yaptırım yazamaz: insert/update/delete grantı yok ve tabloda yazma
-- politikası tanımlı değil; tek yol aşağıdaki RPC'lerdir.
create or replace function public.moderation_active_sanction(p_user_id uuid)
returns public.moderation_sanctions
language sql stable security definer set search_path = public as $$
  select s.* from public.moderation_sanctions s
  where s.target_user_id = p_user_id
    and s.state = 'applied'
    and public.moderation_is_restrictive(s.action)
    and (s.expires_at is null or s.expires_at > now())
  order by s.applied_at desc
  limit 1;
$$;

-- Yalnız yazma kısıtı: okuma açık kalır, auth ban kurulmaz.
create or replace function public.moderation_is_muted(p_user_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.moderation_sanctions s
    where s.target_user_id = p_user_id
      and s.state = 'applied'
      and s.action = 'mute_24h'
      and (s.expires_at is null or s.expires_at > now())
  );
$$;

drop policy if exists class_messages_insert on public.class_messages;
create policy class_messages_insert on public.class_messages
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and public.is_group_member(group_id)
    -- WP-441: susturulmuş kullanıcı okumaya devam eder, yazamaz.
    and not public.moderation_is_muted(auth.uid())
  );

-- ---------------------------------------------------------------------------
-- 3) İki fazlı uygulama: aç → auth işini yap → kapat (audit aynı transaction).
-- ---------------------------------------------------------------------------

create or replace function public.admin_begin_moderation_sanction(
  p_target_user_id uuid,
  p_action text,
  p_reason text,
  p_idempotency_key text,
  p_case_id uuid default null
) returns public.moderation_sanctions
language plpgsql security definer set search_path = public as $$
declare
  v_row public.moderation_sanctions%rowtype;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'sanction_reason_required';
  end if;

  -- Tekrar gönderim yeni yaptırım açmaz; açık kaydı geri verir.
  select * into v_row from public.moderation_sanctions
  where idempotency_key = p_idempotency_key;
  if found then
    if v_row.target_user_id <> p_target_user_id or v_row.action <> p_action then
      raise exception 'sanction_idempotency_conflict';
    end if;
    return v_row;
  end if;

  if public.moderation_is_restrictive(p_action) then
    -- Süresi dolmuş kısıt yeni yaptırımın önünde durmasın.
    update public.moderation_sanctions
    set state = 'revoked', revoked_at = coalesce(revoked_at, expires_at)
    where target_user_id = p_target_user_id
      and state = 'applied'
      and public.moderation_is_restrictive(action)
      and expires_at is not null
      and expires_at <= now();

    -- 🔴 Kapı, `moderation_sanctions_one_active_idx` yüklemiyle **aynı kümeye**
    -- bakmak zorundadır. Index `pending` durumunu da kapsıyor; koruma yalnız
    -- `applied`'a bakınca (eski hâl) bekleyen bir kısıt varken ikinci istek
    -- anlaşılır `sanction_already_active` yerine ham `23505 unique_violation`
    -- ile düşüyordu — iki fazlı tasarımın tam da normal akışında.
    -- `moderation_active_sanction` bilerek değiştirilmedi: kullanıcı yüzeyinde
    -- "aktif kısıt" **uygulanmış** kısıt demektir, açılmayı bekleyen değil.
    if exists (
      select 1 from public.moderation_sanctions
      where target_user_id = p_target_user_id
        and state in ('pending', 'applied')
        and public.moderation_is_restrictive(action)
    ) then
      raise exception 'sanction_already_active';
    end if;
  end if;

  insert into public.moderation_sanctions (
    case_id, target_user_id, action, reason, actor_id, idempotency_key
  ) values (
    p_case_id, p_target_user_id, p_action, btrim(p_reason), auth.uid(),
    p_idempotency_key
  ) returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.admin_finish_moderation_sanction(
  p_sanction_id uuid,
  p_succeeded boolean,
  p_failure_reason text default null
) returns public.moderation_sanctions
language plpgsql security definer set search_path = public as $$
declare
  v_row public.moderation_sanctions%rowtype;
  v_expires timestamptz;
  v_email text;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;
  select * into v_row from public.moderation_sanctions where id = p_sanction_id;
  if not found then raise exception 'sanction_not_found'; end if;
  if v_row.state <> 'pending' then
    -- Kapanmış yaptırım yeniden kapatılmaz; çağrı idempotenttir.
    return v_row;
  end if;

  if not p_succeeded then
    update public.moderation_sanctions
    set state = 'failed', failure_reason = left(coalesce(p_failure_reason, 'unknown'), 200)
    where id = p_sanction_id returning * into v_row;
    return v_row;
  end if;

  v_expires := case v_row.action
    when 'mute_24h' then now() + interval '24 hours'
    when 'suspend_24h' then now() + interval '24 hours'
    when 'suspend_7d' then now() + interval '7 days'
    when 'suspend_14d' then now() + interval '14 days'
    when 'suspend_30d' then now() + interval '30 days'
    else null
  end;

  update public.moderation_sanctions
  set state = 'applied', applied_at = now(), expires_at = v_expires
  where id = p_sanction_id returning * into v_row;

  select u.email into v_email from auth.users u where u.id = v_row.target_user_id;
  insert into public.admin_audit_logs (
    admin_id, target_user_id, target_user_email, action, reason
  ) values (
    v_row.actor_id, v_row.target_user_id, v_email,
    'moderation:' || v_row.action, v_row.reason
  );

  -- Uyarı gerçekten iletilir: hem kalıcı kayıt (kullanıcı kendi satırını okur)
  -- hem de push kuyruğu. Daha önce `warn_user` hiçbir şey yapmıyordu.
  if v_row.action in ('warn', 'mute_24h') then
    insert into public.notification_outbox (
      event_key, recipient_id, notification_type, payload
    ) values (
      'moderation-sanction:' || v_row.id::text,
      v_row.target_user_id,
      'announcement',
      jsonb_build_object(
        'schema_version', '1',
        'event_id', v_row.id::text,
        'route', 'safety_notice',
        'title', case when v_row.action = 'warn'
          then 'Topluluk kuralları uyarısı' else 'Mesaj yazma kısıtı' end,
        'body', left(v_row.reason, 120)
      )
    ) on conflict (event_key) do nothing;
  end if;

  return v_row;
end;
$$;

create or replace function public.admin_revoke_moderation_sanction(
  p_sanction_id uuid,
  p_reason text
) returns public.moderation_sanctions
language plpgsql security definer set search_path = public as $$
declare
  v_row public.moderation_sanctions%rowtype;
  v_email text;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'sanction_reason_required';
  end if;
  update public.moderation_sanctions
  set state = 'revoked', revoked_at = now(), revoked_by = auth.uid()
  where id = p_sanction_id and state in ('pending', 'applied')
  returning * into v_row;
  if not found then raise exception 'sanction_not_revocable'; end if;

  select u.email into v_email from auth.users u where u.id = v_row.target_user_id;
  insert into public.admin_audit_logs (
    admin_id, target_user_id, target_user_email, action, reason
  ) values (
    auth.uid(), v_row.target_user_id, v_email,
    'moderation:revoke:' || v_row.action, btrim(p_reason)
  );
  return v_row;
end;
$$;

-- Auth tarafı başarılı olup kapanış çağrısı düşerse satır `pending` kalır.
-- Uzlaştırma: belirli süre sonra kayıt `failed` olarak işaretlenir; `pending`
-- satır hiçbir zaman aktif yaptırım saymaz, bu yüzden kullanıcı yarım durumda
-- cezalı kalmaz ve admin yeniden uygulayabilir.
create or replace function public.admin_reconcile_moderation_sanctions()
returns integer language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;
  update public.moderation_sanctions
  set state = 'failed', failure_reason = 'reconciled_timeout'
  where state = 'pending' and created_at < now() - interval '15 minutes';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Geri alınabilir karantina — inceleme bitene kadar içerik gizlenir.
-- ---------------------------------------------------------------------------

create or replace function public.is_message_quarantined(p_message_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.moderation_cases c
    where c.target_type = 'message'
      and c.target_id = p_message_id::text
      and c.quarantined_at is not null
      and c.quarantine_released_at is null
  );
$$;

drop policy if exists class_messages_select on public.class_messages;
create policy class_messages_select on public.class_messages
  for select to authenticated
  using (
    public.is_group_member(group_id)
    and (
      public.is_super_admin()
      or user_id = auth.uid()
      or not public.is_message_quarantined(id)
    )
  );

-- Karantina kontrolü her sohbet satırında çalışır; kısmi indeks olmadan
-- `class_messages` seçimi vaka tablosunda seq scan'e düşerdi.
create index if not exists moderation_cases_quarantine_idx
  on public.moderation_cases (target_type, target_id)
  where quarantined_at is not null and quarantine_released_at is null;

create or replace function public.admin_set_case_quarantine(
  p_case_id uuid,
  p_quarantined boolean,
  p_reason text
) returns public.moderation_cases
language plpgsql security definer set search_path = public as $$
declare
  v_case public.moderation_cases%rowtype;
  v_email text;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'sanction_reason_required';
  end if;
  update public.moderation_cases
  set quarantined_at = case when p_quarantined then coalesce(quarantined_at, now()) else quarantined_at end,
      quarantine_released_at = case when p_quarantined then null else coalesce(quarantine_released_at, now()) end,
      quarantined_by = auth.uid(),
      updated_at = now()
  where id = p_case_id
  returning * into v_case;
  if not found then raise exception 'moderation_case_not_found'; end if;

  insert into public.admin_audit_logs (
    admin_id, target_user_id, target_user_email, action, reason
  ) values (
    auth.uid(), null, null,
    case when p_quarantined then 'moderation:quarantine' else 'moderation:quarantine_release' end,
    btrim(p_reason)
  );
  return v_case;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Kötü niyetli rapor sayacı — reddedilen vakalar raporlayana geri sayılır.
-- ---------------------------------------------------------------------------

create or replace function public.admin_reporter_abuse_score(p_reporter_id uuid)
returns jsonb language plpgsql security definer set search_path = public stable as $$
declare v_total bigint; v_rejected bigint;
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;
  select count(*), count(*) filter (where c.status = 'rejected')
  into v_total, v_rejected
  from public.ugc_reports r
  left join public.moderation_cases c on c.id = r.case_id
  where r.reporter_id = p_reporter_id;
  return jsonb_build_object(
    'total_reports', v_total,
    'rejected_reports', v_rejected,
    -- Eşik yalnız admin'e sinyaldir; otomatik yaptırım açmaz.
    'flagged', v_rejected >= 3 and v_rejected * 2 >= v_total
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) Yanlışlıkla kapatılan vaka tam olarak `open`'a döner (WP-440 kod borcu).
-- ---------------------------------------------------------------------------

-- Kuyruk artık raporları kendi kendine gruplamıyor; `moderation_cases` tek
-- gerçektir. `case_id` taşımayan tarihsel satırlar (kapanmış eski raporlar)
-- kuyruktan düşmesin diye ikinci kolda olduğu gibi korunur.
drop function if exists public.admin_ugc_report_groups();
create or replace function public.admin_ugc_report_groups()
returns table (
  case_id uuid, target_type text, target_id text, report_count bigint,
  report_ids uuid[], reasons text[], status text, latest_at timestamptz,
  severity text, sla_due_at timestamptz, quarantined boolean
)
language plpgsql security definer set search_path = public stable as $$
begin
  if not public.is_super_admin() then
    raise exception 'not_super_admin' using errcode = '42501';
  end if;
  return query
  select c.id, c.target_type, c.target_id, count(r.id),
    coalesce(array_agg(r.id order by r.created_at desc)
      filter (where r.id is not null), '{}'::uuid[]),
    coalesce(array_agg(distinct r.reason)
      filter (where r.reason is not null), '{}'::text[]),
    c.status, coalesce(max(r.created_at), c.opened_at),
    c.severity, c.sla_due_at,
    (c.quarantined_at is not null and c.quarantine_released_at is null)
  from public.moderation_cases c
  left join public.ugc_reports r on r.case_id = c.id
  group by c.id
  union all
  select null::uuid, r.target_type, r.target_id, count(*),
    array_agg(r.id order by r.created_at desc),
    array_agg(distinct r.reason),
    case when bool_or(r.status = 'open') then 'open' else max(r.status) end,
    max(r.created_at), 'normal', null::timestamptz, false
  from public.ugc_reports r
  where r.case_id is null
  group by r.target_type, r.target_id
  order by 8 desc;
end;
$$;
revoke all on function public.admin_ugc_report_groups() from public, anon;
grant execute on function public.admin_ugc_report_groups() to authenticated;


create or replace function public.admin_set_ugc_report_group_status(
  p_target_type text, p_target_id text, p_status text
) returns bigint language plpgsql security definer set search_path = public as $$
declare v_count bigint; v_type text;
begin
  if not public.is_super_admin() then raise exception 'not_super_admin' using errcode = '42501'; end if;
  if p_status not in ('open', 'in_review', 'resolved', 'rejected') then
    raise exception 'invalid_ugc_status';
  end if;
  v_type := case when p_target_type = 'user' then 'profile' else p_target_type end;
  update public.moderation_cases set status = p_status, updated_at = now()
  where target_type = v_type and target_id = p_target_id
    and status is distinct from p_status;
  update public.ugc_reports set status = p_status, updated_at = now()
  where case_id in (
    select id from public.moderation_cases
    where target_type = v_type and target_id = p_target_id and status = p_status
  );
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.admin_begin_moderation_sanction(uuid, text, text, text, uuid) from public, anon;
grant execute on function public.admin_begin_moderation_sanction(uuid, text, text, text, uuid) to authenticated;
revoke all on function public.admin_finish_moderation_sanction(uuid, boolean, text) from public, anon;
grant execute on function public.admin_finish_moderation_sanction(uuid, boolean, text) to authenticated;
revoke all on function public.admin_revoke_moderation_sanction(uuid, text) from public, anon;
grant execute on function public.admin_revoke_moderation_sanction(uuid, text) to authenticated;
revoke all on function public.admin_reconcile_moderation_sanctions() from public, anon;
grant execute on function public.admin_reconcile_moderation_sanctions() to authenticated;
revoke all on function public.admin_set_case_quarantine(uuid, boolean, text) from public, anon;
grant execute on function public.admin_set_case_quarantine(uuid, boolean, text) to authenticated;
revoke all on function public.admin_reporter_abuse_score(uuid) from public, anon;
grant execute on function public.admin_reporter_abuse_score(uuid) to authenticated;

comment on table public.moderation_sanctions is
  'WP-441: two-phase, idempotent enforcement ladder; at most one active restrictive sanction per user.';
