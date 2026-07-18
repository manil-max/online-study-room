# WP-174 — UI/UX regresyon taraması (2026-07-18)

> Kod + statik gözden geçirme. `Kodda doğrulandı` · cihaz smoke **`Cihazda doğrulanmalı`**.

## Bu pakette düzeltilen (önceki WP’ler)

| # | Bulgu | Önem | Durum |
|---|---|---|---|
| S1 | Stats sürükle-ızgara UX | Yüksek | **WP-170** klasik ekran |
| S2 | Başarımlar başlığı dikey taşma | Yüksek | **WP-171** |
| S3 | Gruplar nested scroll jesti | Yüksek | **WP-172** |
| S4 | Saat/Hours bağlam + ar/de | Yüksek | **WP-173** (AR kısmi) |

## Yeni tarama bulguları

| # | Yüzey | Bulgu | Önem | Aksiyon |
|---|---|---|---|---|
| F1 | AR dil | ~%50 metin hâlâ EN (MT kota) | Orta | İnsan/ücretli ar turu (WP-173 residual) |
| F2 | DE | Nadir loanword EN kalıntı (Start, Admin, city names) | Düşük | Kabul / soft polish |
| F3 | Profile | `gamification_card` çift XP bar (seviye + taç) görsel yoğun | Düşük | Ürün: sadeleştirme WP önerisi |
| F4 | Groups | `CampfireScene` geniş dokunma alanları scroll’u yavaşlatabilir (nadir) | Düşük | Cihaz smoke; gerekirse IgnorePointer genişlet |
| F5 | Clock | Uzun izin yardım metinleri küçük ekranda scroll | Düşük | Mevcut ListView — OK |
| F6 | Home | Dashboard sürükle **korunacak** (sahip kararı) | — | Dokunulmadı |
| F7 | Stats | Klasik ListView’de year/custom dönem bar yok (sadece today/week/month/all) | Orta | **WP-175 plan** |
| F8 | Settings | analytics beta toggle kaldırıldı | — | WP-170 |
| F9 | Tema | Bu turda yeni sabit gri sızıntısı görülmedi (spot check) | — | OK |
| F10 | a11y | Chip/başlık 48dp — WP-171 Wrap | — | OK |

## Ucuz düzeltmeler (bu WP)

- Yok ek (S1–S4 zaten ayrı commit). F1 büyük iş; F3 ürün kararı.

## WP önerileri

| Öneri | Kapsam |
|---|---|
| **WP-175** | Klasik stats zenginleştirme (sabit bölümler) |
| **WP-176?** | AR %100 insan çeviri + ICU plural ar |
| **WP-177?** | Profile XP bar sadeleştirme |

## Kabul

- [x] Rapor yazıldı  
- [x] Analyze (önceki WP’ler) 0  
- [ ] Cihaz smoke tüm sekmeler — sahip
