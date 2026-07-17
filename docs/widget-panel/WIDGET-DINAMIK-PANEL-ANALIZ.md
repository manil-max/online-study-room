# WP-133 — Android Widget & Dinamik Panel Kararlılık / Yeniden Mimari ANALİZİ

| Alan | Değer |
|---|---|
| Tarih | 2026-07-17 |
| Tür | Araştırma + mimari + plan (**ürün kodu yok**) |
| Ajan | Grok · lane: doküman/analiz |
| Ana ek | [`GECMIS-DENEME-OTOPSISI.md`](./GECMIS-DENEME-OTOPSISI.md) |
| Kanıt kuralı | Her teknik iddia → dosya:satır veya commit hash |

> **“Tamamlandı” notu:** `progress.md` WP-76/80/81/103’ü 2026-07-17 ürün kabulüne almış olabilir; kullanıcı saha şikâyeti (widget güvenilmez, canlı saat bayat, dinamik panel yok) **ayrı kanıt**tır. Bu rapor kodu ve git’i okur; cihaz videosu bu oturumda yok → saha iddiaları `Cihazda doğrulanmalı` ile işaretlenir.

---

## A. Gerçek yüzey haritası (mevcut kod)

### A.1 Native Kotlin

| Bileşen | Dosya | Rol (kanıt) |
|---|---|---|
| FGS sayaç | `StudyTimerService.kt` (478 sat) | Tek native otorite: START/STOP/TOGGLE/BREAK; prefs + bildirim + widget refresh; **oturum yazmaz** (`:32-36`) |
| Toggle receiver | `TimerActionReceiver.kt` | Widget düğme → `ACTION_TOGGLE` (`:19-22`) |
| Widget provider’lar | `StudyWidgetProviders.kt` (310) | Timer Chronometer + 5 diğer widget |
| Widget refresh | `TimerWidgets.kt`, `WidgetRefreshReceiver.kt` | Servisten `ACTION_APPWIDGET_UPDATE` broadcast |
| Dart köprü | `MainActivity.kt` | `startTimer`/`stopTimer`; `STATE_CHANGED` → `reconcile` **yalnız onResume…onPause** (`:83-97`) |
| Alarm | `alarm/*`, `TimerBootReceiver` | Ayrı yüzey; FGS ile yarışabilir (izin/pil) |

### A.2 Manifest & kaynak

| Öğe | Kanıt |
|---|---|
| FGS izinleri | `FOREGROUND_SERVICE_DATA_SYNC` + `SPECIAL_USE` (`AndroidManifest.xml` üst kısım) |
| `StudyTimerService` | `foregroundServiceType="dataSync\|specialUse"`, `exported=false` (`:90-96`) |
| Eski plugin FGS | `flutter_foreground_task` hâlâ `dataSync` (`:80-82`) — ikinci FGS yüzeyi |
| `TimerActionReceiver` | `exported=false` WP-118 (`:70-75`) |
| Timer widget | `odak_timer_widget.xml` — **Chronometer** + TextView düğme (`:12-35`) |
| Widget meta | `updatePeriodMillis="1800000"` = **30 dk** (`odak_timer_widget_info.xml:8`) |
| Bildirim layout | `timer_notification.xml` — Chronometer + pill (`:13-40`) |

### A.3 Flutter / Dart

| Bileşen | Rol |
|---|---|
| `timer_foreground_service.dart` | Method channel köprüsü only; kayıt yok |
| `study_providers.dart` `StudyTimerNotifier` | Reconcile, presence, oturum, widget snapshot debounce |
| `android_widget_service.dart` | home_widget snapshot; **eski** `widgetBackgroundCallback` toggle yolu (`:11-17`) hâlâ duruyor |
| `timer_notification_service.dart` | Eski Flutter bildirim yolu (native ile çiftlik riski — kısmen legacy) |

### A.4 Veri akışı (özet diyagram)

```
[Widget pill] --PendingIntent explicit--> TimerActionReceiver
        --> StudyTimerService.sendCommand(TOGGLE)
            --> prefs (FlutterSharedPreferences)
            --> startForeground + Notification (RemoteViews Chronometer)
            --> TimerWidgets.updateAll --> TimerWidgetProvider.onUpdate
            --> BROADCAST_STATE_CHANGED (package-local)
                    |
                    +--> (yalnız MainActivity RESUMED) MethodChannel "reconcile"
                    +--> (app ölü) pending_intervals kuyruk; Dart cold start'ta _reconcileBackgroundTimer

[In-app Start/Stop] --> MainActivity timer channel --> same StudyTimerService
[Dart UI state] <--> SharedPreferences keys flutter.timer_active_*
```

