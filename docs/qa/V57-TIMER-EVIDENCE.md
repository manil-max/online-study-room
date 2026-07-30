# V57 — Sayaç olay kaydı, otorite haritası ve yeniden üretim kanıtı

> **Ajan A · 2026-07-30.** İki turun ortak kaydı:
> **§1–4 = WP-430** (ölçüm ve kök neden kanıtı, commit `8de8aeb`) ·
> **§5b = WP-431** (uygulanan onarım). Kalanlar WP-432 (bildirim/widget hedefleme
> + sinyal tüketimi) ve WP-433 (çoklu cihaz kod kapısı) işidir.
>
> §1–4 **tarihsel teşhistir**: v56'daki durumu anlatır ve bilerek geçmiş zamanda
> bırakılmıştır. Bugünkü davranış için §5b'ye bakın.
> Buradaki her iddia ya kaynak satırına ya da yeşil bir teste bağlıdır.
>
> Girdi: `docs/V56-SAHIP-GERI-BILDIRIM-RAPORU.md` §3 (V56-S01…S05).
> Tekrar üretim paketi: `app/test/data/global_timer_v57_repro_test.dart`.
> Uçuş kaydı sözleşmesi: `app/test/core/observability/timer_diagnostic_journal_test.dart`.

---

## 1. Sonuç önce

Dört semptomun **tek** bir mimari kökü var:

> Sunucu koşunun otoritesidir, ama **kanonik koşu kimliğini yalnız koşuyu
> BAŞLATAN cihaz öğrenir.** Ayna cihaz koşuyu ekranda gösterir, kimliğini
> öğrenmez. Kimliği olmayan cihazın hiçbir yüzeyi (bildirim, widget, FCM hızlı
> yolu, native durdurma zarfı) o koşuya dokunamaz — ve **hiçbiri hata da
> vermez.** Sessiz düşen komut = ayna durur, kaynak koşar. Sessiz düşen sinyal =
> uzak durdurma öğrenilmez. Öğrenilmeyen durdurma = gece boyu büyüyen, karşılığı
> oturum olmayan hayalet süre.

Yani V56-S01 (ayna durdurma), S03 (aralıklı senkron) ve S04 (sekiz saatlik
hayalet) **aynı kusurun** üç görünümüdür. S02 (kendiliğinden başlama) ayrı ama
komşu bir kusurdur: dış komutların ve aynalanan koşuların **yaşı** hiçbir yerde
ölçülmüyordu.

Bu belgeyle birlikte artık ölçülüyor: `TimerDiagnosticJournal`
(`app/lib/core/observability/timer_diagnostic_journal.dart`).

---

## 2. Otorite haritası — hangi olay otorite, hangi kopya projeksiyon

Tek zaman çizelgesi. **A** koşuyu başlatan cihaz, **B** aynı hesabın ikinci
cihazı.

```mermaid
flowchart TB
  subgraph SERVER["SUNUCU — TEK OTORİTE"]
    RUN["live_study_runs (protocol_version=2)<br/>status · run_revision · lease_expires_at"]
    UTS["user_timer_state.state_version<br/>(monotonik gerçek sayacı)"]
    SESS["study_sessions<br/>KESİNLEŞMİŞ çalışma"]
  end

  subgraph A["CİHAZ A — koşunun SAHİBİ"]
    A_UI["Dart state (isRunning, startedAt)<br/>PROJEKSİYON"]
    A_NATIVE["TimerStateStore prefs<br/>timer_active_started_at* · fg_mode<br/>YEREL SSOT"]
    A_ID["timer_v2_run_id + revision<br/>KANONİK KİMLİK ✅"]
    A_Q["timer_pending_intervals<br/>komut + aralık kuyruğu"]
  end

  subgraph B["CİHAZ B — AYNA"]
    B_UI["Dart state (isGlobalTimerMirror=true)<br/>PROJEKSİYON"]
    B_NATIVE["TimerStateStore prefs<br/>startOrigin=global_timer_mirror"]
    B_ID["timer_v2_run_id<br/>🔴 v56'da HİÇ YAZILMIYORDU<br/>(WP-431: artık yazılır)"]
    B_MIRROR["timer_global_mirror_run_id<br/>yalnız Dart okur, native görmez"]
  end

  A_UI -->|"start() → native yaz → zarf"| A_Q
  A_Q -->|"apply_global_timer_command"| RUN
  RUN --> UTS
  RUN -->|"applyCommand yanıtı"| A_ID
  UTS -->|"fetchSnapshot (poll · yaşam döngüsüne bağlı)"| B_UI
  B_UI --> B_MIRROR
  UTS -.->|"FCM timer_sync (yalnız tetikleyici)"| B_UI
  A_UI -->|"stop() → _recordSession"| SESS
  B_UI -->|"ayna kapanışı oturum YAZMAZ (tasarım)"| SESS
```

