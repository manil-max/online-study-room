-- 0089_global_timer_lease_sweeper.sql
-- WP-373: V2 koşu kirası süpürücüsünü gerçekten çalışır hale getirir.
--
-- `expire_global_timer_v2_leases` 0082'de yazıldı, `service_role`'a grant edildi
-- ve **hiçbir zaman zamanlanmadı**. Aynı anda hiçbir istemci de `heartbeat`
-- komutu göndermiyordu. İkisi birlikte şu anlama geliyordu:
--
--   * Kira 150 sn sonra dolar ama koşu `running` kalır (kimse kapatmaz).
--   * `user_timer_state.current_run_id` dolu kalır → snapshot sonsuza dek
--     "çalışıyor" der → karşı cihaz ÖLÜ bir koşuyu aynalar ve durmaz.
--
-- WP-373 istemci tarafında 60 sn'lik `heartbeat` turunu ekler (kira yenilenir);
-- bu migration da kirası dolmuş koşuları kapatan dakikalık süpürücüyü kurar.
-- İkisi birlikte anlamlıdır: yalnız süpürücü koşan sayacı 150 sn'de keserdi,
-- yalnız heartbeat de öldürülen/çöken cihazın koşusunu sonsuza dek açık bırakırdı.
--
-- Şema değişmez; yalnız bir cron job'ı kurulur. Süpürücü idempotenttir:
-- yalnız `protocol_version = 2 and status = 'running' and lease_expires_at <= now`
-- satırlarını `abandoned` yapar ve presence'ı çevrimdışına çeker.
--
-- Geri alma (Rollback):
--   select cron.unschedule(jobid) from cron.job
--   where jobname = 'global-timer-v2-lease-sweeper';
-- Süpürücü durunca kirası dolmuş koşular açık kalır (0089 öncesi davranış);
-- veri kaybı olmaz, uygulanmış run kayıtları değişmez.

do $migration$
declare
  v_job record;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron')
     or to_regclass('cron.job') is null then
    raise exception 'pg_cron_required_before_0089';
  end if;

  for v_job in
    select jobid from cron.job where jobname = 'global-timer-v2-lease-sweeper'
  loop
    perform cron.unschedule(v_job.jobid);
  end loop;

  perform cron.schedule(
    'global-timer-v2-lease-sweeper',
    '* * * * *',
    'select public.expire_global_timer_v2_leases(200)'
  );
end
$migration$;

notify pgrst, 'reload schema';