**Tek doğruluk kaynağı yok:**  
Native prefs (`flutter.timer_active_started_at_ms`, `timer_fg_mode`, `timer_pending_intervals`) + Dart `StudyTimerState` + RemoteViews anlık görünüm + (opsiyonel) home_widget string snapshot. Üç-dört ayna.

---

## B. Kök neden analizi (kanıtlı)

### B1. 1×1 Başlat/Durdur widget neden güvenilmez?

#### B1.1 Zincir (kodda)

1. `TimerWidgetProvider.onUpdate` düğmeye explicit `PendingIntent.getBroadcast(…, TimerActionReceiver::class, FLAG_UPDATE_CURRENT|FLAG_IMMUTABLE)` (`StudyWidgetProviders.kt:93-101`).
2. `TimerActionReceiver.onReceive` → `StudyTimerService.sendCommand(ACTION_TOGGLE)` (`TimerActionReceiver.kt:19-22`).
3. `sendCommand` → API 26+ `startForegroundService` (`StudyTimerService.kt:471-475`).
4. `ACTION_TOGGLE`: prefs’te `KEY_STARTED_AT` varsa stop, yoksa start stopwatch (`:71-82`).

#### B1.2 `exported=false` (WP-118) bozar mı?

**Kodda bozmaz (bilinçli tasarım):** Intent **sınıfa explicit** (`Intent(context, TimerActionReceiver::class.java)`). Same-UID PendingIntent, non-exported receiver’ı tetikleyebilir.  
**Kanıt:** Manifest yorumu (`AndroidManifest.xml:68-71`) + explicit Intent (`StudyWidgetProviders.kt:93-95`).  
**Açık risk (düşük):** Başka bir yol action-only implicit broadcast kullanırsa API 34+ kısıtları devreye girer — mevcut widget yolu explicit.

#### B1.3 requestCode / IMMUTABLE

- Toggle requestCode **sabit 0** (`:98`). Aynı component+action → UPDATE_CURRENT ile tek PI; genelde OK.
- `FLAG_IMMUTABLE`: extra yok → doğru.

#### B1.4 Durum kaynağı bayatlığı (güçlü bulgu)

Toggle kararı: `prefs().contains(KEY_STARTED_AT)` (`StudyTimerService.kt:72`).  
Widget etiket kararı: `startMillis` + `mode == "stopwatch"` (`StudyWidgetProviders.kt:66-77`).

| Risk | Kanıt |
|---|---|
| **Stop sonrası widget hâlâ “çalışıyor” / ters toggle** | `handleStop` prefs temizliği **`apply()`** (`:207-211`) — async; hemen ardından `TimerWidgets.updateAll` (`:216`). Start yolu bilinçli **`commit()`** (`:117-119`, beta-v15). **Asimetri.** |
| **mode eksik → Chronometer kapalı ama isRunning true** | Chronometer yalnız `mode == "stopwatch"` (`:77`); TOGGLE start mode=`stopwatch` yazar; bozuk/partial prefs’te sapma mümkün |
| **Çift toggle yolu** | Eski `widgetBackgroundCallback` prefs’e `start/stop` komutu yazar (`android_widget_service.dart:11-17`) — native receiver ile **farklı semantik**; hangisinin bağlı olduğu widget meta’sına bağlı (şu an provider native PI kullanıyor) |

#### B1.5 FGS 5 sn / startForeground

Toggle her iki dalda da `handleStart` / `handleStop` **önce** `startForegroundCompat` çağırır (`:121`, `:188`).  
`START_NOT_STICKY` (`:96`) — v13 otopsisine uygun.  
**Kanıt:** beta-v13 mesajı `c6334fd`; kod yorumları `:38-47`.

#### B1.6 App tamamen ölüyken oturum

