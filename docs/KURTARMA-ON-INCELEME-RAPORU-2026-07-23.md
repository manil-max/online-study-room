# Kurtarma Operasyonu — Ön İnceleme ve Adli Durum Raporu

> Tarih: 23 Temmuz 2026
> İnceleme türü: Salt-okunur teknik/adli inceleme
> Kod, workflow, veritabanı veya uzak ortam değişikliği: **Yapılmadı**
> Rapor dışında oluşturulan/değiştirilen proje dosyası: **Yok**

> **Planlama notu:** Yukarıdaki salt-okunur beyan raporun hazırlandığı ana aittir. Rapor tamamlandıktan sonra uygulanabilir kurtarma işleri `progress.md` içinde WP-269–274 olarak planlanmış; yalnız yönetim dokümanları uyumlanmıştır. Kod, workflow, migration ve uzak ortam yine değiştirilmemiştir.

## 1. Kısa hüküm

Proje bütünüyle “bozulmuş” değil. Kullanılmakta olan **v43 stable** sürümü ile
production veritabanı, incelenen bildirim/beta çalışmalarından etkilenmemiş
görünüyor. v43 sonrası production migration, production Edge Function deploy'u
veya yeni stable release kanıtı yok. Bu, kurtarma açısından en önemli iyi haber.

Buna karşılık v43 sonrasında yapılan çalışma birkaç küçük düzeltme değildir:

- yayımlanan `v43` commit'inden bugünkü HEAD'e **28 commit**,
- **71 dosya**,
- yaklaşık **5963 ekleme / 592 silme**,
- yeni Firebase istemcisi,
- üç Supabase migration'ı (`0066–0068`),
- yeni Edge Function,
- üç GitHub Actions yüzeyi,
- Android sayaç bildiriminde iki kez yön değişikliği,
- Windows QA araçları,
- ayrıca bildirim dışı üç ürün değişikliği

vardır.

Ana sorun tek bir kod hatası değil; **kapsamın bir günde fazla genişlemesi,
gerçek cihaz kabulünden önce “tamam” denmesi, staging database deploy'u ile
APK üretiminin aynı workflow'a bağlanması, workflow kırıldıkça ileri fix
commit'leri atılması ve kayıtların gerçek durumla senkron tutulmamasıdır.**

En kritik teknik bulgu, “güvenilir retry” diye kaydedilen push kuyruğunda
zamanlanmış bir worker/cron bulunmamasıdır. İlk dispatch isteği, Edge Function
veya FCM geçici hata verirse kayıt `retry/processing` durumunda bekleyebilir;
başka bir olay veya elle dispatcher çağrısı gelmeden kendiliğinden tekrar
işlenmesini sağlayan kod yoktur.

İkinci kritik operasyon bulgusu, `production` GitHub Environment'ında required
reviewer/protection rule bulunmamasına rağmen deploy sözleşmesinde production
`deploy_enabled` ve `release_enabled` değerlerinin hâlâ `true` olmasıdır.
Production apply betiğinde ayrıca metinsel GO ve backup alanı kontrolleri vardır;
fakat bunlar GitHub tarafından bağımsız insan onayı değildir.

Üçüncü temel bulgu, kullanıcıya “Database Gates içindeki aday APK yolu
kaldırılıyor” denmesine rağmen bu yolun repoda hâlâ bulunmasıdır. Bugünkü
`staging-apply` işi hâlâ Flutter kuruyor, bütün testleri çalıştırıyor, imzalı APK
üretiyor ve imzayı doğruluyor. Gerçek tag release'i daha sonra APK'yı yeniden
üretiyor.

## 2. İnceleme sınırı ve kanıtlar

### 2.1 Git tabanı

| Gerçek | Değer |
|---|---|
| Kullanıcının kullandığı yayımlanmış stable tag | `v43` |
| `v43` tag'inin gerçek commit'i | `fa771ce712853e0b4ac55641db0379d590eb9693` |
| “v43 stable yayınlandı” kayıt commit'i | `09fa159` |
| İnceleme anındaki HEAD | `6b57cf97f9cd7a7b1972f592d380b741e19cb15b` |
| `origin/main` | `3bdf8bb8e25b0d303990f1e28d8ba184b4457ece` |
| Yerel fark | `main`, `origin/main` önünde 1 commit |
| Yayımlanmış koddan HEAD'e commit | 28 |
| Yayın kayıt commit'inden HEAD'e commit | 27 |

Yereldeki tek push edilmemiş commit `6b57cf9` olup taç XP çubuğu kararını
backlog'a kaydeden dokümantasyon commit'idir. İnceleme başında ve hedefli
testlerden sonra çalışma ağacı temizdi.

### 2.2 Kullanılan kaynaklar

- Git commit/diff/tag geçmişi (`v43..HEAD`)
- Kullanıcının verdiği 360 satırlık konuşma dökümü
- Güncel `AGENTS.md`, `.agents/AGENTS.md`, worker/planner skill'leri
- `progress.md` Aktif Çalışma Kaydı
- GitHub Actions koşu geçmişi ve başarısız iş logları
- GitHub release/tag/asset kayıtları
- GitHub `staging` ve `production` Environment protection yapılandırması
- Bildirim istemcisi, migration'lar, Edge Function ve test kaynakları
- Release/Database Gates/Windows workflow'ları
- Resmî Android, Firebase, Supabase ve GitHub belgeleri

