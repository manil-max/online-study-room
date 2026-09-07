-- 0139_unscheduled_sweepers.sql
-- WP-803: yazılmış ama HİÇ ÇALIŞTIRILMAMIŞ üç süpürücüyü zamanlar.
--
-- Ölü özellik denetiminin (2026-09-07) bulgusu. Üçü de tanımlı, grant'lı ve
-- pgTAP'te sınanmış; hiçbiri `cron.job` içinde yok. Yani üçü de bugüne kadar
-- **bir kez bile çalışmadı**.
--
--   1. `moderation_purge_expired_evidence()`  — `0106:388`
--   2. `expire_multi_group_presence_leases()` — `0081:240`
--   3. `prune_stale_push_devices()`           — `0066:438`
--
-- 🔴 EN AĞIRI (1) ve bu bir BELGE–KOD ÇELİŞKİSİDİR. `0106`'nın kendi başlığı
-- şunu yazıyor: *"Kanıt artık süresiz durmaz: `evidence_retention_until`
-- dolduğunda içerik redakte edilir, `evidence_hash` kalır."* Redaksiyonu yapan
-- fonksiyon var, çağıranı yok. Şikâyet edilen kullanıcıların içerik kopyaları
-- (`canonical_snapshot`, `content_snapshot`, `client_hint`) saklama süresi
-- dolduktan sonra da duruyor. Bu bir ekran hatası değil, gizlilik borcudur.
--
-- (2) ve (3) iç borç: presence tarafında istemci `applyPresenceStaleness` ile
-- süresi dolmuş kirayı zaten çevrimdışına çeviriyor (hayalet "çalışıyor" üye
-- OLUŞMUYOR), kalan zarar realtime yayınındaki ölü satırların büyümesi.
-- Push tarafında geçersiz token'lar zaten `disable_push_device` ile tepkisel
-- kapatılıyor; bu yalnız 45 günden eski kayıtların temizliği.
--
-- ---------------------------------------------------------------------------
-- 🔴 (1) OLDUĞU GİBİ ZAMANLANAMAZ — ve bu, bulgunun kendisi kadar önemli.
--
-- `moderation_purge_expired_evidence` gövdesinin ilk satırı:
--     if not public.is_super_admin() then raise exception 'not_super_admin';
--
-- `cron.schedule` işi tablo sahibi olarak koşar; JWT yoktur, `auth.uid()`
-- NULL'dur, `is_super_admin()` FALSE döner. Fonksiyonu olduğu gibi zamanlamak
-- her koşumda exception üretirdi ve `cron.job_run_details` dışında hiçbir yerde
-- görünmezdi — yani "zamanladım" denip yine hiç çalışmamış olurdu.
--
-- Bu yüzden muhafız, KARDEŞ SÜPÜRÜCÜLERİN zaten kullandığı biçime çevriliyor
-- (`expire_global_timer_v2_leases` `0119`, `prune_stale_push_devices` `0066`):
-- service_role/postgres **VEYA** süper admin. Yetki DARALMIYOR, genişliyor —
-- ve genişleyen taraf yalnız sunucunun kendisi. Kullanıcıya açık yüzey
-- (`authenticated` grant'ı) aynen duruyor, yani bir kullanıcı bu fonksiyonu
-- hâlâ ancak süper adminse çağırabilir.
--
-- ---------------------------------------------------------------------------
-- Geri alma (Rollback):
--   select cron.unschedule(jobid) from cron.job where jobname in (
--     'moderation-evidence-purge',
--     'multi-group-presence-lease-sweeper',
--     'push-device-stale-pruner');
-- Süpürücüler durunca 0139 öncesi davranışa dönülür (hiç çalışmıyorlardı);
-- veri kaybı olmaz. Redakte edilmiş kanıt geri GELMEZ — redaksiyon zaten
-- `0106`'nın ilan ettiği davranıştır ve `evidence_hash` korunur.

-- ---------------------------------------------------------------------------
-- 1) Kanıt redaksiyonunu cron'dan çağrılabilir yap.
-- ---------------------------------------------------------------------------

create or replace function public.moderation_purge_expired_evidence()
returns integer language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  -- WP-803: kardeş süpürücülerle aynı muhafız. Sunucu (cron/service_role)
  -- ya da süper admin. Eskiden yalnız `is_super_admin()` idi ve bu, işi
  -- zamanlanamaz kılıyordu.
  if auth.role() is distinct from 'service_role'
     and current_user not in ('postgres', 'service_role')
     and not public.is_super_admin() then
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

revoke all on function public.moderation_purge_expired_evidence() from public, anon;
grant execute on function public.moderation_purge_expired_evidence() to authenticated;

comment on function public.moderation_purge_expired_evidence() is
  'WP-803: süresi dolan ve açık itirazı olmayan kanıtı redakte eder. '
  'Günlük cron (moderation-evidence-purge) ve süper admin çağırabilir.';

-- ---------------------------------------------------------------------------
-- 2) Üç işi zamanla.
-- ---------------------------------------------------------------------------

do $migration$
declare
  v_job record;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron')
     or to_regclass('cron.job') is null then
    raise exception 'pg_cron_required_before_0139';
  end if;

  -- Idempotent: aynı adla duran iş varsa önce kaldırılır (0089 deseni).
  for v_job in
    select jobid from cron.job
    where jobname in (
      'moderation-evidence-purge',
      'multi-group-presence-lease-sweeper',
      'push-device-stale-pruner'
    )
  loop
    perform cron.unschedule(v_job.jobid);
  end loop;

  -- Saklama süresi GÜN ölçeğinde; dakikalık koşmanın anlamı yok.
  -- 03:20 UTC: yoğun olmayan saat, öteki işlerle (03:00 purge, 21:10 rapor)
  -- çakışmıyor.
  perform cron.schedule(
    'moderation-evidence-purge',
    '20 3 * * *',
    'select public.moderation_purge_expired_evidence()'
  );

  -- Kira ölçeği saniye; kardeşi `global-timer-v2-lease-sweeper` de dakikalık.
  perform cron.schedule(
    'multi-group-presence-lease-sweeper',
    '* * * * *',
    'select public.expire_multi_group_presence_leases(200)'
  );

  -- 45 günlük eşik; günde bir yeter.
  perform cron.schedule(
    'push-device-stale-pruner',
    '40 3 * * *',
    'select public.prune_stale_push_devices(45)'
  );
end
$migration$;

notify pgrst, 'reload schema';
