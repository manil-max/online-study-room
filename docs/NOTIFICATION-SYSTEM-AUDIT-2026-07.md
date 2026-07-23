# Odak Kampı Bildirim Sistemi ve Android Canlı Sayaç — Adli İnceleme, Hedef Mimari ve Yol Haritası

> **Güncel durum notu — 23 Temmuz 2026:** Bu dosya WP-265'in karar anındaki inceleme ve uygulama günlüğüdür; post-v43 canlı plan değildir. beta-v4302/4303, staging `0066–0068`, retry-worker açığı, release kapısı ve v43 timer paneli kararının güncel adli değerlendirmesi [`KURTARMA-ON-INCELEME-RAPORU-2026-07-23.md`](KURTARMA-ON-INCELEME-RAPORU-2026-07-23.md)'dedir. Uygulanabilir kalan işler `progress.md` WP-269–274'tür; bu dosyadaki eski “önerilen nihai durum” paragrafları worker talimatı olarak kullanılmaz.

> **Tarih:** 22 Temmuz 2026  
> **Durum:** WP-265 salt-okunur inceleme raporu  
> **Kapsam:** Android genel bildirim teslimi, dürtme/güncelleme/duyuru/hatırlatıcı ayrımı, Samsung Now Bar beklentisi, Android Live Updates ve native sayaç bildirimi  
> **Üretim etkisi:** Yok. Bu rapor hazırlanırken uygulama, Supabase, staging ve production değiştirilmedi.  
> **Ana sonuç:** Kullanıcıdaki iki belirti de gerçektir. Uygulamada kapalı sürece ulaşabilen bir push taşıma hattı bulunmuyor; mevcut özel `RemoteViews` sayaç paneli ise Android'in Live Update terfi şartlarını ihlal ediyor.

> **Karar güncellemesi — 22 Temmuz 2026:** Bu rapordaki standart/promoted sayaç denemesi beta-v4302'de gerçek cihazda ürün kabulü almadı; kullanıcı kabul ettiği stable tasarım, özel `RemoteViews` ile tek satır sayaç ve büyük doğrudan eylem panelidir. Bu nedenle beta-v4303'te standart kart ve promoted ongoing denemesi geri alınmıştır. Samsung Now Bar için ayrı, cihazda kanıtlanmış bir yüzey yoktur; bu ekran bir Now Bar vaadi olarak yeniden getirilmez. Genel push hattı ise FCM data-only mesaj + uygulamanın foreground/background aynı yerel sunumu ile güncellenmiştir.

---

## 1. Yönetici özeti

### 1.1 Kesin teşhis

1. **Dürtme, güncelleme ve duyuru bildirimleri WhatsApp benzeri push değildir.**
   - Dürtme, yalnız `HomeShell` açıkken Supabase Realtime akışını dinleyen Dart koduyla yerel bildirime çevriliyor.
   - Güncelleme, yalnız uygulama açılışında GitHub Releases kontrol edilerek diyalog gösteriyor.
   - Duyuru, yalnız Bildirim Merkezi ekranının Supabase'den çektiği uygulama içi veridir.
   - Projede `firebase_messaging`, Firebase başlatma ayarı, cihaz token kaydı, sunucu göndericisi, push outbox'ı veya teslim kaydı yoktur.

2. **Android izni mevcut olsa da taşıma hattı yoktur.**
   - `POST_NOTIFICATIONS` izni ve yerel bildirim kanalları vardır.
   - İzin, sunucudan telefona mesaj taşımaz. Yalnız telefona ulaşmış veya cihazda planlanmış bildirimin gösterilmesine izin verir.
   - Bu nedenle “izin verdim ama uygulama kapalıyken gelmiyor” davranışı mevcut mimarinin beklenen sonucudur.

3. **Uygulama açılınca gelen davranış da kodda bilinçli olarak şekillendirilmiştir.**
   - Dürtme dinleyicisi, yalnız dinleyici başladıktan sonra oluşan Realtime satırlarını gösterir.
   - Uygulama kapalıyken oluşmuş satırlar açılışta “geçmiş” kabul edilip sessizce bildirilmiş sayılır; toplu bildirim patlamasını önlemek için gösterilmez.
   - Geçmişte yaşanan sahte/tekrarlayan dürtme sorununu çözmek için eklenen bu mekanizma, gerçek push eksikliğini çözmez.

4. **Samsung “dinamik panel” için bugünkü özel tasarım teknik olarak yanlış yöndedir.**
   - Mevcut varsayılan bildirim özel `RemoteViews` kullanır, başlık/metni boşaltır ve native chronometer özelliğini kapatır.
   - Android Live Update şartları açıkça başlık, ongoing durum, standart desteklenen stil ve **özel görünüm kullanılmamasını** ister.
   - Mevcut kodda `POST_PROMOTED_NOTIFICATIONS` izni ve `setRequestPromotedOngoing(true)` isteği de yoktur.

5. **Samsung Now Bar garanti edilemez.**
   - Samsung, yalnız desteklenen uygulamaları ve kullanıcının “Live notifications” ayarını kabul eder; ülke/model/yazılım sürümü değişkenliği olduğunu kendisi belirtir.
   - Üçüncü taraf uygulamalar için belgelenmiş özel bir “Now Bar SDK” bulunmadı.
   - Doğru hedef, Android'in resmi Live Updates/promoted ongoing sözleşmesine uymak; desteklenmeyen Samsung/Android sürümlerinde işlevsel standart ongoing bildirime düşmektir.

### 1.2 Önerilen karar

- **Genel bildirim:** Firebase Cloud Messaging (FCM) + Supabase güvenli outbox/Edge Function + cihaz token yaşam döngüsü.
- **Hızlı geliştirme:** Bildirim Merkezi içinde izin/token/backend/son teslim adımlarını gösteren “Bildirim Sağlığı” ve tek dokunuşla gerçek uzaktan self-test.
- **Sayaç:** Özel `RemoteViews` varsayılanını kaldır; AndroidX `NotificationCompat` standart ongoing chronometer kullan; uygun Android sürümünde promoted ongoing iste; eski cihazlarda aynı standart bildirimle devam et.
- **Ürün vaadi:** “Samsung Now Bar kesin çalışır” değil, “Android Live Update için resmi şartlara uygun; OEM/user ayarı izin verirse terfi eder; her cihazda kalıcı işlevsel sayaç bildirimi vardır.”

### 1.3 Maliyet

- Firebase'in resmi fiyat tablosunda **Cloud Messaging (FCM) no-cost** olarak listelenir.
- Ek Firebase veritabanı/Functions kullanılması gerekmiyor; mevcut Supabase veritabanı ve Edge Function katmanı kullanılacak.
- Supabase'in mevcut plan kotaları ve Edge Function çağrı kotası geçerlidir. Başlangıç ölçeğinde ayrıca ücretli push ürünü gerektiren bir tasarım önerilmemiştir.
- Kaynak: https://firebase.google.com/pricing ve https://firebase.google.com/products/cloud-messaging

