-- WP-225 Supabase CLI history + pg_cron envanteri (salt-okunur).
-- Migration tracking tablosu bulunmasa da cron envanterinin devam etmesi için
-- history varlığı pg_catalog üzerinden kontrol edilir.

begin isolation level repeatable read read only;
set local statement_timeout = '60s';
set local lock_timeout = '5s';
set local idle_in_transaction_session_timeout = '60s';

select
  exists (
    select 1 from pg_namespace where nspname = 'supabase_migrations'
  ) as migration_schema_exists,
  to_regclass('supabase_migrations.schema_migrations') is not null
    as schema_migrations_table_exists,
  case
    when to_regclass('supabase_migrations.schema_migrations') is null
      then 'tracking_table_absent'
    else 'tracking_table_present_run_cli_migration_list_for_rows'
  end as migration_history_state;

select
  jobname,
  schedule,
  command,
  active,
  database,
  username
from cron.job
where jobname in (
  'verified-session-rollout-retention',
  'verified-group-day-finalizer',
  'verified-group-week-finalizer'
)
order by jobname;

select
  j.jobname,
  count(*)::bigint as run_count,
  max(d.end_time) as last_end_time,
  max(d.status) filter (where d.end_time = x.last_end_time) as last_status,
  max(md5(coalesce(d.return_message, '')))
    filter (where d.end_time = x.last_end_time) as last_message_md5
from cron.job j
left join lateral (
  select max(end_time) as last_end_time
  from cron.job_run_details d0
  where d0.jobid = j.jobid
) x on true
left join cron.job_run_details d on d.jobid = j.jobid
where j.jobname in (
  'verified-session-rollout-retention',
  'verified-group-day-finalizer',
  'verified-group-week-finalizer'
)
group by j.jobname, x.last_end_time
order by j.jobname;

rollback;
