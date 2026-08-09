# WP-603 — İnternet yokken uygulama açılmıyor (teşhis + düzeltme)

**Şikâyet (proje sahibi, 2026-08-09, metroda):**
> "İnternete sahip olmadığımda uygulama **20 saniye boyunca 'yükleniyor'** diye
> durdu durdu durdu, **açılmadı**."

Bu bir konfor sorunu değil: uygulamanın çekirdek işi çalışma sayacı, çalışılan
yerlerin çoğu (metro, kütüphane, uçak) internetsiz. Açılmayan uygulama = ürünün
kendisi yok.

Aşağıdaki her iddia **koddan** çıkarıldı, tahminden değil. Paket satırları
`~/AppData/Local/Pub/Cache/hosted/pub.dev/...` altındaki kilitli sürümlerdir.

---

## 1. Açılış yolunun haritası — ilk kare hızlı çiziliyor

`runApp`'ten önce beklenen hiçbir şey ağ istemiyor:

| Adım | Yer | Ağ? |
|---|---|---|
| `initializeDateFormatting`, font lisansları, build manifest | `app/lib/main.dart:51-68` | hayır |
| `loadSystemLocalizations` | `app/lib/main.dart:72` | hayır |
| `TimerNotificationService.initialize`, `HomeWidget` | `app/lib/main.dart:98-101` | hayır |
| `Supabase.initialize` | `app/lib/main.dart:109-121` | **hayır** (aşağıya bak) |
| `SharedPreferences`, `ObservabilityService`, FCM bootstrap | `app/lib/main.dart:124-129` | hayır (yerel/platform kanalı) |
| `DeviceTimezone`, `AlarmNotificationService`, alarm uzlaştırma | `app/lib/main.dart:132-142` | hayır |

`Supabase.initialize` neden bloklamıyor:

* `supabase_flutter-2.15.0/lib/src/supabase.dart:141-153` — `initialize` yalnız
  `supabaseAuth.initialize()`u **bekler**; oturum tazeleyen `recoverSession()`
  bir `CancelableOperation`a sarılır ve **beklenmez**.
* `supabase_flutter-2.15.0/lib/src/supabase_auth.dart:99-112` — beklenen kısım
  diskteki oturumu `setInitialSession` ile belleğe koyar. `gotrue`da bu çağrı
  yalnız `_currentSession`ı atar (`gotrue-2.22.0/lib/src/gotrue_client.dart:1126-1136`),
  ağa gitmez.

**Sonuç (Soru 1):** ilk kare hızlı çiziliyor. Kullanıcının 20 saniye boyunca
gördüğü şey açılış ekranı değil, **`AuthGate`in yükleme çemberi**
(`app/lib/features/auth/auth_gate.dart:80-82`).

---

## 2. 20 saniye tam olarak nerede geçiyor

Çember `authStateProvider`ın ilk olayını bekler. O olayı üreten zincir:

1. **İlk olay ağa bağlı.**
   `app/lib/data/repositories/supabase/supabase_auth_repository.dart:87-98` —
   `_sessionProfiles()` ilk `yield`den **önce** `_profileFor(currentSession)`
   çağırır; `_profileFor` da `profiles` satırını sunucudan çeker
   (aynı dosya, `:158-179`). Yani oturumu olan kullanıcı için akışın ilk sözü
   bir HTTP turunun arkasındadır.

2. **İstek gövdeye gelmeden önce token tazelenir.**
   `supabase-2.13.0/lib/src/supabase_client.dart:153` her REST isteğini
   `AuthHttpClient` ile sarar. `AuthHttpClient.send` gövdeyi göndermeden önce
   `await _getAccessToken()` der (`supabase-2.13.0/lib/src/auth_http_client.dart:12`).
   Oturumun süresi dolmuşsa orada `refreshSession()` beklenir
   (`supabase_client.dart:253-255`).