---

## 2. İnceleme yöntemi ve kanıt sınırı

### 2.1 İncelenen yerel kaynaklar

- Flutter başlangıç, auth ve ana kabuk yaşam döngüsü
- Bildirim Merkezi, bildirim tercihleri, hatırlatıcı ve dürtme servisleri
- Supabase nudge repository, Realtime provider ve `0016_nudges.sql`
- Duyuru/hatırlatıcı veri modeli ve `0023_notification_center.sql`
- GitHub updater ve release kontrolü
- Android manifest, Gradle, foreground servisler, native alarm/timer köprüleri
- `StudyTimerService`, `TimerStateStore`, notification XML ve action pending intent'leri
- Git geçmişindeki WP-2/6/8/17/36/41/42/51/76/79/80/103/133–139/204–206 değişimleri
- Silinmiş eski `WIDGET-DINAMIK-PANEL-ANALIZ.md` ve `GECMIS-DENEME-OTOPSISI.md`
- Kanonik kalite, ürün, ortam ve migration kuralları

### 2.2 Resmî dış kaynaklar

- Android Live Updates: https://developer.android.com/develop/ui/views/notifications/live-update
- Android notification permission: https://developer.android.com/develop/ui/compose/notifications/notification-permission
- Android notification channels: https://developer.android.com/develop/ui/compose/notifications/channels
- AndroidX Core sürümleri: https://developer.android.com/jetpack/androidx/releases/core
- Samsung Now Bar: https://www.samsung.com/my/support/mobile-devices/how-to-use-the-now-bar-on-the-lock-screen-of-your-samsung-galaxy-device/
- Firebase Flutter başlangıç: https://firebase.google.com/docs/flutter/setup
- Flutter FCM kurulum/registration: https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- Flutter mesaj alma durumları: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- FCM HTTP v1 gönderme: https://firebase.google.com/docs/cloud-messaging/send/v1-api
- FCM token yönetimi: https://firebase.google.com/docs/cloud-messaging/manage-tokens
- Supabase Database Webhooks: https://supabase.com/docs/guides/database/webhooks
- Supabase Edge Functions: https://supabase.com/docs/guides/functions

### 2.3 Kanıt seviyesi

| Etiket | Anlam |
|---|---|
| **Kesin** | Kodda veya resmî belgede doğrudan görüldü. |
| **Güçlü çıkarım** | Birden çok doğrudan kanıt aynı sonucu destekliyor. |
| **Cihazda doğrulanmalı** | OEM/Android sürümü/kullanıcı ayarı sonucu etkiliyor. |
| **Aktivasyon gerekiyor** | Kod tek başına yetmez; dış panelde proje/secret/deploy gerekir. |

Bu inceleme sırasında Android fiziksel cihaz veya AVD bağlı değildi. Windows, Chrome ve Edge cihazları görünüyordu. Bu nedenle OEM görünümü hakkında “cihazda geçti” iddiası yoktur.

---

## 3. Mevcut bildirim envanteri

### 3.1 Tür bazında gerçek davranış

| Tür | Bugünkü kaynak | Uygulama kapalıyken | Uygulama açıkken | Gerçek push? | Ana sorun |
|---|---|---:|---:|---:|---|
| Dürtme | Supabase `nudges` Realtime → Dart → local notification | Hayır | Evet | Hayır | Dinleyici `HomeShell` ömrüne bağlı. |
| Güncelleme | Açılışta GitHub Releases HTTP kontrolü → dialog | Hayır | Açılışta | Hayır | Arka plan tetikleyici yok. |
| Duyuru | Supabase query → Bildirim Merkezi listesi | Hayır | Ekran açılınca | Hayır | Yalnız uygulama içi inbox. |
| Çalışma hatırlatıcısı | Cihazda önceden planlı local notification | Evet, OS planına göre | Evet | Gerekmez | Android izin/kanal/OEM scheduling kısıtlarına bağlı. |
| Akıllı seri/haftalık | Cihazda planlı local notification | Evet, OS planına göre | Evet | Gerekmez | Senkron yalnız authenticated shell kurulduğunda yapılır. |
| Alarm/çoklu timer | Native AlarmManager + receiver/activity | Evet | Evet | Gerekmez | Ayrı native ürün; push ile karıştırılmamalı. |
| Çalışma sayacı | Native foreground service ongoing notification | Çalışan FGS süresince | Evet | Gerekmez | Özel panel Live Update şartlarını bozuyor. |

### 3.2 Önemli ayrım

Üç farklı kavram aynı “bildirim” kelimesiyle anılıyor:

1. **Local scheduled notification:** Telefon kendi saatine göre gösterir. Hatırlatıcı/alarm için doğrudur.
2. **Foreground service notification:** Android çalışan uzun işi görünür tutar. Sayaç için doğrudur.
3. **Remote push notification:** Sunucu olay olduğunda FCM/APNs üzerinden telefona ulaşır. Dürtme/duyuru/güncelleme için gereklidir ve bugün yoktur.

Birinci ve ikinci sistemin çalışması, üçüncü sistemin var olduğu anlamına gelmez.

---

## 4. Dürtme akışının adım adım otopsisi

### 4.1 Bugünkü veri yolu

```text
Gönderen “Dürt”
  → Supabase RPC send_nudge
  → nudges satırı
  → Supabase Realtime WebSocket
  → yalnız çalışan Flutter süreci
  → nudgeNotificationListenerProvider
  → flutter_local_notifications
  → Android notification shade
```

Bu zincirde `nudges satırı → cihaz push servisi` bağlantısı yoktur.

### 4.2 Yaşam döngüsü problemi

- `nudgeNotificationListenerProvider`, `HomeShell.build` içinde watch edilir.
- Kullanıcı giriş yapmamışsa, onboarding'deyse veya Flutter süreci yoksa bu dinleyici yoktur.
- Android uygulamayı arka planda öldürürse Supabase WebSocket de kapanır.
- Realtime bir veri senkronizasyon mekanizmasıdır; terminated uygulamayı uyandıran push servisi değildir.

### 4.3 Açılışta sessiz seed davranışı

Dinleyici kurulurken `listeningStartedAt` alınır. Bu zamandan önce oluşan dürtmeler:

- gösterilmez,
- “bildirilmiş” ID listesine eklenir,
- sonraki Realtime reconnect'te de tekrar gösterilmez.

Bu davranış, geçmişteki “uygulama açılınca eski dürtmeler patlıyor / aynı dürtme tekrar tekrar geliyor” sorununa savunmadır. Ancak kullanıcı beklentisi “olay olduğunda telefonuma gelsin” ise çözüm olamaz.

