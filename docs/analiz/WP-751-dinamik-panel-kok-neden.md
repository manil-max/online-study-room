# WP-751 — "Dinamik panel" ve "bildirim silinemesin": kök neden soruşturması

> **Tür:** karar belgesi (kod yok) · **Tarih:** 2026-08-22 · **Rol:** hunter
> **Kapsam:** Sahip şikâyeti — (A) sayaç açıkken bildirim silinebiliyor, (B) THY'de görülen
> "dinamik panel" bizde hiç çalışmadı, en az 5 deneme başarısız.
> **Kanıt kuralı:** Bu belgedeki her iddia ya `dosya:satır`, ya koşturulmuş bir komut çıktısı,
> ya da resmî belge URL'sidir. Ölçemediğim her şey **ÖLÇEMEDİM** diye işaretlidir.

---

## 1. Tek cümlelik cevap

**Kökten yanlış olan şey şu:** ürünün onayladığı sayaç paneli baştan sona özel `RemoteViews`
üzerine kurulu, Android'in Live Update / Samsung Now Bar terfisi ise **özel görünüm taşıyan
bildirimi kural gereği reddediyor** — yani altı turdur birbirini dışlayan iki hedefi *aynı tek
bildirimde* tutmaya çalışıyoruz; üstelik bugün bu çelişki bir **kalite kapısıyla kilitlenmiş**
durumda: repo, Live Update kodunun yazılmasını testle **yasaklıyor**.

Bunun altında dört tane daha kök neden var (hepsi ayrı ayrı ölçüldü):

| # | Kök neden | Kanıt |
|---|---|---|
| K1 | **Karşılıklı dışlama:** promotable bildirim `customContentView` taşıyamaz; bizim ana yolumuz sadece o. | Resmî şart + `StudyTimerService.kt:386-394` |
| K2 | **Kapı ölü yolu değil, GELECEK yolu sabitliyor.** Kalite kapısı `setRequestPromotedOngoing(true)` ve `POST_PROMOTED_NOTIFICATIONS` metinlerinin kaynakta **bulunmamasını** şart koşuyor. Altıncı deneme derlense bile `python scripts/test_all.py` kırmızı düşer. | `app/test/core/verified_timer_bridge_contract_test.dart:115,140-141,169` |
| K3 | **Tek gerçek deneme cihazda hiç ölçülmeden, 4 saat içinde kozmetik gerekçeyle geri alındı.** Terfi yüzeyinin (Now Bar/çip/kilit ekranı) çalışıp çalışmadığı **hiç bakılmadı**; o gün makinede telefon da emülatör de yoktu. | `c6110404` (19:52) → `3bdf8bb8` (23:50), aynı gün; audit `NOTIFICATION-SYSTEM-AUDIT-2026-07.md:830` |
| K4 | **Yanlış inanç dondu:** 2026-07-17 tarihli analiz API 36 Live Updates'i "henüz üründe yok" diye eledi ve "Now Bar'da görünme DoD **değil**" yazdı. Sonraki turlar bu cümleyi miras aldı. | `WIDGET-DINAMIK-PANEL-ANALIZ.md:177,451` (silinmiş, `cfc3e50b`'de) |
| K5 | **Soru A bir platform imkânsızlığı, ama hiç böyle adlandırılmadı.** Android 14'ten beri `setOngoing(true)` silinmeyi engellemiyor; biz beş turdur engellemeye çalıştık. | developer.android.com/about/versions/14/behavior-changes-all |

**İyi haber, ve bu belgenin en önemli cümlesi:** bugün zemin hazır. `compileSdk = 36`,
`targetSdk = 36`, `androidx.core 1.18.0` zaten bağımlılık, `NotificationCompat.ProgressStyle` ve
`setRequestPromotedOngoing` o jar'ın **içinde ölçüldü**, ve sahibin Galaxy S23'ü One UI 8.x
(Android 16) alıyor. 2026 Temmuz'unda eksik olan hiçbir şey bugün eksik değil. Eksik olan tek
şey **karar**: özel panelden vazgeçmek.

---

## 2. Arkeoloji — ne denendi, ne bıraktı

🔴 Aşağıdaki hiçbir satır belgeye dayanmıyor; her satır `git show` ile okundu ve bugünkü kodla
karşılaştırıldı.