3. **Tazeleme çevrimdışıyken susmuyor, ~10 saniye deniyor.**
   `gotrue-2.22.0/lib/src/fetch.dart:43-46` — `Response` olmayan her hata
   (yani her ağ hatası) `AuthRetryableFetchException`a çevrilir, yani
   **yeniden denenebilir** sayılır.
   `gotrue-2.22.0/lib/src/gotrue_client.dart:1245-1284` — `_refreshAccessToken`
   `maxAttempts: 999` ile döner; durma ölçütü `autoRefreshTickDuration`dır ve o
   sabit **10 saniyedir** (`gotrue-2.22.0/lib/src/constants.dart:20`).

4. **Ancak bundan sonra WP-542 tavanına gelinir.**
   `app/lib/main.dart:116-119` + `app/lib/core/net/timeout_http_client.dart:35-38` —
   her Supabase HTTP turuna 10 saniyelik üst sınır.

**Toplam: 10 sn (token tazeleme) + 10 sn (profil isteği) = 20 saniye.**
Kullanıcının saydığı sayı budur.

> 🔴 Buradaki asıl ders: **WP-542'nin 10 saniyelik tavanı zincirin yalnız
> ikinci yarısını kapsıyor.** `AuthHttpClient`, `TimeoutHttpClient`in
> **dışında** sarar; tavan token tazelemeyi görmez. "Zaman aşımı koyduk"
> denilen yerde beklemenin yarısı hâlâ tavansızdı.

**Soru 2'nin cevabı:** evet zaman aşımı var ama yetmiyor; tazeleme kısmı
tavansız ve kendi başına ~10 saniye.

**WP-593'ün 12 saniyelik `kAuthGateLoadingTimeout`u neden kurtarmadı:** eşik
12'de dolduğunda kullanıcıya çıkan şey "Oturum durumu okunamadı. + Tekrar dene
/ Çıkış yap"tır. Metroda **ikisi de kapalı kapıdır**: tekrar denemek yine ağ
ister, çıkış yapmak ise çevrimdışı geri girilemeyen bir yerdir. Yani mesaj
doğru ama **çıkış yok**.

---

## 3. Oturumu olan kullanıcı çevrimdışı girebiliyor muydu? (Soru 3)

Kâğıt üzerinde evet, pratikte hayır.

* `_profileFor` çevrimdışı hatayı yutar ve `user_metadata`dan geçici profil
  döner (`supabase_auth_repository.dart:161-179`) — yani kullanıcı **20
  saniyenin sonunda** içeri girer. Sahip o kadar beklemedi, haklıydı.
* Girse bile o geçici profilde **günlük hedef varsayılana düşer**
  (`kDefaultDailyGoalMinutes` = 360). Hedefe bağlı her şey (ilerleme, günlük
  hedef metni) çevrimdışıyken yanlış görünürdü.

---

## 4. Çevrimdışı sayaç ve senkron (Soru 4) — bu kısım sağlamdı

* `studyRepositoryProvider` gerçekten offline-first sarmalayıcıyı kuruyor
  (`app/lib/data/providers/study_providers.dart:174-185`), ölü kod değil.
* Sayaç durdurmada yerel-önce yazım gerçekten çağrılıyor
  (`app/lib/data/providers/study_providers.dart:2740-2741`).
* Uzak gönderim başarısızsa mutasyon outbox'a alınıyor
  (`offline_first_study_repository.dart:212-242`) ve bağlantı dönünce
  `flushPending` ile akıtılıyor (aynı dosya `:274, :295, :358`).

**Yani çevrimdışı altyapı zaten çalışıyordu; onu boşa çıkaran tek şey açılış
kapısıydı.** Bu WP altyapıyı yeniden yazmadı, kapıyı açtı.

---

## 5. Yapılan düzeltme

### 5.1 Açılışa ağdan bağımsız bir üst sınır
`app/lib/data/providers/auth_providers.dart` — `authStateWithOfflineFallback`.

Sözleşme iki yönlü:

* **Ağ yokken:** oturum akışı `kAuthColdStartBudget` (2 sn) içinde konuşmazsa
  cihazdaki oturumdan üretilen profil yayınlanır; uygulama açılır.
