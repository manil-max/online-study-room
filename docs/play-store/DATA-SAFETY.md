# Play Data Safety Draft (WP-119)

**App:** Odak Kampı · **Date:** 2026-07-17

| Category | Collected | Shared | Purpose |
|---|---|---|---|
| Email | Yes | With Supabase | Account |
| Name | Yes | Group members via RLS | Profile |
| Photos | Yes (avatar) | Public URL / members | Profile |
| App activity (study) | Yes | Group members (sessions visibility) | Core feature |
| Messages | Yes (class chat) | Group members | Chat |
| Crash logs | Optional (Sentry) | Sentry if enabled | Stability |
| Device IDs | No (by design) | — | — |

**Encryption in transit:** Yes (HTTPS)  
**Deletion:** In-app request + 14-day grace + scheduled purge (0037/113)  
**Account required:** Yes  
**Children:** Not directed under 13  

Fill Play Console form to match this table after legal URLs go live.
