# Beta Yayın Arızası — İkinci Adli İnceleme ve Kurtarma Raporu

> **Arşiv uyarısı:** Bu ara rapordaki bazı neden ve öncelik hükümleri sonraki
> doğrulamalarla düzeltilmiştir. Uygulama için kanonik kaynak
> [`BETA-YAYIN-ARIZA-NIHAI-RAPORU-2026-07-23.md`](BETA-YAYIN-ARIZA-NIHAI-RAPORU-2026-07-23.md)
> dosyasıdır.

> Tarih: 23 Temmuz 2026  
> İnceleme türü: Salt-okunur repo, commit, workflow ve GitHub Actions incelemesi  
> Ana inceleme aralığı: önceki raporun son commit'i `6b57cf9` → güncel HEAD `514db21`  
> Karşılaştırma tabanı: son yayımlanmış beta `beta-v4303 / 3bdf8bb`  
> Kod, workflow, migration, tag, release veya uzak ortam değişikliği: **Yapılmadı**  
> Bu rapor dışında oluşturulan/değiştirilen proje dosyası: **Yok**

## 1. Kısa hüküm

Beta yayınını bugün durduran hata Gradle, imza, APK derleme, Firebase veya
Supabase değildir. Her iki yeni beta denemesi de **APK build başlamadan önce**
Ubuntu runner'daki tam Flutter test paketinde durmuştur.

Kesin hata zinciri:

```text
OnlineStudyRoomApp
  → pushLifecycleListenerProvider
  → PushHealthController.synchronize()
  → AppPushNotificationService.snapshot()
  → AppNotificationCoordinator.notificationsEnabled()
  → FlutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation()
  → LateInitializationError
```

`beta-v4304` koşusunda **676 test geçti, aynı 9 test düştü**.
`beta-v4305` koşusunda eklenen yeni dar test de geçtiği için sayı
**677 geçti, aynı 9 test düştü** oldu. Yani `514db21` düzeltmesi ana arızayı
gidermedi; yalnız bir yeni yeşil test ekledi.

Neden açık: düzeltme `initialize()` içindeki ilk eklenti erişimini yakalayıp
geri dönüyor. Gerçek uygulama akışı hemen sonra `notificationsEnabled()` içinde
aynı kayıtlı olmayan platform eklentisine yeniden erişiyor. Bu ikinci erişim
korunmadığı için aynı hata değişmeden devam ediyor.

Ancak tek problem bu kod satırı değildir. Süreçte dört ayrı sistemsel kusur var:

1. Tam aday doğrulaması **tag atıldıktan sonra** yapılıyor; başarısız test
   benzersiz beta numarasını yakıyor.
2. Veritabanı değişmeyen uygulama düzeltmesinde bile tam Database Gates ve
   staging apply yeniden çalıştırılıyor.
3. Staging DB `0069`a alınmış olsa da kayıtlı son Edge Function aktivasyonu
   `3bdf8bb` SHA'sındadır; `87f7965` ile değişen Edge kodunun staging deploy
   kanıtı yoktur.
4. “Başarılı” staging health kontrolü, yaklaşık 16 saattir bekleyen iki delivery
   göstermesine rağmen yalnız sorgunun çalışmasını başarı saymıştır.

Sonuç: **Doğrudan beta blokajı küçük ve belirli bir test/bağımlılık sınırı
hatasıdır; fakat release ve staging gerçeğinin güvenilir olmaması daha büyük
operasyon sorunudur.** Bir sonraki ajan yalnız aynı `LateInitializationError`ı
bir yerde daha yakalayıp tag atmamalıdır.

## 2. İnceleme kapsamı ve güncel gerçekler

### 2.1 Git ve yayın durumu

| Gerçek | Değer |
|---|---|
| Güncel `main`, `origin/main`, HEAD | `514db21788fcd961ec44fa7788604f9949b3931b` |
| Çalışma ağacı | Temiz |
| Son yayımlanmış/kullanılabilir beta | `beta-v4303 / 3bdf8bb` |
| `beta-v4304` tag'i | Var; `9f6c571`; GitHub Release yok |
| `beta-v4305` tag'i | Var; `514db21`; GitHub Release yok |
| Güncel yayımlanmış stable | `v43 / fa771ce`; production `0065` |
| `beta-v4303..HEAD` | 16 commit, 46 dosya, yaklaşık 2322 ekleme / 1915 silme |
| Önceki rapor sonrası | 15 commit |