- Native **oturum kaydetmez**; `timer_pending_intervals` kuyruğu (`:32-36`, `appendPendingInterval :372-389`).
- Dart: soğuk açılışta `Future.microtask` → `_syncBackgroundTimerState` (`study_providers.dart:479-486`); auth yoksa kuyruk **korunur** (`:525-527`).
- **Kayıp senaryoları (kanıtlı risk):**
  1. Auth uzun süre null + kuyruk bozulması / clear yarışı.
  2. `BROADCAST_STATE_CHANGED` app ölüyken **kimse dinlemez** (`MainActivity` yalnız resume, `:83-97`) → UI anında güncellenmez (beklenen); kayıt app açılınca.
  3. Kullanıcı “Durdur basıldı ama süre gitmedi” = kuyruk + reconcile gecikmesi algısı.

#### B1.7 Compact 1×1: düğme var, saat yok

`isCompact`: `width < 150 || height < 110` (`StudyWidgetProviders.kt:36-40`).  
min widget 110×110 (`odak_timer_widget_info.xml:4-5`) → **çoğu 1×1 compact**.  
Compact’te Chronometer **`View.GONE`** (`:107-110`) — kullanıcı “saat akmıyor” derken aslında **gizlenmiş** olabilir.  
`Cihazda doğrulanmalı` (ekran görüntüsü ile minWidth).

---

### B2. Widget canlı saati neden akmıyor / bayat?

#### B2.1 Mekanizma (bugün)

- Layout: **`Chronometer`** (`odak_timer_widget.xml:12-20`) — TextView değil.
- `onUpdate` içinde `setChronometer(…, base, null, true)` yalnız  
  `isRunning && mode == "stopwatch"` (`StudyWidgetProviders.kt:77-79`).
- Aksi: chronometer stopped + format `"00:00:00"` (`:80`).

**Sonuç:** Canlı akış **sistem Chronometer** ile; `updatePeriodMillis` saniye tick **için değil**.

#### B2.2 `updatePeriodMillis = 1800000` (30 dk)

`odak_timer_widget_info.xml:8`.  
Android sistem sınırı: periyodik update **≥ 30 dk** ve agresif throttle.  
**Canlı saniye için yetersiz** — tasarım doğruysa Chronometer yeterli; Chronometer kurulmazsa 30 dk’da bir bayat snapshot.

#### B2.3 Chronometer’ın kurulmadığı / bozulduğu senaryolar

| Senaryo | Etki | Kanıt |
|---|---|---|
| Compact 1×1 | Saat GONE | `:107-110` |
| mode ≠ stopwatch | Chronometer false | `:77` |
| `started_at_ms` yok / parse fail | isRunning false → 00:00:00 | `:66-71` |
| Widget update **toggle sonrası gelmez** | Eski RemoteViews (eski base veya stopped) | `TimerWidgets.updateAll` broadcast; OEM/provider almazsa bayat |
| Process death + servis NOT_STICKY | Bildirim/widget son snapshot; Chronometer process’te yaşar — launcher process’e bağlı OEM farkı | Platform |
| base formülü | `elapsedRealtime - (now - startWall)` (`:78`) — wall clock atlama (TZ/manuel saat) kaydırır | Aynı formül bildirimde `:312` |

#### B2.4 Bildirim saati vs widget saati

Bildirim: custom RemoteViews Chronometer (`StudyTimerService.kt:310-316`), builder `setUsesChronometer(false)` (`:285-286`) — One UI v23 tercih (`c1b9d9c`).  
Widget: ayrı RemoteViews.  
İkisi de aynı ms anahtarına dayanır ama **bağımsız update** — tutarsızlık mümkün.

---

### B3. “Dinamik panel” neden defalarca başarısız? (otopsi özeti)

Detay tablo: [`GECMIS-DENEME-OTOPSISI.md`](./GECMIS-DENEME-OTOPSISI.md).

#### B3.1 Android gerçeği

**iOS Live Activity yok.** Yaklaşık karşılıklar:

| Seçenek | Ne | Garanti |
|---|---|---|
| A | Zengin **ongoing notification** (RemoteViews) | Genişletilebilir bildirim; OEM “Now Bar / Live” **garanti değil** |
| B | Standard `setUsesChronometer` + actions | Bazı OEM’lerde terfi umudu; One UI’de metin/layout kötü olabilir (WP-80→v23 sarkacı) |
| C | StandBy / always-on (mevcut Saat programı) | Ayrı yüzey; widget değil |
| D | MediaStyle / ProgressStyle (API 36 Live Updates) | Sürüm/OEM kısıtlı; henüz üründe yok |

#### B3.2 Ürün belirsizliği (başarısızlığın kökü)

