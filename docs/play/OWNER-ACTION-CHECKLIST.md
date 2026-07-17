# Play / Ops — sahip aksiyonu checklist (ajan deploy etmez)

**Mevcut sürüm (kod):** `1.0.29+29` (`app/pubspec.yaml`)  
**Yerel tag notu (progress):** `v29` / `beta-v29` → WP-104 commit ailesi; main daha ileride olabilir.  
**WP-122 kuralı:** versionCode artırmadan production AAB yükleme; önce tag/version doğrula.

## ⛔ Ajanın YAPMADIĞI

- Edge function deploy / cron secret
- DNS / Resend
- Gizlilik HTTPS URL host
- Play Console form gönderimi
- AAB upload / staged rollout
- Fiziksel cihaz testi (yalnız matris)

## ✅ Sahip aksiyonları

| # | İş | WP | Kanıt alanı (doldur) |
|---|---|---|---|
| 1 | Edge `send-report` / cron secret (S2) | 108 | Deploy hash: ____ tarih: ____ |
| 2 | Canlı gizlilik/ToS HTTPS URL | 111 | URL: ____ |
| 3 | `purge-accounts` Edge + CRON | 113 / 127 | Deploy: ____ |
| 4 | Play Data Safety formu (DATA-SAFETY.md) | 119 / 132 | Form submit: ____ |
| 5 | Store listing + screenshots | 120 | Asset klasör: ____ |
| 6 | Prod migration 0034–0043 + RLS smoke | 121 | SQL Editor log: ____ |
| 7 | versionCode artır → play AAB | 122 | version: ____ AAB SHA: ____ |
| 8 | Cihaz P0 matrisi | 123 | DEVICE-QA-MATRIX: ____ |
| 9 | Internal/closed test + GO | 124 | GO imza: ____ |

## SQL zinciri (sahip uygular)

Sırayla (eksik olanlar): `0034`…`0038`, `0040`, `0041`, `0042`, `0043`.  
0042: `start_time` fix. 0043: cosmetics + dict.

## RLS smoke (sahip / staging)

İki hesap: üye / non-üye → `docs/features/ANALYTICS-RLS-TEST-PLAN.md` + group_daily_totals.

## Release gate

Şablon: mevcut `docs/play-store/` ve `PLAY-STORE-HAZIRLIK-TARAMASI.md`.  
GO yalnız tüm checkbox + cihaz PASS sonrası.
