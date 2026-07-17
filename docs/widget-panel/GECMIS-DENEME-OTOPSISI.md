# Geçmiş deneme otopsisi — Timer FGS / Widget / “Dinamik panel”

**WP-133 ek belgesi · 2026-07-17 · salt okuma**  
Ana rapor: [`WIDGET-DINAMIK-PANEL-ANALIZ.md`](./WIDGET-DINAMIK-PANEL-ANALIZ.md)

Her satır: **commit** · ne denendi · ne bozuldu / ne öğrenildi · bugünkü koda etkisi.

| Commit | Etiket / WP | Ne denendi | Ne bozuldu / yan etki | Öğrenilen | Bugün hâlâ geçerli mi? |
|---|---|---|---|---|---|
| `0edfeaa` | WP-42/51 · beta-v12 | Flutter FGS yerine **native `StudyTimerService`**; widget/bildirim app-kapalı Start/Stop; `timer_pending_intervals`; method channel `…/timer` | İlk cihaz turunda açılış çökme döngüsü (→ v13) | App-kapalı kontrol **native** olmalı; oturum kaydı Dart | Evet — mimari omurga |
| `c6334fd` | beta-v13 | `START_STICKY` → **`START_NOT_STICKY`**; her yolda 5 sn `startForeground`; bildirim aksiyonları `getForegroundService` | v12: Durdur sonrası null-intent restart → `ForegroundServiceDidNotStartInTimeException` | Otomatik sticky restart + FGS 5 sn kuralı ölümcül | Evet — `StudyTimerService.kt:96` `START_NOT_STICKY` |
| `3317a4f` | beta-v14 | Sade widget + yumuşak düğmeler | — | UI sadeleştirme | Kısmen (layout evrildi) |
| `dc53826` / `94945ac` | beta-v15 | Bildirim süre görünümü; **in-app start idle race** | Start sonrası bildirim `00:00:00`+Başlat’ta takılı: native `apply()` + reconcile idle okuma | Start yolunda **`commit()`** + Dart `hasActiveStart` koruması | Evet — start `commit()`; **stop hâlâ `apply()`** (asimetri riski) |
| `a2688de` | **WP-76** | “Dinamik panel”: `timer_notification_expanded.xml` Mola/Durdur; specialUse FGS; reconcile genişletme | **API ≤13 FGS tip uyumsuzluğu** (manifest yalnız specialUse, kod DATA_SYNC) → Not20/A51 çökme (→ WP-103). “Canlı panel” OEM’de garanti değil | expanded RemoteViews + specialUse bir arada yüksek risk yüzeyi | Expanded layout **silindi** (WP-80); specialUse tipi WP-103 ile dual |
| `bf84877` | WP-78 · beta-v19 | Yayın paketi (WP-76/77 ile) | ≤13 cihazlarda sayaç başlat/durdur çökmesi (WP-103 kartı: “beta-v19’dan beri”) | Yayın, native tip hatasını tüm kullanıcıya yayar | Tarihsel |
| `53f3c3b` | WP-79 | Açılışta toplu bildirim (güncelleme/dürtme) | Kullanıcı “bildirim patlaması” algısı | Açılış seed sessizlenmeli | Bildirim UX; timer’dan ayrı |
| `0bba715` | **WP-80** | Expanded RemoteViews **kaldırıldı**; “standart ongoing + usesChronometer + addAction” — OEM Live/Now Bar terfisi umudu | Custom panel gitti; Mola/Durdur standart action; One UI’de MM:SS / alt satır şikayetleri (sonra v23) | **OEM Live Activity yok**; custom vs standard trade-off | Sonra One UI için custom’a **geri dönüş** (`c1b9d9c` + güncel kod) |
| `ccc97c2` / `92a7c3a` | WP-81 · beta-v20 | WP-79/80 paket yayını | — | Paketleme | Tarihsel |
| `c1b9d9c` | v23 One UI layout | Tekrar **custom RemoteViews** satırı (HH:MM:SS + pill); `setUsesChronometer(false)` builder’da | WP-80’in “standart stil = OEM terfi” hipotezi fiilen terk | One UI zorunlu app başlığı altında ürün satırı | **Evet — güncel `buildRunningNotification` custom** |
| `6371eec` | beta-v24 | Bildirim geri dönüşü / yenileme | — | Regresyon döngüsü devam | — |
| `01e8287` | WP-100 | Local emit, refresh timeout, presence race | Senkron UI; timer FGS doğrudan değil | Presence/timer UI ayrımı | Var |
| `4c3e259` | **WP-103** | Manifest `dataSync\|specialUse`; API 29–33 DATA_SYNC, 34+ SPECIAL_USE | WP-76 specialUse-only ≤13 çökmesi | Runtime tip ⊆ manifest | **Evet** — `startForegroundCompat` + manifest |
| `a457b06` | WP-118 | `TimerActionReceiver` **exported=false** | Teorik: implicit broadcast dışarıdan; same-app **explicit** PendingIntent OK | exported=false + explicit class güvenli | Evet — `AndroidManifest.xml:70-75` |
| `c0be5af` | QA park | WP-76…103 “ürün kabulü” işaretlendi | **Kullanıcı şikayeti hâlâ var** → “kabul” ≠ kalıcı memnuniyet / veya reg | progress “Tamamlanan” ile saha gerçeği ayrışabilir | Açık soru |

## Otopsi özeti (tek cümle)

“Dinamik panel” denemeleri **(1)** OEM Live Activity’nin Android’de **ürün garantisi olmadığı**, **(2)** FGS tip/START_STICKY/5 sn kurallarının **bildirim UI değişikliğiyle birlikte** kırıldığı, **(3)** custom RemoteViews ↔ standard chronometer arasında **sarkaç** olduğu için her turda farklı yüzey (widget/bildirim/≤13 çökme) bozuldu.

## WP-76 expanded panel — kayıp özellik listesi

`timer_notification_expanded.xml` (a2688de, sonra 0bba715 ile silindi):

- Büyük Chronometer
- Durum metni (“Odaklanıyorsun” / “Mola sürüyor”)
- Birincil eylem: Mola **veya** Çalışmaya dön
- İkincil: Durdur
- Doğrudan FGS PendingIntent (Flutter resume yok)

Güncel yüzey: dar `timer_notification.xml` — Chronometer + tek pill (Başlat/Durdur); Mola **yok**.