WP-51/76 kartları “native saat gibi / HyperOS Live / Samsung Now Bar / Android 16 Live Updates” ister (`progress.md` tarihsel kartlar).  
Kod sarkacı:

1. **WP-76** (`a2688de`): expanded panel + Mola + specialUse  
2. **WP-80** (`0bba715`): custom kaldır, standard chronometer (OEM terfi)  
3. **v23** (`c1b9d9c`) + **güncel**: tekrar custom One UI satırı, Mola yok  

Kullanıcı “panel teslim edilmedi” diyorsa: expanded + Mola **bilinçli geri alındı**; “kabul” metni ile saha beklentisi **çelişebilir**.

#### B3.3 Yan hasar zinciri

```
WP-76 specialUse-only manifest ──► ≤13 FGS çökme ──► WP-103 dual type
WP-76/80 UI sarkacı ──► One UI layout şikâyeti ──► v23 custom geri
START_STICKY (v12) ──► açılış çökme döngüsü ──► START_NOT_STICKY (v13)
start apply race ──► idle bildirim (v15) ──► commit + hasActiveStart
```

**Örüntü:** Bildirim UI + FGS yaşam döngüsü + widget + Dart reconcile **aynı prefs ve aynı serviste** kilitli → bir “panel” PR’ı üç yüzeyi birden kırar.

---

### B4. Çapraz-bozulma haritası

```
                    ┌─────────────────────────┐
                    │ FlutterSharedPreferences│
                    │ timer_active_* / fg_mode│
                    │ pending_intervals       │
                    └───────────┬─────────────┘
           ┌────────────────────┼────────────────────┐
           v                    v                    v
   StudyTimerService     StudyTimerNotifier    TimerWidgetProvider
   (notif RemoteViews)   (Dart UI+presence)    (widget RemoteViews)
           │                    │                    │
           └────── BROADCAST ───┘ (yalnız resume)    │
           └────── updateAll broadcast ──────────────┘
```

| Paylaşılan | Yarış / bozulma |
|---|---|
| prefs start keys | commit vs apply (start/stop asimetri) |
| `fg_mode` | beta-v15 idle reconcile bug; guard hâlâ karmaşık (`study_providers.dart:553-584`) |
| FGS tip | ≤13 vs 14+ (WP-103) |
| İki FGS | `StudyTimerService` + `flutter_foreground_task` (`Manifest:80-82`) — izin/OEM kafa karışıklığı |
| Presence | Dart start/stop; widget start app ölü → presence app açılana kadar eksik |
| Alarm exact | Ayrı stack; pil OEM’i FGS’i de öldürebilir |

**Mimari neden “birini düzelt öbürü bozulur”:**  
UI kararı (panel stili) ile süreç kararı (FGS sticky/tip) ve veri kararı (prefs commit) **aynı sınıfta** (`StudyTimerService`) birleşik; feature flag yok; rollback = git revert tüm yüzey.

---

## C. Hedef mimari (öneri)

### C.1 Tek doğruluk kaynağı (SSOT)

**Öneri: Native kalıcı store = SSOT (zaten fiilen prefs).**

| Katman | Sorumluluk |
|---|---|
| **Native `TimerStateStore`** (yeni ince modül; bugün prefs dağınık) | `startedAtMs`, `mode`, `phase`, `cycle`, `fgMode`, `pendingIntervals[]` — **yalnız `commit()`** yazım API’si |
| **StudyTimerService** | Store okuyup bildirim + FGS; komut uygular; store yazar |
| **Dart StudyTimerNotifier** | Store’u **okuyarak** türetir; oturum muhasebesi (server-authoritative); presence |
| **Widget** | Store’dan Chronometer base; toggle komutu servise; **UI state tutmaz** |

Dart asla “ben running’im, native idle” diye uzun süre kalmamalı: cold start + resume + (isteğe bağlı) WorkManager periyodik sync.

### C.2 Canlı saat

| Yüzey | Mekanizma | Yapma |
|---|---|---|
| Bildirim | RemoteViews `Chronometer` **veya** (flag) standard `usesChronometer` — **ürün seçimi** | Saniyede Flutter text update |
| Widget | RemoteViews `Chronometer` + **compact’te de görünür** (küçük textSize) | `updatePeriodMillis` ile saniye |
| In-app | Dart ticker (mevcut) OK | |

### C.3 Reconcile dayanıklılığı

