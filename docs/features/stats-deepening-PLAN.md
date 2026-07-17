# WP-150 PLAN — İstatistik derinleştirme

**Durum:** ⏳ **ONAY BEKLİYOR**  
**Tarih:** 2026-07-18

## 1. Kapsam

- Haftalık/aylık trend (line/bar), subject breakdown pie/bar, saat-of-day heatmap, hedef vs gerçekleşen.
- Mevcut `PersonalStatsView` / fl_chart üzerine.

## 2. Agregasyon

| Metrik | Nerede | Not |
|---|---|---|
| Günlük saniye serisi | Client over hot window 90g | `session_window` |
| Uzun dönem | `UserStudySummary` / RPC | WP-142 perf hizası |
| Subject | session.subjectId join | null = “genel” |
| Saat dağılımı | `istanbulHour(start)` bucket | |

**Öneri:** 90g client; 1y+ için SQL RPC `get_user_hourly_histogram(p_from, p_to)`.

## 3. RLS

- Yalnız `auth.uid()` sessions; grup class tab ayrı.

## 4. UI / a11y

- colorScheme chart colors; semantics on bars.
- Empty: “Bu dönemde veri yok”.

## 5. Test

- Bucket math unit; golden optional.
- ⛔ Timer core dokunulmaz.

## 6. Onay

1. 90g yeterli mi yoksa RPC şart mı?  
2. Export (WP-152) ile aynı agregasyon paylaşımı?
