# WP-148 — Bilinen bug regresyon süpürmesi

**Tarih:** 2026-07-18

| Madde | Durum | Not |
|---|---|---|
| In-app start idle bildirim (beta-v15) | **WP-135 store commit + WP-136 reconcile** | FGS core donmuş; Dart/store hizası 135–136 |
| Background timer aksiyonları | **WP-134–137** | Native toggle/SSOT; cihaz QA park |
| Compact widget saat GONE | **WP-134 kapattı** | |
| stop `apply` asimetri | **WP-135 kapattı** | TimerStateStore.commit |
| Reconcile yalnız resume | **WP-136 kapattı** | engine-scope receiver |
| FGS ≤13 tip | **WP-103** (Tamamlanan) | API 33 smoke hâlâ önerilir |
| Campfire InMemory / migration | **Kısmen açık** | 0032/0034 canlı apply; InMemory demo sınırlı |
| Tekrarlayan dürtme | **WP-99/79** | Cihaz teyit |
| Gece yarısı saat kartı | **v28 / 5335002** | release_notes v28 |

## Timer dışı bu WP’de kod

- Yok (kalıntı Dart timer reconcile’a dokunulmadı — donuk yüzey).  
- Hata retry: **WP-147** (session/subjects/stats).

## Kalan cihaz

- WP-134–137 S1–S13 matrisi  
- Presence WP-104  
- Migration 0034–0038 prod