| Bugün | Hedef |
|---|---|
| `STATE_CHANGED` yalnız resume (`MainActivity:83-97`) | (1) Cold start microtask (zaten var) güçlendir; (2) **ProcessLifecycle** veya Application-level receiver **engine ayaktayken**; (3) app ölü: yalnız store + pending — **kayıp yok garantisi** test ile |
| stop `apply()` | **Tüm store yazımları `commit()`** veya tek-thread writer |

### C.4 Dinamik panel — 3 somut ürün tanımı (seçim zorunlu)

#### Seçenek P1 — “Kontrol bildirimi MVP” (önerilen ilk teslim)

```
┌──────────────────────────────────────┐
│ Odak Kampı                    [sys]  │  ← OEM başlık (kaldırılamaz)
│  01:23:45          [ Mola ] [Durdur] │  ← Chronometer + 1–2 action
└──────────────────────────────────────┘
```

- **Davranış:** App kapalı Start/Stop/Mola; süre akar; Mola oturuma yazılmaz (mevcut kural).  
- **Teknik:** Güncel custom RemoteViews’a **Mola’yı geri ekle** (expanded opsiyonel, feature flag).  
- **Artı:** Kontrol edilebilir, Play FGS beyanı ile uyumlu, WP-76’nın somut kısmı.  
- **Eksi:** “Now Bar’da dev ada” **yok**.

#### Seçenek P2 — “OEM Live umudu (best-effort)”

```
Standard ongoing + CATEGORY_STOPWATCH + usesChronometer + actions
→ Samsung/HyperOS terfi EDEBİLİR veya etmez
```

- **Artı:** WP-80 niyeti.  
- **Eksi:** One UI layout regresyonu tarihsel (`c1b9d9c`); **kabul kriteri “terfi” olamaz**.  
- **Kabul:** “Standart sistem stilinde akar; terfi bonus.”

#### Seçenek P3 — “Canlı kilit/StandBy paneli” (ayrı ürün)

Mevcut Saat StandBy / clock hub; çalışma sayacı ile **birleştirme ayrı WP**.  
Widget/FGS’den izole.

**Tavsiye:** Önce **P1** (MVP, ölçülebilir) + P2’yi **opsiyonel flavor/flag** ile dene; P3 ayrı program.

### C.5 Android sürüm / OEM matrisi (hedef)

| API | FGS tip (mevcut WP-103) | Panel notu |
|---|---|---|
| 26–28 | tip parametresiz | Chronometer OK |
| 29–33 | DATA_SYNC | WP-103 kritik; regression test zorunlu |
| 34–35 | SPECIAL_USE | dataSync 6s cap’ten kaçınma yorumu (`:253-255`) |
| 36+ | Live Updates / ProgressStyle **araştır** (ayrı spike) | Henüz vaat etme |

OEM: Samsung One UI (custom layout), Pixel (standard), Xiaomi (agresif pil — FGS + alarm), düşük RAM (process death + pending kuyruk).

### C.6 Play politika

- Exact alarm / FSI: alarm stack; timer FGS **specialUse beyanı** mevcut property ile (`Manifest:93-95`).  
- Widget toggle FGS başlatır → kullanıcı başlatmalı (zaten).  
- WP-118 exported=false korunmalı.  
- Panel değişikliği **izin yüzeyi genişletmemeli**.

---

## D. Fazlı, izole, geri-alınabilir plan

> Numaralar öneri; planner onayı sonrası claim.

| WP | Ad | SAHİP (yaz) | DOKUNMA | Bağımlılık | Tek-commit kuralı | Feature flag / rollback |
|---|---|---|---|---|---|---|
| **WP-133** | Bu analiz | `docs/widget-panel/**`, `progress.md` | Tüm ürün kodu | — | docs only | — |
| **WP-134** | Widget canlı saat + compact görünürlük | `StudyWidgetProviders.kt`, `odak_timer_widget.xml`, info xml | `StudyTimerService` (mümkünse) | 133 onay | Chronometer her boyutta; base/mode fix | Flag yok; revert tek commit |
| **WP-135** | 1×1 toggle güvenilirliği | `StudyTimerService` stop→`commit`, `TimerActionReceiver`, PI requestCode | Bildirim layout stili | 134 tercih | Store yazım atomik; toggle test | Revert |
| **WP-136** | Reconcile / pending dayanıklılık | `study_providers.dart` reconcile, MainActivity lifecycle (dar), store okuma | Panel UI | 135 | Auth gecikmeli kuyruk testleri | Revert |
| **WP-137** | Dinamik panel MVP (**P1**) | `StudyTimerService` notif builders, `timer_notification*.xml` | Widget layout (okur) | 135–136 yeşil + **ürün P1 onayı** | Mola+Durdur; expanded flag | **`panel_expanded=false` default**; tek PR revert |
| **WP-138** | (opsiyonel) P2 OEM standard stil A/B | flag ile standard builder | P1 custom | 137 | Cihaz matrisi | Flag kapat = P1 |
| **WP-139** | (opsiyonel) API 36 Live Updates spike | docs + prototip dal | production main | 137 | Yalnız spike | Merge etme |

