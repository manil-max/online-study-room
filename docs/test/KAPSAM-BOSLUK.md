# WP-145 — Test kapsamı boşluk analizi

**Tarih:** 2026-07-18 · ~91 test dosyası (`app/test`)

## 1. Matris (kritik yol × kapsam)

| Kritik yol | Birim test | Entegrasyon | Cihaz | Boşluk |
|---|---|---|---|---|
| Server XP / ledger | `achievement_*`, `gamification_*` | kısmi | park | RPC contract mock sınırlı |
| RLS / IDOR | az (statik migration testleri) | **zayıf** | smoke | **Yüksek boşluk** |
| Europe/Istanbul gün | `istanbul_calendar_test`, stats | — | — | DST uçları eksik (WP-146) |
| Offline reconcile | offline_first testleri | — | — | Çakışma senaryoları |
| Timer SSOT store | `timer_state_store_semantics` | — | WP-134–137 | FGS donmuş |
| Reconcile Dart | `timer_reconcile_ssot` | — | — | auth-delay partial |
| UGC report/block | moderation filter, blocked_users | — | — | RPC mock |
| Account deletion | — | — | — | **UI/RPC test eksik** |
| l10n parity | audit scripts / release_notes | — | — | dil paketleri WP-155 |
| Grid reflow | `grid_reflow_test` | — | — | golden az |
| Presence staleness | presence tests | — | WP-104 | |

## 2. Öncelikli test WP önerileri

| WP | Kapsam |
|---|---|
| **WP-168** | RLS contract tests (in_memory + fake postgrest veya SQL fixtures) |
| **WP-169** | Istanbul DST ± transition unit suite (WP-146 ile birlikte) |
| **WP-170** | Account deletion repository + UI widget test |
| **WP-171** | Offline conflict golden scenarios |
| **WP-172** | UGC report_sheet widget test (EN/TR) |

## 3. Etiket

- Envanter: **Kodda doğrulandı**  
- Canlı RLS: **Cihazda doğrulanmalı**