### 4.4 Yerel bildirim servisinin sınırı

`NudgeNotificationService`:

- yalnız Android'de çalışır,
- `FlutterLocalNotificationsPlugin` ile high-priority message notification oluşturur,
- Android 13+ izni isteyebilir,
- fakat dışarıdan mesaj alamaz ve öldürülmüş süreci başlatamaz.

### 4.5 Kesin kök neden

**P0 — transport yok:** FCM SDK/token/server sender yok.  
**P1 — yanlış tetik katmanı:** server olayı istemci Realtime listener'ına bağlanmış.  
**P1 — teslim gözlemi yok:** “satır oluştu / outbox oluştu / FCM kabul etti / token geçersiz / cihaz aldı” ayrımı kaydedilmiyor.

---

## 5. Güncelleme ve duyuru akışının otopsisi

### 5.1 Güncelleme

- `AuthGate.initState` ilk frame sonrası `maybeShowUpdateDialog` çağırır.
- Sideload kanalında GitHub release bilgisi HTTP ile kontrol edilir.
- Kullanıcı updates tercihini kapatmışsa dialog gösterilmez.
- Play kanalında sideload updater fail-closed kapalıdır.
- Arka plan worker, FCM topic veya sunucu yayın olayı yoktur.

Git geçmişindeki `WP-79: açılış bildirim teslimini düzelt` commit'i gerçek push eklememiştir. Aksine eski local/best-effort update notification kodunu kaldırıp açılış kontrolünü düzenlemiştir. `project.md` de ilk fazı açıkça “local/best-effort; gerçek push ayrı karar” olarak tarif eder.

### 5.2 Duyuru

- Duyurular RLS filtreli Supabase query ile Bildirim Merkezi'nde listelenir.
- Okundu bilgisi sunucuda tutulur.
- `announcementsEnabled` yerel ayarı query/list görünürlüğünü değiştirir.
- Bir duyuru eklenince cihazlara push üreten trigger/outbox/topic yoktur.

### 5.3 Hedef davranış

- Güncelleme push'ı yalnız release başarıyla yayımlandıktan sonra sürüm manifestinden üretilmelidir.
- Duyuru push'ı, uygulama içi inbox satırının yerine geçmemelidir; push yalnız “yeni içerik var” sinyali ve görünür özet olmalıdır.
- Dürtme, olay başına hedef kullanıcı/tüm aktif cihazlar modelini kullanmalıdır.
- Tür tercihleri sunucu gönderiminde de uygulanmalıdır; yalnız UI switch'i olarak kalmamalıdır.

---

## 6. İzin, kanal ve yerel servis bulguları

### 6.1 Android 13+ izni

Manifestte `POST_NOTIFICATIONS` vardır. Bildirim Merkezi ve farklı saat/bildirim servisleri izin isteyebilir. Resmî Android davranışı:

- yeni kurulumda izin varsayılan kapalıdır,
- kullanıcı reddederse normal bildirimler görünmez,
- foreground service başlatma kuralları ayrı olsa da görünür yüzey davranışı değişebilir.

Kaynak: https://developer.android.com/develop/ui/compose/notifications/notification-permission

### 6.2 Kanal davranışı

Android 8+ notification channel zorunludur. Kanal önem/ses davranışları oluşturulduktan sonra uygulama tarafından serbestçe değiştirilemez; kullanıcı son söz sahibidir.

Bugünkü ekran yalnız izin isteme sonucu için kısa snackbar gösterir. Şunları ayırmıyor:

- uygulama genel izni kapalı,
- ilgili kanal kapalı veya sessiz,
- lock-screen içeriği kapalı,
- Samsung live notifications kapalı,
- push hiç yapılandırılmamış,
- token sunucuya yazılmamış,
- token eski/geçersiz,
- outbox/Edge/FCM hatası.

Kaynak: https://developer.android.com/develop/ui/compose/notifications/channels

### 6.3 Birden fazla plugin instance'ı

Nudge, reminder, timer ve alarm katmanlarında ayrı `FlutterLocalNotificationsPlugin` instance'ları vardır. Birden fazla instance teknik olarak her zaman hata değildir; fakat:

- initialize callback sahipliği dağılır,
- notification tap routing parçalanır,
- kanal/izin teşhisi dağılır,
- foreground push gösterimi eklendiğinde beşinci bağımsız yol oluşur.

**Öneri:** Alarm ve native FGS işlevlerini ayırarak koru; sosyal/reminder/push local presentation için tek bir `AppNotificationCoordinator` oluştur. Alarm full-screen sözleşmesini genel push refactor'ına karıştırma.

---

## 7. Sayaç ve Samsung dinamik panel otopsisi

### 7.1 Güçlü mevcut temel

Bugünkü native sayaç omurgasının değerli ve korunması gereken tarafları:

- Flutter sürecinden bağımsız `StudyTimerService`
- `START_NOT_STICKY`; ölümcül null-intent restart döngüsüne karşı koruma
- her komut yolunda 5 saniye içinde `startForeground`
- Android 29–33 `DATA_SYNC`, Android 34+ `SPECIAL_USE` uyumlu manifest/runtime alt kümesi
- exported olmayan receiver ve açık same-app pending intent
- synchronous `TimerStateStore.commit()` ile atomik running/idle yazımı
- native pending interval/outbox ve idempotent session ID'leri
- uygulama çalışırken state broadcast + Flutter reconcile

Dolayısıyla çözüm “native servisi silip Flutter notification yazmak” değildir.

### 7.2 Bugünkü bildirim yapısı

Varsayılan `timer_panel_expanded=true` yolunda:

- özel `RemoteViews` kullanılır,
- `setCustomContentView` ve `setCustomBigContentView` çağrılır,
- `DecoratedCustomViewStyle` kullanılır,
- `contentTitle` ve `contentText` boşaltılır,
- `setUsesChronometer(false)` yapılır,
- özel XML içindeki `Chronometer` ve tek pill eylem çizilir.

Fallback flag kapalıyken:

- standart ongoing notification,
- başlık/metin,
- native `usesChronometer`,
- native action kullanılır.

### 7.3 Android Live Update şartlarıyla karşılaştırma

| Resmî şart | Bugünkü durum | Sonuç |
|---|---|---|
| Standart desteklenen stil | Varsayılan custom decorated view | Başarısız |
| `POST_PROMOTED_NOTIFICATIONS` | Manifestte yok | Başarısız |
| Promotion isteği | `setRequestPromotedOngoing` yok | Başarısız |
| Ongoing | Running durumda var | Geçer |
| Content title | Custom yolda boş | Başarısız |
| Custom content view olmamalı | İki custom content view var | Başarısız |
| Channel `IMPORTANCE_MIN` olmamalı | Default channel | Muhtemel geçer; kullanıcı ayarı kontrol edilmeli |
| Colorized true olmamalı | Kullanılmıyor | Geçer |
| Kullanıcı başlatmalı/ongoing/zaman duyarlı | Kullanıcı başlatmalı odak oturumu | Ürün açısından güçlü aday; OEM kararı saklı |