**Kural (bu turda değişmedi, yalnız yazıya geçti):**

| Katman | Rol | Otorite mi? |
|---|---|---|
| `live_study_runs` + `user_timer_state.state_version` | koşunun varlığı, revizyonu, kirası | ✅ **tek otorite** |
| `study_sessions` | kesinleşmiş çalışma | ✅ **tek otorite** |
| `timer_v2_run_id` / `timer_v2_run_revision` (prefs) | sunucunun bu cihaza verdiği **kimlik bileti** | ⚠️ otorite değil ama **komut yazma yetkisi** |
| `TimerStateStore` prefs (`timer_active_*`, `fg_mode`) | cihaz-içi SSOT (native ↔ Dart) | ❌ projeksiyon |
| Dart `StudyTimerState` | ekranda görünen | ❌ projeksiyon |
| Bildirim paneli · widget · Chronometer | görünüm | ❌ projeksiyon |
| FCM `timer_sync` | **yalnız tetikleyici**, durum taşımaz | ❌ projeksiyon |

**Kabul kriteri 1 — "hiçbir local görünüm server kabulü olmadan yeni aktif run
yaratamıyor":** doğrulandı ve korunuyor. Yerel `start()` bir *niyet* üretir;
koşuyu `apply_global_timer_command` açar. Eşzamanlı ikinci start çift koşu
doğurmaz, sunucu `adopt_existing` döner
(`supabase/migrations/0082_global_timer_v2.sql`). Ayna benimseme yolu (`mirrorStart`)
bilerek native V2 zarfı **üretmez** — yani projeksiyon yeni koşu doğurmaz
(`StudyTimerService.handleStart`, `startOrigin != "global_timer_mirror"` koşulu).

**Kabul kriteri 2 — "görünür ghost ile kaydedilmiş session ayrımı":** artık
makine-okunur. `run_terminal` satırının `outcome` alanı üç değerden birini alır:

| `outcome` | Anlamı |
|---|---|
| `applied` | görünen süreye karşılık bir oturum yazılıyor |
| `ghost_no_session` | 🔴 süre görünüyordu, karşılığında oturum **yok** |
| `local_only` | yalnız yerel projeksiyon kapandı (ayna) |

`elapsed_seconds` (görünen) ile `session_recorded.elapsed_seconds` (yazılan)
farkı hayalet sürenin **büyüklüğüdür**.

---

## 3. Uçuş kaydı (flight recorder) sözleşmesi

`TimerDiagnosticJournal` — cihazda kalan, dönen, TTL'li, PII'siz olay kaydı.

| Özellik | Değer | Neden |
|---|---|---|
| Depolama | `SharedPreferences` · `timer_diagnostic_journal_v1` | ek bağımlılık yok, native tarafla aynı disk |
| Kapasite | 240 kayıt (halka tampon) | yoğun bir gün + prefs'i şişirmeme |
| TTL | 72 saat | "sabah kalktım" vakası + sahibin bildirme süresi |
| Ağ | **yok** | telemetri açıkken bile transport görmez |
| Kimlik | `sha256(kurulum_tuzu + kimlik)` ilk 12 hex | aynı koşu izlenebilir, kimlik geri üretilemez |
| Metin | kapalı slug sözlüğü (`^[a-z0-9_]{1,48}$`) | serbest metin/mesaj içeriği **yapısal olarak** giremez |
| Sayısal özet | `ObservabilityService.timerTransition` | telemetri açıksa yalnız slug + tamsayı çıkar |