Bu rapor production/staging veritabanına doğrudan sorgu atmamıştır. Uzak ortam
durumu için GitHub Actions logları, deploy sözleşmesi ve repodaki kanıt
kayıtları kullanılmıştır.

## 3. Stable sonrası 28 commit gerçekte ne yaptı?

| Küme | Commit sayısı | İçerik | Değerlendirme |
|---|---:|---|---|
| Stable yayın kaydı | 1 | v43 yayımlandı kaydı | Yalnız dokümantasyon |
| Windows hazırlık/QA | 7 | Store planı, yerel smoke, VM QA, navigasyon testi | Büyük ölçüde script/doküman; uygulama runtime'ını bozduğuna dair kanıt yok |
| Bildirim dışı ürün değişikliği | 3 | Grup istatistik reconnect, gizli rozet rengi, Araçlar sadeleştirme | İlk ikisi makul fix; Araçlar değişikliği kullanıcı görünür kapsam kaybı yaratıyor |
| Bildirim raporu + çekirdek + sayaç yönü | 3 | Adli rapor, FCM/outbox, standard/promoted sayaç | Çok geniş tek günlük kapsam |
| Staging/release/aktivasyon düzeltmeleri | 12 | Sürüm, Flutter, Firebase flavor, dispatcher, `0067/0068`, imza, warmup, Base64 | “Fix üstüne fix” zincirinin ana kısmı |
| Beta-v4303 geri dönüş/düzeltme | 1 | Stable sayaç panelini geri getirme, data-only FCM | Cihaz kabulü hâlâ açık |
| Taç XP backlog notu | 1 | Kullanıcının son isteği | Kod değişikliği yok |

Toplam: **28 commit**.

Konuşmadaki “son bir buçuk saatte üç küçük commit” ifadesi yalnız çok dar bir
anlık pencereyi anlatıyor ve yapılan işin toplam büyüklüğünü yansıtmıyor.
`1b2971b` ile `4fa5697` arasında tek başına 12 hazırlık/CI/Firebase/SQL/Edge
commit'i var.

## 4. Zaman çizelgesi: nerede kontrolden çıktı?

### 4.1 Karmaşıklık stable sonrasında başlamadı

Release sisteminin zorlaşmasının kökü v43'ten **önce**, 20 Temmuz'dadır:

- `b919e25 — WP-227`: beta→staging ve stable→production ayrımı, build manifesti
  ve fail-closed ortam kimliği kuruldu.
- `1e84d63 — WP-228`: `Database Gates`, deploy contract, local replay,
  remote apply, release gate ve staging beta candidate build eklendi.

WP-228 tek commit'te **1222 ekleme / 116 silme** yaptı. Yani kullanıcının
“eskiden tag atardık, şimdi neden bu kadar zor?” hissinin gerçek teknik kökü
budur. Stable v43 bu yeni sistemin üzerinden çıkarılmıştır; sistem kullanıcıya
basit bir komut yüzeyi sunmadan iç operasyon ayrıntılarını görünür hâle
getirmiştir.

### 4.2 22 Temmuz bildirim turu

1. `abf031b`: Bildirim sistemi için 800+ satırlık analiz yazıldı.
2. `23e6426`: Tek commit'te 36 dosyaya dokunan FCM/outbox/Edge/istemci omurgası
   kuruldu.
3. `c611040`: v43'te çalışan özel sayaç paneli kaldırılıp standard/promoted
   notification'a geçildi.
4. `1b2971b`: beta-v4302 staging hazırlığı açıldı.
5. İlk staging apply, migration ve remote testleri geçtikten sonra workflow'un
   en sonundaki APK adımında “Flutter yok” diye kırıldı.
6. Flutter eklendi; sonra kanonik beta sürüm hesabı, sonra imzalama eksikliği
   çıktı.
7. `0067` staging'e uygulandı; post-check eski bir `authenticated` EXECUTE
   yetkisi buldu. Bu gerçek bir güvenlik bulgusuydu.
8. İzin `0068` ileri migration'ıyla kapatıldı.
9. Push aktivasyonu önce DB GUC/pooler yaklaşımı, sonra private runtime config,
   sonra Edge warmup retry, sonra service-account Base64 aktarımı ile birkaç kez
   değişti.
10. beta-v4302 yayımlandı; cihazda sayaç görünümü v43'ten geriye gitti ve remote
    self-test başarısız oldu.
11. `3bdf8bb` ile beta-v4303 çıkarıldı: stable sayaç paneli geri getirildi,
    FCM notification+data yerine data-only akışa geçildi, bekleme 10 saniyeden
    25 saniyeye çıktı.
12. Kullanıcının son geri bildirimi yine kabul başarısızlığıdır: “gene olmadı”.
    Bu nedenle WP-266/267/268 tamamlanmış sayılamaz.

## 5. GitHub Actions gerçekleri

v43'ten sonra incelenen zaman aralığında **26 workflow koşusu** vardır:

