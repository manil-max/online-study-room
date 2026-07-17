# WP-144 — Offline-first & senkron dayanıklılık

**Tarih:** 2026-07-18 · **Kod yok**

## 1. Mimari (mevcut)

| Katman | Dosya | Rol |
|---|---|---|
| Cache | `offline_cache_store.dart` | Oturum/presence local |
| Study offline-first | `offline_first_study_repository.dart` | Yazım + reconcile remote |
| Presence offline-first | `offline_first_presence_repository.dart` | Presence yazım |
| Providers | `offline_providers.dart`, `study_providers`, `presence_providers` | Stream + local emit (WP-100) |
| Timer pending | native `timer_pending_intervals` → Dart reconcile | ⛔ FGS donmuş; yalnız davranış notu |

## 2. Senaryo tablosu

| # | Senaryo | Beklenen | Risk (kod okuma) |
|---|---|---|---|
| O1 | Offline oturum yaz | Cache + local emit UI günceller | Remote kuyruk yoksa online olunca kayıp — reconcile yolu var mı? |
| O2 | Offline → online | `_reconcileRemoteSessions` birleştirir | Çift satır: idempotency zayıfsa |
| O3 | Realtime kopma | Stream hata; cache son değer | Boş ekran / error state eksik olabilir (WP-147) |
| O4 | Presence bayat | `updatedAt` + staleness (WP-104) | Cihaz QA park |
| O5 | İki cihaz aynı anda yaz | Last-write / server clock | Çakışma çözümü basit merge |
| O6 | Pull-to-refresh timeout | WP-100/102: kısa timeout | Kısmi veri |
| O7 | App ölü timer stop | pending_intervals | Auth gecikmeli clear yarışı WP-136’da ele alındı |
| O8 | Grup yokken presence | no-op + group ready rewrite | WP-100 H3 |

## 3. Kayıp / çift-yazım

| Risk | Nerede | Öneri |
|---|---|---|
| Offline write asla flush edilmez | Network sürekli fail | Retry kuyruk + UI “bekleyen senkron” |
| Çift session insert | Reconcile + realtime | Server unique / client temp id |
| Presence ghost | updatedAt null (WP-104 kodda) | Cihaz teyit |
| Optimistic UI geri alma yok | Hata yutulursa | WP-147 |

## 4. Önerilen WP’ler

| WP | İş |
|---|---|
| **WP-165** | Offline write queue + indicator |
| **WP-166** | Session idempotency keys |
| **WP-167** | Realtime reconnect smoke test |

## 5. Etiketler

- Dosya haritası: **Kodda doğrulandı**  
- O1–O8 saha: **Cihazda doğrulanmalı**