Her satır zorunlu olarak `event + reason + outcome` taşır; olay tipine göre
`state_version`, `queue_age_ms`, `elapsed_seconds`, `run_revision` eklenir.
Nedeni veya sonucu olmayan satır kabul edilmez — "log ekledim" ile "kanıt
ürettim" arasındaki fark budur.

### Kaydedilen geçişler

| `event` | Nerede | Ne kanıtlar |
|---|---|---|
| `cold_start_restore` | `StudyTimerNotifier.build` | açılışta ayna mı kendi koşusu mu geri geldi |
| `start_requested` | `start()` · flush (bayat) | her başlatmanın **görülebilir kaynağı** |
| `external_command` | `_processPendingExternalCommand` | bildirim/widget komutunun yaşı ve sonucu |
| `native_reconciled` | `_reconcileBackgroundTimerImpl` | Dart'ın native'den benimsediği koşunun yaşı |
| `mirror_adopted` | `_applyGlobalTimerForegroundDirective` | uzak koşu kaç ms geçmişten aynalandı |
| `snapshot_reconciled` | `GlobalTimerCoordinator.reconcileForeground` | senkron turunun gecikmesi / `duplicate` / `failed` |
| `sync_signal` | `_applyRemoteMirrorStop` | FCM hızlı yolunun neden uygulanmadığı |
| `command_flushed` | `_flush` | zarfın kuyrukta bekleme süresi + sunucu sonucu |
| `lease_heartbeat` | `heartbeat` | kira tazelemenin gerçekten yürüdüğü |
| `stop_requested` / `mirror_stop_requested` | `stop()` · `stopMirroredRun` | durdurma niyetinin kaynağı |
| `run_terminal` | `_finish` | hayalet mi, oturum mu, yalnız yerel mi |
| `session_recorded` | `_recordSession` | gerçekten yazılan saniye |

---

## 4. Dört bulgunun kök neden zinciri (kanıtlı)

### V56-S01 · Ayna cihazdaki bildirim Durdur'u kaynak cihazı durdurmuyor

**Zincir:**

1. `mirrorStart` uygulanırken Dart koşu kimliğini yalnız `timer_global_mirror_run_id`
   anahtarına yazar (`study_providers.dart`, `_persistActiveTimer`). Kanonik
   `timer_v2_run_id`'yi **yazmaz** — o anahtarı yalnız `_persistRunIdentity`
   (yani sunucuya komut göndermiş sahip cihaz) yazar
   (`global_timer_providers.dart:292`).
2. Native taraf `timer_global_mirror_run_id`'yi hiç okumaz. `handleStop` durdurma
   zarfını `KEY_V2_RUN_ID` + `KEY_V2_RUN_REVISION` ile kurar
   (`StudyTimerService.kt:286-295`). Ayna cihazda ikisi de boş.
3. Kimliksiz stop, `appendDeferredV2Stop`'a düşer; o da `KEY_V2_RUN_INTENT_ID`
   ister. Ayna başlatması V2 zarfı üretmediği için (`handleStart`,
   `startOrigin != "global_timer_mirror"`) intent kimliği de yoktur →
   **`return false`. Komut hiç doğmaz.**
4. Dart'ın FCM hızlı yolu da kapalıdır: `_applyRemoteMirrorStop`
   `state.isGlobalTimerMirror` olduğunda erken döner ve ayrıca
   `timer_v2_run_id == signal.runId` eşleşmesi arar — ayna cihazda o anahtar yok.
5. Sonuç: `writeIdle` yerel yüzeyi kapatır, sunucudaki koşu `running` kalır,
   kaynak cihaz çalışmaya devam eder. **Hata mesajı yoktur.**

