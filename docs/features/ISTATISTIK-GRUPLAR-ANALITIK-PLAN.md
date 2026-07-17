# WP-156 — İstatistik & Gruplar: Özelleştirilebilir Analitik (büyük plan)

| Alan | Değer |
|---|---|
| Tarih | 2026-07-18 |
| Tür | Araştırma + mimari + faz planı (**ürün kodu yok**) |
| Üst küme | WP-150 stats derinleştirme + WP-149 streak/heatmap **bu sistemde kart türleri** |
| ⛔ Donuk | Timer/widget/FGS (WP-134–137) |
| Ek | [`DATA-APP-ARASTIRMA.md`](./DATA-APP-ARASTIRMA.md) |

> **Mevcut gerçek:** Stats zaten sabit `ListView` + birçok grafik widget’ı barındırıyor; **özelleştirilebilir ızgara Stats/Gruplar’da yok**. Grup verisi `group_daily_totals` RPC + `ClassStatsView` ile sınırlı zengin. fl_chart **Pie (donut) var**; radar/gauge yok; heatmap **custom** (`StudyHeatmap`, `WeekHourHeatmap`, `StatHeatTable`).

---

## 1. Pazar / ürün araştırması

→ Ayrıntı: [`DATA-APP-ARASTIRMA.md`](./DATA-APP-ARASTIRMA.md).

**Vizyon özeti:** Samsung Health + Digital Wellbeing paternleri (dönem, kıyas, pasta, heatmap, gauge) + **grup katkı/liderlik** farkı + ana ekrandaki **grid_reflow özelleştirme** Stats ve Gruplar’a taşınır.

---

## 2. Mevcut altyapı denetimi (yeniden kullan)

### 2.1 Izgara motoru (Ana Sayfa)

| Parça | Konum | Kanıt |
|---|---|---|
| Reflow | `lib/core/grid/grid_reflow.dart` | `placeGridItem`, `GridItemBounds` — domain-agnostic |
| Kart türleri | `lib/features/home/dashboard_card.dart` | `DashboardCardType` **16 tür** (timer…activeMembers) `:23-40` |
| Layout persist | `dashboard_providers.dart` | `_kLayoutKey`, `_kLayoutProfilePrefix` per columns `:7-9`, `defaultDashboardLayout` |
| Density | 6/8/12/16/32 sütun | `DashboardGridDensity` |

**Paylaşım stratejisi (öneri):**

| Katman | Ana Sayfa | Stats / Gruplar |
|---|---|---|
| `grid_reflow.dart` | paylaş | **aynı motor** (kopyalama yok) |
| Kart enum | `DashboardCardType` | **yeni** `AnalyticsCardType` (veya sealed union) — timer/presence **Stats kataloğunda yok** |
| Persist keys | `dashboard_layout_v2_*` | `stats_layout_v1_*`, `group_stats_layout_v1_*` |
| Provider | `dashboardLayoutProvider` | `statsLayoutProvider` / `groupStatsLayoutProvider` |
| UI kabuk | home edit mode | Stats/Gruplar “Düzenle” (flag) |

### 2.2 Stats çekirdeği

| Parça | Dosya | Not |
|---|---|---|
| Dönem | `stats_period.dart` | `today/week/month/all` — **yıl/özel aralık yok** `:4` |
| Provider | `stats_period_provider.dart` | Ortak kişisel+grup sekmeleri |
| Hot window | `session_window.dart` | 90 gün detay |
| Aggregate helpers | `study_stats.dart` | dailyTotals, streak, weekday split… |
| Canonical | `canonical_stats_projection.dart` | senkron projeksiyon |
| Istanbul | `istanbul_calendar.dart` | gün sınırı |

### 2.3 Grup stats (bugün)

| Parça | Kanıt |
|---|---|
| RPC | `group_daily_totals` — `supabase_study_repository.dart:142-149` |
| Realtime | sessions değişince debounce RPC refresh `:177-179` |
| UI | `ClassStatsView`: leaderboard, heat table üye×dönem, bar/line, group streak/goal `:24-99` |
| Home kart | `GroupTrendCard`, `LeaderboardCard`, `GroupGoalCard` |
| **Eksik** | Üye katkı **halkası**, liderlik **zaman serisi**, üye×subject, dönem **kıyas**, özel tarih aralığı, ızgara özelleştirme |
| `watchGroupSessions` | **boş stream** — ham grup oturumu UI’da yok `:135-139` |