Resmî Android belgesi custom notification'ların sürüm/OEM arasında tutarlı test edilemediğini özellikle belirterek Live Updates için yasaklar. Kaynak: https://developer.android.com/develop/ui/views/notifications/live-update

### 7.4 Geçmiş sarkaç

| Dönem | Karar | Sonuç |
|---|---|---|
| WP-42/51 | Native FGS omurgası | Doğru temel; ilk crash'ler v13 ile düzeldi. |
| WP-76 | Expanded custom dinamik panel + specialUse | API ≤13 FGS type çökmesi ve OEM belirsizliği. |
| WP-80 | Custom kaldırıldı, standard chronometer/actions | OEM terfisine daha uygun; One UI yerleşimi ürünce beğenilmedi. |
| v23 | One UI görünümü için custom geri geldi | Standart terfi hipotezi terk edildi. |
| WP-137 | Standard `usesChronometer` tekrar varsayılan | Sistem sözleşmesine dönüş. |
| WP-204–206 | Custom panel tekrar varsayılan | Bugünkü durum; resmi Live Update şartlarına aykırı. |

Bu geçmiş, görünüm ve süreç güvenliğinin aynı sınıfta beraber değiştirilmesinin regresyon ürettiğini gösteriyor. Yeni değişiklik:

- FGS lifecycle/state/action davranışına dokunmamalı,
- yalnız notification presentation katmanını kontrollü değiştirmeli,
- source-contract ve native compile testleriyle eski crash sınıflarını kilitlemeli,
- önce standart fallback'i kanıtlamalıdır.

### 7.5 Küçük ikon bulgusu

Native sayaç `@mipmap/ic_launcher` değerini small icon olarak kullanıyor. Android small notification icon için saydam/tek renk stat icon daha güvenilir ve OEM yüzeylerine daha uygundur. Ayrı `ic_stat_focus_timer` drawable önerilir.

### 7.6 Samsung Now Bar gerçeği

Samsung'un güncel destek sayfası:

- Now Bar'ın yalnız supported apps ile çalıştığını,
- lock screen notifications ve uygulama bazında Live notifications açık olması gerektiğini,
- model/ülke/yazılım sürümüne göre özelliğin bulunmayabileceğini,
- desteklenen uygulama çalışmıyorsa Now Bar'ın görünmediğini belirtir.

Bu nedenle kabul iki katmanlı olmalıdır:

1. **Garanti edilen ürün:** doğru çalışan ongoing notification, akan süre ve native Start/Stop eylemleri.
2. **Best-effort OEM terfisi:** resmi Android promotable sözleşmesine uygunluk; sistem/Samsung izin verirse Now Bar/chip/lock-screen live yüzeyi.

---

## 8. Kök neden ve öncelik matrisi

| Öncelik | Bulgu | Kullanıcı etkisi | Kanıt | Çözüm |
|---|---|---|---|---|
| P0 | Remote push transport yok | Uygulama kapalıyken dürtme/duyuru/update gelmez | Paket/Gradle/manifest/server taraması | FCM + device registry + server sender |
| P0 | Server event → push outbox yok | Teslim ve retry yapılamaz | Migration/function taraması | Transactional outbox + delivery rows |
| P0 | Custom RemoteViews promotable değil | Samsung/Android live surface oluşmaz | Kod + resmî Live Update şartı | Standard notification + promotion request |
| P1 | Teslim gözlemi yok | “Nerede kırıldı?” bilinmez | Log/schema yok | Health screen + delivery states + redacted errors |
| P1 | Tercihler yalnız cihazda | Server kapalı türü gönderebilir | SharedPreferences-only | Device push prefs sync |
| P1 | Token lifecycle yok | Reinstall/refresh/logout çoklu cihaz sorunları | Token tablosu/kod yok | Refresh/upsert/logout/invalid cleanup |
| P1 | Güncelleme yalnız cold-start | Kullanıcı uygulamayı açmadan haberdar olmaz | AuthGate/update code | Release event → reusable push enqueue |
| P1 | Plugin routing dağınık | Tap/foreground presentation regresyonu | Birden çok initialize | Koordinatör; alarm/FGS izolasyonu |
| P2 | Small icon launcher mipmap | OEM görünümü tutarsız olabilir | Native builder | Monochrome stat icon |
| P2 | No-device/retry/duplicate politikası yok | Sessiz kayıp veya çift bildirim | Outbox yok | Idempotency key + per-device delivery |

---

## 9. Hedef genel bildirim mimarisi

### 9.1 Olaydan cihaza

```text
Supabase transaction
  ├─ domain row (örn. nudges)
  └─ notification_outbox (benzersiz event_key)
        ↓ trigger: aktif push cihazları için delivery satırları
notification_deliveries
        ↓ async database webhook / dispatcher çağrısı
Supabase Edge Function: dispatch-push
        ├─ service-role ile bounded claim (SKIP LOCKED)
        ├─ Firebase service account → kısa ömürlü OAuth token
        ├─ FCM HTTP v1
        ├─ success / retry / permanent failure
        └─ UNREGISTERED tokenı devre dışı bırak
                 ↓
Android FCM
  ├─ foreground: coordinator local notification gösterir
  ├─ background: sistem notification payload'ı gösterir
  └─ terminated: sistem uygulamayı açmadan bildirimi gösterir
```

### 9.2 Cihaz kaydı

`push_devices` önerilen alanları:

- `id`, `user_id`, `installation_id`
- `fcm_token` ve token güncelleme zamanı
- `platform`, `app_version`, `build_number`, `channel`
- `locale`, `time_zone`
- tür tercihleri: nudge/announcement/update
- sessiz saat ayarları
- `last_seen_at`, `disabled_at`, `last_error_code`

Güvenlik:

- token tablosuna doğrudan client select/write yok,
- authenticated security-definer RPC yalnız `auth.uid()` cihazını upsert/unregister eder,
- service role dispatch için okur,
- token ve service-account verisi loglanmaz,
- Firebase service account yalnız Supabase project secret'ta bulunur.

### 9.3 Transactional outbox

`notification_outbox` domain olayını temsil eder. `event_key` benzersizdir; aynı dürtme/release tekrar işlense de ikinci event oluşmaz.

`notification_deliveries` her cihaz teslimini temsil eder:

- `pending → processing → sent`
- geçici hata: `retry`, artan gecikme ve bounded attempt
- kalıcı invalid token: `failed_permanent`, cihaz pasif
- no-device: outbox üzerinde açık durum; sessiz başarı sayılmaz