**Yalnız uygulama içi buton çalışır:** `stop()` → `state.isGlobalTimerMirror` →
`stopMirroredRun()` → gerçek CAS-stop. Bildirim ve widget bu dala hiç uğramaz.
Sahibin "üç yüzeyi ayrı ayrı doğrula" notu tam olarak bu yüzden haklı.

**Kanıt:** `global_timer_v57_repro_test.dart` → grup *V56-S01*, üç test.

### V56-S02 · Sayaç bazen kendiliğinden çalışıyor olabilir

Bugün "doğrulanamıyor" demek zorunda kalmamızın nedeni olay kaydının olmamasıydı.
Ölçüm eklendi; ayrıca iki somut, kaynak-düzeyinde kusur bulundu:

1. **Dış komutun yaşı bilinmiyor.** `TimerExternalCommand.at` alanı var ama
   **hiçbir üretici onu yazmıyor**: `timerNotificationBackgroundHandler`
   (`timer_notification_service.dart:104`) ve
   `TimerExternalCommandStore.setCommand` yalnız `command` + `sequence` yazar.
   Yani kuyrukta kalmış bir `start`, ne kadar eski olduğu bilinmeden soğuk
   açılışta `start()`'ı çağırır → **kullanıcının hatırlamadığı yeni koşu.**
2. **Aynı kusur durdurmayı da bozuyor.** `stop(at: pending.at)` her zaman `null`
   alır, `end` `DateTime.now()`a düşer: app-kapalı basılan Durdur'da,
   uygulamanın **açıldığı ana** kadar geçen ölü zaman oturuma yazılır. WP-233'te
   yazılan koruma fiilen ölüdür.
3. Üçüncü aday: `mirror_adopted`. Kullanıcı açısından "başlatmadım ama çalışıyor"
   görüntüsünün en olası kaynağı budur (bkz. S04).

Artık `start_requested` / `external_command` / `native_reconciled` /
`mirror_adopted` satırları `queue_age_ms` ile birlikte hangisinin gerçekleştiğini
gösterir. `queue_age_ms` yokluğu (`unknown`) da kusurun kanıtıdır.

**Kanıt:** grup *V56-S02*, iki test.

### V56-S03 · Eşitleme aralıklı olarak kararsız

**Zincir:**

1. `TimerSyncSignal.record` FCM **arka plan isolate'inde** çalışır
   (`firebasePushBackgroundHandler`). `_stream` statik bir broadcast
   controller'dır ve **isolate'e özeldir** → ana isolate'teki dinleyici
   (`study_providers.dart:634`) bu olayı asla görmez.
2. Aynı fonksiyon sinyali `timer_sync_pending_v1` anahtarına kalıcı yazar. Ama
   **hiçbir kod o anahtarı geri okumaz.** Üretimde yalnız `setString`,
   `getString` (tekrar-bastırma karşılaştırması) ve `remove` var; diskteki
   değeri `TimerSyncSignal`'a çeviren bir API yok. Anahtar **yaz-ve-unut**.
3. Kalan tek senkron yolu, yaşam döngüsüne bağlı snapshot turudur:
   `_startGlobalTimerForegroundRefresh` `onResume`'da başlar, `onHide`/`onPause`
   ile **durur**. Yani uygulama arka plandayken ya da kapalıyken senkron yoktur.
4. Sonuç tam olarak sahibin tarifi: "bazen çalışıyor" = uygulama önplanda olduğu
   anlar; "bazen çalışmıyor" = geri kalan her an.

**Kanıt:** grup *V56-S03*, iki test. Ayrıca `snapshot_reconciled.queue_age_ms`
artık senkron gecikmesinin dağılımını verir — "bir kez çalıştı" yerine ölçüm.

### V56-S04 · Sekiz saatlik hayalet çalışma, oturum kaydı yok

**Zincir (tablet = A, telefon = B):**

