-- 0101_global_timer_controller_contract.sql
-- WP-431: kanonik timer komut protokolü — hesap-geneli tek aktif koşu, kira
-- farkındalığı ve çevrimdışı başlangıç zamanının güvenli kabulü.
--
-- WP-430 kanıtı (`docs/qa/V57-TIMER-EVIDENCE.md`) üç sunucu kusurunu gösterdi:
--
--   K2/K3  Okuma yolu kirayı yalnız RAPORLUYOR, süzmüyordu. Süpürücü (`0089`,
--          dakikalık, 200 satır/tur) gecikirse `_global_timer_v2_snapshot`
--          kirası saatler önce dolmuş bir koşuyu `running` diye döndürüyordu ve
--          ayna cihaz onu canlı sayaç olarak açıyordu (V56-S04 hayalet koşu).
--          Çözüm: snapshot artık `lease_expired` hesaplar. `status` DEĞİŞMEZ —
--          veri dürüst kalır, kararı istemci bu bayrakla verir.
--
--   —      `effective_started_at` HER ZAMAN `clock_timestamp()` idi. Çevrimdışı
--          başlatılıp saatler sonra flush edilen bir koşu, başlangıcını flush
--          anına kaydırıyordu. Artık `p_client_occurred_at` kabul edilir ama
--          **sınırlandırılır**: geçmişe en fazla 24 saat, geleceğe hiç.
--
--   —      Hesap-geneli "tek aktif koşu" bir invariant olarak yazılı değildi;
--          yalnız uygulama mantığına güveniliyordu. Artık kısmi unique index.
--
-- Ayrıca istemci saati bozuk/kötü niyetli bir cihaz gelecekten komut
-- gönderemez (`client_clock_skew_rejected`).
--
-- DEĞİŞMEYEN sözleşmeler (bilerek korunur):
--   * `0088`in timer_sync outbox enqueue gövdesi birebir korunur.
--   * Dedupe (`command_id` + fingerprint), advisory lock, presence çağrıları,
--     `adopt_existing` / `already_stopped` / `stale` sonuç kodları aynı.
--   * Kira süpürücüsü (`0089`) oturum UYDURMAZ; koşuyu yalnız `abandoned` yapar.
--   * `0082/0087/0088/0089` dosyalarına dokunulmaz; bu ileri migration'dır.
--
-- Geri alma (Rollback):
--   drop index if exists public.live_study_runs_v2_single_active_idx;
--   -- ve `0088`deki apply_global_timer_command gövdesini yeniden çalıştır.
--   -- Şema kaybı yoktur; snapshot `lease_expired` alanını okumayan istemci
--   -- yalnız yaş sınırına düşer (fail-safe), çökmez.

-- ---------------------------------------------------------------------------
-- 1. Hesap-geneli tek aktif V2 koşusu (invariant)
-- ---------------------------------------------------------------------------

-- Index oluşmadan önce olası ihlalleri kapat: aynı hesapta birden fazla
-- `running` v2 koşusu varsa en yenisi kalır, diğerleri `abandoned` olur.
-- Bu bir veri düzeltmesi değil, invariant'ın ön koşuludur; oturum üretmez.
with ranked as (
  select id, user_id,
         row_number() over (
           partition by user_id
           order by coalesce(lease_expires_at, effective_started_at) desc, id desc
         ) as rn
  from public.live_study_runs
  where protocol_version = 2 and status = 'running'
)
update public.live_study_runs r
set status = 'abandoned',
    ended_at = coalesce(r.ended_at, clock_timestamp()),
    lease_expires_at = null,
    run_revision = r.run_revision + 1,
    updated_at = clock_timestamp()
from ranked
where ranked.id = r.id and ranked.rn > 1;

create unique index if not exists live_study_runs_v2_single_active_idx
  on public.live_study_runs(user_id)
  where protocol_version = 2 and status = 'running';

