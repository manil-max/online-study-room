# QA / Regresyon runbook — 2026-07 program kuyruğu

**Durum:** Otomatik test + runbook hazır · **Cihaz/Console kanıtı yok**  
**Ajan:** Grok · **Deploy yok**

## 1. Otomatik komut seti

```bash
cd app
flutter analyze                       # 0 uyarı
flutter test --dart-define-from-file=env.json
# Odak paketler:
flutter test test/features/onboarding/ --dart-define-from-file=env.json
flutter test test/features/profile/data_export_test.dart --dart-define-from-file=env.json
flutter test test/core/smart_reminder_scheduler_test.dart --dart-define-from-file=env.json
flutter test test/core/level_curve_test.dart --dart-define-from-file=env.json
flutter test test/core/l10n_rtl_test.dart --dart-define-from-file=env.json
flutter test test/features/stats/ --dart-define-from-file=env.json
flutter test test/core/grid_reflow_test.dart --dart-define-from-file=env.json
```

## 2. WP-146 Istanbul/DST

- Birim: `istanbul_calendar` / `study_stats` day boundaries.
- Cihaz: yaz saati geçişi gecesi oturum günü kayması yok.
- **Kanıt:** `Cihazda doğrulanmalı` (fiziksel cihaz + saat dilimi simülasyonu)

## 3. WP-147 Hata + yenile

- Kayıt/ders/stats hata kartı + Yenile butonu.
- Offline → snack/error; online yenileme.
- **Kanıt:** `Cihazda doğrulanmalı`

## 4. WP-148 Regresyon süpürme

- Ana sayfa ızgara, saat, grup, stats, profil smoke.
- Rapor: `docs/debug/` geçmiş süpürme notları + bu runbook.

## 5. WP-157–164 Analitik

| Flag | Beklenti |
|---|---|
| `analytics_grid_v1=false` (default) | Eski PersonalStatsView + ClassStatsView + StatsPeriodBar **birebir** |
| `analytics_grid_v1=true` | 6 sütun ızgara, reflow, dönem year/custom, kıyas, gerçek kart verisi |

### SQL/RLS statik (0040–0042)

| Dosya | Kontrol |
|---|---|
| 0040 | `get_user_day_totals` — self only |
| 0041 | contribution + leaderboard series — `is_group_member` |
| 0042 | **`start_time`** (not `s.start`); SECURITY DEFINER; search_path=public |

Uygulama: SQL Editor (sahip). Ham session satırı dönmez.

Otomatik: `analytics_delivery_test.dart`, `analytics_layout_test.dart`.

## 6. WP-151–155 paket smoke

| WP | Otomatik | Cihaz |
|---|---|---|
| 151 Onboarding | onboarding_test | İlk login skip/izin/grup |
| 152 Export | data_export_test | Share sheet, offline hata |
| 153 Smart remind | smart_reminder_* | Bildirim planı / sessiz saat |
| 154 Level/quest | level_curve_test | Profil seviye çubuğu |
| 155 RTL | l10n_rtl_test | AR layout, DE metin |

## 7. Timer / widget donuk yüzey

WP-134–137: **bu runbook kod değiştirmez**. Cihaz matrisi: `docs/qa/DEVICE-QA-MATRIX.md`.