GitHub release listesinde hâlâ son prerelease `beta-v4303`tür. `beta-v4304` ve
`beta-v4305` yalnız tag olarak kalmıştır; APK/MSIX/ZIP içeren release
oluşmamıştır.

### 2.2 İncelenen kanıtlar

- Kullanıcının verdiği yeni konuşma dökümü
- `beta-v4303..514db21` commit ve dosya farkları
- Güncel release, Windows, Database Gates ve Staging Push Activation workflow'ları
- İki başarısız release koşusunun job/step ve tam hata logları
- Yedi Database Gates koşusunun sonuçları
- Staging push activation geçmişi
- Bildirim koordinatörü, push health provider'ı, `0069` migration'ı ve Edge Function
- `progress.md`, kalite programı, ajan kuralları ve release belgeleri
- GitHub staging/production Environment protection durumu

Bu inceleme staging veya production'a sorgu/mutasyon göndermedi. Uzak ortam
durumu yalnız mevcut GitHub Actions kanıtlarından çıkarıldı.

## 3. Tam olarak nerede patlıyor?

### 3.1 `beta-v4304`

[Release Orchestrator run 30007806029](https://github.com/manil-max/online-study-room/actions/runs/30007806029):

- preflight: başarılı,
- Android job `flutter analyze`: başarılı,
- Android job tam `flutter test`: **676 geçti, 9 düştü**,
- APK build: hiç başlamadı,
- Windows tam test paketi: başarılı,
- Windows build, Android zaten düştüğü için ajan tarafından iptal edildi,
- finalize: çalışmadı,
- GitHub Release: oluşmadı.

Düşenlerin yedisi `app/test/widget_test.dart`, ikisi
`app/test/features/v8_critical_flows_test.dart` içindedir. Dokuzunun stack'i
aynı noktaya gider:

```text
FlutterLocalNotificationsPlatform._instance
FlutterLocalNotificationsPlatform.instance
FlutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation
AppNotificationCoordinator.notificationsEnabled
AppPushNotificationService.snapshot
PushHealthController._synchronizeImpl
```

Bu, dokuz bağımsız ürün regresyonu değil; uygulama kökü açıldığında tetiklenen
tek ortak platform-bağımlılığı hatasıdır.

### 3.2 `beta-v4305`

[Release Orchestrator run 30009302420](https://github.com/manil-max/online-study-room/actions/runs/30009302420):

- preflight: başarılı,
- analyze: başarılı,
- yeni `app_notification_coordinator_test.dart`: başarılı,
- tam paket: **677 geçti, aynı 9 test düştü**,
- hata satırı yine `app_push_notification_service.dart:117`,
- APK build: hiç başlamadı,
- Windows test adımı ajan tarafından iptal edildi,
- finalize/release: oluşmadı.

Bu karşılaştırma önemlidir: hata sınıfı, stack ve düşen dokuz senaryo
değişmemiştir. “Yeni bir ikinci hata çıktı” kanıtı yoktur.

### 3.3 Neden yerelde yeşil, CI'da kırmızı?

Yerel tam testler Windows'ta çalıştırıldı. Bildirim koordinatörü
`defaultTargetPlatform == TargetPlatform.android` değilse platform eklentisine
girmeden `false/no-op` döner.

Release Android job'ı ise gerçek Android cihaz/emülatör değildir; Ubuntu
üzerindeki hostless Flutter testidir. Test framework'ü Android hedef
davranışını seçebildiği hâlde native plugin registrant yoktur. Release
`env.json` dosyasında gerçek beta Firebase alanları da bulunduğu için uygulama
kökündeki push lifecycle senkronizasyonu aktif yola girer.

Dolayısıyla:

- Windows'taki 685/685 sonucu Linux release test ortamını temsil etmiyordu.
- Sorun büyük olasılıkla gerçek Android cihaz runtime'ından ziyade widget test
  izolasyonu/bağımlılık enjeksiyonu kusurudur.
- Yine de gerçek cihaz etkisi otomatik olarak “yok” sayılamaz; kod, platform
  eklentisinin yanlış kayıt durumunu hata metniyle ayırt etmeye çalışıyor.

## 4. `514db21` düzeltmesi neden yanlış hedefi test etti?

Commit şu davranışı ekledi:

1. `_plugin.initialize(...)` bir `LateInitializationError` verirse hatayı metin
   başlangıcından tanı,
2. `initialize()` metodundan sessizce dön,
3. yeni testte yalnız `AppNotificationCoordinator.instance.initialize()`
   çağrısının tamamlandığını doğrula.

Gerçek zincir ise şöyledir:

```dart
await initialize();
return await _plugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.areNotificationsEnabled() ?? false;
```

`initialize()` sessiz döndükten sonra `notificationsEnabled()` ikinci satıra
devam eder. Tam hata da orada oluşur. Yeni test:

- `notificationsEnabled()` çağırmıyor,
- `AppPushNotificationService.snapshot()` çağırmıyor,
- `PushHealthController` lifecycle'ını çalıştırmıyor,
- düşen gerçek widget/V8 uygulama başlangıcını Android hedefiyle doğrulamıyor.

Ek sorunlar:

- Hata tipi/capability yerine `error.toString().startsWith(...)` kullanılıyor.
- `_initialized` false kalıyor; sonraki her çağrı tekrar aynı yolu deniyor.
- Yorum gerçek cihaz hatalarının gizlenmediğini söylüyor, fakat gerçekten
  kayıtsız bir production plugin aynı hata metnini üretirse ilk hata yutulur.
- `requestPermission`, `showLocalTest`, `showRemote` ve `showNudge` benzer
  platform erişimleri taşır; tek noktada catch eklemek koordinatör sözleşmesini
  düzeltmez.

Doğru düzeltme sınıfı, mesaj bazlı catch çoğaltmak değil; plugin/capability
bağımlılığını enjekte edilebilir yapmak, testte fake/no-op sunmak ve
`snapshot → health provider → app root` gerçek çağrı zincirini Android hedef
koşulunda sınamaktır.

## 5. Release sistemi gerçekten nasıl değişti?

`a89ba5e / WP-269` önceki rapordaki bazı gerçek sorunları doğru biçimde
iyileştirdi:

- Database Gates içinden Flutter/keystore/APK build kaldırıldı.
- Android ve Windows tek release orkestratöründe toplandı.
- İki zorunlu platform başarılı olmadan GitHub Release finalize edilmiyor.
- `release-status-manifest.json` ile `complete/partial/failed` gerçeği üretiliyor.
- Production deploy/release varsayılanı kapatıldı.

Bunlar geri alınmaması gereken kazanımlardır.

Fakat yeni yapı başka bir sürtünme üretti:

```text
tag push
  → preflight
  → Android: analyze + bütün testler + manifest gate + APK
  → Windows: analyze + bütün testler + manifest gate + MSIX/ZIP
  → ikisi de başarılıysa GitHub Release
```

Eski `beta-v4303` Android workflow'u bütün Flutter paketini çalıştırmıyordu;
yalnız build-manifest gate'i ve APK build yapıyordu. WP-269 tam testi release
içine ekleyerek daha önce görünmeyen gerçek bir taşınabilirlik kusurunu yakaladı.
Bu açıdan gate faydalıdır.

Yanlış olan testin varlığı değil, **ilk kez tag atıldıktan sonra koşmasıdır**.
Sonuçta iki başarısız deneme iki kalıcı tag yaktı.

Ek olarak aynı genel test paketi Android/Ubuntu ve Windows job'larında yeniden
çalışıyor. Platform farkı bazı testlerde değerlidir, fakat:

- ortak testler iki kez koşuyor,
- ortak doğrulama başarısızken iki platform build lane'i de başlıyor,
- Android erken düşünce Windows işi elle iptal ediliyor,
- hata teşhisi ve yeni benzersiz tag döngüsü tekrar başlıyor.

## 6. Database Gates: azaltıldı ama hâlâ yanlış yerde tekrar ediyor

23 Temmuz 15:25–15:59 arasında yedi Database Gates koşusu vardır:

| Commit | Otomatik validate | Manuel staging apply | Sonuç |
|---|---:|---:|---|
| `3061268` | 1 | 1 | İkisi de eski `0068` guard beklentisinde düştü |
| `33e63ab` | 1 | 1 | Validate geçti; apply `0069`u uyguladı, canlı pgTAP yarışıyla kırmızı oldu |
| `9f6c571` | 1 | 1 | İkisi de geçti; DB zaten `0069`du |
| `514db21` | 0 | 1 | Yalnız uygulama/test düzeltmesine rağmen tam replay + staging apply yeniden koştu |

Buradaki ana israflar:

1. Push edilen DB/tooling commit'i otomatik full local replay çalıştırırken
   manuel apply aynı full replay'i tekrar çalıştırıyor.
2. Migration bir kez uygulandıktan sonraki tooling/app düzeltmeleri için yeniden
   “apply” koşuluyor.
3. `514db21` DB, migration veya Edge Function değiştirmediği hâlde
   “staging gate geçmeden tag yok” yaklaşımıyla gereksiz DB hattına sokuldu.
4. İlk guard hatasında evidence dosyası oluşmadığı için `if-no-files-found:
   error` ikinci bir kırmızı hata daha üretti; ana teşhise gürültü ekledi.

Güvenli ayrım şu olmalıdır:

- migration/DB değiştiyse: bir kez local replay + bir kez remote
  list/dry-run/apply/post-check,
- Edge değiştiyse: ayrı activation/deploy ve sürüm kimliği doğrulaması,
- yalnız Dart/native/test değiştiyse: DB apply yok; mevcut doğrulanmış staging
  head kanıtı yeniden kullanılabilir.

## 7. Canlı staging post-check neden güven vermiyor?

İlk `0069` staging apply'ı migration'ı başarıyla uyguladı. Sonraki remote pgTAP,
dakikalık worker'ın test fixture'ını eşzamanlı claim etmesiyle yarıda kaldı:

- `005_push_delivery.test.sql` satır 172'de `no rows returned for \gset`,
- planlanan 37 testin yalnız 18'i yürüdü,
- migration uygulanmışken workflow kırmızı kaldı.

“Paylaşılan canlı staging'de mutasyonlu fixture testi cron ile yarışıyor”
teşhisi makuldür. Fakat hızlı çözüm fazla geniştir: bütün remote pgTAP çıkarılıp
yerine şu salt-okunur kontrol konmuştur:

- `cron.job` tablosu var mı,
- `push-dispatch-retry-worker` isimli satır var mı,
- health RPC var mı,
- health sorgusunu çalıştır ve çıktıyı yazdır.

Bu kontrol şunları **doğrulamıyor**:

- cron satırı `active = true` mı,
- son cron çalışmaları başarılı mı,
- runtime config içindeki URL/secret gerçekten dolu mu,
- Edge route ulaşılabilir ve beklenen kod sürümünde mi,
- stuck/yaşlı queue eşikleri kabul edilebilir mi,
- bir retry kaydı gerçekten ilerliyor mu,
- gerçek FCM teslimi var mı.

Daha da önemlisi `configuration_status`, config alanlarının doluluğunu değil
yalnız singleton satırının varlığını `configured` sayıyor. Worker ise URL veya
secret null ise sessizce dönüyor. Dolayısıyla sağlık raporu teorik olarak
`configured` deyip hiçbir iş yapmayabilir.

[Başarılı son staging gate 30009050419](https://github.com/manil-max/online-study-room/actions/runs/30009050419)
çıktısı:

| Alan | Değer |
|---|---:|
| `configuration_status` | `configured` |
| `queued_count` | 2 |
| `retry_count` | 0 |
| `processing_count` | 0 |
| `stuck_lease_count` | 0 |
| `oldest_age_seconds` | 57272 |
| `max_attempt` | 1 |

`57272` saniye yaklaşık **15 saat 55 dakika**dır. Bu kayıtlar tarihsel
fixture/geçersiz cihaz nedeniyle bilinçli kalmış olabilir; salt logdan ürün
arızası kesinleştirilemez. Fakat kapının bu değerleri yorumlamadan yeşil olması
kesindir. “Health sorgusu çalıştı” ile “queue sağlıklı” aynı şey değildir.

## 8. Staging tek bir aday SHA'sını temsil etmiyor

`87f7965` commit'i hem:

- `0069_push_dispatch_retry_health.sql`,
- hem de `supabase/functions/dispatch-push/index.ts`

dosyasını değiştirdi.

Database Gates `0069`u staging'e uyguladı. Buna karşılık GitHub'daki son kayıtlı
`Staging Push Activation`:

- run: [29956832128](https://github.com/manil-max/online-study-room/actions/runs/29956832128),
- SHA: `3bdf8bb`,
- tarih: 22 Temmuz,
- sonuç: başarılı.

Bu koşu `87f7965`ten öncedir. Sonraki commit için activation/deploy koşusu yoktur.
GitHub Actions kanıtına göre staging bugün:

- DB/migration: `0069`,
- Edge Function: son doğrulanmış deploy `3bdf8bb`,
- app candidate: `514db21`

olmak üzere üç ayrı kimlik taşımaktadır.

Doğrudan dışarıdan elle Edge deploy yapılmış olma ihtimali bu kaynaklarla
dışlanamaz; fakat yapılmışsa da repo/GitHub kanıt zincirinde görünmüyor. Bu
nedenle “staging `514db21` adayıyla tamamen doğrulandı” denemez.

Release preflight de remote migration veya Edge deployment kimliğini sorgulamaz;
yalnız checkout edilen repodaki deploy contract, SHA ve head değerlerini
karşılaştırır. Manuel staging gate ile release arasında makinece doğrulanan bir
evidence bağı yoktur.

## 9. Beta ve stable çıkarma akışı neden kullanıcıya zor geliyor?

### 9.1 Beta

Fiilî beta yolu:

1. Gerekirse migration commit edilir.
2. Otomatik Database Gates validate beklenir.
3. Elle staging apply çalıştırılır.
4. Edge değiştiyse ayrı Staging Push Activation çalıştırılmalıdır.
5. Changelog/release-notes hazırlanır.
6. Benzersiz beta tag'i oluşturulup push edilir.
7. Preflight çalışır.
8. Android ve Windows analyze/test/build paralel gider.
9. İkisi de yeşilse tek prerelease oluşur.

Kullanıcı açısından hâlâ “beta çıkar” komutu vardır; fakat arkada üç farklı
workflow ve aralarında elle korunan kanıt bağı vardır. Ajanlar bu ayrımı
anlamadığında her adayda bütün kapıları tekrar koşturur.

### 9.2 Stable

Güncel workflow yalnız `beta-v*` tag push'unda otomatik tetiklenir. Stable için:

1. `vN` tag'i önceden var olmalıdır,
2. `workflow_dispatch` elle açılır,
3. tag, channel, tam SHA, migration head, production confirmation ve evidence
   ayrı ayrı girilir,
4. production Environment seçilir.

Bu, `.agents/AGENTS.md` içindeki “yayın tamamen tag adından sürülür; elle
flavor/env seçilmez” anlatımıyla tam uyumlu değildir. Workflow elle channel ve
birçok kimlik girdisi istemektedir.

Üstelik GitHub API'ye göre:

- `production` Environment protection rule: boş,
- required reviewer: yok,
- prevent self-review: yok,
- `main` branch protection: yok.

Yani stable akışı kullanıcı için çok adımlı görünürken bağımsız ikinci insan
onayı teknik olarak kurulmuş değildir. `release-gate.ps1`:

- protected environment adını,
- exact GO metnini,
- boş olmayan bir evidence string'ini

kontrol eder; evidence'in gerçekten varlığını/içeriğini doğrulamaz. Aynı yetkili
ajan bunları girerse yazılım kapısı geçebilir.

Şu anda production açısından acil olay yoktur: yeni stable run/tag veya
production apply kanıtı yok, contract varsayılanı false ve v43 korunuyor. Fakat
“çok sürtünme = güçlü bağımsız onay” sonucu doğru değildir.

## 10. Kurallar silindi mi?

Hayır. `beta-v4303` sonrasında:

- kök `AGENTS.md` değişmedi,
- `.agents/AGENTS.md` değişmedi,
- worker/planner skill'leri değişmedi,
- kalite programına kurtarma ve GitHub beta cihaz-adayı politikası eklendi.

Sorun kural silinmesi değil, operasyonel kayıtların ayrışmasıdır:

- `progress.md` üst gerçeği hâlâ beta `4303`, staging `0068` yazıyor.
- Aynı dosyada aktif lane “beta-v4305 hazırlanıyor” diyor; oysa tag çoktan
  atıldı ve workflow başarısız oldu.
- Aktif lane hâlâ dolu görünüyor; ajan durdurulmuş durumda.
- `docs/KALITE-PROGRAMI.md` kurtarma tabanı hâlâ staging `0068` diyor.
- `docs/AJAN-KULLANIM.md` hâlâ “canlı migration SQL Editor” ve eski `v7/v8`
  anlatımı taşıyor; güncel CLI ve release kurallarıyla çelişiyor.
- `app/pubspec.yaml` hâlâ `1.0.43-beta.3+4303`; release workflow tag'den override
  ettiği için tek başına build blokajı değildir, fakat yerel görünür sürüm ile
  aday metadata'sını ayırıp zihinsel yük yaratıyor.

Sonuç: kurallar duruyor, fakat hangi dosyanın güncel gerçek olduğu yeniden
belirsizleşmiş durumda.

## 11. Son commitlerin değerlendirmesi

| Commit/küme | Hüküm |
|---|---|
| `a89ba5e` WP-269 | Ana yön doğru: DB/APK ayrımı, atomik iki-platform release ve production HOLD korunmalı |
| `87f7965` retry/health | Önceki cron eksiğini kod düzeyinde kapatıyor; fakat staging Edge deploy kimliği ve gerçek retry kabulü yok |
| `a288461` timer fallback | Önceki rapordaki v43 fallback kaybını hedefliyor; gerçek Samsung kabulü yine yok |
| `2b93c78`, `1bf619f` | Taç ve Araçlar ürün değişiklikleri; beta kurtarma adayının kapsamını gereksiz genişletiyor |
| `fa4a168` | Windows flaky testi deterministikleştirme yönü doğru; `beta-v4304` Windows testleri geçti |
| `3061268` | Aday metadata/head güncellemesi; stale guard yüzünden ilk gereksiz kırmızı |
| `33e63ab` | Test beklentisini gerçek `0069`a hizaladı |
| `9f6c571` | Canlı mutasyonlu pgTAP yarışını kaldırdı; fakat remote doğrulamayı fazla zayıflattı |
| `514db21` | Yanlış kapsamlı regresyon testi ve eksik hata sınırı; beta blokajını çözmedi |

Kurtarma turuna aynı anda retry/health, native sayaç, taç, Araçlar, Windows,
release metadata ve DB tooling girmiştir. Hepsi tek tek makul olabilir; ancak
incident adayı olarak kapsam yine büyümüştür.

## 12. Önceliklendirilmiş bulgular

| Öncelik | Bulgu | Etki |
|---|---|---|
| P0 | `notificationsEnabled()` kayıtlı olmayan plugin'e ikinci kez erişiyor | Android/Ubuntu release tam testi 9 uygulama senaryosunda düşüyor; APK başlamıyor |
| P0 | `514db21` gerçek çağrı zincirini test etmiyor | Yanlış yeşil hedef test yeni beta tag'inin yakılmasına yol açtı |
| P0 | Staging DB `0069`, kayıtlı Edge deploy `3bdf8bb` | Retry/health adayının bütün backend parçaları aynı SHA'da değil |
| P1 | Health kapısı değerleri yorumlamadan başarı veriyor | 16 saatlik queue bile yeşil görünebiliyor |
| P1 | Remote pgTAP tamamen kaldırıldı | Yarış çözüldü ama staging davranış kanıtı aşırı zayıfladı |
| P1 | Tam doğrulama tag'den sonra | Her deterministik hata yeni benzersiz beta numarası yakıyor |
| P1 | DB değişmeyen adayda staging apply tekrarı | Süre, log ve teşhis gürültüsü |
| P1 | Ortak suite iki platform job'ında tekrar | Gereksiz runner/bekleme; erken ortak hata iki lane'i de meşgul ediyor |
| P1 | Stable workflow ve kural anlatımı çelişkili | “Tag at” komutu yerine elle çoklu input; hakimiyet kaybı |
| P1 | Production Environment gerçekte korumasız | Sürtünme var, bağımsız reviewer güvenliği yok |
| P2 | `progress.md` ve kalite programı stale | Sonraki ajan yanlış head/tag/aşamayla başlıyor |
| P2 | Incident beta kapsamına ilgisiz ürün değişiklikleri girdi | Hata yüzeyi ve cihaz kabul matrisi büyüdü |

## 13. Önerilen kurtarma sırası

Bu rapor aşağıdaki işleri **uygulamamıştır**.

### Faz 0 — Yeni tag ve gereksiz gate'i durdur

- `beta-v4304` ve `beta-v4305` yeniden kullanılmaz veya başka commit'e taşınmaz.
- Sorun yerelde/CI eşleniğinde kanıtlanmadan `beta-v4306` atılmaz.
- App-only düzeltme için yeni staging apply çalıştırılmaz.
- Production/stable HOLD korunur.

### Faz 1 — Beta blokajını doğru sınırda çöz

- `AppNotificationCoordinator` platform eklentisi/fake'i enjekte edilebilir
  hâle getirilir veya push lifecycle widget testlerinde açıkça override edilir.
- Mesaj metnine göre `LateInitializationError` yutma kaldırılır.
- En az şu zincir Android hedefli hostta test edilir:
  `snapshot → notificationsEnabled → PushHealthController → OnlineStudyRoomApp`.
- Bugün düşen dokuz senaryo aynı Linux/Ubuntu koşulunda çalıştırılır.
- Önce full Linux suite yeşil olur; sonra Windows suite ve iki platform build
  dry-run'ı yapılır.

### Faz 2 — Staging dağıtım kimliğini tekleştir

- `dispatch-push` Edge Function'ın hangi committen deploy edildiği makinece
  kayda alınır.
- `87f7965` sonrası beklenen Edge değişikliği staging'e kontrollü deploy edilip
  route/version/health kanıtı üretilir.
- DB head, Edge SHA ve app candidate SHA tek manifestte gösterilir.
- Mevcut iki yaşlı queue kaydının nedeni salt-okunur incelenir; fixture mı,
  geçersiz token mı, işlemeyen worker mı ayrılır.

### Faz 3 — Staging health kapısını anlamlı yap

- Config satırı varlığı değil gerekli alanların doluluğu doğrulanır.
- Cron'un aktifliği ve son çalışma sonucu kontrol edilir.
- `stuck_lease_count = 0` zorunlu olur.
- Queue yaşı/sayısı için açık eşik ve bilinen fixture istisnası tanımlanır.
- Paylaşılan staging'deki pgTAP ya izole test namespace/fixture ile
  concurrency-safe yapılır ya da remote için ayrı, salt-okunur fakat gerçek
  invariant seti hazırlanır.

### Faz 4 — Release akışını tag öncesi doğrula

Önerilen yalın model:

```text
candidate verify (SHA)
  → ortak Linux suite bir kez
  → platforma özgü test/build smoke
  → staging evidence identity
  → hepsi yeşilse benzersiz tag
  → immutable artefakt publish/finalize
```

Android ve Windows'un ortak testleri tek verify job'ında çalışabilir;
platforma özgü testler kendi job'larında kalır. Böylece ortak hata varken iki
build başlamaz ve başarısız tag üretilmez.

### Faz 5 — DB ve Edge kapılarını değişiklik türüne bağla

| Değişiklik | Koşması gereken |
|---|---|
| Dart/UI/test | Analyze + hedefli test + ortak suite; DB apply yok |
| Android native | Hedefli/native test + Android build |
| Windows native/package | Windows hedefli test + paket build |
| Migration/DB | Local replay + pgTAP, sonra tek remote dry-run/apply/post-check |
| Edge Function | Type-check/test + tek staging activation + route health |
| Release metadata | Manifest/changelog kimliği; DB apply yok |

### Faz 6 — Yönetim gerçeğini temizle

- `progress.md` üst gerçekleri staging `0069`, başarısız `4304/4305` ve mevcut
  boş lane durumuyla güncellenir.
- Kalite programının kurtarma tabanı güncellenir.
- `docs/AJAN-KULLANIM.md` SQL Editor/eski sürüm anlatımından arındırılır.
- Tek kısa “beta çıkar” runbook'u; ayrı ve gerçekten reviewer korumalı “stable
  çıkar” runbook'u tutulur.

## 14. Bir sonraki ajan için kabul kriteri

Bir sonraki ajan “çözüldü” demeden önce aşağıdaki somut kanıtların tamamını
sunmalıdır:

1. Bugünkü aynı dokuz test Linux/Ubuntu Android-target davranışında geçiyor.
2. Eklenen regresyon testi yalnız `initialize()` değil gerçek `snapshot` ve app
   root zincirini çalıştırıyor.
3. Full Linux Flutter suite yeşil.
4. Full Windows suite yeşil.
5. Android APK ve Windows MSIX/ZIP tag atmadan önce aynı SHA'da build edilebiliyor.
6. Staging DB head `0069`, Edge deploy SHA ve app candidate SHA tek kanıtta.
7. Health kontrolü yaşlı queue'yu yorumluyor; yalnız tablo/RPC varlığını değil
   çalışmayı doğruluyor.
8. Bundan sonra ve ancak bundan sonra `beta-v4306` gibi yeni benzersiz tag
   oluşturuluyor.
9. GitHub prerelease iki zorunlu platform artefaktıyla tek seferde finalize
   oluyor.
10. Gerçek Android cihazda foreground/background/terminated FCM ve retry kabulü
    ayrıca yapılıyor; otomatik test bunun yerine sunulmuyor.

## 15. Ne yapılmamalı?

- Aynı hata için `notificationsEnabled`, `requestPermission`, `show...`
  metotlarına dağınık `try/catch` ekleyip devam etmek.
- Yalnız yeni hedef test yeşil diye tekrar tag atmak.
- App-only commit için yeniden migration apply yapmak.
- Yaşlı queue değerlerini görmezden gelip “staging sağlıklı” demek.
- Edge deploy edilmeden yalnız DB migration geçti diye retry işini tamamlanmış
  saymak.
- Başarısız `beta-v4304/4305` tag'lerini silip aynı numarayı başka committe
  kullanmak.
- Release kolaylaşsın diye ortam ayrımı, migration dry-run, RLS veya production
  GO kapılarını topluca kaldırmak.
- Stable workflow'un çok input istemesini gerçek independent approval sanmak.

## 16. Nihai değerlendirme

Proje yeniden baştan yazılacak durumda değildir. Kullanıcının kullandığı v43
stable için bu inceleme aralığında yeni production mutasyonu veya stable release
yoktur. Kurallar da silinmemiştir.

Bugünkü beta arızası dar ve kanıtlıdır: platform plugin'i olmayan Flutter test
hostunda global push health lifecycle'ı izole edilmemiştir; ilk düzeltme yanlış
seviyeyi test etmiştir.

Fakat yalnız bu satırı düzeltmek yeterli kurtarma değildir. Staging'in DB, Edge
ve app kimlikleri ayrışmış; health kapısı yorum yapmadan yeşil olmuş; release
doğrulaması tag sonrasına taşınmış; DB değişmeyen adaylarda bile ağır gate
tekrarlanmıştır. Ajanların sürekli “şimdi buldum” deyip ilerleyememesinin nedeni
tek tek hataların zor olması değil, **her düzeltmenin gerçek uçtan uca zincir
yerine dar bir alt adımda doğrulanmasıdır.**

Doğru sonraki hareket: yeni tag değil; önce aynı CI ortamında gerçek çağrı
zincirini kırmızıdan yeşile çevirmek, sonra staging deploy kimliğini teklemek,
son olarak tag öncesi aday doğrulamasını kurmaktır.