| Workflow | Koşu | Başarılı | Başarısız | İptal | Koşu süreleri toplamı |
|---|---:|---:|---:|---:|---:|
| Database Gates | 16 | 11 | 4 | 1 | 65,8 dk |
| Staging Push Activation | 6 | 2 | 4 | 0 | 4,7 dk |
| Release APK | 2 | 2 | 0 | 0 | 18,9 dk |
| Windows Release | 2 | 1 | 1 | 0 | 31,3 dk |
| **Toplam** | **26** | **16** | **9** | **1** | **120,7 runner-dakikası** |

Runner süreleri paralel çalışabildiği için 120,7 dakika kullanıcının beklediği
duvar saatiyle birebir aynı değildir. Ayrıca GitHub runner süresi ile Codex
haftalık token limiti aynı şey değildir. Yine de 26 workflow, tekrarlı log
okuma, hata teşhisi ve 12 düzeltme commit'i; 2,5 saatlik ajan döngüsünün neden
uzadığını açıklar. Haftalık limitin tam olarak hangi adıma ne kadar gittiği bu
kaynaklardan ölçülemez.

### 5.1 Dört Database Gates arızası

| Run | Önce ne başarılı oldu? | Son hata | Sonuç |
|---|---|---|---|
| [29942462286](https://github.com/manil-max/online-study-room/actions/runs/29942462286) | Staging `0066` apply + remote post-check | Runner'da Flutter yok | DB değişti ama workflow kırmızı |
| [29949142705](https://github.com/manil-max/online-study-room/actions/runs/29949142705) | `0067` staging'e uygulandı | `authenticated` dispatcher config yetkisi bulundu | Gerçek güvenlik açığı; `0068` gerekti |
| [29950326255](https://github.com/manil-max/online-study-room/actions/runs/29950326255) | DB tarafı geçmişti | Aday build `invalid_version_build` | DB işi ile APK kimliği gereksiz bağlı |
| [29950935464](https://github.com/manil-max/online-study-room/actions/runs/29950935464) | Analyze + bütün Flutter testleri geçti | Release keystore hazırlanmadı | 8,9 dk sonra gereksiz aday APK adımı kırıldı |

Bu tasarımın temel UX sorunu şudur: workflow kırmızı olduğunda “migration
uygulanmadı” sanılabilir, oysa ilk iki örnekte staging zaten değişmiştir.
Database mutation ve artifact build aynı job'da ardışık olduğu için sonuç
anlamsızlaşmıştır.

### 5.2 beta-v4303 eksik release

- Android [Release APK koşusu](https://github.com/manil-max/online-study-room/actions/runs/29956967730)
  başarılı oldu ve APK yayımlandı.
- Windows [Release koşusu](https://github.com/manil-max/online-study-room/actions/runs/29956967665)
  680 test geçtikten sonra iki sayaç zamanlama testinde hata verdi.
- beta-v4303 GitHub release'inde Android APK vardır; Windows MSIX/ZIP yoktur.
- Aynı iki test bu incelemede yerel Windows makinede geçti. Bu, büyük olasılıkla
  platform/zamanlama hassasiyetli flaky testtir; yine de yayın sonucunun eksik
  olduğu gerçeğini değiştirmez.

Android ve Windows ayrı workflow'lar olduğu için release atomik değildir.
Android release görünür hâle geldikten sonra Windows saatler sonra eklenebilir
veya hiç eklenmeyebilir.

## 6. Release sistemi bugün nasıl çalışıyor?

### 6.1 Beta akışı

Bugünkü fiilî akış:

1. Kod `main`e gelir.
2. Supabase/tooling dosyası değiştiyse otomatik `Database Gates validate`
   çalışır:
   - deploy guard testleri,
   - sıfır DB'ye bütün migration zinciri,
   - pgTAP/RLS/invariant testleri.
3. Staging migration için elle `staging-apply` başlatılır:
   - yukarıdaki validate **yeniden** çalışır,
   - remote list/dry-run/apply/post-check,
   - Java/Flutter kurulum,
   - keystore çözme,
   - analyze,
   - build-manifest testi,
   - **bütün Flutter testleri**,
   - imzalı beta APK build,
   - APK kimlik ve imza kontrolü.
4. Push için ayrı `Staging Push Activation` elle çalıştırılır:
   - Edge secret'ları,
   - Edge deploy,
   - dispatcher DB config,
   - dispatcher çağrısı.
5. Sonra `beta-v<patch*100+sıra>` tag'i atılır.
6. Tag iki bağımsız workflow başlatır:
   - Android APK yeniden build edilir ve release yayımlanır.
   - Windows analyze + bütün testler + build + MSIX/ZIP yapar.

Dolayısıyla “tag at ve bitsin” hâlâ tetikleme şeklidir, fakat tag'den önce
birden fazla gizli önkoşul vardır. Ayrıca staging apply sırasında üretilen
aday APK release'te kullanılmaz; release aynı kodu yeniden derler.

### 6.2 Stable akışı ve mevcut çelişki

Mevcut deploy contract:

- local head: `0068`
- staging head: `0068`
- staging deploy/release: açık
- production head: `0065`
- production deploy/release: açık

Fakat `release-gate.ps1`, stable release'te checkout edilen repodaki **yerel en
yüksek migration head'inin** production beklenen head'iyle aynı olmasını
istiyor. Bugünkü HEAD `0068`, production sözleşmesi `0065` olduğu için
HEAD'den `v44` benzeri bir stable tag atılırsa `Migration head mismatch:
local=0068 expected=0065` ile durması beklenir.

Yani production `release_enabled: true` görünmesine rağmen stable release
pratikte kapalıdır. Bu fail-closed davranış veri güvenliği açısından anlaşılır,
fakat “staging production'dan ileride olabilir” ortam modelini stable
hotfix/release modeliyle fazla sıkı bağlamıştır.

### 6.3 Korunması gereken kapılar

Aşağıdakiler gereksiz değildir:

- beta/stable'ın ayrı Supabase ortamına bağlanması,
- yanlış kanal/backend eşleşmesinin fail-closed durması,
- release keystore'un korunması,
- migration dry-run ve remote head kontrolü,
- RLS/pgTAP güvenlik testi,
- production için somut GO,
- secret'ların repoya girmemesi,
- tag/build/version kimliğinin benzersiz olması.

Sorun bu kontrollerin varlığı değil; **aynı işin birden fazla yerde
tekrarlanması, database mutation ile artifact build'in aynı job'a bağlanması ve
kullanıcıya tek bir sade komut/özet sunulmamasıdır.**

## 7. Bildirim sistemi: ne doğru yapıldı?

`Kodda doğrulandı`:

- Firebase service account veya private key repoya commit edilmemiştir.
- Commit edilen `google-services.json` dosyaları public Firebase Android client
  config'idir; beta ve stable package/app kimlikleri doğru eşleşir.
- Beta ve stable ayrı Android `applicationId` kullanmaya devam eder.
- `push_devices`, outbox ve delivery tabloları normal kullanıcıya kapalıdır.
- Cihaz kaydı kullanıcı/kurulum bazlıdır; logout unregister yolu vardır.
- Notification event ve per-device delivery için benzersizlik/idempotency
  anahtarları vardır.
- FCM HTTP v1 ve kısa ömürlü OAuth token kullanılır.
- `UNREGISTERED` token disable yolu vardır.
- `0067`'deki gerçek EXECUTE yetki açığı staging post-check tarafından bulunmuş
  ve immutable ileri migration `0068` ile kapatılmıştır.
- Production'a `0066–0068` uygulanmamıştır.
- Kullanıcı oturumu, XP, grup veya başarım verisini silen/değiştiren SQL yoktur.

`Cihazda doğrulanmalı`:

- Foreground/background/terminated data-only FCM'nin Samsung cihazda gerçekten
  görsel bildirim oluşturması,
- tek cihaz self-test'in `outbox sent + cihaz receipt` olarak tamamlanması,
- duplicate=0,
- uygulama son uygulamalardan kapatıldığında teslim,
- geçici ağ/Edge/FCM hatası sonrası gerçek retry,
- uzun süreli soak.

Firebase'in resmî Flutter dokümanı, Android'de uygulama ayarlardan force-stop
edilmişse yeniden açılana kadar mesaj alınamayacağını doğrular:
[Receive messages in Flutter apps](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
Bu platform sınırıdır; uygulama koduyla aşılamaz.

## 8. Bildirim sistemi: kritik ve önemli kusurlar

### P0 — Retry modeli tamamlanmamış

Migration ve Edge Function şunları içeriyor:

- `retry` durumu,
- `available_at`,
- artan retry gecikmesi,
- lease,
- en çok 6 deneme.

Fakat `0066`, `0067`, `0068`, activation workflow veya başka yeni dosyada
dispatcher'ı periyodik çağıran `pg_cron`/Supabase Cron/queue worker yoktur.
Outbox insert'i yalnız bir kez `net.http_post` çağırır.

Sonuç:

- İlk HTTP çağrısı başarısızsa outbox bekler.
- Edge FCM'den retry alırsa kayıt ileri tarihe ertelenir, fakat o tarihte
  dispatcher'ı çağıran mekanizma yoktur.
- İşlem `processing` iken worker ölürse lease dolar, fakat yeni worker'ı
  otomatik başlatan mekanizma yoktur.
- Daha sonra başka bir bildirim veya elle health çağrısı gelirse eski kayıtlar
  tesadüfen işlenebilir.

Kod yorumunda “cron/manual dispatcher sonra tekrar deneyebilir” yazması,
cron'un gerçekten var olduğunu kanıtlamaz. Resmî Supabase belgesi periyodik Edge
çağrısı için `pg_cron`/Supabase Cron kurulması gerektiğini gösterir:
[pg_net async networking](https://supabase.com/docs/guides/database/extensions/pg_net),
[Supabase Cron](https://supabase.com/docs/guides/cron).

Bu eksik kapanmadan sistem “güvenilir push” diye adlandırılmamalıdır.

### P1 — Health check salt-okunur değil

`Staging Push Activation` içindeki “Verify dispatcher health without enqueueing
a notification” adımı yeni outbox üretmiyor; fakat Edge Function çağrısı
`claim_push_deliveries` çalıştırıyor ve bekleyen gerçek teslimleri FCM'e
gönderebiliyor.

Bu nedenle:

- “health” operasyonu kuyruk tüketen/mutasyon yapan bir worker çağrısıdır,
- bekleyen mesaj varken salt sağlık kontrolü değildir,
- operasyonun adı ve kullanıcıya yapılan açıklama eksiktir.

### P1 — Toplu duyuru/update fan-out HTTP fırtınası yaratabilir

Announcement ve update RPC'leri bir SQL statement içinde kullanıcı başına bir
outbox satırı oluşturuyor. Outbox'taki `AFTER INSERT FOR EACH ROW` trigger'ı her
satır için ayrı `net.http_post` çağırıyor. Küçük mevcut kullanıcı sayısında
çalışabilir; ölçek büyüyünce aynı anda çok sayıda Edge isteği ve yarışan worker
oluşturabilir. Rapor bunu “ileride batch worker” diye not etmiş, fakat bugünkü
mimari yine de bu riski taşıyor.

### P1 — Otomatik testler gerçek FCM kanıtı değil

`app/test/core/push_delivery_contract_test.dart` içindeki beş testin önemli
kısmı kaynak dosyada şu metinler var mı diye bakıyor:

- `FirebaseMessaging.onBackgroundMessage`
- `getInitialMessage`
- `FCM_SERVICE_ACCOUNT_BASE64`
- `claim_push_deliveries`
- workflow içinde Firebase değişken adları

Bu testler yararlı statik sözleşme kontrolleridir; fakat:

- Edge Function'ı gerçek ortamda çalıştırmaz,
- Google OAuth token üretmez,
- FCM'e mesaj göndermez,
- Samsung receiver/background isolate çalıştırmaz,
- bildirimin gerçekten göründüğünü doğrulamaz.

“682/682 test geçti” denip cihazdaki remote test başarısız olduğunda şaşırtıcı
bir çelişki yoktur; test kapsamı yanlış yorumlanmıştır.

### P1 — Migration standardı ihlali

`0066_push_notification_delivery.sql` doğru dosya adıyla başlıyor; fakat proje
kuralının istediği açık “Geri alma (Rollback)” bloğu yoktur. `0067` ve `0068`
rollback notu içerir.

Ayrıca `_request_push_dispatch()` içindeki `exception when others`, HTTP
başlatma hatasını warning'e çevirip domain transaction'ını başarılı döndürüyor.
Domain kaydını push ağı yüzünden geri almamak doğru bir tercih olabilir; ancak
otomatik retry/alert olmadığı için hata görünür ve telafi edilebilir değildir.

### P1 — beta-v4303 hâlâ cihaz kabulünden geçmedi

beta-v4303'te yapılan data-only FCM değişikliği teknik olarak mantıklıdır:
foreground ve background aynı Flutter local-notification yolunu kullanır.
Resmî Firebase dokümanı Android'de data mesajlarının background handler'a
gidebildiğini doğrular:
[Receive messages in Android apps](https://firebase.google.com/docs/cloud-messaging/android/receive-messages).

Ancak kullanıcı “gene olmadı” diyerek turu durdurmuştur. Dolayısıyla kodun
mantıklı olması ürün kabulü değildir. Hangi katmanda kaldığını söyleyen
sunucu/canlı cihaz kanıtı raporda yoktur.

## 9. Sayaç bildirimi: ne oldu?

### 9.1 beta-v4302 regresyonu tesadüf değildi

`c611040`, v43'te kullanıcı tarafından kabul edilmiş özel `RemoteViews`
panelini bilinçli olarak sildi ve yerine:

- başlık + açıklama,
- standard chronometer,
- native action,
- promoted ongoing/Live Update isteği

koydu.

Bu değişiklik Android Live Update şartları açısından teorik olarak doğrudur.
Resmî Android belgesi promoted Live Update için custom `RemoteViews`
kullanılmamasını şart koşar:
[Create live update notifications](https://developer.android.com/develop/ui/views/notifications/live-update).

Fakat ürün hedefi yanlış okunmuştur. Kullanıcının istediği ve v43'te çalışan
şey Samsung bildirim panelindeki büyük tek satır sayaç/eylem tasarımıydı.
“Dinamik panel” isteği ayrı bir OEM Live Update/Now Bar deneyiyle
karıştırılmıştır. Sonuç beta-v4302'de görünür regresyon olmuştur.

### 9.2 beta-v4303 neyi geri getirdi?

`3bdf8bb`:

- `timer_notification.xml` dosyasını geri getirdi,
- `RemoteViews` custom content/big content'i tekrar kullandı,
- promoted notification iznini ve teşhis köprüsünü kaldırdı,
- v43'e yakın tek satır sayaç + büyük eylem panelini geri getirdi.

Bu, stabil tasarımı geri getirme yönünde doğru bir geri dönüş olmuştur.

### 9.3 Hâlâ v43 ile birebir değil

v43'te `flutter.timer_panel_expanded` kaçış valfi vardı:

- varsayılan custom panel,
- sorunlu cihazda standard notification fallback.

Bugünkü kod bu flag/fallback'i tamamen kaldırıyor ve custom paneli zorunlu
kılıyor. Yani “stable ile aynı” ifadesi tam doğru değildir; görünür ana yol
benzerdir ama recoverability azalmıştır.

### 9.4 Doküman kendi içinde tarihsel olarak çelişkili

`docs/NOTIFICATION-SYSTEM-AUDIT-2026-07.md` başına beta-v4303 karar güncellemesi
eklenmiş; ancak aşağıdaki “uygulama günlüğü” bölümleri hâlâ:

- custom layout kaldırıldı,
- standard/promoted notification uygulanmıştır,
- custom content testte yasaktır

diye yazıyor. Bunlar bugünkü HEAD için artık doğru değildir. Üstteki iki
satırlık caveat tarihsel bağlam sağlar, fakat operasyonel gerçek kaydı
temizlemez.

## 10. Windows tarafında ne oldu?

v43 sonrası ilk yedi Windows commit'inin çoğu:

- dokümantasyon,
- yerel çalıştırma script'i,
- hızlı smoke,
- VM/temiz makine QA planı,
- integration test navigasyon uyumu

oluşturdu. `.github/workflows/windows-release.yml` v43 sonrasında değiştirilmedi.
Bu kümenin stable Android'i bozduğuna dair kanıt yok.

Firebase bağımlılığı nedeniyle Windows generated plugin listesine
`firebase_core` eklendi; `firebase_messaging` Windows runtime yolu
başlatılmıyor. Mevcut kod `defaultTargetPlatform == android` ile push'ı no-op
yapıyor.

Asıl Windows sorunu süreçtedir:

- Her beta tag'i Windows'ta analyze + bütün test suite'i tekrar çalıştırıyor.
- beta-v4303'te iki timing testi flaky davranıp bütün Windows paketini
  engelledi.
- Android release buna rağmen ayrı workflow'da yayımlandı.

## 11. Bildirim dışı sürpriz değişiklikler

### 11.1 Araçlar ekranında özellik erişimi kayboldu

`7713541 — refactor: araclar ekranini sadelestir` ile `ClockScreen` yaklaşık
282 satır küçültüldü.

v43'te Araçlar içinde erişilebilen:

- Saat + odak ana yüzeyi,
- Kronometre,
- Dünya Saatleri

sekmeleri kaldırıldı. Bugün yalnız:

- Alarm,
- Timer,
- Görevler

var.

`stopwatch_screen.dart` ve `world_clock_screen.dart` dosyaları hâlâ repoda,
fakat uygulama içinde bunlara referans kalmamıştır. Test de bu sekmelerin
**bulunmamasını** bekleyecek şekilde değiştirilmiştir. Bu, kod silinmediği hâlde
özelliklerin kullanıcı için erişilemez/dead hâle gelmesidir.

Bu değişiklik bilinçli ürün kararı olabilir; fakat bildirim kurtarma turuyla
aynı commit aralığında olması kapsam kontrolü açısından risktir ve kullanıcı
tarafından yeniden onaylanmalıdır.

### 11.2 Grup istatistik reconnect

`14aaffc`, remote group stats stream'i hata verirse cache gösterip iki saniye
sonra yeniden bağlanıyor. İlgili otomatik test var. Bu değişiklik migration,
XP veya production verisini değiştirmiyor. Kod düzeyinde makul bir dayanıklılık
düzeltmesidir; iki cihaz/ağ kesintisi cihaz QA'sı yine açık olmalıdır.

### 11.3 Gizli başarım rozeti rengi

`5920a3e`, profil rozet rengini merkezi `badgeVisualColor` sözleşmesine bağlar.
İlgili test kapsamı var. İncelenen diff'te yüksek riskli bir veri veya runtime
değişikliği görülmedi.

## 12. Kurallar silindi mi?

Hayır. `Kodda doğrulandı`:

- Kök `AGENTS.md`, v43 tag'i ile bugünkü HEAD arasında aynıdır.
- `.agents/AGENTS.md`, v43 ile bugünkü HEAD arasında aynıdır.
- worker ve planner `SKILL.md` dosyaları v43 ile bugünkü HEAD arasında aynıdır.
- Gizli dosya, RLS, production GO, tek `main`, migration ve test kuralları
  duruyor.

Kuralların silinmesinden çok **kurallara uyum/kayıt disiplini bozulmuştur**:

- `progress.md` v43 sonrası net **195 satır büyüdü**.
- Aktif Codex lane hâlâ `WP-268 beta-v4302`, “dispatcher activation/beta release
  bekliyor” diyor.
- Oysa beta-v4302 ve beta-v4303 yayımlandı; activation iki kez başarıyla geçti.
- Lane görev bitince/ajan durdurulunca boşaltılmamış.
- Aynı bilgi lane notu, WP kartı ve 834 satırlık bildirim raporunda tekrar
  edilmiş; bazı kopyalar güncel, bazıları eski kalmış.

Sonuç: kurallar kaybolmadı; **tek gerçek kaynağı olma iddiasındaki kayıt yüzeyi
güvenilirliğini kaybetti.**

## 13. Production ve stable şu anda güvende mi?

### Doğrulanabilen güvenli taraf

- v43 tag'i `fa771ce` üzerindedir.
- Kullanıcının kullandığı stable APK yeni beta commit'lerini içermez.
- `0066`, `0067`, `0068` yalnız staging'e uygulanmış görünüyor.
- v43 sonrası production Database Gates apply, production Edge deploy veya
  stable tag/release koşusu yok.
- Yeni SQL oturum/XP/grup/başarım verisini silmez.
- Service account/private key repoya girmemiştir.

### Açık operasyon riski

GitHub API incelemesinde:

- `staging` environment protection rules: boş,
- `production` environment protection rules: boş,
- `main` branch protection: yok.

GitHub'ın resmî belgesine göre environment'a required reviewer eklenirse job
onay bekler; yalnız workflow'da `environment: production` yazmak kendi başına
manuel onay oluşturmaz:
[Deployments and environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments).

Bugünkü production apply betiği backup JSON ve tam
`PRODUCTION GO:<sha>:<head>:<project-ref>` metni ister. Bu iyi bir yazılım
korumasıdır; fakat aynı ajan gerekli girdileri üretip workflow'u başlatabiliyorsa
bağımsız ikinci onay değildir.

Ayrıca production deploy/release flag'leri v43 sonrası kapatılmamıştır. Bu
bayraklar “v43 için açıldı” test açıklamasıyla bugün de `true` duruyor.

## 14. Test ve denetim yükü: hangisi değerli, hangisi israf?

### Tutulması gereken

- Migration varsa bir kez local full replay + pgTAP.
- Staging apply öncesi dry-run/head kontrolü.
- RLS/abuse testleri.
- Android release imzası ve package/version kimliği.
- Kanal/backend fail-closed kontrolü.
- Production için bağımsız insan GO.
- Sayaç, veri bütünlüğü ve offline queue için hedefli regresyon testleri.

### Sadeleştirilmesi gereken

1. **Database Gates içinden APK build kaldırılmalı.** Database apply sonucu,
   DB post-check bittiği anda kesinleşmeli.
2. **Aynı commit için full Flutter suite bir kez koşmalı.** Staging apply,
   Android tag ve Windows tag içinde tekrar tekrar koşmamalı.
3. **Beta candidate build ile release build tek artifact olmalı** ya da candidate
   yalnız isteğe bağlı QA workflow'u olmalı.
4. **Her küçük fix commit'inde full baseline yerine değişiklik kümesi
   tamamlanınca tek doğrulama** yapılmalı.
5. **Polling azaltılmalı.** Uzun GitHub job'ı kısa aralıklarla tekrar tekrar
   okunmamalı; completion/event beklenmeli.
6. **Static source-contract testi gerçek cihaz kanıtı gibi sunulmamalı.**
7. **Windows flaky timing testi deterministic fake clock/fake async ile
   sabitlenmeli; 680 test geçtikten sonra paket kaybettirmemeli.**

### Önerilen yalın kalite matrisi

| Olay | Zorunlu kontrol |
|---|---|
| Normal Dart/UI commit'i | Analyze + ilgili hedef testler |
| Migration/Edge commit'i | Local full replay + pgTAP + Edge type-check |
| Staging apply | Remote list + dry-run + apply + post-check |
| Beta tag | Build identity + imza + kritik smoke; daha önce yeşil suite SHA'sı |
| Stable GO | Staging cihaz kabulü + soak + production dry-run + bağımsız kullanıcı onayı |
| Stable tag | Onaylı SHA'dan tek build/publish |

## 15. Bugünkü doğrulama sonucu

Bu inceleme sırasında kod değiştirilmeden:

- `flutter analyze`: **temiz**
- `push_delivery_contract_test.dart`: geçti
- `timer_background_reconcile_test.dart`: geçti
- hedefli toplam: **19 test geçti**
- git çalışma ağacı: temiz

Bu sonuçlar:

- Dart statik analizinin temiz olduğunu,
- sayaç uzlaştırma testlerinin bu Windows makinede geçtiğini,
- kaynak sözleşme testlerinin güncel dosyalarla uyumlu olduğunu

kanıtlar.

Şunları kanıtlamaz:

- gerçek FCM teslimi,
- Samsung bildirim görünümü,
- beta-v4303 remote self-test,
- retry worker,
- Pixel/API matrisi,
- Windows beta-v4303 paketinin yayımlanabilirliği,
- production davranışı.

## 16. Önceliklendirilmiş bulgu listesi

| Öncelik | Bulgu | Etki |
|---|---|---|
| P0 | Push retry state var, zamanlanmış worker yok | Geçici hata sonrası bildirim süresiz bekleyebilir |
| P0 | Production Environment required reviewer yok; contract flag'leri açık | Bağımsız insan onayı otomasyonla garanti edilmiyor |
| P1 | Database apply ile full APK build aynı job'da | DB değişmişken workflow kırmızı; gereksiz süre ve fix zinciri |
| P1 | Stable release contract local `0068` ile production `0065`i bağdaştıramıyor | HEAD'den stable tag pratikte bloklu |
| P1 | beta-v4303 cihaz kabulü başarısız/açık | Bildirim işi tamamlanmış sayılamaz |
| P1 | beta-v4303 Windows release başarısız | Release eksik/atomik değil |
| P1 | Timer v43 tasarımı önce kaldırıldı, sonra tam olmayan geri dönüş yapıldı | Görünür regresyon ve fallback kaybı |
| P1 | Araçlar'dan Saat ana yüzeyi/Krono/Dünya erişimi kaldırıldı | Bildirim dışı kullanıcı görünür kapsam kaybı |
| P1 | Health endpoint kuyruk tüketiyor | Salt-okunur denetim sanılan adım gerçek gönderim yapabilir |
| P1 | Bulk fan-out her outbox satırında HTTP tetikliyor | Büyümede thundering-herd riski |
| P2 | `0066` rollback notu eksik | Operasyonel geri dönüş belirsiz |
| P2 | Push testleri ağırlıkla kaynak metni kontrol ediyor | Yeşil suite yanlış güven üretiyor |
| P2 | `progress.md` ve audit günlüğü stale/çelişkili | Sonraki ajan yanlış gerçeklikle başlıyor |

## 17. Kurtarma operasyonu için önerilen sıra

Bu rapor hiçbirini uygulamamıştır. Önerilen ilk kurtarma dalgası:

### Faz 0 — Dondur ve doğru tabanı ilan et

- Stable gerçek: `v43/fa771ce`, production `0065`.
- Beta deney tabanı: `beta-v4303/3bdf8bb`, staging `0068`.
- Yeni stable/production mutasyonu geçici olarak HOLD.
- Aktif lane ve WP durumları gerçek GitHub/release durumuna göre temizlenir.

### Faz 1 — Release sistemini sadeleştir

- Database Gates yalnız database işi yapsın.
- Aday APK build ayrı ve isteğe bağlı olsun veya gerçek tag artifact'i olarak
  yeniden kullanılsın.
- Production `deploy_enabled/release_enabled` varsayılan kapalı olsun.
- GitHub production Environment'a required reviewer eklensin.
- Kullanıcı için tek bir “beta çıkar” ve tek bir “stable preflight → GO → çıkar”
  komutu/wrapper'ı olsun.
- Android/Windows artifact durumu tek manifestte açıkça “partial/complete”
  gösterilsin.

### Faz 2 — Push güvenilirliğini gerçekten tamamla

- Periyodik dispatcher worker/Cron ekle.
- Health ve work endpoint'lerini ayır.
- Stuck lease/retry/queue-depth alarmı ekle.
- Self-test hata kodunu UI'da görünür yap.
- Gerçek staging cihazında outbox→delivery→FCM→receipt zaman çizelgesi kaydet.
- Tek telefon/tek hesap için test matrisi basitleştir.

### Faz 3 — Sayaç ürün kararını sabitle

- Kullanıcının kabul ettiği v43 custom panel ana ürün davranışı olarak
  sabitlensin.
- Now Bar/Live Update ayrı deney olarak ele alınsın; stable tasarımı değiştirmesin.
- v43'teki fallback flag'i geri mi gelecek, tamamen mi kaldırılacak ürün kararı
  verilsin.
- “Stable ile aynı” testi yalnız kaynak metni değil, screenshot/device kabulü
  üzerinden yapılsın.

### Faz 4 — Bildirim dışı drift'i temizle

- Kronometre ve Dünya Saatleri geri mi gelecek, yoksa dosyaları gerçekten
  kaldırılacak mı karar verilsin.
- Dead ekranlar ve onları “yok” sayan testler gözden geçirilsin.
- Grup stats reconnect gerçek ağ kesintisinde cihazda doğrulansın.
- Windows flaky sayaç testleri deterministic hâle getirilsin.

### Faz 5 — Dokümantasyon tek gerçek hâline getirilsin

- `progress.md` aktif lane kısa ve güncel tutulmalı.
- Uzun olay günlüğü ayrı incident raporunda kalmalı.
- Eski beta-v4302 “bekliyor” kayıtları kapanmalı.
- Bildirim audit'inde “uygulandı” bölümü mevcut HEAD'e göre yeniden yazılmalı;
  üst notla çelişkili eski nihai durum bırakılmamalı.

## 18. Nihai değerlendirme

### Güvenle söylenebilen

1. Kullanıcının kullandığı v43 stable yeni beta karmaşasından bağımsızdır.
2. Production'a bildirim migration'ları uygulanmamıştır.
3. Kurallar silinmemiştir.
4. SQL'ler kullanıcı oturum/XP/grup verisini silmiyor.
5. `0068` gerçek bir güvenlik açığını doğru biçimde ileri migration ile
   kapatmıştır.
6. beta-v4302 sayaç görünümü gerçek bir regresyondur ve kasıtlı presentation
   değişikliğinden kaynaklanmıştır.
7. beta-v4303 bu görünümü büyük ölçüde geri almıştır, fakat cihaz kabulü yoktur.
8. Remote push'ın güvenilirlik iddiası cron/worker eksikliği nedeniyle bugün
   teknik olarak tamam değildir.
9. Release süreci gereğinden fazla tekrar ve bağlılık içeriyor.
10. Projenin yönetim gerçeği koddan çok `progress.md` ve workflow anlatımında
    dağılmıştır.

### En doğru kurtarma yaklaşımı

Toplu revert veya acele fix zinciri doğru ilk adım değildir. Stable v43
korunmalı; beta/HEAD ayrı deney alanı olarak dondurulmalı; önce release
orkestrasyonu ve push worker modeli sadeleştirilmeli; sonra tek cihazla ölçülen
küçük bir beta kabulü yapılmalıdır.

Bu rapor kurtarma operasyonunun ilk halkasıdır: **gerçeği sabitler, değişiklik
yapmaz ve hangi güvenlik kapılarının korunup hangi tekrarların kaldırılması
gerektiğini ayırır.**