### 2.4 Grafik envanteri (kodda)

| Tür | Durum | Dosya |
|---|---|---|
| Bar | fl_chart | `daily_bar_chart.dart` |
| Line | fl_chart | `daily_line_chart.dart` |
| Scatter | fl_chart | `session_scatter_chart.dart` |
| **Pie / donut** | fl_chart **var** | `subject_donut.dart` (`PieChart`) |
| Heatmap takvim | **custom** | `study_heatmap.dart` |
| Week×hour heat | **custom** | `week_hour_heatmap.dart` |
| Heat table | custom | `stat_heat_table.dart` |
| Hour activity | chart | `hour_activity_chart.dart` |
| Radar | **yok** | — |
| Stacked bar | **yok** | — |
| Area fill | line ile kısmen | genişletme |
| Gauge | **yok** | — |

**pubspec:** `fl_chart: ^1.2.0`

### 2.5 Tema / a11y

- WP-141: `colorScheme` bağlama; chart serileri `subject_colors` + scheme.  
- WP-140: tooltip/Semantics/48dp — yeni kart aksiyonlarına aynı.  
- Yalnız renge dayalı seri → etiket + desen (karar).

### 2.6 Stats ekran yapısı (bugün)

```
StatsScreen
  Tab: Kişisel | Grup
  StatsPeriodBar (today/week/month/all)
  PersonalStatsView → sabit ListView (özet, bar, line, donut, heatmap…)
  ClassStatsView → sabit ListView (sıralama, trend, heat table…)
```

**Wireframe hedef:**

```
StatsScreen / Gruplar-analitik
┌─────────────────────────────────────┐
│ Dönem: [Bugün|Hafta|Ay|Yıl|Özel] [⇄]│  ← kıyas toggle
│ [Düzenle]  [Kart ekle +]            │
├─────────────────────────────────────┤
│ ┌─────┐ ┌──────────┐ ┌────┐        │
│ │Gauge│ │  Trend   │ │Donut│  grid │
│ └─────┘ │  line    │ └────┘        │
│ ┌──────────────────────────────┐   │
│ │     Heatmap / streak         │   │
│ └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## 3. Mimari tasarım (öneri)

### 3.1 Özelleştirilebilir stat-ızgara

```
AnalyticsSurface { personalStats | groupStats }
  → AnalyticsLayoutRepository (prefs local + optional cloud profile)
  → List<AnalyticsCardConfig { type, x,y,w,h, params }>
  → grid_reflow (shared)
  → AnalyticsCardRegistry.build(type, size, context)