-- ---------------------------------------------------------------------------
-- 2. Kira farkındalığı olan snapshot
-- ---------------------------------------------------------------------------

create or replace function public._global_timer_v2_snapshot(
  p_user_id uuid,
  p_device_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select jsonb_build_object(
    'user_id', p_user_id,
    'server_time', clock_timestamp(),
    'state_version', coalesce(s.state_version, 0),
    'run', case when r.id is null then null else jsonb_build_object(
      'id', r.id,
      'status', r.status,
      'protocol_version', r.protocol_version,
      'run_revision', r.run_revision,
      'user_state_version', r.user_state_version,
      'effective_started_at', r.effective_started_at,
      'lease_expires_at', r.lease_expires_at,
      -- WP-431 (K3): kararı istemciye bırakmadan önce gerçeği sunucu söyler.
      -- `status` bilerek değiştirilmez: süpürücü henüz geçmemiş olabilir ama
      -- koşu görüntülenebilir DEĞİLDİR. İstemci saatine güvenilmez.
      'lease_expired', (
        r.status = 'running'
        and r.protocol_version = 2
        and r.lease_expires_at is not null
        and r.lease_expires_at <= clock_timestamp()
      ),
      'controller_device_id', r.controller_device_id,
      'origin', r.origin
    ) end,
    'device', case when d.device_id is null then null else jsonb_build_object(
      'last_seen_state_version', d.last_seen_state_version,
      'last_applied_state_version', d.last_applied_state_version,
      'last_apply_status', d.last_apply_status
    ) end
  )
  from (select p_user_id as user_id) u
  left join public.user_timer_state s on s.user_id = u.user_id
  left join public.live_study_runs r on r.id = s.current_run_id
  left join public.global_timer_device_state d
    on d.user_id = u.user_id and d.device_id = p_device_id;
$$;

-- ---------------------------------------------------------------------------
-- 3. Komut uygulama — çevrimdışı başlangıç zamanı ve saat kayması
-- ---------------------------------------------------------------------------

create or replace function public.apply_global_timer_command(
  p_command_id uuid,
  p_device_id uuid,
  p_action text,
  p_run_id uuid default null,
  p_expected_run_revision bigint default null,
  p_client_occurred_at timestamptz default null,
  p_payload jsonb default '{}'::jsonb,
  p_protocol_version integer default 2
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_existing public.global_timer_commands%rowtype;
  v_state public.user_timer_state%rowtype;
  v_run public.live_study_runs%rowtype;
  v_snapshot jsonb;
  v_fingerprint jsonb;
  v_result text := 'applied';
  v_now timestamptz := clock_timestamp();
  v_primary_group_id uuid;
  v_subject_id uuid;
  v_origin text;
  v_started_at timestamptz;
begin
  if v_uid is null then raise exception 'authentication_required'; end if;
  if p_command_id is null or p_device_id is null or p_protocol_version <> 2
     or p_action not in ('start', 'stop', 'heartbeat')
     or p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'invalid_global_timer_command';
  end if;
  -- WP-431: gelecekten gelen komut kabul edilmez. İstemci saati bozuksa ya da
  -- kayıt kurcalandıysa, ileri tarihli bir başlangıç sonsuza kadar "yeni"
  -- görünen bir koşu üretirdi. 120 sn makul saat kayması payıdır.
  if p_client_occurred_at is not null
     and p_client_occurred_at > v_now + interval '120 seconds' then
    raise exception 'client_clock_skew_rejected';
  end if;
  if not (select v2_enabled from public.global_timer_v2_runtime_config where singleton) then
    raise exception 'global_timer_v2_disabled';
  end if;
  if not exists (
    select 1 from public.push_devices
    where id = p_device_id and user_id = v_uid and disabled_at is null
  ) then
    raise exception 'active_device_required';
  end if;

  v_fingerprint := jsonb_build_object(
    'action', p_action, 'run_id', p_run_id,
    'expected_run_revision', p_expected_run_revision,
    'payload', p_payload, 'protocol_version', p_protocol_version
  );
  select * into v_existing from public.global_timer_commands
  where user_id = v_uid and command_id = p_command_id;
  if found then
    if v_existing.request_fingerprint <> v_fingerprint then
      raise exception 'command_id_payload_mismatch';
    end if;
    return v_existing.result_snapshot || jsonb_build_object('result_code', 'duplicate');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 216));
  insert into public.user_timer_state(user_id) values (v_uid)
  on conflict (user_id) do nothing;
  select * into v_state from public.user_timer_state where user_id = v_uid for update;

  insert into public.global_timer_device_state(user_id, device_id, last_seen_at, updated_at)
  values (v_uid, p_device_id, v_now, v_now)
  on conflict (user_id, device_id) do update set
    last_seen_at = excluded.last_seen_at, updated_at = excluded.updated_at;

  if p_action = 'start' then
    select * into v_run from public.live_study_runs
    where user_id = v_uid and run_kind = 'study' and status in ('running', 'paused')
    order by created_at desc limit 1 for update;
    if found and v_run.protocol_version = 2
       and v_run.status = 'running' and v_run.lease_expires_at <= v_now then
      update public.live_study_runs set
        status = 'abandoned', ended_at = v_now, lease_expires_at = null,
        run_revision = run_revision + 1,
        user_state_version = v_state.state_version + 1,
        updated_at = v_now
      where id = v_run.id returning * into v_run;
      update public.user_timer_state set state_version = state_version + 1,
        current_run_id = null, updated_at = v_now where user_id = v_uid
      returning * into v_state;
      perform public.apply_multi_group_presence_state('offline', null, 0, null);
      v_run := null;
    end if;

    if v_run.id is not null then
      v_result := 'adopt_existing';
    else
      v_subject_id := nullif(p_payload->>'subject_id', '')::uuid;
      if v_subject_id is not null and not exists (
        select 1 from public.subjects where id = v_subject_id and user_id = v_uid
      ) then raise exception 'subject_ownership_required'; end if;
      v_origin := coalesce(nullif(p_payload->>'origin', ''), 'app');
      if v_origin not in ('app', 'widget', 'notification', 'recovery') then
        raise exception 'invalid_global_timer_origin';
      end if;
      -- WP-431: çevrimdışı başlatılan koşu gerçek başlangıcını korur, ama
      -- sınırsız değil. Geçmişe en fazla 24 saat (kuyruk zaten 24 saatten eski
      -- start'ı düşürür), geleceğe hiç. Sınır dışı değer sessizce kırpılır:
      -- komutu reddetmek kullanıcının çalışmasını tamamen kaybettirirdi.
      v_started_at := least(
        greatest(coalesce(p_client_occurred_at, v_now), v_now - interval '24 hours'),
        v_now
      );
      select p.primary_group_id into v_primary_group_id
      from public.user_group_preferences p
      join public.group_members gm on gm.group_id = p.primary_group_id
        and gm.user_id = v_uid and gm.left_at is null
      where p.user_id = v_uid;
      update public.user_timer_state set state_version = state_version + 1,
        updated_at = v_now where user_id = v_uid returning * into v_state;
      insert into public.live_study_runs(
        user_id, client_request_id, group_id_snapshot, subject_id_snapshot,
        status, protocol_version, run_kind, effective_started_at,
        accounting_group_id_snapshot, origin, controller_device_id,
        run_revision, user_state_version, lease_expires_at, updated_at
      ) values (
        v_uid, p_command_id, v_primary_group_id, v_subject_id,
        'running', 2, 'study', v_started_at,
        v_primary_group_id, v_origin, p_device_id,
        1, v_state.state_version, v_now + interval '150 seconds', v_now
      ) returning * into v_run;
      update public.user_timer_state set current_run_id = v_run.id,
        updated_at = v_now where user_id = v_uid;
      perform public.apply_multi_group_presence_state('studying', v_started_at, 0, v_subject_id);
    end if;
  elsif p_action = 'stop' then
    if p_run_id is null or p_expected_run_revision is null then
      raise exception 'stop_run_revision_required';
    end if;
    select * into v_run from public.live_study_runs
    where id = p_run_id and user_id = v_uid for update;
    if not found then raise exception 'global_timer_run_not_found'; end if;
    if v_run.protocol_version <> 2 then raise exception 'global_timer_v2_run_required'; end if;
    -- WP-431: terminal durum HER ZAMAN üstün gelir. Kirası dolmuş ama henüz
    -- süpürülmemiş bir koşuya gelen stop da kabul edilir; hiçbir yol bu koşuyu
    -- yeniden `running` yapamaz.
    if v_run.status in ('stopped', 'abandoned') then
      v_result := 'already_stopped';
    elsif v_run.run_revision <> p_expected_run_revision then
      v_result := 'stale';
    else
      update public.user_timer_state set state_version = state_version + 1,
        current_run_id = case when current_run_id = v_run.id then null else current_run_id end,
        updated_at = v_now where user_id = v_uid returning * into v_state;
      update public.live_study_runs set status = 'stopped', ended_at = v_now,
        lease_expires_at = null, controller_device_id = p_device_id,
        run_revision = run_revision + 1, user_state_version = v_state.state_version,
        updated_at = v_now where id = v_run.id returning * into v_run;
      perform public.apply_multi_group_presence_state('offline', null, 0, null);
    end if;
  else
    if p_run_id is null then raise exception 'heartbeat_run_required'; end if;
    select * into v_run from public.live_study_runs
    where id = p_run_id and user_id = v_uid for update;
    if not found or v_run.protocol_version <> 2 or v_run.status <> 'running' then
      raise exception 'global_timer_run_not_active';
    end if;
    if p_expected_run_revision is not null and v_run.run_revision <> p_expected_run_revision then
      v_result := 'stale';
    else
      update public.live_study_runs set lease_expires_at = v_now + interval '150 seconds',
        controller_device_id = p_device_id, updated_at = v_now
      where id = v_run.id returning * into v_run;
    end if;
  end if;

  -- 0088 sözleşmesi — DEĞİŞMEDİ. Yalnız state geçişi oluşturan start/stop
  -- komutları B cihazlarına sinyal üretir. Adopt/stale/duplicate/heartbeat yeni
  -- bir kullanıcı state'i değildir.
  if v_result = 'applied' and p_action in ('start', 'stop') then
    perform public._enqueue_global_timer_v2_sync(
      v_uid, v_run.id, v_state.state_version, v_run.run_revision,
      p_device_id, p_command_id
    );
  end if;

  v_snapshot := public._global_timer_v2_snapshot(v_uid, p_device_id);
  insert into public.global_timer_commands(
    user_id, command_id, device_id, action, run_id, expected_run_revision,
    accepted_run_revision, accepted_state_version, client_occurred_at,
    payload, request_fingerprint, result_code, result_snapshot
  ) values (
    v_uid, p_command_id, p_device_id, p_action, coalesce(v_run.id, p_run_id),
    p_expected_run_revision, v_run.run_revision,
    coalesce(v_run.user_state_version, v_state.state_version), p_client_occurred_at,
    p_payload, v_fingerprint, v_result, v_snapshot || jsonb_build_object('result_code', v_result)
  );
  return v_snapshot || jsonb_build_object('result_code', v_result);
end;
$$;

revoke all on function public._global_timer_v2_snapshot(uuid, uuid) from public, anon, authenticated;
revoke all on function public.apply_global_timer_command(uuid, uuid, text, uuid, bigint, timestamptz, jsonb, integer) from public, anon;
grant execute on function public.apply_global_timer_command(uuid, uuid, text, uuid, bigint, timestamptz, jsonb, integer) to authenticated;

notify pgrst, 'reload schema';
