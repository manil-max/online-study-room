# WP-177 — Feedback kapanış (client + ensure SQL)

| Alan | Değer |
|---|---|
| Tarih | 2026-07-18 |
| Önceki | WP-168 (oturum/RLS mesajları) |
| Migration | `supabase/migrations/0044_feedback_ensure.sql` |

## Sahip aksiyonu

1. Supabase SQL Editor’de **`0044_feedback_ensure.sql`** içeriğini çalıştır (idempotent; 2× OK).
2. Beta’da Ayarlar → Geri bildirim: düz metin + (varsa) ekli görsel.
3. `feedback_tickets` satırı ve (ek varsa) `storage.objects` path doğrula.

## Client

| Kod | Kullanıcı mesajı |
|---|---|
| `session_required` / `session_or_rls` | Tekrar giriş |
| `schema_missing` (42P01) | Sunucu hazır değil + admin notu |
| `storage` | Görsel yüklenemedi |
| diğer | Jenerik gönderilemedi |

Insert `user_id` = `auth.currentUser.id` (profile mismatch RLS kırmaz).

## Kabul

- [x] Ensure SQL repo’da
- [x] Net mesaj eşlemesi release’te
- [ ] Sahip: SQL Editor 0044
- [ ] Cihaz: feedback DB’ye düşer
