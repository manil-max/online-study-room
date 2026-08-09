# DENETİM — Bildirimler · Arka Plan · Cihaz Entegrasyonları

Tarih: 2026-08-09 · Yöntem: **salt okunur kod denetimi**. `progress.md`, `docs/**` ve
kod yorumları kanıt sayılmadı; her bulgunun altında `dosya:satır` var. Bugün (2026-08-09)
atılan commit'lerle düzeltilmiş konular raporlanmadı; WP-592'nin **eksik kalan yarısı**
bilerek raporlandı (madde R1).

Özet: **2 KANAMA · 4 RİSK · 5 TEMİZLİK**

---

## KANAMA

### K1 — Windows'ta alarm kaydetmek/silmek istisna atıyor; alarm hiç kurulmuyor, liste tazelenmiyor

**Belirti.** Windows sürümünde Saat sekmesi ve alarm ekranı görünüyor. Kullanıcı alarm
ekleyip kaydediyor: alarm diske yazılıyor ama **listede belirmiyor**, ve hiçbir zaman
çalmıyor. Sildiğinde de satır ekranda kalmaya devam ediyor. Ekranda tek kelime hata yok.

**Kanıt.**
- `app/lib/core/notifications/alarm_notification_service.dart:57-63` — Windows/Linux/macOS'ta
  `_plugin.initialize(...)` **atlanıyor** ama `_initialized = true` yazılıyor.
- Aynı dosya `:122-130` — `_useNative` (`= Platform.isAndroid`) false olduğu için Windows
  `_plugin.zonedSchedule(...)` dalına düşüyor; `:161-167` `cancelAlarm` her koşulda
  `_plugin.cancel(...)` çağırıyor.
- `flutter_local_notifications_windows-3.1.1/lib/src/plugin/ffi.dart:310-322` ve `:136-142`
  — kurulmamış eklentide `zonedSchedule` ve `cancel` **`StateError` fırlatıyor**
  ("must be initialized before use").
- `app/.dart_tool/flutter_build/dart_plugin_registrant.dart:339` — Windows implementasyonu
  kayıtlı, yani `resolvePlatformSpecificImplementation<...>()` `null` dönmüyor; `?.` bir
  kurtarma sağlamıyor.
- `app/lib/data/providers/alarm_providers.dart:63-72` — `saveAlarm` içinde `_syncNative()`
  try/catch'siz; istisna `ref.invalidateSelf()`'ten **önce** atılıyor. `:75-80` `deleteAlarm`
  aynı desende.
- `app/lib/core/navigation/home_shell.dart:35-42` — `ClockScreen` sekmesinde platform kapısı yok.
- `app/lib/data/providers/alarm_providers.dart:231-243` — `_syncTimerNative` de aynı yoldan
  `scheduleTimer`/`cancelTimer` çağırıyor (`:224, :290, :320, :471, :493`).

**Etki.** Windows yayınında alarm/zamanlayıcı ekranı **vaat edilen ama çalışmayan** bir yüzey;
üstelik liste tazelenmediği için kullanıcı kendi işleminin kaydedildiğinden de emin olamıyor.

**Not.** Aynı dosyanın `:55-63` yorumu bu tuzağı biliyor ve `initialize`'ı kapatıyor — ama
kapatma yalnızca `initialize`'a uygulanmış, çağrı yüzeyinin geri kalanına uygulanmamış.

**Öncelik: KANAMA**

---

### K2 — Windows'ta "Seri koruma" / "Haftalık özet" anahtarı kaydedilmiyor, izin düğmesi sessiz

**Belirti.** Bildirim Merkezi'nde "Seri koruma" veya "Haftalık özet" anahtarını açıyorsun;
anahtar geri kapanıyor (tercih hiç yazılmıyor). "Bildirim iznini kontrol et" düğmesine
basınca da hiçbir şey olmuyor — ne SnackBar, ne hata.

**Kanıt.**
- `app/lib/core/notifications/reminder_notification_service.dart:31-38` — `initialize()`
  koşulsuz olarak `InitializationSettings(android: ...)` ile `_plugin.initialize` çağırıyor.