1. A başlatır → sunucuda koşu `running`. B, snapshot turunda `mirrorStart`
   uygular. `planGlobalTimerForegroundApply` koşunun **yaşını sorgulamaz**:
   `status == 'running'` ve `effective_started_at != null` yeter. Sekiz saatlik
   bir koşu da sorgusuz aynalanır.
2. İstemci modeli kirayı görmez: `GlobalTimerRun` sınıfında `lease_expires_at`
   alanı **yok** — sunucu snapshot'ta gönderse bile `fromMap` onu düşürür.
3. Sunucu okuma yolu da süzmez: `_global_timer_v2_snapshot` kirayı yalnız
   *raporlar*, filtre uygulamaz. Süpürücü (`0089`, dakikalık, 200 satır/tur)
   gecikirse ölü koşu canlı görünür.
4. A durdurur. B'nin bunu öğrenmesi gereken iki yol da kapalıdır (bkz. S03):
   FCM ana isolate'e ulaşmaz, poll telefon uyurken ölüdür.
5. B sabaha kadar aynayı sayar. Kullanıcı açar; poll canlanır, `run == null`
   görülür, `mirrorStop` → `_finish()`. **`_finish()` oturum yazmaz** ve ayna
   koşusu için oturum yazan başka bir yol da yoktur.
6. Sonuç: sekiz saat göründü, `study_sessions`'a hiçbir satır girmedi, kullanıcıya
   hiçbir açıklama yapılmadı.

**Kanıt:** grup *V56-S04*, beş test. Artık bu kapanış `run_terminal` satırında
`outcome=ghost_no_session` (kendi koşusu) ya da `local_only` (ayna) olarak
işaretlenir ve `elapsed_seconds` görünen süreyi taşır.

---

## 5. WP-431…433'e devredilen kararlar

Bunlar WP-430'un kapsamı DIŞINDADIR; burada yalnız kayda geçiyor.

| # | Karar | Sahip WP | Durum |
|---|---|---|---|
| K1 | Ayna cihaz da kanonik koşu kimliği (`run_id` + `revision`) edinmeli; native durdurma zarfı kurulabilmeli | WP-431 | ✅ uygulandı |
| K2 | Ayna benimseme yaş/kira sınırına bağlanmalı; sınır aşımı `needs_reconcile` yüzeyi üretmeli | WP-431 | ✅ uygulandı |
| K3 | `GlobalTimerRun` kirayı taşımalı; okuma yolu kirası dolmuş koşuyu `running` diye vermemeli | WP-431 (+ WP-464 retention) | ✅ uygulandı |
| K4 | Bildirim ve widget Durdur'u ayna cihazda onaylı global stop üretmeli | WP-431 | ✅ uygulandı (rol tabanlı; `stopMirroredRun`'a değil, aynı CAS sözleşmesine yönlendi) |
| K5 | `timer_sync_pending_v1` tüketilebilir olmalı: soğuk açılış/isolate geçişinde okunup uzlaştırılmalı | WP-432 | ⏳ açık |
| K6 | Dış komut `at` (üretim anı) taşımalı; yaşı eşiği geçen komut yeni koşu doğurmamalı | WP-432 | ⏳ açık |
| K7 | Ayna kapanışı ya sunucuda kesinleşmiş oturumu göstermeli ya da kullanıcıya "kayıt oluşmadı" demeli | WP-433 | ⏳ açık (WP-431 hayaleti **önlüyor**; kullanıcıya açıklama yüzeyi WP-433) |
| K8 | Üç yüzey (uygulama içi · bildirim · widget) ayrı ayrı kabul edilmeli; biri diğerinin kanıtı değildir | WP-433 · Ajan H WP-466 | ⏳ açık |

---

## 5b. WP-431 — uygulanan onarım (2026-07-30)

Kök neden tek cümleydi: *kimliği olmayan cihazın hiçbir yüzeyi koşuya
dokunamıyor ve hata da vermiyordu.* Onarım üç ayak üzerine kuruldu.

### Ayak 1 — Rol, artık native tarafın GÖREBİLECEĞİ bir gerçek