| # | Deneme | Commit / sürüm | Ne denendi | Neden tutmadı (kanıt) | Geriye ne bıraktı |
|---|---|---|---|---|---|
| 0 | **Taban** WP-42/51 | `0edfeaa2` (beta-v12), `c6334fd0` (v13) | Flutter FGS yerine native `StudyTimerService`; app kapalıyken widget/bildirimden Başlat/Durdur | Deneme değil, omurga. v12'de `START_STICKY` açılış çökme döngüsü yaptı, v13'te `START_NOT_STICKY` ile düzeldi | Bugünkü mimari (`StudyTimerService.kt:129` `START_NOT_STICKY`) |
| 1 | **WP-76 "dinamik panel"** | `a2688ded` (beta-v19) | `timer_notification_expanded.xml`: büyük Chronometer + durum metni + Mola/Durdur, doğrudan FGS PendingIntent | Manifest yalnız `specialUse`, kod `DATA_SYNC` → **Android ≤13'te çökme** (Note20/A51). Ayrıca "canlı panel" OEM'de zaten oluşmuyordu | Expanded layout `0bba715d` ile **silindi**; FGS tip hatası `WP-103`/`4c3e259e` ile dual tipe çevrildi |
| 2 | **WP-80 "standarda geç, terfi umut et"** | `0bba715d` | Custom RemoteViews kaldırıldı; `setUsesChronometer` + `addAction` — "OEM Live/Now Bar terfi eder" hipotezi | Terfi **olmadı**. Olamazdı: Android'de terfi diye bir API o tarihte üründe yoktu (Live Updates = API 36) ve talep edilmiyordu. One UI'da metin/yerleşim şikâyeti geldi | Sarkacın ilk salınımı |
| 3 | **v23 "One UI için custom'a dön"** | `c1b9d9c3` | Tek satır HH:MM:SS + pill düğme, `setUsesChronometer(false)` | WP-80'in hipotezi fiilen terk edildi; ürün görünümü kazandı, terfi yolu kapandı | **Bugünkü `timer_notification.xml` bu** |
| 4 | **WP-137 "bayrakla ikiye böl"** | `1f4f4d62` | Varsayılan standart ongoing; custom yalnız `timer_panel_expanded=true` iken | Bayrak sonradan tersine çevrildi (`useV43CustomPanel()` varsayılanı `true`) ve **Dart tarafı bu anahtarı hiç yazmadı** → dallardan biri ulaşılamaz oldu | **Ölü anahtar** `KEY_PANEL_EXPANDED` (`StudyTimerService.kt:590`) |
| 5 | **WP-204/205 tema-güvenli** | `1d9db60d` | Sabit `#FFFFFFFF` yerine `TextAppearance.Compat.Notification.Title`; eylemler sistem action'ına alındı. Commit mesajı: *"beyaz kronometre açık bildirim temasında görünmez oluyordu"* | Teknik olarak doğruydu ama One UI'da eylemleri ikinci satıra çizince ürün tasarımı bozuldu | 26 dakika sonra WP-206 (`5792d759`) ile **geri alındı** |
| 6 | **WP-266/267 — TEK GERÇEK LIVE UPDATE DENEMESİ** | `c6110404` (beta-v4302) | Tam resmî sözleşme: `POST_PROMOTED_NOTIFICATIONS` manifest izni, `setRequestPromotedOngoing(true)`, `setShortCriticalText(...)`, standart stil + `setUsesChronometer(true)`, ayrı `ic_stat_focus_timer` durum ikonu, `androidx.core:core-ktx:1.18.0`, `canPostPromotedNotifications()` tanısı | **Cihazda hiç ölçülmedi.** Audit'in kendi satırı: *"Bu çalışma makinesine bağlı Android telefon ve kurulu AVD yoktur… Now Bar/lock-screen/chip görünümü … 'cihazda geçti' diye işaretlenmemiştir."* Aynı gün 19:52'de girdi, 23:50'de çıktı | `androidx.core-ktx:1.18.0` bağımlılığı **kaldı** (bugün hâlâ orada, `build.gradle.kts:306`) |
| 7 | **Geri alma** | `3bdf8bb8` (beta-v4303) | v43 paneli geri | CHANGELOG'un kendi ifadesi: *"beta-v4302'de **yanlışlıkla görünen** başlıklı eski/standart kart ile promoted ongoing denemesi kaldırıldı"* — yani terfi denemesi "kaza" sayıldı | Sarkaç tamamlandı |
| 8 | **WP-272 — kararı DONDUR** | `a2884611` | v43 custom panel "ana kontrat" ilan edildi; `test/fixtures/timer_notification_v43_contract.json` içine `"promotedNowBar": "not_requested"` yazıldı; sözleşme testi eklendi | Kusur değil, **karar**. Ama karar bir kapıya çevrildiği için sonraki her denemeyi otomatik reddeder hâle geldi | `verified_timer_bridge_contract_test.dart` |
| 9 | **WP-558 — kalıntı temizliği** | `29b37d7c` | Ölü `EXTRA_PROMOTED_NOW_BAR` / `EXTRA_TIMER_PRESENTATION` silindi; kapı iddiaları **negatife** çevrildi | Doğru bir temizlikti ama yan etkisi K2: kapı artık gelecekteki kodu da yasaklıyor | `isNot(contains(...))` iddiaları |

### 2.1 Sahibin "5 kez denedik" hafızası doğru

Ürün yüzeyine dokunan **altı** ayrı deneme var (1, 2, 3, 4, 5, 6). Sarkaç şu:
custom → standart → custom → bayrak → standart → custom. Her turda **yalnız görünüm** değişti;
**hiçbir turda "terfi gerçekten oldu mu"** cihazda ölçülmedi.

### 2.2 Liderin verdiği grep terimi neden boş döndü (ve niye önemli)

`git log --all -S "requestPromotedOngoing"` **sıfır** sonuç verir. Bu, "hiç denenmedi" demek
değildir: kaynaktaki metin `.setRequestPromotedOngoing(` — yani aranan alt dize büyük `R` ile
başlıyor. Doğru komut:

```
$ git log --all --oneline -S "requestPromotedOngoing"     # kucuk r -> BOS
$ git log --all --oneline -S "RequestPromotedOngoing"     # buyuk R
3e4cba7d docs: tarihsel ve tekrarli md dosyalarini repodan kaldir
3bdf8bb8 fix(beta): restore timer panel and reliable push delivery
c6110404 feat: android canli sayaci standart bildirime tasi
abf031b6 docs: bildirim sistemini adli olarak analiz et
```

🔴 Bu bir metodoloji dersi: bu turda "hiç denenmemiş" sonucuna varmaya bir harf kalmıştı.

---

## 3. Zemin gerçeği (ölçülmüş sayılar)

### 3.1 SDK sürümleri — ÇÖZÜLDÜ

`app/android/app/build.gradle.kts` sayıları `flutter.*` üzerinden alır:

```
app/android/app/build.gradle.kts:118   compileSdk = flutter.compileSdkVersion
app/android/app/build.gradle.kts:132   minSdk     = flutter.minSdkVersion
app/android/app/build.gradle.kts:133   targetSdk  = flutter.targetSdkVersion
```

Gerçek sayı Flutter SDK'sındadır. `app/android/local.properties` → `flutter.sdk=C:\src\flutter`.

`C:\src\flutter\bin\cache\flutter.version.json`:
```json
{ "frameworkVersion": "3.44.2", "channel": "stable", "dartSdkVersion": "3.12.2" }
```

`C:\src\flutter\packages\flutter_tools\gradle\src\main\kotlin\FlutterExtension.kt`:
```kotlin
val compileSdkVersion: Int = 36
val minSdkVersion: Int = 24
val targetSdkVersion: Int = 36
val ndkVersion: String = "28.2.13676358"
```