Bu ayrım, kısmi çoklu cihaz başarısında başarılı telefona duplicate göndermeden yalnız başarısız telefonu tekrar denemeyi sağlar.

### 9.4 Mesaj sözleşmesi

Her mesajda:

- `schema_version`
- `notification_type`
- `event_id`
- `route`
- minimal route parametreleri
- title/body notification payload
- Android channel ve high priority

Hassas içerik push payload'ına konmamalı. Dürtme mesajı 120 karakter sınırında olsa da lock-screen gizlilik tercihi göz önünde bulundurulmalı; asıl veri uygulama açılınca RLS ile alınmalıdır.

### 9.5 Güncelleme bildirimi

- Stable/beta release workflow'u başarılı asset + manifest yayımlandıktan sonra idempotent enqueue endpoint'i çağırır.
- Mesaj `version_code`, `version_name`, `channel` ve güvenli route taşır.
- Play kanalında GitHub sideload updater açılmaz; mağaza kanalına göre aksiyon seçilir.
- Workflow secret eksikse push adımı fail-closed veya açıkça skipped olur; release varmış gibi sahte başarı vermez.

---

## 10. “10 saniyede görülebilen” test sistemi

### 10.1 Bildirim Sağlığı kartı

Bildirim Merkezi'nde teknik olmayan ama tanısal bir kart:

| Kontrol | Kullanıcı dili | Kaynak |
|---|---|---|
| OS izni | “Bildirim izni açık/kapalı” | Android permission |
| Push config | “Uzak bildirim hizmeti hazır/kurulmamış” | Firebase config |
| Token | “Bu telefon kayıtlı/kayıt bekliyor” | FCM + Supabase RPC |
| Kanal | “Dürtme kanalı açık/sessiz/kapalı” | NotificationManager |
| Backend | “Gönderim servisi hazır/erişilemiyor” | health/self-test RPC |
| Son olay | “Son test 14:32'de ulaştı” | local receipt timestamp |
| Live timer | “Canlı yüzey uygun/ayar kapalı/desteklenmiyor” | Android native diagnostic |

### 10.2 İki ayrı test butonu

1. **Telefonda yerel test:** yalnız izin/kanal/presentation katmanını ölçer; ≤1 saniye.
2. **Gerçek uzaktan test:** authenticated RPC → outbox → Edge → FCM → cihaz; hedef p95 ≤10 saniye.

Bu iki test ayrı olmalıdır. Yerel testin geçmesi, push'ın geçtiği anlamına gelmez.

### 10.3 Test sonucu

Self-test ekranda adımları gösterir:

```text
İstek oluşturuldu ✓
Sunucu kuyruğa aldı ✓
FCM kabul etti ✓
Bu telefon aldı ✓  2,4 sn
```

Timeout halinde son başarılı adım ve kullanıcı aksiyonu gösterilir; service account, token veya ham backend hata metni gösterilmez.

### 10.4 Geliştirici hızlı döngüsü

- Local/unit: fake messaging gateway ile saniyeler içinde.
- Local Supabase: outbox/RLS/idempotency pgTAP.
- Android debug/beta: health screen self-test.
- Firebase Console test message: client registration ve background/terminated izolasyon testi.
- Staging synthetic sender/recipient hesapları: gerçek dürtme E2E.

---

## 11. Android canlı sayaç hedef mimarisi

### 11.1 Değiştirilecek tek sorumluluk

`StudyTimerService` içindeki state/lifecycle/action korunur. Notification factory şu sözleşmeye geçirilir:

- running: standard ongoing notification
- content title zorunlu
- native chronometer (`setWhen`, `setUsesChronometer`)
- Start/Stop veya break state'e göre native action
- API/AndroidX uygunsa `setRequestPromotedOngoing(true)`
- `POST_PROMOTED_NOTIFICATIONS` manifest izni
- `hasPromotableCharacteristics` diagnostic
- sistem ayarı için `canPostPromotedNotifications` diagnostic
- monochrome small icon
- custom content view yok

### 11.2 API/sürüm davranışı

| Cihaz | Beklenen |
|---|---|
| Android 16+/Live Updates destekli | Promoted ongoing talebi; sistem uygun bulursa lock-screen/chip/top card |
| Samsung güncel One UI | Android resmi sinyali + Samsung live notification/user setting; OEM sonucu best-effort |
| Android 8–15 | Standart ongoing chronometer + native action |
| Bildirim izni/kanal kapalı | Health screen açık neden gösterir; gizlice “başarılı” sayılmaz |

### 11.3 Idle davranışı

Live Update yalnız aktif, ongoing, user-initiated iş içindir. Sayaç durduğunda:

- promotion istenmez,
- foreground bağından çıkılır,
- ürün kararı gereği idle Start notification tutulacaksa standard/non-ongoing kalır,
- kullanıcı dismissed ettiyse zorla tekrar tekrar post edilmez.

### 11.4 Neden custom görünüm kaldırılmalı?

- Resmî uygunluk zorunluluğu.
- Koyu/açık tema ve OEM kontrast farklarında daha güvenli.
- TalkBack/action erişilebilirliği sistem tarafından yönetilir.
- Android 8–16 arasında tek davranış matrisi.
- Custom XML'in sabit beyaz/turuncu renk ve One UI satır ölçümü borcu ortadan kalkar.

Bedeli: One UI'nin standart action yerleşimi özel pill kadar tasarım kontrollü olmayabilir. Bu bilinçli bir ürün takasıdır; işlev, erişilebilirlik ve live-surface uygunluğu görsel piksel kontrolünden üstündür.

---

## 12. Uygulama yol haritası

### WP-265 — Adli rapor ve kabul sözleşmesi

- **Amaç:** Yanlış teşhisle yeni regresyon üretmeden tek kanonik resim.
- **Çıktı:** Bu rapor, WP kartları, backlog/project karar güncellemesi.
- **Kabul:** Kod ve geçmiş kanıtları, resmî kaynaklar, hedef mimari, cihaz/rollback/deploy kapıları belgeli.
- **Production etkisi:** Yok.

### WP-266 — Güvenilir push çekirdeği ve 10 saniyelik self-test

- FCM Flutter client entegrasyonu; foreground/background/terminated sözleşmesi.
- Firebase config eksikse fail-closed/no-op; uygulamanın geri kalanı bozulmaz.
- Token refresh, installation ID, login/logout ve çoklu cihaz yaşam döngüsü.
- Supabase `push_devices`, outbox ve per-device deliveries; RLS/security-definer RPC.
- Dürtme insert trigger'ı ile idempotent enqueue.
- Edge dispatcher, OAuth/FCM HTTP v1, retry ve invalid token cleanup.
- Bildirim türü/quiet-hours tercihlerini cihaz kaydıyla sync.
- Bildirim Sağlığı + local test + gerçek remote self-test.
- In-memory karşılığı ve fake gateway testleri.
- **Aktivasyon kapıları:** Firebase app kayıtları, Supabase secret, migration local→staging, Edge deploy/webhook; production için ayrıca somut GO.

