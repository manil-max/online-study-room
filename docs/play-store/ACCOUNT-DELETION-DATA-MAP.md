# Account Deletion Data Map (WP-112)

**Karar varsayılanı:** 14 gün grace · soft request ≠ hard delete  
**Migration:** `0037_account_deletion_core.sql`

## Hard-delete öncesi bağımlılık özeti

| Kaynak | on delete / not | Purge notu |
|---|---|---|
| `profiles` | CASCADE from auth.users | Auth silinince gider |
| `study_sessions` | CASCADE | Auth silinince |
| `group_members` | CASCADE | Üyelik kalkar |
| `groups.created_by` | CASCADE risk | **Önce ownership devri** (WP-113) |
| `class_messages` | user FK | Scrub / silinmiş üye (ürün) |
| `presence` | CASCADE | İstekte offline |
| `gamification_*` / `xp_ledger` | CASCADE / revoke | Kullanıcı satırları |
| `study_reminders` | CASCADE | — |
| Storage `avatars/{uid}/` | path | Edge list-delete |
| `feedback_tickets` | user | Retention ~90g sonra scrub |
| `admin_audit_logs` | — | PII yok / hash ≥1y |
| `email_job_queue` | user | Opt-out istekte; hard’da cascade |
| Offline prefs | cihaz | Client logout wipe (WP-114) |

## Durum makinesi

`scheduled` (istek anında) → `processing` (worker) → `completed` | `failed`  
Grace içinde: `cancel` → `canceled`

## RPC

| Fonksiyon | Rol |
|---|---|
| `request_account_deletion()` | authenticated self |
| `cancel_account_deletion()` | authenticated self, purge_after > now |
| `my_account_deletion_status()` | authenticated self |

Hard-delete worker: WP-113 (`purge-accounts`).