| Değer | Sayı | Nereden |
|---|---|---|
| **compileSdk** | **36** (Android 16) | `FlutterExtension.kt:23` |
| **targetSdk** | **36** | `FlutterExtension.kt:33` |
| **minSdk** | **24** (Android 7.0) | `FlutterExtension.kt:26` |
| AGP | 9.0.1 | `app/android/settings.gradle.kts` |
| Gradle | 9.1.0 | `gradle-wrapper.properties` |
| Kotlin | 2.3.20 | `settings.gradle.kts` |
| androidx.core | **1.18.0** | `build.gradle.kts:306` (WP-267'den kalma) |
| Kurulu platform | android-33/34/35/**36** (rev 2, `AndroidVersion.ApiLevel=36`) | `C:\Android\Sdk\platforms\android-36\source.properties` |

🔴 **Liderin hipotezinin bu ayağı YANLIŞ.** "compileSdk 36'nın altındaysa API yoktur" şüphesi
haklı bir şüpheydi ama **compileSdk 36'dır**. Live Updates API'si bugün derlenebilir durumda.
Not: `gradlew :app:properties` koşturulmadı (bkz. ÖLÇEMEDİM-3); sayılar Flutter'ın kaynağından
okundu ve projede hiçbir override yok (`grep -rn "compileSdk\|targetSdk\|minSdk"` yalnız
yukarıdaki üç satırı döndürür).

### 3.2 API'ler gerçekten var mı? — jar'lardan ÖLÇÜLDÜ

`javap` ile doğrudan platform jar'ları ve androidx aar'ı okundu:

```
### android-36 (Android 16):
  public static final int FLAG_PROMOTED_ONGOING;
  public boolean hasPromotableCharacteristics();
  public android.app.Notification$Builder setShortCriticalText(java.lang.String);
  public class android.app.Notification$ProgressStyle extends android.app.Notification$Style

### android-35 (Android 15):
  -> setRequestPromotedOngoing/setShortCriticalText YOK
  Error: class not found: android.app.Notification$ProgressStyle

### androidx.core 1.18.0 (aar → classes.jar), NotificationCompat$Builder:
  public androidx.core.app.NotificationCompat$Builder setRequestPromotedOngoing(boolean);
  public androidx.core.app.NotificationCompat$Builder setShortCriticalText(java.lang.String);
  androidx/core/app/NotificationCompat$ProgressStyle.class
  androidx/core/app/NotificationCompat$ProgressStyle$Segment.class
  androidx/core/app/NotificationCompat$ProgressStyle$Point.class
  androidx/core/app/NotificationCompat$ProgressStyle$Api36Impl.class
  (sabit havuzunda: "android.requestPromotedOngoing", "android.shortCriticalText")
```

**Sonuç:** Live Update için gereken hiçbir bağımlılık eksik değil. `androidx.core 1.18.0` zaten
projede — ironik biçimde onu **WP-267 denemesi** eklemişti ve geri almada unutuldu.

⚠️ **Tek gerçek boşluk:** `POST_PROMOTED_NOTIFICATIONS` sabiti kurulu **android-36 rev 2**
platformunda **yok** (`javap -constants android.Manifest$permission` içinde `PROMOTED` geçmiyor;
jar içinde `strings … | grep POST_PROMOTED` boş). Resmî belge bu izni **şart koşuyor**. Yorum:
izin muhtemelen Android 16 QPR / daha yüksek platform revizyonunda tanımlı. Manifest'te
tanınmayan bir `uses-permission` **derlemeyi kırmaz** (yok sayılır), yani engel değil; ama
"terfi çalışacak" demeden önce SDK Platform 36'nın daha yüksek revizyonu (veya API 37) kurulup
doğrulanmalı. → ÖLÇEMEDİM-1.

### 3.3 Test cihazı: Galaxy S23 bugün nerede

- S23 serisi **Android 13 / One UI 5.1** ile çıktı ve Samsung **4 büyük OS yükseltmesi** sözü verdi.
- **One UI 8 (Android 16)** stable yayını S23 için **29 Eylül 2025**'te başladı, 21 Ekim'de
  duraklatıldı, sonra devam etti.
- Ağustos 2026 itibarıyla seri **One UI 8.5 (Android 16 QPR2)** kullanıyor; son büyük yükseltme
  One UI 9.0 (Android 17) olacak.

**Sonuç: sahibin S23'ü Android 16 üzerinde, yani Live Updates ve Now Bar'ın çalıştığı zeminde.**
Bu, "hedef cihaz eski, o yüzden olmadı" mazeretini kapatır.

Kaynaklar: [9to5Google — One UI 8 S23 yayını](https://9to5google.com/2025/09/29/samsung-rolls-out-one-ui-8-android-16-update-to-galaxy-s23-tab-s10-a55-more/) ·
[Android Authority — yayın devam](https://www.androidauthority.com/samsung-galaxy-s23-one-ui-8-update-resumes-3610393/) ·
[SamMobile — S23'ün son büyük güncellemesi One UI 9.0](https://www.sammobile.com/news/galaxy-s23-series-receive-one-ui-9-0-last-major-update-samsung-confirms/)

⚠️ Bunlar basın kaynağıdır; **cihazın gerçek sürümü ölçülmedi** (telefon bağlı değil). Sahip
`Ayarlar > Telefon hakkında > Yazılım bilgileri`'nden One UI ve Android sürümünü tek ekran
görüntüsüyle kesinleştirmeli. → ÖLÇEMEDİM-2.

### 3.4 Now Bar'a ne besliyor?

- One UI 7'de **Live Notifications / Now Bar yalnız Samsung'un (ve birkaç Google) uygulamasına**
  açıktı — üçüncü taraf için belgelenmiş bir "Now Bar SDK" **yok**.
- One UI 8'de Samsung Now Bar'ı **Android 16'nın Live Updates API'sine bağladı**; yani üçüncü
  taraf uygulamalar Now Bar'a **kendi API'siyle değil, Android'in standart promoted ongoing
  bildirimiyle** giriyor. One UI 8 beta'sında bu `Geliştirici seçenekleri > Live notifications
  for all apps` bayrağının arkasındaydı.

**Ürün cümlesi bundan çıkar:** "Now Bar entegrasyonu yapacağız" diye bir iş yoktur. Yapılacak iş
**Android'in resmî Live Update sözleşmesine uymaktır**; Now Bar bunun Samsung'daki görüntüsüdür.

Kaynaklar: [9to5Google — Samsung üçüncü taraf Now Bar'ı doğruladı](https://9to5google.com/2025/07/09/samsung-one-ui-8-now-bar-third-party-apps/) ·
[Android Authority — One UI 8 Live Updates desteği](https://www.androidauthority.com/one-ui-8-live-updates-support-3573794/) ·
[Android Police — One UI 8 Now Bar genişlemesi](https://www.androidpolice.com/now-bar-cover-screen-expanded-app-support-one-ui-8/)

⚠️ **Resmî Samsung geliştirici belgesi bulunamadı.** Bulunanların hepsi basın. Bu yüzden
"Now Bar'da görünecek" bir **DoD olamaz**; DoD "Android Live Update sözleşmesine uygunuz + durum
çubuğu çipi çalışıyor" olmalı, Now Bar bonus olarak cihazda kaydedilmeli. → ÖLÇEMEDİM-4.

---

## 4. SORU A — "Sayaç açıkken bildirim silinemesin"

### 4.1 Cevap: HAYIR. Bu **imkânsız**. Beş turdur var olmayan bir kapıyı zorluyoruz.

Android 14 (API 34) resmî davranış değişikliği belgesinden **birebir**:

> "If your app shows non-dismissable foreground notifications to users, Android 14 has changed
> the behavior to allow users to dismiss such notifications. This change applies to apps that
> prevent users from dismissing foreground notifications by setting `Notification.FLAG_ONGOING_EVENT`
> through `Notification.Builder#setOngoing(true)` or `NotificationCompat.Builder#setOngoing(true)`.
> The behavior of `FLAG_ONGOING_EVENT` has changed to make such notifications actually dismissable
> by the user."

Kaynak: <https://developer.android.com/about/versions/14/behavior-changes-all>

**Hâlâ silinemediği tek iki durum:**
- Telefon **kilitliyken**
- Kullanıcı **"Tümünü temizle"** derse (kazara silmeye karşı)

**Kuralın hiç uygulanmadığı dört istisna:**
- `CallStyle` bildirimleri
- Kurumsal cihaz yöneticisi (DPC) paketleri
- **Medya** bildirimleri
- Varsayılan Search Selector paketi

Bir çalışma sayacı bu dörtten hiçbiri **değildir**. `CallStyle` kullanmak, olmayan bir aramayı
taklit etmektir: yanlış ikon, yanlış ses/öncelik davranışı, Play politikası riski ve One UI'da
"gelen arama" görünümü. **Öneri: asla.** MediaStyle da aynı sınıf sahtekârlıktır (medya oturumu
yoksa Now Playing/ses tuşları yanlış davranır).

`targetSdk = 36` olduğu için bu davranış **bize tam olarak uygulanıyor**; `targetSdk` düşürerek
kaçmak da yok (Play zaten API 36 zorunluluğuna gidiyor — `docs/KALITE-PROGRAMI.md:165`).

### 4.2 Bugün kod ne yapıyor (ölçüldü)

- Bildirim `setOngoing(true)` ile kuruluyor (`StudyTimerService.kt:382`) — Android 14+'ta bu
  artık **yalnız sıralama/görsel** anlamı taşır, silinmeyi engellemez.
- `setDeleteIntent` **hiçbir yerde yok**: `grep -rn "setDeleteIntent" android/ lib/` → **boş**.
  Yani kullanıcı bildirimi kaydırdığında uygulama bunu **öğrenmiyor bile**.
- Bildirimi periyodik yeniden gönderen hiçbir kod yok: `notify(NOTIFICATION_ID, …)` yalnız
  `handleStart` içinde (`StudyTimerService.kt:182`).

**Sonuç — kullanıcının yaşadığı gerçek:** bildirimi kaydırıp siliyor → sayaç **çalışmaya devam
ediyor**, ama artık ne görünüyor ne de durdurulabiliyor; uygulamayı açana kadar hiçbir yerden
geri gelmiyor. Şikâyetin gerçek acısı "silinebiliyor" değil, **"silinince ortada kalıyorum"**.

### 4.3 Doğru tasarım (soruyu değiştir)

Doğru soru "nasıl engelleriz" değil, **"kullanıcı silerse ne olmalı ve nasıl geri getirir"**.
Önerilen üç katman:

1. **Sil = durdur DEĞİL.** Sayaç çalışmaya devam eder (veri kaybı yok). `setDeleteIntent` ile
   silinme **kaydedilir**; resmî Live Update rehberi de bunu söylüyor:
   > "Don't repost Live Updates that the user dismissed. Use `setDeleteIntent` to detect dismissed updates."
   Yani silineni **inatla geri basmak yasak** — kullanıcı izni geri çeker.
2. **Geri getirme yolları görünür olsun.** Ana ekran widget'ı (zaten var, `TimerWidgets`), ve
   **yeni: Hızlı Ayarlar kutucuğu (`TileService`)** — kullanıcı bildirim gölgesinden tek dokunuşla
   sayacı geri çağırır. Bu, "silinemez bildirim"in meşru muadilidir.
3. **Uygulama içinde dürüst tek cümle.** Sayaç kartında, bildirim silinmişken:
   *"Bildirimi kapattın; sayaç arka planda çalışıyor. Geri getir."* + düğme. Android 14+'ta
   bildirimin silinebilir olduğunu **gizlemek** yerine söylemek — WP-598/WP-592'nin
   ("kullanıcıya söyle") çizgisinin devamı.

🔴 **Bonus, ve K1 ile birleşen nokta:** Live Update olarak **terfi edilmiş** bir bildirim durum
çubuğunda **çip** olarak durur. Kullanıcı gölgedeki kartı silse bile çip yüzeyi ayrı bir
görünürlük katmanıdır. Yani Soru B'nin çözümü, Soru A'nın acısını da büyük ölçüde dindirir.
**Liderin hipotezi — "aynı yüzeyin iki yüzü" — DOĞRULANDI**, ama sandığından farklı bir yönden:
ikisi de "tek RemoteViews bildirimine her şeyi yükledik" kararından doğuyor.

---

## 5. SORU B — "Dinamik panel" (THY'de görülen)

### 5.1 THY ne yapıyor?

Belirtiler birebir Android 16 Live Update tarifidir: uçuş **adımları sürekli görünüyor**
(= `ProgressStyle` segment/point'leri), **basınca boarding kartı açılıyor** (= `contentIntent`),
ve şerit sürekli orada (= promoted ongoing). Samsung'da bu tam olarak **Now Bar** kutusunda
çizilir, çünkü One UI 8 Now Bar'ı Android'in Live Updates API'sine bağladı (§3.4).

Yani üç ihtimalden **(i) Android 16 Live Update (`ProgressStyle` + promoted ongoing)** doğru
cevap; (ii) Samsung Now Bar bunun **görüntüsüdür**, ayrı bir SDK değildir; (iii) özel
`RemoteViews` **olamaz**, çünkü özel görünüm taşıyan bildirim terfi edemez.

⚠️ THY APK'sının hedef SDK'sı **ölçülmedi** (APK elde yok, Play sayfası açılmadı). Belirti
eşleşmesi güçlü ama teknik kanıt değil. → ÖLÇEMEDİM-5.

### 5.2 Bizim bugünkü bildirimimiz hangisi? — (iii)

`StudyTimerService.kt:386-394`:

```kotlin
if (useV43CustomPanel()) {
    val custom = buildRunningRemoteViews(startedAtMs, isBreak)
    builder
        .setContentTitle("")            // ← Live Update contentTitle ŞART koşar
        .setContentText("")
        .setUsesChronometer(false)
        .setShowWhen(false)
        .setStyle(NotificationCompat.DecoratedCustomViewStyle())
        .setCustomContentView(custom)   // ← Live Update bunu YASAKLAR
        .setCustomBigContentView(custom)
}
```

Ve `useV43CustomPanel()` = `prefs().getBoolean(KEY_PANEL_EXPANDED, true)` — anahtarı yazan kod
**repoda yok** (§8), yani **daima bu dal koşar**. Standart fallback dalı ulaşılamaz.

### 5.3 Live Update için TAM koşul listesi (resmî, birebir)

Kaynak: <https://developer.android.com/develop/ui/views/notifications/live-update>

| # | Şart | Bizde bugün | Fark |
|---|---|---|---|
| 1 | Stil: **Standard**, `BigTextStyle`, `CallStyle`, `ProgressStyle` veya `MetricStyle` | `DecoratedCustomViewStyle` | ❌ |
| 2 | *"Must **NOT** have any `customContentView` set (no `RemoteViews`)"* | `setCustomContentView` + `setCustomBigContentView` | ❌ **ana blokaj** |
| 3 | *"Must have `contentTitle` set"* | `setContentTitle("")` | ❌ |
| 4 | *"Must be `ongoing` (`FLAG_ONGOING_EVENT`)"* | `setOngoing(true)` | ✅ |
| 5 | Manifest izni `android.permission.POST_PROMOTED_NOTIFICATIONS` | yok (WP-267'de vardı, geri alındı) | ❌ |
| 6 | `NotificationCompat.Builder#setRequestPromotedOngoing(true)` | yok | ❌ |
| 7 | *"Must NOT be the summary of a group"* | grup yok | ✅ |
| 8 | *"Must NOT `setColorized` to TRUE"* | çağrılmıyor | ✅ |
| 9 | Kanal `IMPORTANCE_MIN` **olmamalı** | `IMPORTANCE_DEFAULT` (`StudyTimerService.kt:550`) | ✅ |
| 10 | Kullanıcı ayarı: sistem/kullanıcı terfiyi geri alabilir (`canPostPromotedNotifications()`) | ölçülmüyor | ⚠️ tanı gerekir |
| 11 | Yüzeyler: *"top of the notification drawer and the lock screen, and as a chip in the status bar"* | — | hedef |
| 12 | Çip metni: `setShortCriticalText` (**maks. 96dp**, sığmazsa hiç yazılmaz) veya `setWhen` | yok | ekle |

Ayrıca yaşam döngüsü şartı: *"A Live Update must represent an activity that is actively in
progress, with a distinct start and end."* — çalışma sayacı bunun ders kitabı örneğidir.

**Kritik okuma:** 2, 3 ve 1 aynı kararla düzelir — **özel paneli bırakmak**. Bu bir yama değil,
ürün kararıdır ve sahibinin vermesi gerekir. Beş turdur yapılmayan tek şey bu kararın açıkça
sorulmasıydı.

### 5.4 Flutter katmanı engel mi? — HAYIR (ölçüldü)

- Sayaç bildirimini **saf Kotlin** kuruyor. `timer_notification_service.dart`'ın kendi dosya
  başlığı: *"Sayaç bildirimini **Dart üretmez**… metnini ve kronometresini Kotlin tarafı kurar"*;
  paket yalnız üç iş yapar (aksiyon akışı, izin, eski bildirimi iptal).
- `flutter_local_notifications ^22.0.1` bu yolda **hiç kullanılmıyor** → paketin Live Update
  desteği alakasız.
- `androidx.core 1.18.0` `NotificationCompat.ProgressStyle` + `setRequestPromotedOngoing` sağlıyor
  (§3.2'de jar'dan ölçüldü) → **ham platform API'sine inmeye bile gerek yok**, minSdk 24 ile
  compat yolu güvenli.

Yani "önceki denemeler Flutter yüzünden tıkandı" hipotezi **YANLIŞ**. Tıkanma tek yerdeydi:
`RemoteViews` ürün kararı + kapı.

### 5.5 Stopwatch mi ProgressStyle mı?

- **Pomodoro / geri sayım:** `ProgressStyle` birebir uyar — segmentler = çalışma/mola turları,
  point = faz sınırı. THY'nin "adımlar" görüntüsünün aynısı.
- **Açık uçlu kronometre (stopwatch):** üst sınır yok → `ProgressStyle` yerine **Standard stil +
  `setWhen(startedAt)` + `setUsesChronometer(true)`** kullanılır; çipte akan süre `setWhen` ile
  gelir. Bu da listedeki geçerli stildir (1. satır: "Standard Style").

---

## 6. YOL HARİTASI

Sıra önemlidir. **WP-A yapılmadan WP-B yazılamaz** — çünkü kapı reddeder.

### WP-A — Kapıyı aç: yasağı "iki yol da geçerli"ye çevir  🟢 cihazsız
- **Ne yapar:** `verified_timer_bridge_contract_test.dart`'taki negatif iddiaları
  (`:115` `POST_PROMOTED_NOTIFICATIONS`, `:140` `setRequestPromotedOngoing`, `:141`
  `hasPromotableCharacteristics`) ve fixture'daki `"promotedNowBar": "not_requested"` satırını
  **kaldırır**; yerine "sunum yolu tek ve tutarlıdır" iddiası koyar.
- **Dosyalar:** `app/test/core/verified_timer_bridge_contract_test.dart`,
  `app/test/fixtures/timer_notification_v43_contract.json`
- **Nasıl kanıtlanır:** kapı önce/sonra koşar; kaldırılan her iddia için "bu iddia neyi
  koruyordu" tek cümleyle yazılır. Sabotaj: iddia geri kondu → yeni kod kırmızı.
- **Not:** bu WP tek başına hiçbir davranış değiştirmez; yalnız altıncı denemenin önündeki
  otomatik reddi kaldırır.

### WP-B — Ölü anahtarı gerçek bir ürün ayarına çevir  🟢 cihazsız
- **Ne yapar:** `timer_panel_expanded` bugün hiçbir yerden yazılmıyor (§8) → DoD'nin "ölü anahtar
  yok" kuralını ihlal ediyor. Ayarlar'a **"Sayaç bildirimi görünümü: Sade (canlı yüzey) / Zengin
  panel"** seçeneği eklenir ve anahtar Dart'tan yazılır.
- **Dosyalar:** `app/lib/features/settings/**`, `app/lib/core/notifications/**` (Dart→prefs),
  `StudyTimerService.kt` (yalnız okuma tarafı zaten var)
- **Nasıl kanıtlanır:** ayar değişince prefs anahtarının yazıldığını ölçen test + native tarafın
  o anahtarı okuduğunu gösteren mevcut JVM testi. Sabotaj: yazıcı kaldırıldı → kırmızı.
- **Neden bu sırada:** WP-C'yi **geri dönüşü olan** bir deney yapar. Sahip beğenmezse tek
  dokunuşla eski panele döner; altıncı "geri alma commit'i" gerekmez.

### WP-C — Live Update sözleşmesine uy (asıl iş)  🔴 cihaz gerekir
- **Ne yapar:** "Sade" modda bildirimi §5.3 tablosuna göre kurar:
  `contentTitle` dolu · custom view **yok** · Standard stil (stopwatch) veya `ProgressStyle`
  (pomodoro/geri sayım) · `setRequestPromotedOngoing(true)` · `setShortCriticalText(...)` ·
  `setWhen` + `setUsesChronometer(true)` · manifest `POST_PROMOTED_NOTIFICATIONS` ·
  ayrı monokrom `ic_stat_focus_timer` durum ikonu (bugün `setSmallIcon(R.mipmap.ic_launcher)` —
  durum çubuğu ikonu olarak yanlış tür).
- **Dosyalar:** `app/android/app/src/main/kotlin/.../timer/StudyTimerService.kt`,
  `app/android/app/src/main/AndroidManifest.xml`,
  `app/android/app/src/main/res/drawable/ic_stat_focus_timer.xml` (`c6110404`'ten geri alınabilir)
- **Cihazsız kanıtlanabilir kısım:** JVM/sözleşme testi — "sade modda üretilen `Notification`
  nesnesi `customContentView == null`, `extras` içinde `android.requestPromotedOngoing == true`,
  `contentTitle` boş değil, kanal importance ≥ DEFAULT". Bu **davranış** testidir, kaynak metni
  taraması değil (§ hunter kuralı). `Notification.hasPromotableCharacteristics()` (API 36) bir
  Robolectric/enstrümantasyon testinde doğrudan çağrılabilir.
- **Cihazda kanıtlanması ŞART olan kısım:** çipin görünmesi, Now Bar, kilit ekranı, AOD.

### WP-D — Silinme dürüstlüğü (Soru A)  🟡 kısmen cihazsız
- **Ne yapar:** `setDeleteIntent` ekler (silinme kaydedilir, **yeniden basılmaz**); sayaç kartına
  "bildirim kapalı, geri getir" satırı; **Hızlı Ayarlar kutucuğu (`TileService`)**.
- **Dosyalar:** `StudyTimerService.kt`, yeni `.../timer/TimerTileService.kt`,
  `AndroidManifest.xml`, `app/lib/features/classroom/widgets/study_timer_card.dart`
- **Cihazsız kanıt:** delete intent'in prefs'e "dismissed" yazdığını ve kartın o bayrağı okuduğunu
  ölçen test (bu tam olarak "kullanıcının GÖRDÜĞÜ satırı ölç" kuralıdır).
- **Cihazda:** kutucuğun gölgeden eklenip çalışması.

### WP-E — Tema güvenliği (zengin panel kalırsa)  🟢 cihazsız
- `timer_notification.xml` bugün `#FFFFFFFF` kronometre + `#26FFFFFF` pill + `#FFFFD8A6` metin
  taşıyor; `values-night/` var ama layout literal hex kullanıyor → **açık temada okunmaz**.
  WP-205 bunu düzeltmişti (`1d9db60d`), WP-206 26 dakika sonra geri aldı (`5792d759`). Bugün
  geri alınmış hâl canlı.
- Renkler `values`/`values-night` çiftinden gelen kaynaklara bağlanır; kapı literal hex'i yasaklar.

### Sahibe düşen cihaz işi (S23) — net liste

| Adım | Ne yapacak | Neden |
|---|---|---|
| D0 | `Ayarlar > Telefon hakkında > Yazılım bilgileri` ekran görüntüsü | One UI + Android sürümü kesinleşsin (ÖLÇEMEDİM-2) |
| D1 | `Ayarlar > Geliştirici seçenekleri`'nde **"Live notifications for all apps"** var mı, bak | One UI 8'de bayrak arkasındaydı; stable'da yerini bilmiyoruz (ÖLÇEMEDİM-4) |
| D2 | USB hata ayıklama açık + kabloyla bağla, tek komut: `adb shell dumpsys notification --noredact \| findstr /i promoted` | Terfi gerçekten verildi mi — **tek gerçek ölçüm** |
| D3 | WP-C build'i kurup sayacı başlat; **durum çubuğu çipi**, **kilit ekranı**, **Now Bar** için üç ekran görüntüsü | Kabul kanıtı |
| D4 | Bildirimi kaydırıp sil, sonra Hızlı Ayarlar kutucuğuyla geri getir | WP-D kabul kanıtı |

---

## 7. YAPMAYIN listesi (altıncı başarısız denemeyi önleyen maddeler)

1. **Özel `RemoteViews` ile terfi denemeyin.** Resmî şart: *"Must NOT have any `customContentView`
   set (no RemoteViews)"*. "Belki One UI yine de gösterir" bir hipotez değil, üç turdur
   yanlışlanmış bir umuttur.
2. **`CallStyle` veya `MediaStyle` ile silinmezlik satın almayın.** Çalışır ama yalandır:
   yanlış ikon/ses/öncelik, Play politikası riski, One UI'da "arama geldi" görünümü.
3. **Silinen bildirimi yeniden basmayın.** Resmî rehber açıkça yasaklıyor; kullanıcı izni geri
   çeker ve o noktadan sonra hiçbir yüzey kalmaz.
4. **Görünümü kabul ölçütü yapmadan tur açmayın.** Beş turun üçü, kod doğruyken görünüm
   beğenilmediği için geri alındı. Sahibin memory kuralı: *görsel işte önce parametrik önizleme*.
   WP-C'ye başlamadan **iki ekran taslağı** (sade vs zengin) sahibe gösterilmeli.
5. **Cihaz ölçümü olmadan "terfi çalışıyor" yazmayın.** `c6110404` tam da bunu yaptı: kod
   doğruydu, hiç ölçülmedi, 4 saat sonra silindi.
6. **Terfiyi tek bir commit'te panel değişikliğiyle birlikte yapmayın.** WP-76'nın dersi: bildirim
   UI değişimi + FGS/manifest değişimi aynı turda = ≤13 çökmesi. Ayrı WP, ayrı commit.
7. **`targetSdk`'yi düşürerek Android 14 davranışından kaçmayın.** Play, effective target API 36
   istiyor (`docs/KALITE-PROGRAMI.md:165`).
8. **"Now Bar'da görünecek"i DoD yapmayın.** Samsung'un üçüncü taraf Now Bar'ı için **resmî
   geliştirici belgesi bulunamadı**. DoD = Android Live Update uyumu + durum çubuğu çipi; Now Bar
   cihazda kaydedilen bir bulgudur, vaat değil.
9. **Negatif kaynak-metin iddiası yazmayın.** `isNot(contains('setRequestPromotedOngoing'))` tipi
   bir kapı, ölü kodu değil **geleceği** dondurur. Bu repoda tam olarak bu oldu (WP-558 notu bunu
   bir kez zaten "ölü kodu kapı sabitliyor" diye yakalamıştı; ters yönü kaçtı).

---

## 8. Ölü kod / ölü anahtar envanteri

`grep -rn "PROMOTED_NOW_BAR\|RequestPromotedOngoing\|ProgressStyle\|POST_PROMOTED" app/ supabase tooling scripts docs` **tam çıktısı**:

```
app/test/core/verified_timer_bridge_contract_test.dart:115:    expect(manifest, isNot(contains('POST_PROMOTED_NOTIFICATIONS')));
app/test/core/verified_timer_bridge_contract_test.dart:169:    expect(service, isNot(contains('EXTRA_PROMOTED_NOW_BAR')));
```

| Kalıntı | Yer | Durum | Karar |
|---|---|---|---|
| `EXTRA_PROMOTED_NOW_BAR`, `EXTRA_TIMER_PRESENTATION` | üretim kodunda **yok** | WP-558 (`29b37d7c`) sildi — temizlik doğru yapılmış | — |
| `isNot(contains('EXTRA_PROMOTED_NOW_BAR'))` | `verified_timer_bridge_contract_test.dart:169` | Zararsız (sabit adı geri gelmeyecek) | Bırakılabilir |
| `isNot(contains('POST_PROMOTED_NOTIFICATIONS'))` | `…:115` | 🔴 **Geleceği bloke ediyor** | **WP-A'da kaldır** |
| `isNot(contains('.setRequestPromotedOngoing(true)'))` | `…:140` | 🔴 **Geleceği bloke ediyor** | **WP-A'da kaldır** |
| `isNot(contains('hasPromotableCharacteristics'))` | `…:141` | 🔴 **Geleceği bloke ediyor** | **WP-A'da kaldır** |
| `"promotedNowBar": "not_requested"` | `app/test/fixtures/timer_notification_v43_contract.json:10` | 🔴 Kararı fixture'a çakmış | **WP-A'da güncelle** |
| `KEY_PANEL_EXPANDED` / `flutter.timer_panel_expanded` | `StudyTimerService.kt:590`, okunuş `:449` | 🔴 **ÖLÜ ANAHTAR** — repo genelinde yazan tek satır yok; DoD "ölü anahtar yok" ihlali. `docs/V58-TEKNIK-ANALIZ-RAPORU.md:740` bunu 2026-08 başında zaten bildirmiş, kapanmamış | **WP-B'de gerçek ayara bağla** (silme — asıl kaçış valfi bu) |
| `androidx.core:core-ktx:1.18.0` | `build.gradle.kts:306` | WP-267 denemesinden **kalmış**, geri almada unutulmuş; bugün kapı bu sürümü şart koşuyor (`…test.dart:114`) | **Tut** — WP-C'nin ihtiyacı bu |
| `drawable/ic_stat_focus_timer.xml` | silinmiş (`3bdf8bb8`) | Monokrom durum ikonu; bugün `setSmallIcon(R.mipmap.ic_launcher)` kullanılıyor (yanlış tür) | **WP-C'de `c6110404`'ten geri getir** |
| `timer_notification_expanded.xml` | silinmiş (`0bba715d`) | WP-76'nın Mola/Durdur paneli | Geri getirmeyin (§7.1) |
| `docs/widget-panel/GECMIS-DENEME-OTOPSISI.md` | repodan silinmiş (`65a1e2a4`) | Aynı sorunun 2026-07 otopsisi; sonuç cümlesi *"custom RemoteViews ↔ standard chronometer arasında sarkaç"* | Bu belge onun yerini alır |
| `docs/NOTIFICATION-SYSTEM-AUDIT-2026-07.md` | repodan silinmiş (`65a1e2a4`) | 836 satır; `:830` "cihaz/AVD yok" itirafı burada | Alıntılar bu belgede |

---

## 9. YALANLADIĞIM BELGELER

| Belge | Yazan | Bugünkü gerçek |
|---|---|---|
| `WIDGET-DINAMIK-PANEL-ANALIZ.md:177` (silinmiş) | *"MediaStyle / ProgressStyle (API 36 Live Updates) — Sürüm/OEM kısıtlı; **henüz üründe yok**"* | Yanlıştı. Android 16 Haziran 2025'te çıktı; S23 Eylül 2025'te aldı. Belge Temmuz 2026'da yazıldı |
| `WIDGET-DINAMIK-PANEL-ANALIZ.md:451` (silinmiş) | *"Now Bar'da görünme DoD **değil** (P2 bonus)"* | Kısmen hâlâ doğru (Now Bar vaat edilemez) ama **Live Update uyumu** artık pekâlâ DoD olabilir |
| `docs/KALITE-PROGRAMI.md:178` (WP-272) | *"promoted/Now Bar yolunu stable davranışı değiştirmeyen **deney** olarak ayır"* | "Deney olarak ayrılmadı"; **testle yasaklandı**. Deney ≠ yasak |
| `StudyTimerService.kt:373-375` yorumu | *"`timer_panel_expanded` yalnız OEM/custom-layout sorunu için **kaçış valfidir**"* | Valf **yok**: anahtarı yazan hiçbir kod yok, daima `true` |
| `NOTIFICATION-SYSTEM-AUDIT-2026-07.md:49` (silinmiş) | *"Özel `RemoteViews` varsayılanını kaldır… uygun Android sürümünde promoted ongoing iste"* | 🔴 **Bu tavsiye DOĞRUYDU ve uygulandı; sonra geri alındı.** Bir yıl önce doğru cevap yazılmıştı |

---

## 10. ÖLÇEMEDİM

| # | Ne | Neden | Kapatmak için ne gerek |
|---|---|---|---|
| 1 | `POST_PROMOTED_NOTIFICATIONS` izninin gerçekten hangi API'de tanımlı olduğu | Kurulu **android-36 rev 2** platformunda sabit **yok** (jar'da `strings \| grep POST_PROMOTED` boş); resmî belge şart koşuyor | SDK Platform 36'nın daha yüksek revizyonu veya API 37 kurulup `javap`/`aapt2` ile tekrar bakmak |
| 2 | Sahibin S23'ünün gerçek Android/One UI sürümü | Telefon bağlı değil: `adb devices` → **boş liste** | Sahip: `Ayarlar > Telefon hakkında > Yazılım bilgileri` ekran görüntüsü |
| 3 | `gradlew :app:properties` ile derlenmiş gerçek `compileSdk` | Paylaşılan çalışma dizininde Gradle koşturmak başka lane'in `flutter test`/build kilidini asabilir (`AGENTS.md §1.5`) | Lider tek merkezden `cd app/android && ./gradlew :app:properties \| findstr Sdk` koşturur. Beklenen: 36/36/24 |
| 4 | One UI 8.x **stable**'da üçüncü taraf Live Update'in gerçekten Now Bar'a düşüp düşmediği | Resmî Samsung geliştirici belgesi **bulunamadı**; eldeki her şey basın. Cihaz da yok | Cihazda D1+D3 adımları |
| 5 | THY uygulamasının gerçekten `ProgressStyle` kullandığı | APK/Play sayfası incelenmedi; yalnız belirti eşleşmesi var | THY APK'sında `dumpsys notification` ya da manifest incelemesi |
| 6 | Kapının Live Update kodu yazılınca gerçekten kırmızı düştüğü | Sabotaj `StudyTimerService.kt`'ye geçici yazmayı gerektirir; o dosya bu WP'nin SAHİP yolu **değil** ve dizin paylaşımlı | Lider WP-A'da: önce `.setRequestPromotedOngoing(true)` satırını ekle, `flutter test test/core/verified_timer_bridge_contract_test.dart` → **kırmızı** çıktısını sakla, sonra kaldır |
| 7 | Bugünkü panelin açık temada gerçekten okunmaz olduğu | Kod düzeyinde kesin (literal `#FFFFFFFF`, `values-night` kullanılmıyor); ekranda görülmedi | Cihazda açık tema + bildirim gölgesi ekran görüntüsü |
| 8 | Android 16 davranışının emülatörde ölçülmesi | Kurulu system image yalnız **android-33**; `emulator -list-avds` → `wp516_api33`. Android 16 imajı yok | `sdkmanager "system-images;android-36;google_apis_playstore;x86_64"` (~1.5 GB indirme) + yeni AVD |

---

## 11. Sahibe tek paragraf

Dinamik panel beş turdur çalışmadı çünkü uygulamanın onayladığı **güzel** sayaç paneli, Android'in
**canlı yüzey** kuralıyla aynı anda var olamıyor: Android, kendi çizdiği bildirimleri durum
çubuğuna/Now Bar'a çıkarıyor, bizim kendi çizdiğimizi çıkarmıyor. Her turda ya güzeli seçtik ve
canlı yüzeyi kaybettik, ya tersi; bir kere doğrusunu yaptık ama telefonda hiç bakmadan dört saat
sonra geri aldık. Bugün altyapı tamam (Android 16 hedefi, gerekli kütüphane zaten kurulu, S23
Android 16'da) — tek gereken **karar**: sayaç bildiriminin görünümünü Android'e bırakmak.
"Sayaç açıkken bildirim silinmesin" ise Android 14'ten beri **mümkün değil**; onu engellemeye
çalışmayı bırakıp "silinirse ne olacak, nasıl geri gelecek"i çözmek gerekiyor — ve canlı yüzeye
geçmek zaten o acıyı büyük ölçüde bitiriyor.