### WP-267 — Android standard/promoted canlı sayaç

- AndroidX Core resmi promoted ongoing API sürümünü pinle.
- Manifest permission ve standard notification factory.
- Native chronometer/title/action/small icon.
- Promotable/can-post diagnostic bridge.
- FGS state/store/action kodunu değiştirmeden source-contract testleri.
- Kotlin compile + Flutter regression + physical Samsung/Pixel matrix.
- Custom panel varsayılanını kaldır; gerekirse yalnız acil rollback flag'i bir sürüm korunur.

### İzleyen aktivasyon/QA

Bu üç WP'nin kodu bitse bile canlı kullanıcıya “tamamlandı” demek için:

1. Firebase production ve beta Android app kayıtları
2. FCM service account secret'ının ilgili Supabase ortamına güvenli eklenmesi
3. `0066` türü ileri migration'ın local ve staging'de doğrulanması
4. Edge dispatcher deploy + database webhook/secret
5. Samsung fiziksel cihaz ve mümkünse Pixel/API 36 test
6. Beta soak ve teslim metriği
7. Production migration/Edge/release için açık kullanıcı GO

gereklidir. Production mutation rapor veya local kod commit'iyle otomatikleşmez.

---

## 13. Test ve kabul matrisi

### 13.1 Otomatik testler

#### Flutter

- Firebase config yokken Windows/web/local açılış bozulmaz.
- Push service yalnız desteklenen Android'de etkinleşir.
- Auth yokken token kullanıcıya bağlanmaz.
- Auth değişince eski kullanıcı kaydı temizlenir, yeni kullanıcıya upsert edilir.
- Token refresh aynı installation row'u günceller.
- Foreground aynı `event_id`yi ikinci kez göstermez.
- Preference/quiet-hours sync.
- Health state mapping ve secret redaction.
- InMemory repository davranış eşliği.

#### PostgreSQL/pgTAP

- Client push table doğrudan SELECT/INSERT/UPDATE/DELETE yapamaz.
- Kullanıcı yalnız kendi device RPC'sini çağırabilir.
- `send_nudge` transaction'ı tek event/outbox üretir.
- Aynı event key duplicate outbox/delivery üretmez.
- Bir event her aktif cihaz için tek delivery üretir.
- Disabled/tercihi kapalı cihaz delivery almaz.
- Claim `SKIP LOCKED` ile aynı delivery'yi iki worker'a vermez.
- Service-only complete/fail RPC'leri authenticated kullanıcıya kapalıdır.

#### Edge dispatcher

- Missing/invalid secret fail-closed.
- Authorization kontrolü.
- FCM 200 → sent.
- 429/5xx → bounded retry.
- UNREGISTERED → permanent failure + device disable.
- Kısmi multi-device sonuçta başarıya tekrar gönderim yok.
- Ham token/private key log yok.

#### Android native

- Running notification ongoing/title/chronometer/action içerir.
- Running notification custom content view içermez.
- Promotion request yalnız running.
- Idle promotion istemez.
- FGS type matrisi değişmez.
- `START_NOT_STICKY` değişmez.
- state writes commit kalır.
- app-closed native Stop session queue üretir.

### 13.2 Fiziksel cihaz senaryoları

Her senaryo beta/staging test hesaplarıyla:

| # | Senaryo | Kabul |
|---|---|---|
| N-01 | App foreground dürtme | Tek bildirim ≤5 sn, duplicate 0 |
| N-02 | App background dürtme | Tek sistem bildirimi ≤10 sn |
| N-03 | App terminated dürtme | Uygulama açılmadan görünür ≤10 sn |
| N-04 | Android Settings force-stop | Gelmemesi Android sınırı; app yeniden açılınca registration iyileşir |
| N-05 | İnternet kapalı→açık | Bounded retry; duplicate 0 |
| N-06 | Aynı hesap iki telefon | Her aktif telefona bir teslim |
| N-07 | Logout | Eski hesap bildirimi yeni oturumda görünmez |
| N-08 | Reinstall/token refresh | Eski token pasif, yeni token aktif |
| N-09 | Dürtme kapalı | Dürtme delivery 0; update tercihi bağımsız |
| N-10 | Sessiz saat | Politikaya göre sessiz/drop; eski bildirim topluca patlamaz |
| N-11 | Remote self-test | Dört adım görünür, p95 ≤10 sn |
| T-01 | Sayaç app içinden start | Akan süre, Stop çalışır, session doğru |
| T-02 | App kill sonrası Stop | Uygulama açılmaz; pending interval kayıpsız |
| T-03 | Lock screen | Standard ongoing okunur/action ulaşılır |
| T-04 | Samsung Live notifications açık | Uygunsa Now Bar/live yüzey; değilse standard fallback |
| T-05 | Live notifications kapalı | Standard notification sürer; health nedeni gösterir |
| T-06 | 8 saat sayaç | Sapma ≤±1 sn, FGS crash 0 |
| T-07 | Reboot/update | Mevcut timer recovery sözleşmesi regresyonsuz |

### 13.3 Cihaz matrisi

- Samsung güncel One UI / Android 16+ mümkünse
- Samsung Android 13 veya daha eski desteklenen cihaz
- Pixel/AOSP API 36
- API 29–33 FGS type regression
- Android 8/9 min destek sınırı temsilcisi

Now Bar sonucu tek cihazda bile OEM garantisi sayılmaz; cihaz/firmware/user-setting kanıtı olarak kaydedilir.

---

## 14. Dağıtım ve aktivasyon planı

### 14.1 Ortam ayrımı

| Kanal | Firebase app | Supabase | Push test |
|---|---|---|---|
| local | ayrı local app veya push kapalı | local Docker | fake/local notification |
| beta | `.beta` package kaydı | staging | gerçek self-test ve iki hesap |
| stable | kalıcı package kaydı | production | yalnız beta kabul + açık GO sonrası |

Beta tokenı production'a, stable tokenı staging'e yazılmamalıdır. Cihaz kaydında channel/environment tutulmalı; server dispatcher yanlış tuple'ı fail-closed reddetmelidir.

### 14.2 Secret'lar

- Client Firebase seçenekleri benzersiz tanımlayıcılardır, service credential değildir; yine de environment manifestinden doğru kanalla sağlanır.
- `FCM_SERVICE_ACCOUNT_JSON` yalnız Supabase Edge secret.
- `SUPABASE_SERVICE_ROLE_KEY` yalnız Edge runtime.
- Webhook/dispatcher secret DB setting/Vault veya Supabase secret üzerinden ortam bazlı.
- Hiçbiri `env.json`, git, workflow log, delivery error veya UI'ya yazılmaz.

