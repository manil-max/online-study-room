-- 0030_monthly_report_infrastructure.sql
-- WP-69: Aylık Çalışma Raporu Altyapısı
-- E-posta opt-in bayrakları, iş kuyruğu ve istatistik RPC'si.

-- 1. Kullanıcı tercihleri
alter table public.profiles 
  add column if not exists monthly_report_opt_in boolean default true,
  add column if not exists email_bounced boolean default false;

-- 2. İptal tokenları
create table if not exists public.email_unsubscribe_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  used_at timestamptz
);
create index if not exists idx_unsubscribe_tokens_user on public.email_unsubscribe_tokens (user_id);

-- 3. İş Kuyruğu Tablosu
create table if not exists public.email_job_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  report_month text not null, -- 'YYYY-MM'
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'failed', 'abandoned')),
  retry_count int not null default 0,
  error_log text,
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (user_id, report_month) -- Bir kullanıcı bir aya ait sadece bir rapor alabilir
);

create index if not exists idx_email_job_queue_status on public.email_job_queue (status, created_at asc);

-- Sadece admin / service_role bu tablolara erişebilir. 
alter table public.email_job_queue enable row level security;
drop policy if exists email_job_queue_admin on public.email_job_queue;
create policy email_job_queue_admin on public.email_job_queue
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

alter table public.email_unsubscribe_tokens enable row level security;
drop policy if exists email_unsubscribe_tokens_admin on public.email_unsubscribe_tokens;
create policy email_unsubscribe_tokens_admin on public.email_unsubscribe_tokens
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());


-- 4. İstatistik Çıkarıcı (Edge Function çağıracak, service_role ile yetkili)
create or replace function public.get_user_monthly_stats(p_user_id uuid, p_month text)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_start_date date;
  v_end_date date;
  v_total_seconds int;
  v_active_days int;
  v_peak_date date;
  v_peak_seconds int;
begin
  -- p_month '2026-07' formatında
  v_start_date := (p_month || '-01')::date;
  v_end_date := (v_start_date + interval '1 month' - interval '1 day')::date;
  
  -- Toplam süre ve aktif gün (Europe/Istanbul)
  select 
    coalesce(sum(duration_seconds), 0),
    count(distinct (start_time at time zone 'Europe/Istanbul')::date)
  into v_total_seconds, v_active_days
  from public.study_sessions
  where user_id = p_user_id
    and (start_time at time zone 'Europe/Istanbul')::date >= v_start_date
    and (start_time at time zone 'Europe/Istanbul')::date <= v_end_date;
    
  -- Zirve gün
  select (start_time at time zone 'Europe/Istanbul')::date as day_date,
         sum(duration_seconds) as sum_sec
  into v_peak_date, v_peak_seconds
  from public.study_sessions
  where user_id = p_user_id
    and (start_time at time zone 'Europe/Istanbul')::date >= v_start_date
    and (start_time at time zone 'Europe/Istanbul')::date <= v_end_date
  group by day_date
  order by sum_sec desc
  limit 1;
  
  return jsonb_build_object(
    'total_seconds', v_total_seconds,
    'active_days', v_active_days,
    'daily_average_seconds', case when v_active_days > 0 then v_total_seconds / v_active_days else 0 end,
    'peak_date', v_peak_date,
    'peak_seconds', coalesce(v_peak_seconds, 0)
  );
end;
$$;

-- Edge function yetkilendirmesi (aslında service role ile çalışacak ama önlem olarak veriyoruz)
grant execute on function public.get_user_monthly_stats(uuid, text) to authenticated;

-- 5. pg_cron Job (Her ayın 2'si 06:00 UTC = 09:00 İstanbul)
-- pg_cron yoksa (yerel / bazı planlar) atla — tablolar ve RPC yine kurulur.
-- Dashboard: Database → Extensions → pg_cron aç, sonra job'u elle ekle.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule(
      'monthly-report-collector',
      '0 6 2 * *',
      $cron$
        select net.http_post(
          url := 'http://localhost:54321/functions/v1/collect-reports',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
          ),
          body := jsonb_build_object('month', to_char(now() - interval '1 day', 'YYYY-MM'))
        );
      $cron$
    );
  else
    raise notice 'pg_cron (schema cron) yok — monthly-report-collector planlanmadı. Aylık rapor tabloları/RPC kuruldu; zamanlamayı Dashboard veya harici cron ile ekleyin.';
  end if;
end $$;

-- Geri alma (Rollback):
-- select cron.unschedule('monthly-report-collector');
-- drop function if exists public.get_user_monthly_stats(uuid, text);
-- drop table if exists public.email_job_queue;
-- drop table if exists public.email_unsubscribe_tokens;
-- alter table public.profiles drop column if exists monthly_report_opt_in, drop column if exists email_bounced;
