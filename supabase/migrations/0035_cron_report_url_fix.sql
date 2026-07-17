-- 0035: Aylık rapor cron URL + secret header (WP-108 B8)
--
-- 0030 localhost:54321 URL'sini kaldırır; prod Functions URL + cron secret
-- `app.settings.*` GUC'larından okunur (plaintext secret migration'da yok).
--
-- Ops (Supabase SQL Editor / Dashboard, bir kez):
--   alter database postgres set app.settings.supabase_url =
--     'https://YOUR_PROJECT_REF.supabase.co';
--   alter database postgres set app.settings.service_role_key = '…';
--   alter database postgres set app.settings.cron_secret = 'uzun-rastgele';
-- Edge Function secrets: CRON_SECRET = aynı değer; SUPABASE_SERVICE_ROLE_KEY zaten var.
--
-- Geri alma (Rollback):
--   select cron.unschedule('monthly-report-collector');
--   -- 0030 cron bloğunu yeniden çalıştır (localhost) veya job'u sil.

do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'cron') then
    raise notice 'pg_cron yok — monthly-report-collector güncellenmedi.';
    return;
  end if;

  -- Eski job varsa kaldır (yoksa yoksay).
  begin
    perform cron.unschedule('monthly-report-collector');
  exception
    when others then
      raise notice 'unschedule monthly-report-collector: %', sqlerrm;
  end;

  perform cron.schedule(
    'monthly-report-collector',
    '0 6 2 * *',
    $cron$
      select net.http_post(
        url := rtrim(
          coalesce(
            nullif(current_setting('app.settings.supabase_url', true), ''),
            nullif(current_setting('app.settings.functions_base_url', true), '')
          ),
          '/'
        ) || '/functions/v1/collect-reports',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || coalesce(
            nullif(current_setting('app.settings.service_role_key', true), ''),
            ''
          ),
          'x-cron-secret', coalesce(
            nullif(current_setting('app.settings.cron_secret', true), ''),
            ''
          )
        ),
        body := jsonb_build_object(
          'month', to_char((now() at time zone 'Europe/Istanbul') - interval '1 day', 'YYYY-MM')
        )
      );
    $cron$
  );
end $$;