### 14.3 Aktivasyon sırası

1. Kod ve fake testler
2. Local DB baseline + pgTAP
3. Beta Firebase app kaydı
4. Staging migration
5. Staging Edge secret/deploy
6. Database webhook/dispatcher health
7. Beta APK + physical device self-test
8. İki hesap gerçek dürtme ve terminated test
9. ≥3 gün soak; P0/P1=0
10. Production için backup/rollback ve somut kullanıcı GO

### 14.4 Geri dönüş

- Client push config feature gate ile kapatılabilir; Realtime/in-app inbox veri yolu korunur.
- Dürtme domain row'u push başarısız olsa da kaybolmaz.
- Dispatcher durdurulursa outbox kalır; bounded retry sonradan sürer.
- Native timer presentation flag'i bir beta boyunca standard/custom rollback için tutulabilir; state/service kodu değişmediği için geri dönüş notification factory ile sınırlıdır.
- Production migration geriye dönük dosya editlenmez; ileri düzeltme veya erişimi kapatma yapılır.

---

## 15. Riskler ve bilinçli kapsam dışı alanlar

### 15.1 Riskler

- Firebase projesi/app kimliği yanlış kanala bağlanırsa token teslimi sessizce ayrışabilir.
- Edge webhook secret/URL ortam ayarı eksikse outbox birikir; health metriği zorunludur.
- Notification payload + foreground local gösterim birlikte yanlış ele alınırsa duplicate olabilir.
- FCM “accepted” cihazda “gösterildi” garantisi değildir; izin/kanal/OEM/batarya kullanıcı kontrolündedir.
- Samsung Now Bar uygulama allowlist/firmware kriteri uygulayabilir.
- Production migration history durumu nedeniyle yeni migration doğrudan production'a uygulanamaz; mevcut ortam yönetişim kapısı geçerlidir.

### 15.2 İlk dilimde kapsam dışı

- iOS/APNs
- Web push
- Pazarlama kampanyası/segmentasyon
- Büyük broadcast fanout sistemi
- Notification analytics için kullanıcı davranışı profilleme
- Samsung'a özel private/undocumented API
- Push'ı kritik verinin tek kaynağı yapmak

---

## 16. Senior mühendislik kararları

1. Supabase Realtime korunur; açık uygulamanın UI'sını hızlı günceller. Ancak push yerine kullanılmaz.
2. Domain verisi ve push ayrılır. Dürtme satırı gerçek kayıttır; push yeniden etkileşim sinyalidir.
3. Outbox transaction içinde yazılır. “Önce DB, sonra best-effort HTTP” sessiz kayıp üretmez.
4. Retry per-device yapılır. Çoklu cihazda başarılı teslim duplicate edilmez.
5. Kullanıcı tercihi server dispatch öncesinde uygulanır.
6. Alarm/reminder/sayaç sistemleri tek refactor'da karıştırılmaz.
7. Timer'ın native SSOT/FGS/action katmanı korunur; yalnız presentation resmi Android sözleşmesine alınır.
8. Now Bar ürün vaadi yapılmaz; promotable compatibility ve standard fallback vaadi yapılır.
9. “Test geçti” yalnız Flutter unit testi demek değildir. Terminated app + gerçek push + fiziksel Samsung/Pixel kanıtı DoD'nin parçasıdır.
10. İlk sınıf geliştirici deneyimi health/self-test ekranıyla kurulur; log aramak temel test yöntemi olmaz.

---

## 17. Nihai durum cümlesi

Analiz başlangıcındaki uygulama **yerel bildirim, native alarm ve foreground sayaç** yeteneklerine sahipti; fakat **uzak push bildirim sistemi yoktu**. Samsung canlı panel sorunu da tek bir eksik flag değil, varsayılan özel notification tasarımının resmi Live Update sözleşmesiyle uyumsuz olmasıydı. En güvenilir ve maliyetsiz yön; FCM'yi mevcut Supabase backend'e güvenli outbox/Edge Function ile bağlamak, teslimi uygulama içinden ölçülebilir yapmak ve sayaç bildirimini custom panelden standard/promoted ongoing yapısına taşımaktı. WP-266 ve WP-267 kod uygulama sonuçları aşağıdaki günlüklerde kayıtlıdır.

---

## 18. Uygulama günlüğü — WP-266 (2026-07-22)

Raporun ilk adımı kodda tamamlandı; bu bölüm analiz sonrası bulunan gerçek uygulama ayrıntılarını ve aktivasyon sınırını kaydeder.

### 18.1 Kurulan istemci omurgası

- Android istemcisine `firebase_core` + `firebase_messaging` eklendi. Firebase seçenekleri yalnız dört public Android istemci tanımlayıcısından ve environment manifestinden okunur; service account/özel anahtar uygulamaya girmez.
- Config tamamen boşsa özellik fail-closed/no-op çalışır; kısmi config “hazır” sayılmaz. Windows/web ve Firebase kurulmamış local akış bozulmaz.
- Foreground, background isolate ve terminated/opened mesaj yolları bağlandı. Aynı domain `event_id` için SharedPreferences tabanlı son-100 idempotency penceresi, açık uygulamadaki legacy Realtime dürtmesiyle FCM'nin çift bildirim üretmesini önler.
- `social_nudges`, `announcements`, `app_updates`, `push_system_test` kanalları uygulama başlangıcında açıkça oluşturulur; FCM varsayılan kanal metadata'sı tanımlıdır.
- FCM token + token refresh, kurulum UUID'si, beta/stable kanal, sürüm/build, dil, timezone, kullanıcı bildirim tercihleri ve sessiz saatler self-scoped RPC ile eşitlenir. Logout önce mevcut kurulumu devre dışı bırakmayı dener; ağ hatası logout'u kilitlemez.
- Bildirim Merkezi'ne iki ayrı test kondu: local presentation testi ve gerçek remote self-test. Remote test artık yalnız “FCM kabul etti” sonucunu yeterli saymaz; aynı `outbox_id` cihaz receiver'ında görülmeden başarı göstermez ve 10 saniyede görünür hata verir.

### 18.2 Kurulan backend omurgası

- `0066_push_notification_delivery.sql`: private/RLS `push_devices`, transactional `notification_outbox`, per-device `notification_deliveries`, idempotency anahtarları, lease/`SKIP LOCKED`, en çok 6 deneme, retry, geçersiz/stale token disable ve self-test RPC'leri.
- Dürtme insert'i transaction içinde outbox'a bağlandı. Duyurular hedef türüne göre yalnız kayıtlı/opt-in kullanıcılara fan-out olur. Release kanalına özel service-only update enqueue RPC'si beta/stable cihaz ayrımını korur.
- `dispatch-push` Edge Function service account'tan kısa ömürlü OAuth token üretir ve FCM HTTP v1 kullanır. Token/credential loglamaz; 429/5xx için geri çekilme, `UNREGISTERED` için cihaz kapatma, sessiz saat ertelemesi ve TR/EN/DE/AR temel metinleri içerir.
- GitHub Android release işi dört Firebase istemci alanı yoksa artık sessizce push'suz APK üretmez; kapıda durur. Release başarıyla oluşunca dispatcher aktive edilmişse aynı kanalın opt-in cihazlarına güncelleme push'ı otomatik kuyruğa alınır.