* **Ağ varken:** akış bütçeden önce konuşur, yedek **hiç** çalışmaz; çevrimiçi
  davranış birebir korunur. Kaynak bir kez konuştuktan sonra yedek bir daha
  asla devreye girmez (geç gelen gerçek profilin üstüne bayat veri yazmak
  WP-478'in kapattığı hatayı geri getirirdi).

Hata dalı da yedeğe düşer — ama **yalnız yerel oturum varsa**. Yerel oturum
yoksa hata aynen iletilir; gerçek arıza gizlenmez.

### 5.2 Son bilinen iyi profil
`app/lib/data/repositories/offline/offline_cache_store.dart` — `readProfile` /
`saveProfile`. Sunucudan gelen her profil bir sonraki çevrimdışı açılışın
yedeğidir. Böylece çevrimdışı açılışta ad, günlük hedef, avatar **gerçek**
değerleriyle gelir; §3'teki "hedef varsayılana düşer" sorunu da kapanır.

### 5.3 Çevrimdışılık söyleniyor
`app/lib/features/auth/auth_gate.dart` — açılış yerel oturumla tamamlandıysa
tek seferlik bir şerit: *"İnternet yok. Uygulama çevrimdışı açıldı; sayaç
çalışır, kayıtların bağlantı gelince eşitlenir."* Engellemez, bildirir.
(`authCevrimdisiAcildi`, TR+EN.)

### 5.4 Ölçüm
`app/test/data/auth_offline_cold_start_wp603_test.dart` — 10 test, üç katman:

1. **Saf uç:** akış sözleşmesi (yedek çalışır / yedek hiç çalışmaz / geç gelen
   gerçek profil kazanır / hata yerel oturumla karşılanır / yerel oturum yoksa
   hata gizlenmez).
2. **Önbellek:** profil gidiş-dönüşü + bozuk kayıt açılışı düşürmez.
3. **Kablo ucu:** gerçek `authStateProvider` + gerçek `AuthGate` — yedeğin
   üretimde bağlı olduğu. Bu depoda tekrar eden hata "yazılmış ama çağıran
   yok"; saf uç tek başına onu yakalamaz.

Zaman **enjekte** edilir (`budget` parametresi); gerçek saate/ağa bağlı tek bir
bekleme yoktur.

**Kırmızı doğrulaması yapıldı (iki ayrı deney):**

* Kablo geri alındı (`authStateProvider` eski gövdeye döndürüldü) →
  yalnız kablo ucu testi kırmızı (`+8 -1`), saf uç yeşil kaldı. Yani kablo
  testi gerçekten kabloyu ölçüyor.
* Yedek zamanlayıcısı silindi → 3 test kırmızı (`+7 -3`), aralarında kablo
  ucu da var. Sonra ikisi de geri kondu, 10/10 yeşil.

---

## 6. Düzeltilmeyenler (bilerek — kapsam/sahiplik dışı)

1. **`SupabaseAuthRepository._sessionProfiles` hâlâ ilk `yield`den önce ağa
   gidiyor.** Bu WP'nin SAHİP yollarında değil. Artık kullanıcıyı bekletmiyor
   (yedek 2 sn'de açıyor) ama her soğuk açılışta arka planda ~20 saniyelik boş
   bir tur hâlâ dönüyor. Doğru düzeltme: önce yerel oturumu `yield` et, profil
   satırını sonra çek. **Ayrı WP önerilir.**
2. **`AuthHttpClient`, `TimeoutHttpClient`in dışında.** Token tazelemenin
   tavanı yok; SDK içi olduğu için `main.dart`tan sarılamaz. Tek gerçek çare
   `Supabase.initialize`a `accessToken` geri çağırması vermek olurdu, o da auth
   semantiğini baştan değiştirir. **Bilinçli olarak dokunulmadı.**
3. **`UpdaterService.checkForUpdate`de `connectTimeout` yok**
   (`app/lib/features/updater/updater_service.dart:75-79` yalnız
   `receiveTimeout`/`sendTimeout` veriyor). Açılışı bloklamıyor (kare sonrası
   çalışıyor) ama çevrimdışı asılı kalabilen bir istek. SAHİP yolu değil.
4. **`HomeShell` ve gösterge paneli çevrimdışı davranışı** bu turda uçtan uca
   denetlenmedi; açılış kapısı ölçüldü.
