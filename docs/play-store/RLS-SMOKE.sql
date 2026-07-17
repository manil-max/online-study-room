-- WP-121 read-only style checks (run as authenticated test users in SQL editor carefully).
-- Prefer app-level tests with two accounts.

-- 0036: profiles policy should not be using(true)
select polname, pg_get_expr(polqual, polrelid) as using_expr
from pg_policy
where polrelid = 'public.profiles'::regclass;

-- 0037 table
select to_regclass('public.account_deletion_requests') is not null as has_deletion;

-- 0038 tables
select to_regclass('public.ugc_reports') is not null as has_ugc,
       to_regclass('public.user_blocks') is not null as has_blocks;

-- 0034 index
select indexname from pg_indexes
where tablename = 'group_members' and indexname = 'idx_group_members_active';
