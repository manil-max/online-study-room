-- 0144_push_ios_platform.sql
-- WP-906: iOS cihazlari push kaydi yapabilir; dispatcher cihazin platformunu gorur.
--
-- KUSUR (olculdu): `0066_push_notification_delivery.sql:11`
-- `push_devices.platform` kolonunu `check (platform = 'android')` ile kilitler ve
-- `register_push_device` kolona 'android' literalini kendisi yazar (`0066:163`).
-- iOS uygulamasi (WP-900..905) kayit olabilse bile satiri Android sanilir;
-- dispatcher (`supabase/functions/dispatch-push/index.ts`) da cihazin
-- platformunu hic almaz (`claim_push_deliveries`, son hali `0083:141`), bu
-- yuzden iOS'un arka planda gosterebilecegi `apns` blogunu ekleyemez.
--
-- YAPILAN:
--   1. `push_devices.platform` kisiti `platform in ('android', 'ios')` olur.
--      Mevcut satirlarin hepsi 'android'; veri degismez (DML yok).
--   2. `register_push_device` 14. parametre `p_platform text default 'android'`
--      alir. 🔴 Eski 13 parametreli imza DUSURULUR: ikisi yan yana kalsaydi
--      13 adli argumanla gelen eski istemci cagrisi PostgREST'te iki overload'a
--      birden uyar ve belirsizlik hatasiyla duserdi. Default sayesinde eski
--      Android surumleri (p_platform gondermeyen) aynen calisir ve 'android'
--      yazilir. Gecersiz deger `invalid_platform` ile reddedilir.
--      security definer / search_path / grant'lar 0066 ile birebir aynidir.
--   3. `claim_push_deliveries` donus tablosunun SONUNA `platform text` eklenir.
--      Donus tipi degistigi icin `create or replace` yetmez; fonksiyon dusurulup
--      0083 govdesiyle aynen yeniden kurulur, grant'lar 0083 ile aynidir.
--      Eski dispatcher fazla kolonu yok sayar; yeni dispatcher kolonu bulamazsa
--      'android' varsayar. Yani DB ve Edge Function hangi sirayla deploy edilirse
--      edilsin Android teslimi bozulmaz.
--
-- Geri alma (Rollback): once iOS satirlarini kapat
--   (`update public.push_devices set disabled_at = now(), last_error_code =
--   'platform_rollback' where platform = 'ios';` — ya da sil), sonra
--   `drop function public.register_push_device(text, text, text, text, integer,
--   text, text, boolean, boolean, boolean, boolean, integer, integer, text);`
--   ile 0066'daki 13 parametreli govdeyi + grant'lari yeniden kur,
--   `claim_push_deliveries`'i dusurup 0083 govdesini + grant'lari yeniden kur,
--   kisiti `check (platform = 'android')` olarak geri koy. Ileri migration ile
--   yapilir; bu dosya uygulandiktan sonra degistirilmez.

-- ---------------------------------------------------------------------------
-- 1. Platform kisiti
-- ---------------------------------------------------------------------------
do $migration$
declare v_constraint record;
begin
  for v_constraint in
    select conname from pg_constraint
    where conrelid = 'public.push_devices'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%platform%'
  loop
    execute format('alter table public.push_devices drop constraint %I', v_constraint.conname);
  end loop;
end
$migration$;

alter table public.push_devices
  add constraint push_devices_platform_check
  check (platform in ('android', 'ios'));

-- ---------------------------------------------------------------------------
-- 2. register_push_device: p_platform (default 'android')
-- ---------------------------------------------------------------------------
drop function public.register_push_device(
  text, text, text, text, integer, text, text, boolean, boolean, boolean,
  boolean, integer, integer
);