### D.1 “Önce şunu bozmadan” kuralları

1. **WP-134/135** bildirim RemoteViews stilini değiştirmez.  
2. **WP-137** widget Chronometer formülünü değiştirmez (okur store).  
3. FGS tip/`START_NOT_STICKY` / `getForegroundService` **ayrı commit’siz “yanına dokunma”** — değişecekse kendi mini-WP.  
4. Her WP sonrası: API 33 emülatör start/stop + widget toggle + in-app start (v15 regresyon).

### D.2 Rollback

- Her WP tek commit, main’de (proje kuralı).  
- Panel: layout XML + builder dalı flag ile → flag off = önceki görünüm.  
- Store API: eski key isimleri korunur (`flutter.timer_active_*`).

---

## E. Test & cihaz QA matrisi

### E.1 Cihaz / OS

| Cihaz sınıfı | API | Zorunlu senaryo |
|---|---|---|
| Emülatör stok | 29, 33, 34, 35 | FGS tip + toggle + chronometer |
| Samsung One UI | 13–15 | Bildirim satırı HH:MM:SS; widget 1×1/2×2 |
| Pixel | 14–15 | Standard vs custom farkı |
| Xiaomi/MIUI | 12–14 | App öldürme + widget toggle + kuyruk |
| Düşük RAM | herhangi | Process death mid-run |

### E.2 Senaryolar ve kabul

| # | Senaryo | Beklenen | Ölçüt |
|---|---|---|---|
| S1 | App açık, in-app Start | Bildirim akar; Dart UI akar | ≤1 sn tutarlı |
| S2 | App arka plan, bildirim Durdur | FGS biter; pending aralık; açılışta oturum | Süre kaybı 0 (auth sonrası) |
| S3 | App **ölü**, widget Start | Servis + bildirim + widget Chronometer (non-compact) | 5 sn içinde FG; çökme 0 |
| S4 | App ölü, widget Stop | idle pill; pending yazıldı | commit sonrası widget Durdur etiketi |
| S5 | 1×1 compact | **Saat görünür** (WP-134 sonrası) | GONE değil |
| S6 | 1 saat akış | Widget/bildirim sapma | ≤ ±2 sn / saat (wall) |
| S7 | Reboot | Servis NOT_STICKY → idle; pending korunmuş olmalı | Açılış reconcile |
| S8 | TZ / saat değişimi | base kayması belgelenir veya düzeltilir | Açık kabul |
| S9 | Europe/Istanbul gece yarısı | Oturum gün sınırı Dart | Mevcut kural |
| S10 | Alarm çalarken sayaç | İkisi birden; FGS çökmez | Manuel |
| S11 | Bildirim + widget + in-app | Üçü aynı startedAtMs | Snapshot |
| S12 | API 33 start/stop 20 tur | WP-103 regresyon | 0 crash |
| S13 | Panel Mola (P1) | Mola duration oturuma yazılmaz | Pending yalnız work |

### E.3 Otomatik vs cihaz

| Otomatik (Dart/unit) | Yalnız cihaz |
|---|---|
| Reconcile pending list parse | Chronometer görsel akış |
| hasActiveStart / idle race (mevcut testler genişlet) | OEM Now Bar terfi |
| Store commit sıralaması (mock) | Widget 1×1 compact ölçümü |
| — | Pil kill + toggle |

---

## F. Risk & açık sorular

### F.1 Riskler

