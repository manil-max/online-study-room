# WP-175 — Klasik istatistiği zenginleştir (PLAN)

| Alan | Değer |
|---|---|
| Tarih | 2026-07-18 |
| Tür | **PLAN — kod yok** · onay bekler |
| Bağlam | WP-170 ızgara kaldırıldı; klasik `PersonalStatsView` / `ClassStatsView` |
| ⛔ | Timer/widget/FGS · **Home dashboard** · sürükle-grid geri getirme |
| Primitifler | `features/stats/charts/**` (gauge/stacked/radar/area) + fl_chart mevcut |
| RPC | 0039 `get_user_day_totals` · 0040 contribution/leaderboard · 0041 start_time |

---

## 1. Vizyon

Samsung Health / Digital Wellbeing tarzı: **sabit kaydırılabilir bölümler**, dönem seçici, kıyas, zengin grafikler — **sürükle-bırak ızgara yok**.

---

## 2. Kişisel sekme — sabit bölüm düzeni

Sıra (ListView, yukarı→aşağı):

| # | Bölüm | Widget / primitif | Veri |
|---|---|---|---|
| P0 | Dönem çubuğu | `StatsPeriodBar` genişlet: +yıl +özel + “önceki dönemle kıyas” | `stats_period` / Istanbul |
| P1 | Özet şerit | Toplam süre · oturum sayısı · gün/hedef % | sessions + summary |
| P2 | Trend | Line veya **Area** (`area_line_chart`) | daily series |
| P3 | Çubuk | Mevcut bar (haftalık/aylık) | daily |
| P4 | Ders dağılımı | Donut (mevcut) + opsiyonel **stacked** bar | subject split |
| P5 | Saatlik aktivite | Mevcut hour chart | hour histogram |
| P6 | Hedef gauge | **Gauge** primitif | daily goal |
| P7 | Streak / heatmap | Mevcut heatmap | day totals |
| P8 | Hafta içi / sonu | Mevcut split | weekday |
| P9 | Rekorlar | Mevcut records | — |
| P10 | Scatter | Mevcut (opsiyonel collapse) | sessions |
| P11 | **Detaylı geçmiş** | Yıl / özel aralık tablosu veya sparkline grid | **`get_user_day_totals`** (hot window dışı) |
| P12 | Radar (opsiyonel) | 5 eksen: tempo/tutarlılık/ders çeşitliliği… | türetilmiş skorlar |

**Placeholder yasak** — veri yoksa empty state.

---

## 3. Grup sekmesi — sabit bölümler

| # | Bölüm | Veri / RPC |
|---|---|---|
| G0 | Dönem (kişisel ile aynı bar) | — |
| G1 | Grup toplam + hedef gauge | `group_daily_totals` / goal |
| G2 | Üye katkı **donut** | **`group_contribution_breakdown`** |
| G3 | Liderlik listesi | mevcut + breakdown |
| G4 | Liderlik zaman serisi | **`group_leaderboard_series`** |
| G5 | Grup trend bar/area | day totals |
| G6 | Heat table üye×gün | mevcut |

Non-üye: yetkisiz empty (RLS 42501).

---

## 4. Detaylı geçmiş (retrospektif)

- Dönem: **yıl** ve **özel aralık** (date range picker).
- Sunucu: `get_user_day_totals(p_from, p_to)` — 90g hot window dışı.
- UI: ay bazlı özet kartları + seçili aralıkta günlük seri (area/bar).
- Kıyas: eşit uzunlukta önceki aralık delta (WP-163 fikirleri).

---

## 5. Veri / repo

| Parça | Not |
|---|---|
| `AnalyticsQueryRepository` | Korunur (supabase + in_memory) — grid UI yok |
| `AnalyticsCardRegistry` | İsteğe bağlı: bölüm builder’larına devşir veya silinir |
| Yeni migration | **v1 gerekmez** (0039–0041 yeterli) |
| RLS | Mevcut DEFINER RPC; ham session yok |

---

## 6. Faz / WP dilimleme (onay sonrası)

| WP | Kapsam |
|---|---|
| **WP-175** | Bu plan |
| **WP-176** | StatsPeriodBar year/custom + kıyas + l10n |
| **WP-177** | Personal sabit bölümler (gauge/area/stacked + geçmiş) |
| **WP-178** | Group sabit bölümler (contribution donut + series) |
| **WP-179** | Empty/error/a11y + golden smoke |

---

## 7. l10n (tr/en/ar/de)

Yeni anahtarlar: dönem year/custom, kıyas etiketi, bölüm başlıkları, empty states.  
AR residual (WP-173) ile aynı anda tamamlanabilir.

---

## 8. Test & kabul

- Unit: period range Istanbul; previous equal-length  
- Widget: empty/loading; gauge/area mount  
- analyze 0; flag/grid yok  
- Cihaz: kaydırma akıcı; Home dokunulmadı  

---

## 9. Riskler

| Risk | Azaltma |
|---|---|
| Ekran çok uzun | Bölüm collapse / “daha fazla” |
| RPC uygulanmamış | Empty + sahip SQL notu |
| fl_chart radar kalitesi | Opsiyonel / flag |
| Grid kod kalıntısı | Registry dead-code silme WP-176+ |

---

## 10. Açık ürün kararları

1. Radar v1’de mi? ☐ evet ☐ hayır  
2. Scatter kalsın mı? ☐ evet ☐ collapse  
3. Grup donut varsayılan açık mı? ☐  

---

## 11. Bitiş

**STOP — onay bekle, kod yok.**  
Onay → WP-176+ claim.