`TimerStateStore.KEY_CONTROLLER_ROLE` (`source` | `mirror`). Rol eskiden yalnız
Dart `state.isGlobalTimerMirror` alanında yaşıyordu; bildirim/widget Durdur'u
native'de çalıştığı için onu göremiyordu. Bunun **iki** sonucu vardı ve ikisi de
kapandı:

| Eski davranış | Yeni davranış |
|---|---|
| Ayna cihazda `appendPendingInterval` çağrılıyor, Dart açılışta bunu **uydurma bir oturum** olarak yazıyordu | `if (recordInterval && !isMirror)` — projeksiyon oturum üretmez |
| Kimlik olmadığı için stop zarfı doğmuyordu | Ayna kimlik biletini edinir (Ayak 2), zarf kurulur |
| Yerel modu `countdown` olan ayna cihazda `mode == "stopwatch"` kapısı stop'u sessizce düşürüyordu | `if (isMirror \|\| (mode == "stopwatch" && phase == "work"))` + ayna her zaman stopwatch olarak açılır |

Karar artık **girişten değil rolden** türer: `planTimerStop()`
(`app/lib/data/models/global_timer.dart`) uygulama içi, bildirim ve widget için
tek karar noktasıdır.

### Ayak 2 — Kimlik bileti aynaya da verilir

`mirrorStart` uygulanırken `timer_v2_run_id` + `timer_v2_run_revision` +
`timer_v2_controller_role` yazılır. Başarılı ayna Durdur'unda bilet **tüketilir**
(aksi halde `_finish()` yolundaki native `STOP_SILENT` ölü koşuya ikinci, zehirli
bir stop zarfı üretirdi).

### Ayak 3 — Hayalet koşu doğmadan kesilir

| Kapı | Nerede |
|---|---|
| Kirası dolmuş koşu aynalanmaz | `GlobalTimerRun.leaseExpired` + `isDisplayableAt` |
| Sunucu kirayı **hesaplar**, yalnız raporlamaz | `0101` → `_global_timer_v2_snapshot.lease_expired` |
| Yaş sınırı (12 sa) — kira alanı taşımayan eski sunucuya karşı ikinci set | `kGlobalTimerMaxMirrorRunAge` |
| Ekranda duran ölü ayna kapatılır | `planGlobalTimerForegroundApply` → `mirrorStop` |
| Gösterilemeyen koşu `needs_reconcile` işaretlenir, **canlı sayaç açmaz** | yeni direktif türü |
| Soğuk açılışta ayna **diriltilmez** | `build()` + native `ACTION_DISCARD_PROJECTION` (sunucuya komut GİTMEZ — koşunun sahibi başka cihaz olabilir) |
| Hesap-geneli tek aktif koşu | `0101` kısmi unique index |
| Çevrimdışı başlangıç korunur ama sınırlı (≤24 sa geçmiş, gelecek yok) | `0101` clamp + `client_clock_skew_rejected` |

### Ayak 4 — Sessiz yutma bitti

`classifyGlobalTimerFailure` hatayı üçe ayırır: `retry` (kuyrukta kalır),
`quarantine` (hesap bağı yok), `terminal` (sunucu asla kabul etmeyecek → kuyruktan
düşer). Eskiden `catch (_)` üçünü de aynı torbaya atıyordu; bozuk kayıt kuyruğu
sonsuza kadar tıkıyordu.

### Yaşam döngüsü

Logout/hesap değişiminde kimlik bileti, rol ve ayna durumu silinir; kuyruk
kayıtları **karantinada kalır** (silinmez — sahibi geri dönebilir).

---

## 6. Kanıt durumu

