# WP-156 ek — Data / analitik uygulama araştırması

**Tarih:** 2026-07-18 · **Kod yok** · Ana plan: [`ISTATISTIK-GRUPLAR-ANALITIK-PLAN.md`](./ISTATISTIK-GRUPLAR-ANALITIK-PLAN.md)

## Transfer tablosu

| Kaynak ürün | Öne çıkan özellik | Bizde karşılık | Uygulanabilirlik | Efor |
|---|---|---|---|---|
| **Samsung Health** | Hafta/ay/yıl sekmeleri, dönem kıyas (“geçen haftaya göre +%X”), halka aktivite | StatsPeriod + **karşılaştırma kartı** (yeni) | Yüksek | Orta |
| **Samsung Health** | Aktivite heatmap takvim | `StudyHeatmap` (`study_heatmap.dart`) zaten var | Mevcut → ızgaraya bağla | Düşük |
| **Digital Wellbeing** | Kategori pasta/halka + süre listesi | `SubjectDonut` + subject list | Mevcut → kart kataloğu | Düşük |
| **Digital Wellbeing** | Günlük “ekran süresi” zaman çizgisi | Saat-of-day `HourActivityChart` / `WeekHourHeatmap` | Mevcut | Düşük |
| **iOS Screen Time** | Uygulama limiti gauge | Kişisel/grup **hedef gauge** kartı | Orta (UI) | Orta |
| **Google Fit** | Haftalık çubuk + “hedef %” | Goal cards + bar chart | Mevcut parçalar | Düşük |
| **Toggl / Clockify** | Proje kırılımı, faturalanabilir vs | Subject kırılımı | Yüksek | Orta |
| **Toggl** | Dönem rapor export | WP-152 plan ile hizala | Ayrı WP | — |
| **RescueTime** | Productivity score / insight cümlesi | “Bu hafta en verimli günün…” şablon insight | Orta (kural tabanlı) | Orta |
| **Streaks / Habitica** | Seri + takvim | WP-149 → katalog kartı `streakHeatmap` | Yüksek | Orta (server day table opsiyonel) |
| **ActivityWatch** | Multi-device birleştirme | Offline-first + multi-device (WP-144) | İleri faz | Yüksek |
| **GitHub contrib** | Yoğunluk rengi | StudyHeatmap renk skalası | Mevcut | Düşük polish |

## Bizim ürüne özel (Health’te yok)

- **Grup** üye katkı halkası, liderlik **geçmişi**, grup hedefi serisi — Digital Wellbeing “aile” yok; bu bizim ana farkımız.
- **Kamp ateşi / presence** canlılık → analitikte “aktif saatler ortak” kartı (dikkat: privacy).

## Alınacak paternler (özet)

1. **Dönem + önceki dönem kıyas** (Samsung/DW)  
2. **Katalog + ızgara özelleştirme** (bizde ana ekran zaten var)  
3. **Kırılım pasta + liste** (DW/Toggl)  
4. **Heatmap + streak** (GitHub/Streaks)  
5. **Insight şeridi** (1–2 cümle, kural tabanlı; AI şart değil)  
