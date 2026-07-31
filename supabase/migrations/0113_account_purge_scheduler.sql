-- 0113_account_purge_scheduler.sql
-- WP-464: hesap silme purge zincirinin EKSIK HALKASI + atomik claim + denetim.
--
-- 🔴 BULGU (kodda dogrulandi, 2026-07-31): `purge-accounts` Edge function'i
-- repoda var ve dogru yazilmis, ama onu CAGIRAN hicbir sey yok. Tum repo
-- tarandi: `purge-accounts` yalniz belgelerde geciyor (DATA-SAFETY.md,
-- PLAY-RELEASE-GATE.md, backlog.md, progress.md). Ne pg_cron job'i, ne
-- workflow, ne baska bir cagri.
--
-- Sonuc: kullanici "hesabimi sil" dedi -> `0037` satiri `scheduled` yazdi ->
-- `purge_after = now() + 14 gun` gecti -> HICBIR SEY OLMADI. Veri silinmedi,
-- satir sonsuza dek `scheduled` kaldi. Karsilastirma icin `dispatch-push` ayni
-- ihtiyaci `0069`da `cron.schedule('push-dispatch-retry-worker', ...)` ile
-- cozmustu; silme icin o adim hic atilmadi.
--
-- DATA-SAFETY.md §4 adim 4 "Cron + purge-accounts" diyor; bu migration o
-- ifadeyi DOGRU hale getiriyor.
--
-- Bu migration ayrica kartin (WP-464) saydigi uc yapisal acigi kapatir:
--   * claim atomik degildi -> iki worker ayni isi alabiliyordu,
--   * cokmus worker satiri `processing`de birakiyordu ve satir BIR DAHA
--     hic secilmiyordu (sessiz kalici kayip),
--   * `deleteUser` cascade ile istek satirini siliyordu, geriye tamamlanma
--     izi KALMIYORDU.
--
-- Retention: `docs/HESAP-SILME-RETENTION-KARARI.md` §4.1 satir F
-- ("Admin audit: >= 1 yil meta (uid hash), PII yok") ve §4 adim 4
-- ("PII'siz id hash"). Bu belge politikayi zaten karara baglamis; burada
-- uydurulan bir saklama kurali YOKTUR.
--
-- Geri alma (Rollback):
--   select cron.unschedule(jobid) from cron.job where jobname = 'account-purge-worker';
--   drop function if exists public._request_scheduled_account_purge();
--   drop function if exists public.get_account_purge_health();
--   drop function if exists public.record_account_purge_outcome(uuid, uuid, text, integer, text);
--   drop function if exists public.claim_account_deletion_jobs(integer);
--   drop table if exists public.account_purge_runtime_config;
--   drop table if exists public.account_purge_audit;
--   alter table public.account_deletion_requests drop column if exists claimed_at;

-- ---------------------------------------------------------------------------
-- 1. Lease damgasi
-- ---------------------------------------------------------------------------
-- Claim eden worker'in satiri ne zaman aldigi. Cokme sonrasi kurtarmanin tek
-- olcusu bu: `processing` satiri suresiz kilitli kalamaz.
alter table public.account_deletion_requests
  add column if not exists claimed_at timestamptz;

create index if not exists account_deletion_claimed_at_idx
  on public.account_deletion_requests (claimed_at)
  where status = 'processing';

