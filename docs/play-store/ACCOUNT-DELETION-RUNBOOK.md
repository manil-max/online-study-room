# Account Deletion Runbook (WP-113)

## Deploy

1. Apply `0037_account_deletion_core.sql` (staging → prod).  
2. Deploy Edge Function `purge-accounts` with secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `CRON_SECRET`.  
3. Schedule (pg_cron or external) daily:
   ```
   POST /functions/v1/purge-accounts
   Headers: x-cron-secret: $CRON_SECRET
   Body: {"limit": 5}
   ```
4. Dry-run: `{"limit":1,"dry_run":true}` — no Auth delete.

## Order of purge (code)

1. Claim job `scheduled|failed` where `purge_after <= now()`  
2. Abandon pending email jobs  
3. Delete `avatars/{uid}/*`  
4. Transfer or delete owned groups  
5. Scrub `class_messages` body  
6. `auth.admin.deleteUser` → CASCADE profile/sessions  
7. Mark request `completed`

## Safety

- Unauthorized invoke → 401  
- Never log email/token  
- Staging full proof before prod limit=1  
- Failed jobs retry via `attempt_count` (manual review if ≥5)