- `flutter_local_notifications-22.0.1/lib/src/flutter_local_notifications_plugin.dart:186-190`
  — Windows'ta `settings.windows == null` ise **`ArgumentError` fırlatılıyor**.
- `app/lib/core/notifications/reminder_notification_service.dart:40-47` —
  `requestPermissionIfNeeded()` ilk satırda `await initialize()`; istisnayı yutmuyor.
- `app/lib/features/notifications/notification_center_screen.dart:413-420` (seri) ve
  `:428-435` (haftalık) — `await ...requestPermissionIfNeeded()` **başarılı olmadan**
  `notifier.setSmart...Enabled(value)` satırına gelinmiyor.
- Aynı dosya `:350-366` — `_PermissionCard` düğmesi de try/catch'siz; `granted` hiç
  hesaplanmadığı için `ScaffoldMessenger` satırı çalışmıyor.
- Karşılaştırma: `alarm_notification_service.dart:57-63` **aynı** tuzağı bilerek kapatmış.
  Yani doğru desen repoda var, hatırlatıcı servisine uygulanmamış.

**Etki.** Masaüstü kullanıcısı için iki bildirim tercihi tamamen erişilemez; izin düğmesi
"bozuk düğme" olarak görünüyor. Bu, `nudgeNotificationsEnabled` anahtarını etkilemiyor
(`nudge_notification_service.dart:22-25` yolundaki iki çağrı da Android dışında sessizce
`false` dönüyor, atmıyor) — yalnız iki akıllı hatırlatıcı anahtarı ve izin düğmesi.

**Öncelik: KANAMA** (Windows yayın hedefiyse; yalnız Android yayınlanacaksa RİSK)

---

## RİSK

### R1 — WP-592 uyarı şeridi bir kez hesaplanıyor: izin açılınca gitmiyor, kapatılınca gelmiyor

**Belirti.** Sayaç kartındaki "bildirim izni kapalı" şeridinde "Eksik izinleri aç"a basıp
sistem ayarlarında izni açıyorsun, uygulamaya dönüyorsun — **şerit hâlâ orada**. Uygulamayı
kapatıp açana kadar gitmiyor. Tersi de doğru: oturum içinde izni kapatırsan şerit hiç çıkmıyor.

**Kanıt.**
- `app/lib/core/notifications/timer_notification_service.dart:62-64` —
  `timerNotificationPermissionStatusProvider` düz bir `FutureProvider` (autoDispose değil);
  değeri `ProviderScope` ömrü boyunca bir kez hesaplanıyor.
- `app/lib/features/classroom/widgets/study_timer_card.dart:292` — tek tüketici, yalnız `watch`.
- Repo genelinde bu provider'a `invalidate` / `refresh` / `ref.invalidate` çağrısı **yok**
  (grep: yalnız yukarıdaki iki referans).
- `app/lib/features/classroom/widgets/study_timer_card.dart:305-309` — düğme
  `openSystemNotificationSettings()` çağırıyor ama dönüşte durumu tazeleyen bir
  lifecycle/`AppLifecycleListener` kancası yok.
- Ölçmeyen kapı: `app/test/core/timer_notification_denied_wp592_test.dart:38-49` —
  `_FakePermissionGateway` **sabit** bir bool döndürüyor; test iki yönlü ama "izin değişince
  şerit güncellenir mi" iddiasını hiç kurmuyor, dolayısıyla bu yolu göremiyor.

**Etki.** Bugün eklenen doğru fikrin ikinci yarısı eksik: kullanıcı sorunu çözüyor, uygulama
"hâlâ sorun var" demeye devam ediyor. Uyarının güvenilirliği bir kez yalan söylediğinde biter.

**Öncelik: RİSK**

---

### R2 — Arka plan isolate'inde işlenen push, ana isolate'in prefs önbelleğine yansımıyor

**Belirti.** Uygulama arka plandayken gelen bildirimden sonra Bildirim Merkezi'ndeki
"Son teslim" satırı eski değeri gösteriyor; uzak test bazı turlarda "ulaşmadı" diyor.
Dürtme için (nadiren) tepside iki satır belirebilir.