-- ---------------------------------------------------------------------------
-- 2. Gizlilik-guvenli, degistirilemez tamamlanma izi
-- ---------------------------------------------------------------------------
-- `auth.admin.deleteUser` sonrasi `account_deletion_requests` satiri
-- `on delete cascade` ile gider. Bugun geriye HICBIR iz kalmiyor: "bu hesap
-- gercekten silindi mi" sorusunun cevabi yok. Bu tablo o izi tutar ve
-- kimligi tasimaz.
--
-- `user_hash`: sha256(uid) hex. `sha256(bytea)` PostgreSQL 11+ ile GOMULU
-- gelir, pgcrypto gerektirmez. Ham uid, e-posta veya ad HICBIR sutunda yok.
-- Metin -> bytea donusumu `convert_to(..., 'UTF8')` ile yapilir (`0106`daki
-- kanit zincirinin ayni deyimi); PostgreSQL'de dogrudan `text::bytea` cast'i
-- YOKTUR ve "cannot cast type text to bytea" ile patlar.
create table if not exists public.account_purge_audit (
  id           uuid primary key default gen_random_uuid(),
  user_hash    text not null check (char_length(user_hash) = 64),
  request_id   uuid,
  outcome      text not null check (outcome in ('completed', 'failed')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_error_code text,
  purge_after  timestamptz,
  recorded_at  timestamptz not null default now()
);

create index if not exists account_purge_audit_recorded_idx
  on public.account_purge_audit (recorded_at desc);
create index if not exists account_purge_audit_user_hash_idx
  on public.account_purge_audit (user_hash);

alter table public.account_purge_audit enable row level security;
-- Okuma bile istemciye kapali: bu tablo operasyon/hukuk izidir, urun yuzeyi
-- degildir. Service-role RLS'i zaten bypass eder.
revoke all on table public.account_purge_audit from anon, authenticated;

-- Append-only: `0106` moderasyon zincirindeki desenin aynisi. Satir tetigi
-- `truncate`i gormedigi icin ayri bir statement tetigi gerekiyor.
create or replace function public._account_purge_audit_append_only()
returns trigger
language plpgsql
as $$
begin
  raise exception 'account_purge_audit_append_only' using errcode = '42501';
end;
$$;

drop trigger if exists account_purge_audit_no_update_delete on public.account_purge_audit;
create trigger account_purge_audit_no_update_delete
before update or delete on public.account_purge_audit
for each row execute function public._account_purge_audit_append_only();

drop trigger if exists account_purge_audit_no_truncate on public.account_purge_audit;
create trigger account_purge_audit_no_truncate
before truncate on public.account_purge_audit
for each statement execute function public._account_purge_audit_append_only();

-- ---------------------------------------------------------------------------
-- 3. Atomik claim
-- ---------------------------------------------------------------------------
-- 🔴 Eski davranis: worker `select ... limit N` ile isleri okuyor, sonra
-- `update ... set status='processing'` yapiyor ama SONUCU OKUMUYORDU. Iki
-- worker ayni anda kostugunda ikisi de ayni satiri seciyor, ikisi de update
-- ediyor ve ikisi de `auth.admin.deleteUser` cagiriyordu.
--
-- Yeni davranis: secim ve isaretleme TEK ifadede, `for update skip locked`
-- ile. Ikinci worker kilitli satiri atlar ve o isi HIC gormez. Claim'i
-- kazanamayan worker eli bos doner.
--
-- Ayrica cokmus worker kurtarmasi: `processing` satiri `p_lease_seconds`
-- boyunca dokunulmadiysa yeniden claim edilebilir hale gelir. Bu olmadan
-- cokme = satirin sonsuza dek kaybolmasi demekti (claim yalniz
-- scheduled/failed seciyordu).
create or replace function public.claim_account_deletion_jobs(
  p_limit integer default 5,
  p_lease_seconds integer default 1800,
  p_max_attempts integer default 5
)
returns table (
  id uuid,
  user_id uuid,
  attempt_count integer,
  purge_after timestamptz,
  recovered_from_stale boolean
)
language plpgsql
security definer
set search_path = public
as $$
-- OUT parametre adlari (id, user_id, attempt_count, purge_after) ayni zamanda
-- sutun adlari. Nitelenmemis bir gonderme kalirsa plpgsql degiskeni degil
-- SUTUNU secsin: sessizce yanlis satiri claim etmektense acik davranis.
#variable_conflict use_column
begin
  return query
  with due as (
    -- `requested` bilerek DISARIDA: `0037`deki tek yazar
    -- (`request_account_deletion`) satiri dogrudan `scheduled` olarak acar,
    -- yani o durumun uretici yolu yoktur. Burada da `scheduled`/`failed`
    -- kullanmak `account_deletion_purge_after_idx` kismi indeksiyle birebir
    -- ortusur; degistirilirse o indeks de guncellenmeli.
    select r.id, (r.status = 'processing') as was_stale
    from public.account_deletion_requests r
    where r.attempt_count < p_max_attempts
      and (
        (r.status in ('scheduled', 'failed') and r.purge_after <= now())
        or (
          r.status = 'processing'
          and coalesce(r.claimed_at, r.updated_at)
              < now() - make_interval(secs => p_lease_seconds)
        )
      )
    order by r.purge_after
    limit greatest(coalesce(p_limit, 5), 0)
    for update skip locked
  )
  update public.account_deletion_requests r
  set status = 'processing',
      claimed_at = now(),
      -- Cokme SAYILIR. Sert cokme (timeout/OOM) Edge function'in `catch`
      -- blogunu hic calistiramaz, yani attempt_count'u kimse artirmaz. Burada
      -- artirmazsak lease kurtarmasi ayni isi saatte bir, EBEDIYEN yeniden
      -- claim eder ve `p_max_attempts` guvenligi hic devreye girmez.
      -- Normal hata yoluna dokunulmaz: onu Edge function `catch`i artirir.
      attempt_count = r.attempt_count + case when due.was_stale then 1 else 0 end,
      updated_at = now()
  from due
  where r.id = due.id
  -- RETURNING YENI degerleri verir: kurtarilan is artmis sayaciyla doner.
  returning r.id, r.user_id, r.attempt_count, r.purge_after, due.was_stale;
end;
$$;

revoke all on function public.claim_account_deletion_jobs(integer, integer, integer)
  from public, anon, authenticated;
grant execute on function public.claim_account_deletion_jobs(integer, integer, integer)
  to service_role;

-- ---------------------------------------------------------------------------
-- 4. Denetim yazici
-- ---------------------------------------------------------------------------
-- Worker bunu `deleteUser` BASARILI olduktan sonra cagirir. O anda istek
-- satiri cascade ile gitmis olabilir; bu yuzden audit satiri istek satirina
-- FK ile bagli DEGILDIR.
create or replace function public.record_account_purge_outcome(
  p_request_id uuid,
  p_user_id uuid,
  p_outcome text,
  p_attempt_count integer default 0,
  p_error_code text default null,
  p_purge_after timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_user_id is null then
    raise exception 'account_purge_audit_requires_user';
  end if;
  if p_outcome not in ('completed', 'failed') then
    raise exception 'account_purge_audit_invalid_outcome';
  end if;

  insert into public.account_purge_audit (
    user_hash, request_id, outcome, attempt_count, last_error_code, purge_after
  ) values (
    encode(sha256(convert_to(p_user_id::text, 'UTF8')), 'hex'),
    p_request_id,
    p_outcome,
    coalesce(p_attempt_count, 0),
    p_error_code,
    p_purge_after
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.record_account_purge_outcome(uuid, uuid, text, integer, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.record_account_purge_outcome(uuid, uuid, text, integer, text, timestamptz)
  to service_role;

-- ---------------------------------------------------------------------------
-- 5. Calisma zamani yapilandirmasi
-- ---------------------------------------------------------------------------
-- `0067`deki push deseninin aynisi: secret repoya girmez, ortam basina bir
-- kez service-role ile yazilir. Yapilandirma yoksa scheduler sessizce hicbir
-- sey yapmaz ve saglik fonksiyonu bunu `not_configured` olarak bildirir --
-- yanlislikla "calisiyor" gorunmesin diye.
create table if not exists public.account_purge_runtime_config (
  singleton boolean primary key default true check (singleton),
  functions_base_url text,
  cron_secret text,
  updated_at timestamptz not null default now()
);

alter table public.account_purge_runtime_config enable row level security;
revoke all on table public.account_purge_runtime_config from anon, authenticated;
grant select, insert, update, delete
  on table public.account_purge_runtime_config to service_role;

create or replace function public._request_scheduled_account_purge()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_base_url text;
  v_secret text;
begin
  select functions_base_url, cron_secret
  into v_base_url, v_secret
  from public.account_purge_runtime_config
  where singleton = true;

  -- Yapilandirma yoksa sessizce cik. Secret veya endpoint HICBIR hata
  -- mesajina yazilmaz.
  if v_base_url is null or v_secret is null then
    return;
  end if;

  perform net.http_post(
    url := rtrim(v_base_url, '/') || '/functions/v1/purge-accounts',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', v_secret
    ),
    body := jsonb_build_object('source', 'scheduled_purge', 'limit', 5)
  );
end;
$$;

revoke all on function public._request_scheduled_account_purge()
  from public, anon, authenticated;
grant execute on function public._request_scheduled_account_purge() to service_role;

-- ---------------------------------------------------------------------------
-- 6. Saglik gorunumu
-- ---------------------------------------------------------------------------
-- Staging kanit turunda "calisiyor mu" sorusunun tek cevabi. `not_configured`
-- ile `configured` ayrimi onemli: yapilandirilmamis bir kuyruk sifir hata
-- uretir ve saglikli gorunur.
create or replace function public.get_account_purge_health()
returns table (
  configuration_status text,
  due_count integer,
  processing_count integer,
  stale_lease_count integer,
  terminal_failed_count integer,
  oldest_due_age_seconds integer,
  purged_last_30d integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    case
      when exists (
        select 1 from public.account_purge_runtime_config
        where singleton = true
          and functions_base_url is not null
          and cron_secret is not null
      ) then 'configured'
      else 'not_configured'
    end,
    (select count(*)::integer from public.account_deletion_requests
     where status in ('scheduled', 'failed')
       and attempt_count < 5 and purge_after <= now()),
    (select count(*)::integer from public.account_deletion_requests
     where status = 'processing'),
    (select count(*)::integer from public.account_deletion_requests
     where status = 'processing'
       and coalesce(claimed_at, updated_at) < now() - interval '30 minutes'),
    -- "Terminal" = bir daha ASLA claim edilmeyecek. Iki yoldan olusur:
    -- normal hata yolunda `failed`, sert cokme yolunda ise satir `processing`
    -- kalir ama sayaci tukenmistir. Ikincisini saymazsak sessizce kaybolan
    -- is yine gorunmez olurdu -- WP-464'un kapatmaya calistigi desenin ta
    -- kendisi. Esikler claim ile ayni: 5 deneme / 30 dk lease.
    (select count(*)::integer from public.account_deletion_requests
     where attempt_count >= 5 and status in ('failed', 'processing')),
    (select coalesce(
       extract(epoch from (now() - min(purge_after)))::integer, 0)
     from public.account_deletion_requests
     where status in ('scheduled', 'failed')
       and attempt_count < 5 and purge_after <= now()),
    (select count(*)::integer from public.account_purge_audit
     where outcome = 'completed' and recorded_at >= now() - interval '30 days');
$$;

revoke all on function public.get_account_purge_health() from public, anon, authenticated;
grant execute on function public.get_account_purge_health() to service_role;

-- ---------------------------------------------------------------------------
-- 7. EKSIK HALKA: zamanlayici
-- ---------------------------------------------------------------------------
-- Saatlik. Grace 14 gun oldugu icin dakikalik kosmanin anlami yok; saatlik
-- hem cokme sonrasi kurtarmayi hizli tutar hem de gereksiz cagri uretmez.
do $migration$
declare
  v_job record;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron')
     or to_regclass('cron.job') is null then
    raise exception 'pg_cron_required_before_0113';
  end if;

  for v_job in
    select jobid from cron.job where jobname = 'account-purge-worker'
  loop
    perform cron.unschedule(v_job.jobid);
  end loop;

  perform cron.schedule(
    'account-purge-worker',
    '15 * * * *',
    'select public._request_scheduled_account_purge()'
  );
end
$migration$;
