# Production Deploy Runbook (WP-121)

## Order

1. Backup / snapshot  
2. SQL: **0034** (index concurrently alone)  
3. SQL: **0035** after GUC set (`supabase_url`, `service_role_key`, `cron_secret`)  
4. SQL: **0036** security  
5. SQL: **0037** account deletion  
6. SQL: **0038** UGC  
7. Edge deploy: `purge-accounts`, `collect-reports`, `send-report` with `CRON_SECRET`  
8. RLS smoke (see `RLS-SMOKE.sql`)  
9. App release only after smoke PASS  

## Never

- Paste all migrations in one transaction with CONCURRENTLY  
- Deploy auth-required Edge before secrets  
- Log secrets in evidence screenshots  