1. Compact GONE — “saat akmıyor” şikâyetinin bir kısmı **layout** olabilir.  
2. stop `apply()` — toggle flaky kökü adayı.  
3. İkinci FGS (`flutter_foreground_task`) — temizlik ayrı WP; şimdi dokunma.  
4. “Panel” = OEM Live → **teslim edilemez garanti**; ürün hayal kırıklığı.  
5. progress “WP-76 tamamlandı” vs saha — iletişim riski.  
6. Presence app-ölü start’ta gecikmeli — sosyal özellik ayrı kabul.

### F.2 Ürün / Claude’a net sorular

1. **Dinamik panel tanımı:** P1 (kontrol bildirimi + Mola), P2 (OEM best-effort), P3 (StandBy) — hangisi MVP?  
2. Compact 1×1’de saat **zorunlu görünür** mü (küçük punto)?  
3. Mola widget’ta da mı, yalnız bildirimde mi?  
4. WP-76 “ürün kabulü” geri alınsın mı yoksa “kabul = native kontrol var, Live Activity yok” mu?  
5. API 36 Live Updates spike bütçesi var mı?  
6. Xiaomi cihaz laboratuvarı var mı (S12–S13)?

### F.3 Varsayımlar (doğrulanmadı)

- Kullanıcı 1×1’i home launcher’da **compact** boyutunda kullanıyor.  
- Şikâyet mevcut `main` + v29 civarı binary üzerinde.  
- `widgetBackgroundCallback` home_widget URI ile bağlı değil (provider native PI kullanıyor).

---

## Claude doğrulama kontrol listesi

Aşağıdakileri **tek tek** onayla / reddet / değiştir; sonra uygulama WP’leri claim edilebilir.

### Mimari

- [ ] **SSOT = native prefs/store; Dart türetici** kabul  
- [ ] **Tüm store yazımları senkron `commit()` (veya eşdeğeri)** kabul  
- [ ] **Chronometer** canlı saniye için doğru mekanizma; `updatePeriodMillis` saniye için kullanılmayacak  
- [ ] **Reconcile:** cold start + resume zorunlu; app-ölü yalnız kuyruk (kayıp yok) kabul  
- [ ] **İkinci FGS (flutter_foreground_task)** bu paket dışı / ayrı temizlik  

### Ürün tanımı (birini seç)

- [ ] **P1** Kontrol bildirimi MVP (Mola+Durdur, expanded flag) — **önerilen**  
- [ ] **P2** Standard OEM best-effort (terfi garanti değil)  
- [ ] **P3** StandBy birleşimi (ayrı program)  
- [ ] P1+P2 A/B flag  

### Faz sırası

- [ ] WP-134 saat görünürlük/Chronometer  
- [ ] WP-135 toggle atomikliği  
- [ ] WP-136 reconcile/pending  
- [ ] WP-137 panel P1 (öncekiler yeşil + ürün onayı)  
- [ ] WP-138/139 opsiyonel  

### Kabul / progress

- [ ] WP-76 “Tamamlanan” notuna “OEM Live garanti edilmedi; kontrol bildirimi MVP ayrı” şerhi  
- [ ] WP-133 sonrası kod WP’leri ancak bu checklist imzası ile  

### Cihaz kapısı

- [ ] API 33 + One UI + process death senaryoları DoD’ye girer  
- [ ] “Now Bar’da görünme” DoD **değil** (P2 bonus)  

---

## Ek: Hızlı dosya:satır dizin (tekrar)

| Konu | Konum |
|---|---|
| TOGGLE mantığı | `StudyTimerService.kt:71-82` |
| START_NOT_STICKY | `StudyTimerService.kt:96` |
| start commit | `StudyTimerService.kt:117-119` |
| stop apply | `StudyTimerService.kt:207-211` |
| FGS tip WP-103 | `StudyTimerService.kt:251-269` |
| Bildirim Chronometer | `StudyTimerService.kt:310-316` |
| Widget Chronometer | `StudyWidgetProviders.kt:77-80` |
| Compact hide | `StudyWidgetProviders.kt:107-110` |
| Widget PI | `StudyWidgetProviders.kt:93-101` |
| Receiver | `TimerActionReceiver.kt:19-22` |
| Reconcile channel | `MainActivity.kt:20-26, 83-97` |
| Dart reconcile | `study_providers.dart:479-610` |
| 30 dk period | `odak_timer_widget_info.xml:8` |
| exported=false | `AndroidManifest.xml:70-71` |

---

*WP-133 sonu. Kod değişikliği yok. Sonraki adım: Claude checklist imzası → WP-134+ worker.*