**Kanıt.**
- `app/lib/core/notifications/app_push_notification_service.dart:521-528` — FCM arka plan
  handler'ı **ayrı bir isolate**te `showRemote` çağırıyor; `:238` ve `:273` orada
  `SharedPreferences.getInstance()` ile `push_seen_event_ids_v1`, `push_last_event_id`,
  `push_last_received_at` yazıyor (`:543-561`).
- Aynı dosya `:451, :475, :490-494` — `snapshot()` **ana isolate**teki `_prefs` alanından
  okuyor ve hiçbir yerde `reload()` çağrılmıyor (repo genelinde `prefs.reload()` kullanan
  yerler: `global_timer_providers.dart:189,249`, `study_providers.dart:1286,1538,1691,1845`,
  `timer_external_command_store.dart:21-23` — push tarafında yok).
- Repo bu tuzağı zaten biliyor: `app/lib/data/providers/global_timer_providers.dart:245-249`
  yorumu tam bu mekanizmayı anlatıyor.
- İkinci kat: dürtme iki yoldan gösterilebiliyor ve **bildirim id'leri farklı** —
  `app_push_notification_service.dart:251` (`eventId.hashCode`, eventId = `nudge:<id>`) ve
  `:288` (`nudge.id.hashCode`). Prefs dedupe kaçarsa aynı dürtme tek satırı ezmez, tepside
  **iki ayrı satır** olur.