| Doğrulama | Sonuç |
|---|---|
| `flutter analyze` | 0 uyarı |
| `test/core/observability/timer_diagnostic_journal_test.dart` | 11/11 yeşil |
| `test/data/global_timer_v57_repro_test.dart` | 14/14 yeşil |
| `test/data/global_timer_controller_contract_test.dart` | 14/14 yeşil |
| Tam `flutter test` | 1212 testten 1211 yeşil · tek kırmızı **başka lane'e ait**: `auth_faq_link_wp422_test.dart` DE/AR yerelini istiyor, Ajan G WP-457 runtime dillerini TR/EN ile sınırladı |
| Yerel Supabase replay + pgTAP | ⏳ **ÇALIŞTIRILAMADI** — bu hostta Docker motoru ayağa kalkmıyor (`docker info` yanıt vermiyor). `0101` ve `019_*.test.sql` replay ile **doğrulanmadı** |
| Cihaz kanıtı | ❌ **yok** — Ajan H WP-466 matrisi |

**Kanıt etiketi:** `Kodda doğrulandı` (Dart/Kotlin sözleşmeleri) ·
`Replay bekliyor` (SQL) · `Cihazda doğrulanmalı` (saha).

> 🔴 **Açık risk:** `0101` gerçek bir PostgreSQL'de hiç çalıştırılmadı. Staging'e
> gitmeden önce `tooling/supabase/local.ps1 baseline` yeşil olmalıdır. Bu, WP-431
> kapanış kanıtının eksik ayağıdır ve Ajan H WP-466'ya devredilmiştir.

## 7. WP-433 — iki-cihaz otomatik matris ve cihaz teslimi

Bu tablo gerçek iki cihazın yerine geçmez; her satırın otomatik sözleşmesini ve
WP-466'da fiziksel olarak yeniden denenmesi gereken yüzeyi ayırır. "A" koşuyu
başlatan cihazı, "B" aynı hesaptaki ikinci cihazı ifade eder.

| Otomatik senaryo | Kod kapısı | Beklenen değişmez | Fiziksel kabul |
|---|---|---|---|
| A başlatır → B uygulama içinden Durdur | `global_timer_mirror_stop_test.dart` | B, `run_id` + revizyonlu tek CAS-stop gönderir; stale ret yerelde başarı sayılmaz | A ve B en geç 10 sn içinde terminal; ek session/XP 0 |
| Bildirim/widget kaynaklı terminal niyeti | `global_timer_v57_repro_test.dart`, `timer_v2_stop_entry_contract_test.dart` | Kaynak ile ayna rolü tek karar noktasında ayrılır; ayna yerel interval/session yazmaz | Her iki cihazda bildirim ve widget Durdur ayrı denenir |
| Çevrimdışı start → terminal niyeti | `global_timer_deferred_stop_test.dart` | Start kabul edilirse bağlı stop aynı kimlik/revizyonla gider; 24 saati aşan niyet oynatılmaz | Ağ kes/aç, uygulama arka planda ve kapalıyken denenir |
| FCM kayıp/gecikmeli → foreground reconcile | `global_timer_command_publish_test.dart`, `timer_sync_signal_test.dart` | Sinyal yalnız tetikleyicidir; açık uygulama auth snapshot ile uzlaşır, arka planda poll dönmez | A/B farklı yaşam döngülerinde start/stop sonrası görünüm ölçülür |
| Eski/ölü koşu ve cold-start | `global_timer_v57_repro_test.dart` | Kira/yaş sınırını aşan run aynalanmaz; ayna server doğrulaması olmadan dirilmez | Force-stop, reboot ve 23:59–00:01 sınırında tekrar denenir |

Çalıştırılacak otomatik paket:

```text
flutter test test/data/global_timer_v57_repro_test.dart test/data/global_timer_mirror_stop_test.dart test/data/global_timer_deferred_stop_test.dart test/data/global_timer_command_publish_test.dart test/core/timer_sync_signal_test.dart test/core/timer_v2_stop_entry_contract_test.dart --dart-define-from-file=env.json
```

SQL replay bu paketten bağımsızdır: `0102` için local deploy contract head'i
güncellenmeden wrapper güvenli olarak replay başlatmaz. Bu sözleşme sorunu çözülse
bile fiziksel A/B kabulü WP-466'da kalır.