create function public.register_push_device(
  p_installation_id text,
  p_fcm_token text,
  p_app_channel text,
  p_app_version text,
  p_build_number integer,
  p_locale text,
  p_time_zone text,
  p_nudge_enabled boolean,
  p_announcement_enabled boolean,
  p_update_enabled boolean,
  p_quiet_hours_enabled boolean,
  p_quiet_start_minutes integer,
  p_quiet_end_minutes integer,
  p_platform text default 'android'
)
returns table (device_id uuid, registered_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_installation_id text := trim(coalesce(p_installation_id, ''));
  v_token text := trim(coalesce(p_fcm_token, ''));
  v_platform text := lower(trim(coalesce(p_platform, 'android')));
  v_row public.push_devices;
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;
  if char_length(v_installation_id) not between 16 and 128 then
    raise exception 'invalid_installation_id';
  end if;
  if char_length(v_token) not between 20 and 4096 then
    raise exception 'invalid_fcm_token';
  end if;
  if p_app_channel not in ('local', 'beta', 'stable') then
    raise exception 'invalid_app_channel';
  end if;
  if v_platform not in ('android', 'ios') then
    raise exception 'invalid_platform';
  end if;
  if char_length(trim(coalesce(p_app_version, ''))) not between 1 and 64
    or p_build_number < 0
    or char_length(trim(coalesce(p_locale, ''))) not between 2 and 16
    or char_length(trim(coalesce(p_time_zone, ''))) not between 1 and 64
    or p_quiet_start_minutes not between 0 and 1439
    or p_quiet_end_minutes not between 0 and 1439 then
    raise exception 'invalid_device_metadata';
  end if;

  -- Ayni FCM token reinstall/logout sonrasi baska kullaniciya gectiyse eski
  -- baglantiyi sil. Token yuksek entropilidir; caller yalniz kendi aldigi tokeni
  -- gonderebilir ve sonuc tablosunu dogrudan okuyamaz.
  delete from public.push_devices
  where fcm_token = v_token
    and (user_id <> v_user_id or installation_id <> v_installation_id);

  insert into public.push_devices (
    user_id, installation_id, fcm_token, platform, app_channel, app_version,
    build_number, locale, time_zone, nudge_enabled, announcement_enabled,
    update_enabled, quiet_hours_enabled, quiet_start_minutes,
    quiet_end_minutes, registered_at, last_seen_at, disabled_at, last_error_code
  ) values (
    v_user_id, v_installation_id, v_token, v_platform, p_app_channel,
    trim(p_app_version), p_build_number, lower(trim(p_locale)), trim(p_time_zone),
    p_nudge_enabled, p_announcement_enabled, p_update_enabled,
    p_quiet_hours_enabled, p_quiet_start_minutes, p_quiet_end_minutes,
    now(), now(), null, null
  )
  on conflict (user_id, installation_id) do update set
    fcm_token = excluded.fcm_token,
    platform = excluded.platform,
    app_channel = excluded.app_channel,
    app_version = excluded.app_version,
    build_number = excluded.build_number,
    locale = excluded.locale,
    time_zone = excluded.time_zone,
    nudge_enabled = excluded.nudge_enabled,
    announcement_enabled = excluded.announcement_enabled,
    update_enabled = excluded.update_enabled,
    quiet_hours_enabled = excluded.quiet_hours_enabled,
    quiet_start_minutes = excluded.quiet_start_minutes,
    quiet_end_minutes = excluded.quiet_end_minutes,
    registered_at = now(),
    last_seen_at = now(),
    disabled_at = null,
    last_error_code = null
  returning * into v_row;

  return query select v_row.id, v_row.registered_at;
end;
$$;

revoke all on function public.register_push_device(
  text, text, text, text, integer, text, text, boolean, boolean, boolean,
  boolean, integer, integer, text
) from public, anon;
grant execute on function public.register_push_device(
  text, text, text, text, integer, text, text, boolean, boolean, boolean,
  boolean, integer, integer, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. claim_push_deliveries: donus tablosuna platform (govde 0083 ile ayni)
-- ---------------------------------------------------------------------------
drop function public.claim_push_deliveries(uuid, integer, integer);

create function public.claim_push_deliveries(
  p_worker_id uuid, p_limit integer default 50, p_lease_seconds integer default 60
)
returns table (delivery_id uuid, outbox_id uuid, device_id uuid, fcm_token text,
  notification_type text, payload jsonb, locale text, time_zone text,
  quiet_hours_enabled boolean, quiet_start_minutes integer, quiet_end_minutes integer, attempt integer,
  platform text)
language plpgsql security definer set search_path = public
as $$
begin
  if auth.role() is distinct from 'service_role' and current_user not in ('postgres', 'service_role') then raise exception 'service_role_required'; end if;
  if p_worker_id is null or p_limit not between 1 and 100 or p_lease_seconds not between 15 and 300 then raise exception 'invalid_claim_parameters'; end if;
  update public.notification_deliveries d set status = 'skipped', updated_at = now(), last_error_code = 'expired'
  from public.notification_outbox o
  where d.outbox_id = o.id and d.status in ('pending', 'retry')
    and o.expires_at is not null and o.expires_at <= clock_timestamp();
  update public.notification_deliveries d set status = 'skipped', updated_at = now(), last_error_code = 'device_disabled'
  from public.push_devices pd, public.notification_outbox o
  where d.device_id = pd.id and d.outbox_id = o.id and d.status in ('pending', 'retry')
    and (pd.disabled_at is not null or not public._push_type_enabled(pd, o.notification_type));
  update public.notification_deliveries set status = 'failed_permanent', updated_at = now(), last_error_code = 'attempts_exhausted'
  where status in ('pending', 'retry', 'processing') and attempts >= 6;
  return query with candidates as (
    select d.id from public.notification_deliveries d join public.notification_outbox o on o.id = d.outbox_id
    where ((d.status in ('pending', 'retry') and d.available_at <= now()) or (d.status = 'processing' and d.lease_until < now()))
      and d.attempts < 6 and (o.expires_at is null or o.expires_at > clock_timestamp())
    order by d.available_at, d.created_at for update skip locked limit p_limit
  ), claimed as (
    update public.notification_deliveries d set status = 'processing', attempts = d.attempts + 1,
      claimed_by = p_worker_id, lease_until = now() + make_interval(secs => p_lease_seconds), updated_at = now()
    from candidates c where d.id = c.id returning d.*
  ) select c.id, c.outbox_id, c.device_id, pd.fcm_token, o.notification_type, o.payload,
    pd.locale, pd.time_zone, pd.quiet_hours_enabled, pd.quiet_start_minutes, pd.quiet_end_minutes, c.attempts,
    pd.platform
  from claimed c join public.push_devices pd on pd.id = c.device_id join public.notification_outbox o on o.id = c.outbox_id;
end;
$$;

revoke all on function public.claim_push_deliveries(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.claim_push_deliveries(uuid, integer, integer) to service_role;

notify pgrst, 'reload schema';