```

- **params:** `{ periodOverride?, comparePrevious: bool, subjectFilter? }`  
- Ana ekran `DashboardCardType.timer` **Stats layout’a eklenemez** (donuk/ürün ayrımı).  
- Grup yüzeyi: yalnız grup-context kartları + “benim katkım”.

### 3.2 Kart kataloğu (≥18 tür)

| ID | Ad | Veri | Grafik | Yüzey |
|---|---|---|---|---|
| `totalPeriod` | Dönem toplamı | sessions/summary | big number | kişisel |
| `goalGauge` | Hedef % | goal + today | **gauge** (yeni) | kişisel |
| `trendLine` | Trend | dailyTotals | line | her ikisi |
| `trendBar` | Günlük çubuk | dailyTotals | bar | her ikisi |
| `subjectDonut` | Konu dağılımı | subject | pie/donut **mevcut** | kişisel |
| `subjectStacked` | Konu yığılmış | subject×day | **stacked bar** | kişisel |
| `hourOfDay` | Saat aktivite | istanbulHour | bar/heatmap **mevcut** | kişisel |
| `weekHourHeat` | Hafta×saat | WeekHourHeatmap | heat **mevcut** | kişisel |
| `streakHeatmap` | Seri + takvim | day totals | StudyHeatmap + streak (WP-149) | kişisel |
| `weekdaySplit` | Hafta içi/sonu | split | bar | kişisel |
| `records` | Rekorlar | study_stats | text/list | kişisel |
| `scatterSessions` | Oturum dağılımı | sessions | scatter | kişisel |
| `periodCompare` | Geçen döneme göre | 2× range | dual bar / delta % | kişisel |
| `insightStrip` | 1 cümle insight | kurallar | text | kişisel |
| `groupTotal` | Grup dönem toplam | DailyStat | number | grup |
| `groupGoalGauge` | Grup hedef | groupDay | gauge | grup |
| `groupTrend` | Grup trend | groupDayTotals | line/bar **kısmen var** | grup |
| `groupLeaderboard` | Sıralama anlık | userTotalsInRange | list **var** | grup |
| `groupLeaderboardHistory` | Sıralama zaman serisi | RPC yeni | line multi | grup |
| `groupMemberDonut` | Üye katkı payı | totals | pie | grup |
| `groupHeatTable` | Üye×dönem | StatHeatTable **var** | table | grup |
| `groupStreak` | Grup hedef serisi | currentStreak group | number | grup |

**MVP (öneri, onaylanacak):** 10 kart — totalPeriod, goalGauge, trendLine, subjectDonut, streakHeatmap, hourOfDay, periodCompare, groupTotal, groupMemberDonut, groupLeaderboard + heatTable.

### 3.3 Grafik kütüphanesi kararı

| Tür | Yol |
|---|---|
| Line/Bar/Scatter/Pie | fl_chart **mevcut** |
| Heatmap takvim / week-hour | **mevcut custom** — fl_chart şart değil |
| Stacked bar | fl_chart BarChart stack veya custom |
| Area | LineChart belowBarData |
| Radar | fl_chart RadarChart (pakette var mı sürümle doğrula) veya basit custom |
| Gauge | CustomPainter + scheme (hafif) |

**Öneri:** Yeni paket eklemeden fl_chart + mevcut heat custom + 1–2 CustomPainter (gauge). Radar **P1 opsiyonel**.

### 3.4 Dönem modeli genişletme

```
StatsPeriod → AnalyticsPeriod {
  today, week, month, year, all, custom(from, to)
}
compare: none | previousEqualLength
```

- Gün sınırı: `istanbulDay` (WP-146 testleri).  
- `all` hâlâ hot window + summary; gerçek “ömür” summary alanları.

---

## 4. Veri modeli & backend

### 4.1 Client vs server

| Agrega | Client (90g sessions) | Server RPC |
|---|---|---|
| Kişisel günlük seri 90g | ✓ | — |
| Kişisel yıl/ömür | summary | mevcut |
| Saat histogram 90g | ✓ | opsiyonel |
| 1y+ histogram | — | `get_user_day_totals(p_from,p_to)` |
| Grup günlük üye | — | **`group_daily_totals` mevcut** |
| Grup liderlik geçmişi | zor | **yeni** `group_leaderboard_series` |
| user_study_day | WP-149 B | 0039+ backfill |

### 4.2 Migration taslak (onay sonrası)

- **0039** `user_study_day` (opsiyonel ama streak/uzun heatmap için önerilir)  
- **0040** `get_user_day_totals` / histogram SECURITY DEFINER `search_path=public`  
- **0041** `group_contribution_breakdown` (member seconds in range) — RLS üyelik  
- Layout cloud sync **opsiyonel 0042** `user_ui_layouts` jsonb — v1 yalnız prefs

### 4.3 RLS / gizlilik

| Kural | |
|---|---|
| Kişisel kartlar | yalnız `auth.uid()` |
| Grup kartları | `is_group_member(gid)` |
| Üye isimleri | profiles select 0036 kuralları |
| Ham başkasının session listesi | **yok** (sadece aggregate RPC) |
| Super-admin | mevcut admin yolları; Stats ızgara sızdırmaz |

### 4.4 Repository çift

```
AnalyticsLayoutRepository { load/save surface }
AnalyticsQueryRepository {
  personalDaySeries, subjectBreakdown, hourHistogram,
  groupDaySeries, groupMemberShares, groupLeaderboardSeries
}
→ supabase/ + in_memory/
```

---

## 5. Fazlı uygulama planı (onay sonrası numaralar WP-157+)

| Faz | WP öneri | SAHİP | DOKUNMA | Flag | Rollback |
|---|---|---|---|---|---|
| **F0** | WP-157 grafik primitives (gauge, stacked helper, seri paleti a11y) | `features/stats/charts/**` yeni | home dashboard | n/a | sil paket |
| **F1** | WP-158 Analytics grid shell + layout persist (prefs) | stats_screen, new providers, grid_reflow **read-only share** | dashboard keys | `analytics_grid_v1=false` | flag off = eski ListView |
| **F2** | WP-159 Kart kataloğu kişisel part 1 (mevcut widget sarmalayıcılar) | registry + cards | class_stats logic kopya yok — extract | flag | |
| **F3** | WP-160 Kart kataloğu kişisel part 2 (compare, gauge, streak) | + WP-149 merge | timer | flag | |
| **F4** | WP-161 Grup analitiği + RPC 0040/41 | migrations, supabase_study, ClassStatsView replace shell | FGS | flag | SQL rollback notu |
| **F5** | WP-162 Düzenle UI (ekle/çıkar/boyut) + l10n ARB | edit mode | home edit code share dikkat | flag | |
| **F6** | WP-163 dönem year/custom + insight strip | stats_period expand | — | flag | |

**Önce şunu bozmadan:**

1. Flag kapalıyken mevcut `PersonalStatsView` / `ClassStatsView` **birebir**.  
2. `dashboard_layout_*` anahtarlarına yazma.  
3. `group_daily_totals` sözleşmesini bozmadan genişlet (yeni RPC ayrı).  
4. Timer/widget/FGS dosyalarına **0 satır**.

---

## 6. Test & QA

| Katman | Ne |
|---|---|
| Unit | period range, compare previous, istanbul boundaries, member share % |
| Unit | grid_reflow with AnalyticsCardConfig ids |
| Widget | empty/loading/error per surface (WP-147 paterni) |
| Golden (opsiyonel) | donut/heatmap contrast |
| Cihaz | 50+ üye grup, 90g data, textScale 1.3, light/dark, TalkBack kart ekle |
| RLS | 2 hesap grup üye/non-üye |

---

## 7. Risk & açık sorular

| Risk | Azaltma |
|---|---|
| Stats ekranı 2× karmaşıklık | Flag + kademeli kart partileri |
| fl_chart radar kalitesi | MVP dışı |
| Grup privacy sızıntısı | Yalnız aggregate RPC |
| Perf büyük aralık | server day table (WP-142 hizası) |
| Ana ekran / stats kod birleşimi | shared grid only; ayrı registry |

### Karar bekliyor

1. MVP 10 kart listesi onay?  
2. `user_study_day` 0039 şart mı yoksa 90g client yeterli mi v1?  
3. Gruplar sekmesi mi (classroom) yoksa Stats→Grup tab mı birincil ızgara?  
4. Layout cloud sync v1? (öneri: hayır, prefs)  
5. Insight cümleleri ürün dili kimin?

---

## Claude / kullanıcı onay kontrol listesi

### Mimari
- [ ] `grid_reflow` paylaşılır; **ayrı** `AnalyticsCardType` + persist keys  
- [ ] Flag `analytics_grid_v1` default **kapalı**  
- [ ] Timer kartı Stats ızgarasında **yok**  

### Katalog / grafik
- [ ] MVP kart seti (yukarıdaki 10) onay / değiştir  
- [ ] fl_chart + mevcut heat + custom gauge yeterli; yeni heavy package yok  
- [ ] Radar P1 opsiyonel  

### Veri
- [ ] Grup: mevcut `group_daily_totals` + yeni contribution/history RPC  
- [ ] `user_study_day` v1 veya ertele  
- [ ] RLS: üye-only aggregate  

### Faz
- [ ] F0→F6 sırası onay  
- [ ] WP-149/150 bu plana **devredildi**; ayrı kör kod yok  

### Kırmızı çizgi
- [ ] WP-134–137 timer/widget/FGS dosyalarına dokunulmaz  

---

## WP-150 / WP-149 ilişkisi

| Eski | Yeni |
|---|---|
| WP-150 stats derinleştirme | **WP-156 planı kapsar** → uygulama F2–F3 |
| WP-149 streak/heatmap | Kart `streakHeatmap` + opsiyonel 0039 |

progress: WP-150 “WP-156’ya devredildi”; WP-149 planı hâlâ referans, uygulama 156 fazına bağlı.

---

*WP-156 sonu. Onay gelmeden migration/kod yok.*