### 18.3 Otomatik doğrulama kanıtı

- `flutter analyze`: temiz.
- Flutter: tüm **679 test** geçti; push hedef testleri config, repository mapping, receiver yaşam döngüsü, secret sızıntısı ve release sözleşmesini kapsar.
- Android: `local` debug APK başarıyla derlendi (`app-local-debug.apk`).
- Edge: Deno type-check temiz.
- Supabase: boş yerel DB'de `0001→0066` zinciri başarıyla kuruldu; 5 pgTAP dosyasında **116 test** geçti. Kanıt: `.artifacts/deploy-evidence/20260722T162841498Z-local-baseline`.
- Deploy guard: **36/36** geçti. Workflow YAML parse edildi.

### 18.4 Bilinçli olarak yapılmayan aktivasyon

Bu turda staging/production migration, Edge deploy, Firebase Console kaydı, Supabase secret veya database setting yazımı yapılmadı. Bunlar uzak ortam mutasyonudur; repo ortam yönetişimi ve production için açık kullanıcı GO gerektirir. Kodun gerçek cihazda push alabilmesi için sırasıyla:

1. Staging Firebase Android app'i ve dört public istemci değişkeni,
2. staging `0066` migration,
3. `dispatch-push` deploy + `FCM_SERVICE_ACCOUNT_JSON` + `PUSH_DISPATCH_SECRET`,
4. database dispatcher URL/secret ayarı,
5. beta APK ile foreground/background/force-stop dışı terminated ve Samsung/Pixel test matrisi

tamamlanmalıdır. Android’in kullanıcı tarafından **Force stop** uygulanmış uygulamaya yeniden açılana kadar push teslim etmemesi platform davranışıdır; bunu uygulama kodu aşamaz. Production terfisi ancak beta soak ve açık GO sonrasıdır.

### 18.5 Ölçek notu

Mevcut duyuru fan-out'u küçük/orta kullanıcı sayısında kayıtlı cihaz sahipleriyle sınırlıdır ve domain transaction'ında outbox satırı üretir. Çok büyük yayın hacmine geçilirse recipient expansion ayrı batch/queue worker'a taşınmalıdır; bu rapordaki “büyük broadcast sistemi kapsam dışı” sınırı korunur.

---

## 19. Uygulama günlüğü — WP-267 (2026-07-22)

### 19.1 Sunum değişikliği

- Native `StudyTimerService` state, `START_NOT_STICKY`, foreground-service type matrisi, widget güncellemesi, pending interval/verified command kuyruğu ve Start/Stop/break aksiyon sözleşmesi korunmuştur.
- Varsayılan/kaçış-valfi dahil custom `RemoteViews`, `DecoratedCustomViewStyle`, boş title ve custom layout kodu kaldırılmıştır. Artık running ve idle yüzeyleri tek standard notification factory kullanır.
- Running notification: dolu localized title/body, native count-up chronometer, ongoing flag, native Stop/Çalışmaya dön action, `setShortCriticalText`, `setRequestPromotedOngoing(true)` ve DEFAULT-importance kanal taşır.
- Idle notification promotion istemez; standard/non-ongoing Start aksiyonuyla foreground borcunu güvenli kapatmak için mevcut davranışı korur.
- Manifestte non-runtime `POST_PROMOTED_NOTIFICATIONS` vardır. AndroidX Core `1.18.0` açıkça pinlenmiştir.
- Launcher bitmap'i küçük bildirim ikonu olmaktan çıkarıldı; sistemin renkleyebileceği tek renk `ic_stat_focus_timer` vector drawable eklendi.

### 19.2 Cihaz içi hızlı teşhis

Bildirim Merkezi → Bildirim Sağlığı içine salt-okunur native diagnostic köprüsü eklendi. Sayaç bir kez başlatıldıktan sonra yenile düğmesi şunları gösterir:

1. custom view kullanılmadan standard notification üretildi mi,
2. notification promotion istedi mi ve AndroidX `hasPromotableCharacteristics` doğrulamasını geçti mi,
3. kanal importance değeri MIN üstünde mi,
4. Android 16+ sistem/user ayarı `canPostPromotedNotifications` ile izin veriyor mu.

Köprü yanıt vermezse UI sonsuz beklemez; 2 saniyede standard/pending görünümüne döner. Android 8–15'te promoted yüzey vaadi yapılmaz, aynı standard kalıcı chronometer çalışır. Android 16+/Samsung sonucu sistem ve OEM kararına bağlıdır.

### 19.3 Doğrulama

- `flutter analyze`: temiz.
- Hedef native/source contract + timer testleri: **10/10**.
- Tüm Flutter suite: **682/682**.
- Gerçek Gradle/Kotlin derleme: local debug APK başarıyla üretildi.
- APK içi kontrol: `POST_PROMOTED_NOTIFICATIONS`, mevcut FGS izinleri ve `drawable/ic_stat_focus_timer` paket içinde doğrulandı.
- Custom timer layout dosyası silindi; kaynak sözleşmesi `setCustomContentView`, `setCustomBigContentView` ve `R.layout.timer_notification` dönüşünü testte yasaklar.

### 19.4 Fiziksel cihaz sınırı ve kabul adımı

Bu çalışma makinesine bağlı Android telefon ve kurulu AVD yoktur. Bu nedenle Samsung Now Bar/lock-screen/chip görünümü veya uygulama kapalıyken native Stop aksiyonu “cihazda geçti” diye işaretlenmemiştir. Beta/staging aktivasyonundan sonra hızlı kabul:

1. Beta APK'yı Samsung + mümkünse Pixel/API 36 cihaza kur.
2. Sayacı başlat; bildirimin süreyi native olarak akıttığını ve Stop aksiyonunu gösterdiğini kontrol et.
3. Bildirim Merkezi → Bildirim Sağlığı → Canlı sayaç yüzeyi → yenile; standard ve canlı yüzey şartlarının sonucunu oku.
4. Uygulamayı son uygulamalardan kapat; bildirimden Stop yap; uygulamayı açıp oturumun tam bir kez kaydedildiğini doğrula.
5. Samsung ayarı/OEM promotion vermiyorsa bunu hata diye gizleme: standard ongoing notification çalışıyorsa fonksiyonel fallback geçerlidir; Now Bar ayrıca cihaz/firmware/ayar bulgusudur.
