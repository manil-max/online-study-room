-- Local-only prerequisite bootstrap, executed by Supabase CLI before migrations.
-- Production baseline already has these three extensions. Keeping them here
-- lets immutable historical migrations replay under the same prerequisites.
create extension if not exists pgcrypto with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists pg_cron;

-- The historical project was created before the CLI's fail-closed Data API
-- default. Recreate only the table/sequence DML grants it needs. Deliberately
-- do not auto-grant function EXECUTE: each migration's REVOKE/GRANT is the
-- authority for RPC exposure.
alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant usage, select, update on sequences to anon, authenticated, service_role;