**Etki.** Sağlık paneli yanlış rapor veriyor (denetlenemez bir teşhis yüzeyi), ve dürtme
idempotanlığı tek bir kırılgan katmana (isolate'ler arası paylaşılmayan bir önbellek) bağlı.

**Öncelik: RİSK**

---

### R3 — `timer_sync` push'u arka planda düşerse tamamen kayboluyor (`timer_sync_pending_v1` okunmuyor)

**Belirti.** Diğer cihazda sayaç durdurulduğunda gelen sessiz `timer_sync` mesajı, uygulama
ön planda **değilse** hiçbir şey tetiklemiyor. Cihaz senkronu yalnız periyodik yoklamayla
yakalanıyor.

**Kanıt.**
- `app/lib/core/notifications/timer_sync_signal.dart:22` — `static final _stream =
  StreamController...`. Dart'ta `static` alanlar **isolate başına**dır.
- Aynı dosya `:54-67` — `record()` yalnız kendi isolate'inin `_stream`'ine `add` ediyor.
- `app/lib/core/notifications/app_push_notification_service.dart:527` — arka plan handler'ı
  `showRemote` → `:232-236` `TimerSyncSignal.record(...)`. Yani arka planda kaydedilen sinyal,
  **dinleyicisi olmayan** bir stream'e gidiyor.
- Tek dinleyici ana isolate'te: `app/lib/data/providers/study_providers.dart:929`.
- `timer_sync_signal.dart:21` — `pendingKey` (`timer_sync_pending_v1`) `lib/` içinde
  **hiçbir yerde okunmuyor**; yalnız `record()` içindeki dedupe karşılaştırması ve
  `clear()` (`study_providers.dart:915, :1226`) dokunuyor. Yani "bekleyen sinyal" diye
  yazılan anahtarın tüketicisi yok.

**Etki sınırı (dürüst olmak gerekirse).** Etkiyi sınırlayan bir emniyet var: ön plana
dönünce periyodik uzlaşma koşuyor (`study_providers.dart:1072-1082`) ve
`MainActivity.onResume` `reconcile` yolluyor (`MainActivity.kt:118-122`). Yani veri
bozulmuyor; **kaybolan şey push'un vaat ettiği anında tepki**. Kalıcı bir bayat prefs
anahtarı da geride kalıyor.

**Öncelik: RİSK**

---

### R4 — Play sürümü "çalar saat değiliz" diyerek `USE_EXACT_ALARM`'ı düşürdü ama tam ekran + pil izinleri duruyor

**Belirti.** İki Play beyan formu aynı ürün tanımına **zıt** cevap verecek: exact alarm
formunda "alarm uygulaması değiliz" denip izin kaldırıldı, ama tam ekran amaç izni alarm
gerekçesiyle isteniyor.

**Kanıt.**
- `app/android/app/src/main/AndroidManifest.xml:20` — `USE_FULL_SCREEN_INTENT`;
  `:22` — `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- `app/android/app/src/play/AndroidManifest.xml` — play flavor'ında `tools:node="remove"`
  yalnız `USE_EXACT_ALARM`, dört medya izni ve üç passkey izni için var; yukarıdaki ikisi yok.
- `scripts/test_all.py:481-484` — beyaz listede ikisi de "Play beyanı ister / hassas kullanım
  gerekçesi ister" notuyla duruyor; yani kapı bunu **bilerek** geçiriyor, kaza değil.
- Kodda karşılıkları gerçek: `AlarmNotificationFallback.kt:76` (`setFullScreenIntent`),
  `ExactAlarmHelper.kt:151-155, :172-184`.

**Etki.** İlk Play gönderiminde en olası ikinci blokaj burası. Ürün kararı gerektiriyor:
ya alarm "temel işlev" olarak savunulur (o zaman `USE_EXACT_ALARM` kararı yeniden düşünülür),
ya tam ekran alarm Play kanalından düşürülür.

**Öncelik: RİSK** (kod hatası değil, gönderim riski)

---

## TEMİZLİK

### T1 — `widgetBackgroundCallback` ölü kod: kayıtlı ama üreteni yok

- `app/lib/features/android_widgets/android_widget_service.dart:11-19` — `home_widget://timer/toggle`
  URI'sini bekleyen bir arka plan callback'i.
- `app/lib/main.dart:100` — her Android soğuk açılışında `registerInteractivityCallback` ile kayıt.
- Üreten yok: widget düğmesi `StudyWidgetProviders.kt:199-212`'de `TimerActionReceiver`
  broadcast'i kullanıyor. `app/android/app/src/main` içinde tek bir `home_widget` background
  intent kaydı yok (yalnız `StudyWidgetProviders.kt:13` import'u ve plugin registrant).
- Ayrıca içindeki `prefs.containsKey('timer_active_started_at')` kontrolü, native yolun
  kullandığı `TimerStateStore.isRunning` (`TimerStateStore.kt:99-100`, `_MS` anahtarını da
  okur) ile aynı şey değil — yani canlansa bile ikinci bir gerçek üretirdi.

### T2 — `timerNotificationBackgroundHandler` ölü (WP-563 sonrası)

- `app/lib/core/notifications/timer_notification_service.dart:66-89` ve `:131-132` — hâlâ
  kayıtlı; `stop_timer` / `start_timer` actionId'li bir **flutter_local_notifications**
  bildirimine bağlı.
- WP-563'ten beri Dart bildirim göstermiyor (`:19-29` sözleşmesi); FGS bildiriminin
  aksiyonları native PendingIntent (`StudyTimerService.kt:466-486`). Dolayısıyla ne bu
  handler ne de `commands` stream'i (`:110-121`, tüketicisi `study_providers.dart:837-840`)
  bir daha veri görür — `getNotificationAppLaunchDetails` üzerinden eski bir bildirime
  dokunmak dışında.

### T3 — Alarm yedek bildiriminin kanal sesi susturulmamış

- `app/android/app/src/main/kotlin/com/manilmax/online_study_room/alarm/AlarmNotificationFallback.kt:105-117`
  — kanal `IMPORTANCE_HIGH` ile kuruluyor, `setSound(null, null)` yok; `Notification.Builder`
  tarafında da ses kapatılmıyor.
- Aynı anda `AlarmRingActivity.kt:230` kendi `USAGE_ALARM` `MediaPlayer`'ını çalıştırıyor.
- **Emin değilim:** cihazda ölçmedim; OEM'e göre bildirim sesi bastırılmış olabilir. Ama
  kod düzeyinde iki ses kaynağı da açık.

### T4 — `notified_nudge_ids` seti sınırsız büyüyor

- `app/lib/data/providers/nudge_notification_listener.dart:13, :83` — set hiç kırpılmıyor.
- Karşılaştırma: push tarafındaki eşdeğeri 100 kayıtta kırpılıyor
  (`app_push_notification_service.dart:552`).

### T5 — İçeriksiz push "alındı" işaretlendikten sonra düşürülüyor

- `app/lib/core/notifications/app_push_notification_service.dart:239` teslim kaydı yazılıyor,
  `:247` başlık ve gövde boşsa `return`. Sonuç: sağlık kartındaki "son teslim" damgası,
  kullanıcının hiç görmediği bir mesajla ilerliyor.

---

## Kontrol ettim, SAĞLAM çıktı

1. **`android.notification` tuzağı tekrar etmemiş.** `supabase/functions/dispatch-push/index.ts:256-275`
   yalnız `data` + `android.{priority,ttl,collapse_key}` yolluyor; `android.notification` bloku yok
   ve neden olmaması gerektiği yorumda duruyor.
2. **Dürtme çift bildirimi (aynı isolate içinde) kapalı.** Push payload'ındaki `event_id`,
   `nudges.id` (`supabase/migrations/0066_push_notification_delivery.sql:307-314`); Dart iki
   yolda da aynı anahtarı üretiyor (`app_push_notification_service.dart:530-541` ve `:274`),
   dolayısıyla `_markReceivedOnce` ikisini birleştiriyor. (Isolate sınırı için bkz. R2.)
3. **FGS tipi ↔ manifest uyumlu.** `AndroidManifest.xml:93-100` `dataSync|specialUse`;
   `StudyTimerService.kt:321-340` API 34+ `SPECIAL_USE`, API 29-33 `DATA_SYNC` — runtime tip
   manifest alt kümesi. `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` metni de var.
4. **Tekrarlayan alarm zinciri sağlam.** `AlarmReceiver.kt:47-54` FIRE dalında bir sonraki
   occurrence'ı çalmadan önce kuruyor; `NativeAlarmScheduler.kt:38` `MISSED_TRIGGER_WINDOW_MS`
   ile eski kaçırmalar elenmiş; `:445-480` `setAlarmClock → setExactAndAllowWhileIdle →
   setAndAllowWhileIdle` zinciri `SecurityException`'ı yakalayıp sessizce yutmuyor.
5. **Boot sonrası davranış Android 15 kuralına uygun.** `TimerBootReceiver.kt:29-35` boot'ta
   FGS başlatmıyor, yalnız widget yayını gönderiyor.
6. **Play izin kapısı gerçekten ölçüyor.** `scripts/test_all.py:510-737` hem kaynak hem
   **birleştirilmiş** manifesti okuyor, beyaz liste dışı izin/feature/FGS tipini düşürüyor,
   artefakt tazeliğini `versionCode` ile doğruluyor; `.github/workflows/release.yml:188`
   `--require-merged` ile koşuyor (yani yayın turunda "atlandı" diyerek yeşil basamaz).
7. **Kısayol ↔ kod eşlemesi tam.** `res/xml/shortcuts.xml` sekiz aksiyon bildiriyor; sekizinin
   de karşılığı `device_integration_listener.dart:10-15` (üç navigasyon) ve `:23-29` + `:59-77`
   (beş sayaç aksiyonu) içinde var.
8. **Manifestteki altı widget sağlayıcısının altısı da Kotlin'de var** (`StudyWidgetProviders.kt:129,
   217, 264, 316, 356, 371`); yayın bayrağı tek kaynakta (`published_home_widgets.dart:44-60`)
   ve manifest `enabled="false"` ile hizalı.
9. **Bildirim kanalı adları tek kaynaktan ve dile duyarlı.** `app_push_notification_service.dart:313-350`
   tek `_channelFor`; native taraf da koşulsuz `createNotificationChannel` ile ad/açıklamayı
   tazeliyor (`StudyTimerService.kt:515-528`), per-app locale manifest+`MainActivity.kt:150-170`
   ile bağlanmış.
10. **Alarm çalma yüzeyi receiver kaydı doğru.** `AlarmRingActivity.kt:92-97` Android 13+ için
    `RECEIVER_NOT_EXPORTED`, `:107-111` `onDestroy`'da kayıt siliniyor.
