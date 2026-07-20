-- WP-225 production preflight (salt-okunur).
-- Bu dosya DDL/DML/RPC çalıştırmaz. SQL Editor'da tek başına çalıştırın.

begin isolation level repeatable read read only;
set local statement_timeout = '60s';
set local lock_timeout = '5s';
set local idle_in_transaction_session_timeout = '60s';

select
  clock_timestamp() as captured_at_utc,
  current_database() as database_name,
  current_user as database_role,
  current_setting('transaction_read_only') as transaction_read_only,
  current_setting('TimeZone') as database_timezone,
  current_setting('server_version') as postgres_version,
  pg_is_in_recovery() as is_replica;

select
  extname,
  extversion
from pg_extension
where extname in ('pg_cron', 'pgcrypto', 'uuid-ossp')
order by extname;

rollback;
