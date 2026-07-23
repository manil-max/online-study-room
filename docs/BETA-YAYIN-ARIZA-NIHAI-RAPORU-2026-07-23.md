# Beta Yayın Arızası — Nihai Birleşik Adli Rapor ve Kurtarma Yol Haritası

> Tarih: 23 Temmuz 2026  
> Durum: **Nihai birleşik rapor**  
> İnceleme türü: Repo, commit, workflow, GitHub Actions logu ve yerel yeniden üretim  
> Ana karşılaştırma tabanı: son yayımlanmış beta `beta-v4303 / 3bdf8bb`  
> Güncel incelenen HEAD: `514db21788fcd961ec44fa7788604f9949b3931b`  
> Kod, workflow, migration, tag, release veya uzak ortam değişikliği: **Yapılmadı**  
> Nihai rapor hazırlanırken değiştirilen kod/yapılandırma/yönetim dosyası: **Yok**  
> Çalışma ağacında önceden oluşturulmuş iki taslak rapor ile önceki ajanın
> ignore kapsamında bıraktığı `app/env.cirepro.json` ayrıca bulunmaktadır.

Bu belge:

- `KURTARMA-ON-INCELEME-RAPORU-2026-07-23.md`,
- `BETA-YAYIN-ARIZA-ANALIZI-2026-07-23.md`,
- `BETA-ARIZA-KARSI-RAPOR-2026-07-23.md`,
- iki başarısız beta release koşusu,
- yedi Database Gates koşusu,
- ilgili commit farkları,
- Flutter SDK davranışı,
- ve aynı arızanın yerel Windows makinede yeniden üretimi

birlikte değerlendirilerek hazırlanmıştır.

Önceki iki beta arıza raporu arasındaki anlaşmazlıklar bu belgede çözülmüştür.
Bu rapor yeni kanıtla çürütülen eski yorumu tekrar etmez.

---

## 1. Yönetici özeti

### 1.1 Beta bugün neden çıkmıyor?

`beta-v4304` ve `beta-v4305` Android APK derlemesinde, imzada, Gradle'da,
Firebase sunucusunda veya Supabase migration'ında düşmedi.

İki release de **APK build başlamadan önce**, Android release job'ının tam
Flutter test paketinde durdu.

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

`beta-v4304`:

- 676 test geçti,
- aynı ortak kökten 9 test düştü,
- APK build başlamadı.

`beta-v4305`:

- yeni, fakat eksik kapsamlı bir test eklendi,
- 677 test geçti,
- önceki aynı 9 test yine düştü,
- APK build yine başlamadı.

### 1.2 Gerçek tetikleyici nedir?

Sorunun CI/Linux'a özgü olduğu yönündeki ilk yorum **yanlıştı**.

`flutter test`, hangi host işletim sisteminde çalışırsa çalışsın debug test
ortamında varsayılan hedef platformu Android yapıyor. Yerel Windows ve CI
arasındaki gerçek fark dört Firebase `--dart-define` değeridir:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_ANDROID_API_KEY`
- `FIREBASE_ANDROID_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`

Bu dört alan boş olduğunda:

```text
FirebasePushConfig.notConfigured
  → snapshot() erken döner
  → local-notification plugin'ine erişilmez
  → widget testleri geçer
```

Bu dört alan dolu olduğunda:

```text
FirebasePushConfig.configured
  → snapshot() notificationsEnabled() çağırır
  → native plugin registrant olmayan Flutter test hostunda platform singleton'ına erişilir
  → LateInitializationError
  → aynı 9 uygulama testi düşer
```

Bu davranış aynı Windows makinede yerel olarak yeniden üretildi:

| Test profili | Sonuç |
|---|---:|
| Normal `app/env.json` — yalnız iki Supabase alanı | Hedef iki dosyada 10/10 geçti |
| `app/env.cirepro.json` — aynı iki alan + dört dolu Firebase alanı | Aynı hedefte 1 geçti / 9 düştü |
| GitHub Android release profili | Tam pakette 677 geçti / 9 düştü |

Dolayısıyla iki beta tag'i, tag atmadan önce aynı makinede yaklaşık bir dakika
içinde görülebilecek deterministik bir yapılandırma farkı nedeniyle yakılmıştır.

### 1.3 `514db21` neden çözmedi?

Commit yalnız `_plugin.initialize(...)` çağrısındaki
`LateInitializationError`ı yakalıyor. `initialize()` sessizce döndükten sonra
`notificationsEnabled()` aynı kayıtsız plugin'e yeniden erişiyor ve hata
orada çıkıyor.

Eklenen test yalnız:

```dart
AppNotificationCoordinator.instance.initialize()
```

çağrısının tamamlandığını doğruluyor. Gerçek:

```text
snapshot → notificationsEnabled → plugin
```

zincirini hiç çalıştırmıyor.

### 1.4 Beta testleri yeşile dönse bile ikinci bir P0 neden var?

Staging health çıktılarının iki zaman noktası karşılaştırıldığında:

| UTC | pending | retry | processing | stuck | oldest age | max attempt |
|---|---:|---:|---:|---:|---:|---:|
| 12:38:08 | 2 | 0 | 0 | 0 | 55988 sn | 1 |
| 12:59:32 | 2 | 0 | 0 | 0 | 57272 sn | 1 |

`57272 - 55988 = 1284 saniye`.
İki ölçüm arasındaki duvar saati de tam `1284 saniye`dir.

Yani 21 dakika 24 saniye boyunca:

- pending satır sayısı değişmedi,
- retry oluşmadı,
- processing oluşmadı,
- stuck lease oluşmadı,
- aktif kuyruğun en eski kaydı yalnız yaşlandı.

Bu, worker'ın kesin olarak hangi noktada bozuk olduğunu tek başına kanıtlamaz.
Satırlar `available_at` nedeniyle o sırada claim edilemez de olabilir.
Fakat `0069`un amacı dakikalık retry worker olduğu için bu iki satır
açıklanmadan ve worker'ın gerçekten bir delivery ilerlettiği gösterilmeden yeni
beta çıkarılması kabul edilemez.

### 1.5 Sistem tamamen bozuk mu?

Hayır.

- Kullanıcının kullandığı `v43 / fa771ce` stable korunuyor.
- Yeni production migration, production Edge deploy veya stable release kanıtı
  yok.
- Kurallar silinmedi.
- WP-269'un DB/APK ayrımı ve iki platform tamamlanmadan release oluşturmaması
  doğru yönde ve korunmalı.

Ancak:

- yerel aday profili CI profiliyle eşleşmiyor,
- doğrulama tag'den sonra yapılıyor,
- DB değişmeyen app fix'inde bile staging apply tekrarlanıyor,
- staging health sorgusu değerleri yorumlamadan yeşil oluyor,
- remote pgTAP'ın kırılma nedeni yanlış teşhis edilmiş olabilir,
- DB, Edge ve app dağıtım kimlikleri tek kanıtta birleşmiyor,
- yönetim dokümanları yeniden stale durumda,
- production kullanıcı açısından çok adımlı görünse de bağımsız reviewer
  koruması gerçekte yok.

---

## 2. Kanıt seviyeleri

Bu raporda üç ayrı ifade seviyesi kullanılır:

| Etiket | Anlam |
|---|---|
| **Kesin doğrulandı** | Kaynak kodu, commit diff'i, CI logu veya yerel yeniden üretim doğrudan kanıtlıyor |
| **Kuvvetli çıkarım** | Birden fazla kanıt aynı sonucu destekliyor; eksik uzak veri nedeniyle yüzde yüz kesin değil |
| **Açık soru** | Mevcut kanıt seçim yaptırmıyor; salt-okunur ek gözlem gerekli |

Özellikle staging retry worker için:

- kuyruğun iki gözlem arasında değişmediği **kesin**,
- worker zincirinde işlevsel sorun olduğu **kuvvetli çıkarım**,
- cron, pg_net, Edge, secret veya delivery eligibility katmanlarından hangisinin
  sorumlu olduğu **açık soru**dur.

---

## 3. Güncel depo ve yayın gerçeği

| Gerçek | Değer |
|---|---|
| Güncel branch | `main` |
| HEAD | `514db21788fcd961ec44fa7788604f9949b3931b` |
| `origin/main` | Aynı SHA |
| Takip edilen çalışma ağacı | Temiz |
| Son yayımlanmış beta | `beta-v4303 / 3bdf8bb` |
| `beta-v4304` tag'i | Var; `9f6c571`; GitHub Release yok |
| `beta-v4305` tag'i | Var; `514db21`; GitHub Release yok |
| Son stable | `v43 / fa771ce`; production `0065` |
| `beta-v4303..HEAD` | 16 commit |
| Değişen dosya | 46 |
| Diff büyüklüğü | yaklaşık +2322 / -1915 |
| Önceki ana rapor sonrası commit | 15 |

GitHub release listesinde son prerelease hâlâ `beta-v4303`tür.
`beta-v4304` ve `beta-v4305` release değil, yalnız başarısız aday tag'leridir.

`app/env.cirepro.json`:

- Git tarafından ignore edilmektedir,
- takip edilen çalışma ağacında görünmez,
- mevcut iki yerel Supabase değeri ile dört dolu Firebase test değeri taşır,
- bu hatanın configured dalını yerelde yeniden üretmek için yeterlidir,
- fakat tam 17 alanlı Android release manifestinin kalıcı eşleniği değildir.

---

## 4. İnceleme kapsamı

### 4.1 Okunan kaynaklar

- Kullanıcının iki konuşma dökümü
- Son yayımlanmış beta sonrası commit/diff/tag geçmişi
- İki başarısız Release Orchestrator koşusu
- Yedi Database Gates koşusu
- Son Staging Push Activation koşuları
- Eski `beta-v4303` Android ve Windows release koşuları
- `app_push_notification_service.dart`
- `push_notification_providers.dart`
- `firebase_push_config.dart`
- widget ve V8 kritik akış testleri
- `0066`, `0067`, `0068`, `0069` migration'ları
- `dispatch-push` Edge Function
- `release.yml`
- `windows-release.yml`
- `database-gates.yml`
- `staging-push-activation.yml`
- release/deploy guard betikleri
- `progress.md`
- `.agents/AGENTS.md`
- `docs/KALITE-PROGRAMI.md`
- `docs/AJAN-KULLANIM.md`
- önceki iki beta arıza raporu
- yerel Flutter SDK `_platform_io.dart`

### 4.2 Yapılmayanlar

- Staging veya production DB'ye sorgu gönderilmedi.
- Workflow dispatch edilmedi.
- Tag/release oluşturulmadı.
- Edge Function deploy edilmedi.
- Migration uygulanmadı.
- Kod veya mevcut yönetim dosyaları değiştirilmedi.
- `env.cirepro.json` silinmedi veya değiştirilmedi.

---

## 5. Önceki rapor sonrası commit zaman çizelgesi

| Commit | İçerik | Nihai değerlendirme |
|---|---|---|
| `3f3ce3b` | Kurtarma raporu, kalite programı ve progress uyumu | Önceki adli taban |
| `004369c` | Backlog/progress düzenlemesi | Yönetim değişikliği |
| `a89ba5e` | WP-269 release ve DB gate sadeleştirmesi | Ana yön doğru; bazı yeni sürtünmeler doğurdu |
| `87f7965` | Retry worker, health, `0069`, Edge ve UI | Kod düzeyinde önceki worker eksiğini hedefledi; staging kabulü eksik |
| `a288461` | v43 timer panel fallback'i | Önceki fallback kaybını düzeltme yönünde |
| `2b93c78` | Taç XP barı | Release incident kapsamını genişleten ürün değişikliği |
| `1bf619f` | Eski clock tools ekran/dosyalarını kaldırma | Release incident kapsamını genişleten kullanıcı görünür değişiklik |
| `fa4a168` | Windows timer testini deterministikleştirme | `beta-v4304` Windows testlerinin geçmesine katkı sağladı |
| `18bc7b3` | Windows paket smoke kaydı | Dokümantasyon/kanıt |
| `7d53f7d` | Beta cihaz kabul hazırlığı | Cihaz QA henüz yapılmadı |
| `795f07a` | GitHub beta'yı cihaz QA varsayılanı yapma | Kullanıcı kararını kayda aldı |
| `3061268` | `beta-v4304` metadata ve staging `0069` adayı | Eski guard beklentisi nedeniyle ilk gate kırıldı |
| `33e63ab` | Guard testini `0069`a hizalama | Gerçek stale test düzeltmesi |
| `9f6c571` | Remote post-check'i salt-okunur yapma | Yarışı kaldırdı; doğrulamayı fazla zayıflattı |
| `514db21` | Kayıtsız notification test hostu fix'i | Yanlış seviyeyi test etti; beta blokajı sürüyor |

Son yayımlanmış beta sonrası kurtarma adayına aynı anda:

- release orkestrasyonu,
- database tooling,
- retry worker,
- Edge Function,
- push health UI,
- native timer presentation,
- crown XP görünümü,
- clock tools kaldırma,
- Windows timing,
- release metadata

girmiştir. Her biri tek başına gerekçeli olabilir; fakat incident beta kapsamı
yeniden gereksiz büyümüştür.

---

## 6. GitHub Actions zaman çizelgesi

### 6.1 Database Gates — yedi koşu

| Run | Commit | Tetik | Sonuç | Gerçek olay |
|---|---|---|---|---|
| [30006956698](https://github.com/manil-max/online-study-room/actions/runs/30006956698) | `3061268` | push validate | Başarısız | Guard hâlâ local head `0068` bekliyordu; evidence upload da dosya yok diye ikinci hata verdi |
| [30006967571](https://github.com/manil-max/online-study-room/actions/runs/30006967571) | `3061268` | manuel staging apply | Başarısız | Aynı stale guard; remote'a geçilmedi |
| [30007042924](https://github.com/manil-max/online-study-room/actions/runs/30007042924) | `33e63ab` | push validate | Başarılı | Local replay/pgTAP geçti |
| [30007050182](https://github.com/manil-max/online-study-room/actions/runs/30007050182) | `33e63ab` | manuel staging apply | Başarısız | `0069` staging'e uygulandı; remote pgTAP `005_push_delivery` satır 172'de durdu |
| [30007579826](https://github.com/manil-max/online-study-room/actions/runs/30007579826) | `9f6c571` | push validate | Başarılı | Local replay/pgTAP geçti |
| [30007588454](https://github.com/manil-max/online-study-room/actions/runs/30007588454) | `9f6c571` | manuel staging apply | Başarılı | DB zaten `0069`; salt-okunur post-check ilk health snapshot'ını verdi |
| [30009050419](https://github.com/manil-max/online-study-room/actions/runs/30009050419) | `514db21` | manuel staging apply | Başarılı | App-only fix olmasına rağmen full local replay ve remote no-op apply tekrarlandı |

### 6.2 Release Orchestrator — iki başarısız beta

| Run | Tag/SHA | Android | Windows | Final |
|---|---|---|---|---|
| [30007806029](https://github.com/manil-max/online-study-room/actions/runs/30007806029) | `beta-v4304 / 9f6c571` | Analyze geçti; full test 676/9; APK başlamadı | Full test geçti; build ajan tarafından iptal edildi | Release yok |
| [30009302420](https://github.com/manil-max/online-study-room/actions/runs/30009302420) | `beta-v4305 / 514db21` | Analyze geçti; full test 677/9; APK başlamadı | Test ajan tarafından iptal edildi | Release yok |

İptaller otomatik bir release sistemi sonucu değil; konuşma dökümünde ajan
`gh run cancel` komutunu açıkça çalıştırmıştır.

### 6.3 Önceki beta tabanı

- Android `beta-v4303` release:
  [run 29956967730](https://github.com/manil-max/online-study-room/actions/runs/29956967730),
  başarılı.
- Windows `beta-v4303`:
  [run 29956967665](https://github.com/manil-max/online-study-room/actions/runs/29956967665),
  başarısız.
- Buna rağmen GitHub prerelease Android APK ile yayımlandı; Windows
  MSIX/ZIP yoktu.

WP-269'un iki platform tamamlanmadan release finalize etmemesi tam olarak bu
eski kısmi-release kusurunu kapatmaktadır.

---

## 7. Beta blokajının ayrıntılı teknik analizi

### 7.1 Bildirim koordinatörü

`AppNotificationCoordinator` global singleton olarak doğrudan:

```dart
FlutterLocalNotificationsPlugin()
```

oluşturuyor.

Koordinatörde test için enjekte edilebilir:

- platform capability,
- plugin interface,
- notification enabled reader,
- fake/no-op adapter

yok.

### 7.2 Uygulama kökündeki tetik

`pushLifecycleListenerProvider` uygulama kökü boyunca auth ve notification
preference durumunu izliyor. Her context güncellemesinde:

```text
updateContext
  → unawaited(synchronize())
  → snapshot()
```

çalışıyor.

Bu nedenle görünürde push ile ilgisiz:

- login ekranı,
- sekme navigasyonu,
- profil badge'i,
- grup boş durumu,
- V8 temel akışları

aynı arka plan exception'ı yüzünden düşüyor.

### 7.3 Firebase yapılandırma dallanması

`FirebasePushConfig.resolveStatus` yalnız dört değerin boş/dolu olmasına bakar:

- hepsi boş → `notConfigured`,
- biri eksik → `incomplete`,
- hepsi dolu → `configured`.

Biçim veya gerçek credential doğrulaması yapmaz. Bu nedenle güvenli, sahte ama
dolu dört test değeri gerçek Firebase'e bağlanmadan configured kod yolunu
tetiklemek için yeterlidir.

### 7.4 Flutter test hedef platformu

Yerel Flutter SDK kaynağında:

```dart
if (Platform.environment.containsKey('FLUTTER_TEST')) {
  result = TargetPlatform.android;
}
```

bulunur.

Bu nedenle:

- Windows host + `flutter test`,
- Linux host + `flutter test`

ikisi de varsayılan olarak Android hedef davranışına girebilir.

Önceki “Windows'ta `_isAndroid` false olur” açıklaması bu test ortamında
geçerli değildir.

### 7.5 Üç farklı test manifesti

| Profil | Alan sayısı | Firebase alanları | Davranış |
|---|---:|---:|---|
| Yerel `app/env.json` | 2 | Yok | Push `notConfigured`; problemli dal çalışmaz |
| Yerel `app/env.cirepro.json` | 6 | Dört dolu test alanı | Problemli dal çalışır; hata yeniden üretilir |
| GitHub Android release `env.json` | 17 | Var | Problemli dal çalışır |
| GitHub Windows release `env.json` | 13 | Yok | Push `notConfigured`; problemli dal çalışmaz |

Karşı rapordaki Windows alan sayısı 14 olarak yazılmıştır; güncel
`windows-release.yml` manifestinde sayılan alan **13**tür. Bu küçük sayım farkı
ana teşhisi değiştirmez.

### 7.6 Aynı suite iki kez mi koşuyor?

Dosya/test adı olarak büyük ölçüde evet; kapsam olarak tamamen aynı değil.

- Android job: Firebase-configured beta profili.
- Windows job: Firebase-unconfigured desktop profili.
- Windows ayrıca `--concurrency=1` kullanıyor.
- Host dosya sistemi, timing ve build zinciri de farklı.

Dolayısıyla “ortak testleri tek profile indir” önerisi bu haliyle yanlıştır.
Doğru sadeleştirme:

1. configured profilini koru,
2. unconfigured profilini koru,
3. platforma özgü testleri ayır,
4. aynı semantik profilin gereksiz tekrarını kaldır.

---

## 8. `514db21` düzeltmesinin ayrıntılı kusurları

Commit:

```dart
try {
  await _plugin.initialize(settings: settings);
} on Error catch (error) {
  if (!error.toString().startsWith('LateInitializationError:')) {
    rethrow;
  }
  return;
}
```

ekledi.

### 8.1 Korunmayan ikinci erişim

`notificationsEnabled()`:

```dart
await initialize();
return await _plugin
    .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >()
    ?.areNotificationsEnabled() ?? false;
```

çalıştırır. `initialize()` geri döndükten sonra plugin singleton'ına tekrar
erişilir. CI stack'i tam bu satırı gösterir.

### 8.2 Yanlış kapsamlı test

Yeni test:

- Android target override yapıyor,
- yalnız `initialize()` çağırıyor,
- `notificationsEnabled()` çağırmıyor,
- `snapshot()` çağırmıyor,
- `PushHealthController` çalıştırmıyor,
- `OnlineStudyRoomApp` kök lifecycle'ını çalıştırmıyor,
- Firebase configured dalını test etmiyor.

Sonuç: yeni test geçtiği hâlde gerçek dokuz test değişmeden kaldı.

### 8.3 Kırılgan hata tanıma

Hata:

```dart
error.toString().startsWith('LateInitializationError:')
```

ile tanınıyor.

Bu:

- tipe/capability'ye değil metne bağlı,
- paket mesajı değişirse bozulur,
- test hostu ile gerçekten yanlış kayıtlı production plugin'ini ayıramaz,
- gerçek Android init problemini ilk noktada gizleyebilir.

### 8.4 Tekrarlanan başarısız init

Catch yolunda `_initialized = true` veya ayrı bir unsupported/test capability
durumu set edilmez. Sonraki çağrılar aynı init yolunu tekrar deneyebilir.

### 8.5 Benzer açık yüzeyler

Aynı koordinatörde:

- `requestPermission`,
- `showLocalTest`,
- `showRemote`,
- `showNudge`

platform plugin'ine erişir. Tek bir çağrıyı exception catch ile yamamak genel
koordinatör sözleşmesini düzeltmez.

### 8.6 Doğru düzeltme sınıfı

Tercih sırası:

1. Platform notification adapter/interface enjekte edilebilir olsun.
2. Widget/unit testinde fake/no-op adapter verilsin.
3. Runtime capability sonucu açık bir değer olsun:
   `supported`, `unavailableOnTestHost`, `ready`, `failed`.
4. `snapshot()` hata fırlatmak yerine kontrollü sağlık durumu üretsin.
5. Unawaited lifecycle future'ları yakalanmamış async error bırakmasın.
6. Configured ve unconfigured iki test profili ayrı doğrulansın.

---

## 9. Remote pgTAP arızasının düzeltilmiş analizi

### 9.1 Ne oldu?

`0069` staging'e başarıyla uygulandıktan sonra remote:

```text
005_push_delivery.test.sql:172
no rows returned for \gset
```

ile durdu.

Testin ilgili kısmı:

```sql
select delivery_id as alpha_retry_delivery
from public.claim_push_deliveries(worker_id, 1, 60)
where outbox_id = :alpha_test_outbox
\gset
```

### 9.2 İlk ajan açıklaması

Konuşmada:

> Dakikalık cron worker aynı test fixture'ını testten önce claim etti.

denildi.

Bu açıklama **kanıtlanmış değildir**.

### 9.3 Neden şüpheli?

Test dosyası `begin;` ile başlar. Yeni fixture aynı transaction içinde
oluşturulur. PostgreSQL MVCC altında başka bir cron/Edge session'ı commit
edilmemiş bu satırı normalde göremez.

Dolayısıyla dış cron'un yeni, uncommitted alpha fixture'ını kapması doğrudan
beklenen davranış değildir.

### 9.4 Daha doğrudan açıklama

`claim_push_deliveries(..., p_limit = 1, ...)` fonksiyonu:

1. bütün global delivery tablosundan,
2. en eski uygun satırı,
3. `limit 1` ile seçer,
4. onu processing yapar,
5. fonksiyon döndükten sonra dış sorgudaki
   `where outbox_id = alpha_test_outbox`
   filtresi uygulanır.

Staging'de testten önce eski pending satırlar varsa fonksiyon alpha fixture
yerine global eski satırı claim eder. Dış `where` onu filtreler ve `\gset`
“no rows returned” verir.

Sonraki health snapshot'larında gerçekten iki eski pending satır görülmüştür.
Bu nedenle **paylaşılan canlı queue'nun testi kirletmesi**, “cron yeni fixture'ı
yarışta aldı” açıklamasından daha doğrudan ve kodla uyumlu bir açıklamadır.

### 9.5 Ne kesin, ne değil?

Kesin:

- remote pgTAP live queue'dan izole değildir,
- claim testi global oldest queue davranışına bağlıdır,
- p_limit 1 + dış outbox filtresi deterministik izolasyon sağlamaz,
- canlı staging'de güvenilir bir fixture testi değildir.

Kesin değil:

- satırın cron tarafından mı, testin kendi global claim'i tarafından mı
  işlendiği,
- iki eski pending delivery'nin tam kaynağı,
- transaction hata sonrasında hangi test etkilerinin rollback olduğu.

### 9.6 Doğru çözüm

Remote pgTAP'ı tamamen kaldırmak yerine:

- claim RPC test için outbox/event anahtarıyla izole edilebilir,
- özel, izole staging test kullanıcısı/cihazı kullanılabilir,
- worker geçici durdurulmadan concurrency-safe fixture tasarlanabilir,
- test production benzeri shared queue'yu global `limit 1` ile tüketmemelidir,
- mutasyonlu tam pgTAP local disposable DB'de kalabilir,
- remote için salt-okunur ama gerçek invariant seti ayrıca yazılabilir.

---

## 10. Retry worker — P0 yayın blokajı

### 10.1 `0069` neyi vaat ediyor?

- `push-dispatch-retry-worker` isimli cron,
- her dakika `_request_scheduled_push_dispatch()`,
- private runtime config'ten Edge URL ve secret,
- `net.http_post`,
- Edge içinde `claim_push_deliveries`,
- geçici hatada retry/backoff,
- stuck lease'in yeniden claim edilmesi,
- read-only queue health.

### 10.2 İki snapshot ne kanıtlıyor?

21 dakika 24 saniyelik aralıkta aktif queue özeti hiç değişmedi.

Bu süre içinde cron yaklaşık 21 kez tetiklenmiş olmalıydı.

Eğer iki pending satır:

- `available_at <= now`,
- attempts < 6,
- ve normal active device/preference koşullarındaysa

worker Edge'deki claim fonksiyonuna ulaşınca en az bir durum değişikliği
beklenirdi:

- processing,
- retry,
- sent,
- skipped,
- failed_permanent,
- attempt artışı sonrası farklı durum.

Hiçbiri görünmüyor.

### 10.3 Ne henüz kanıtlanmıyor?

Health RPC şunları göstermiyor:

- delivery ID,
- `available_at`,
- `updated_at`,
- ilgili cihaz active/disabled durumu,
- notification type tercihi,
- cron active flag,
- cron run history,
- pg_net response/status,
- Edge HTTP sonucu.

Bu nedenle “worker kesin cron katmanında bozuk” denemez.

### 10.4 Kuvvetli ek çıkarım

İlk snapshot zamanı eksi `oldest_age_seconds` yaklaşık:

```text
2026-07-22 21:05 UTC
```

verir. `beta-v4303` release update bildirimi yaklaşık 21:02:51–21:02:55 UTC'de
çalışmıştır.

Bu yakınlık, iki satırın gerçek beta update fan-out'uyla ilgili olabileceğini
düşündürür; **kanıt değildir**. ID/type sorgusu olmadan kesin yazılamaz.

### 10.5 Zorunlu salt-okunur teşhis

Yeni beta veya mutasyon öncesi en az:

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname = 'push-dispatch-retry-worker';
```

```sql
select status, start_time, end_time, return_message
from cron.job_run_details
where jobid = (
  select jobid from cron.job
  where jobname = 'push-dispatch-retry-worker'
)
order by start_time desc
limit 20;
```

```sql
select
  id,
  outbox_id,
  device_id,
  status,
  attempts,
  available_at,
  lease_until,
  created_at,
  updated_at,
  last_error_code
from public.notification_deliveries
where status in ('pending', 'retry', 'processing')
order by created_at;
```

gerekir.

Gerekirse pg_net request/response geçmişi de salt-okunur incelenmelidir.
Sonuca göre yalnız ilgili katman düzeltilmelidir.

### 10.6 P0 hükmü

“Worker kesin şu nedenle bozuk” henüz denemez.

Fakat:

> İki eski pending satırın neden 21 dakika hiç ilerlemediği açıklanmadan ve
> worker'ın ardışık iki gözlem arasında gerçek bir delivery'yi ilerlettiği
> gösterilmeden beta cihaz kabulüne geçilemez.

Bu kesin bir **release-readiness P0**dır.

---

## 11. Health gate neden yanlış yeşil?

Güncel remote post-check:

- `cron.job` relation var mı,
- job adı var mı,
- health RPC var mı,
- RPC'yi çalıştır

kontrolü yapar.

Şunları kontrol etmez:

- cron `active`,
- schedule tam `* * * * *`,
- son cron run success/failure,
- son başarılı tick yaşı,
- pg_net HTTP sonucu,
- runtime config alanları null mı,
- Edge endpoint ulaşılabilir mi,
- queue age eşiği,
- pending/retry/stuck eşikleri,
- max attempt anomalisi,
- delivery'nin iki snapshot arasında ilerlemesi.

### 11.1 False configured

`get_push_dispatch_queue_health()`:

```sql
exists (
  select 1
  from push_dispatch_runtime_config
  where singleton = true
)
```

ise `configured` döndürür.

Ama worker:

```sql
if v_base_url is null or v_secret is null then
  return;
end if;
```

der.

Yani singleton satırı var, fakat URL/secret boşsa:

- health `configured`,
- worker no-op

olabilir.

### 11.2 Başarı semantiği

Bugünkü kapı:

```text
sorgu hata vermedi = success
```

anlamına gelir.

İstenen:

```text
worker yapılandırılmış + aktif + yakın zamanda başarılı +
queue kabul edilen sınırlar içinde = success
```

olmalıdır.

---

## 12. Edge Function deployment drift'i

### 12.1 Kesin gerçek

`87f7965`:

- `0069` migration'ını,
- `dispatch-push/index.ts` değişikliğini

aynı committe içerir.

Son kayıtlı Staging Push Activation:

- [run 29956832128](https://github.com/manil-max/online-study-room/actions/runs/29956832128)
- SHA `3bdf8bb`
- `87f7965`ten önce

çalışmıştır.

GitHub Actions kanıtına göre:

- staging DB: `0069`,
- son kayıtlı Edge deploy: `3bdf8bb`,
- app candidate: `514db21`.

### 12.2 Fonksiyonel önem

`87f7965` Edge diff'inin tek yeni davranışı:

```json
{"action":"health"}
```

isteğine claim yapmadan read-only health dönmektir.

Repo içinde bu action'ı çağıran aktif bir istemci/workflow yoktur.

Cron:

```json
{"source":"scheduled_retry"}
```

gönderir ve eski/yeni Edge sürümünde normal claim fallback'ine girer.

Bu nedenle stale Edge SHA:

- gerçek bir deployment identity/izlenebilirlik borcudur,
- fakat bugünkü retry stagnation'ının kanıtlanmış kök nedeni değildir,
- **P2** olarak izlenmelidir,
- yalnız bu gerekçeyle plansız ayrı deploy turu yapılmamalıdır.

### 12.3 Ayrı bir mevcut kusur

`Staging Push Activation` içindeki:

> Verify dispatcher health without enqueueing a notification

adımı `{"source":"staging_activation"}` gönderir.

Bu yeni `action:"health"` dalına girmez; normal claim worker'ını çalıştırır.
Yeni outbox üretmese de bekleyen kuyruğu tüketebilir. Adı “health” olsa da
salt-okunur değildir.

---

## 13. WP-269 ve yeni release mimarisi

### 13.1 Korunması gereken kazanımlar

- Database Gates artık Flutter/keystore/APK build yapmıyor.
- Android ve Windows tek orkestratör altında.
- İki zorunlu platform başarılı olmadan release finalize edilmiyor.
- Tek status manifesti `complete/partial/failed` gerçeği üretiyor.
- Production deploy/release varsayılanı false.
- Eski beta-v4303 kısmi release problemi tekrarlanmıyor.

### 13.2 Yeni sorun: doğrulama tag'den sonra

Mevcut beta:

```text
tag push
  → preflight
  → Android configured suite + build
  → Windows unconfigured suite + build
  → ikisi başarılıysa release
```

İlk CI-equivalent full suite tag'den sonra çalıştığı için:

- deterministik test hatası kalıcı tag yakıyor,
- düzeltme için yeni beta numarası gerekiyor,
- ajan zaman baskısıyla dar fix atıyor,
- ikinci tag de aynı gerçek zincir sınanmadan yakılabiliyor.

### 13.3 Doğru model

```text
candidate verify (immutable SHA)
  → configured profile
  → unconfigured/desktop profile
  → Android build smoke
  → Windows build/package smoke
  → staging evidence identity
  → hepsi yeşilse benzersiz tag
  → doğrulanmış SHA/artefakt publish
```

WP-269 geri alınmamalı; verification tag'in önüne taşınmalıdır.

---

## 14. Database Gates tekrar maliyeti

### 14.1 Kanıtlanan tekrar

- DB/tooling push'u otomatik validate çalıştırıyor.
- Manuel staging apply `needs: validate` ile aynı full local replay'i yeniden
  çalıştırıyor.
- Migration uygulandıktan sonraki tooling fix'inde apply tekrarlandı.
- Yalnız app/test dosyası değiştiren `514db21` için bile staging apply tekrar
  çalıştırıldı.

### 14.2 Neden zararlı?

- Aynı güvenlik kanıtı tekrar üretiliyor.
- Kullanıcı/ajan bekleme süresi artıyor.
- Her yeni kırmızı log yeni “fix” baskısı doğuruyor.
- App bug'ı DB hattıyla zihinsel olarak karışıyor.
- Workflow başarı rengi gerçek değişiklik türünü anlatmıyor.

### 14.3 Evidence upload gürültüsü

İlk guard testinde evidence directory oluşmadan hata geldi.
`if-no-files-found: error` ikinci bir upload hatası üretti.

Ana hata:

```text
local migration head expected 0068, got 0069
```

iken logda ayrıca:

```text
No files were found...
```

görüldü.

Evidence manifesti guard başlamadan oluşturulmalı veya bu erken hata yolu
ayrı ele alınmalıdır.

### 14.4 Değişiklik-türü matrisi

| Değişiklik | Zorunlu doğrulama |
|---|---|
| Dart/UI/test | Analyze + ilgili test + configured/unconfigured aday profilleri |
| Android native | Native/contract test + Android build |
| Windows native/package | Windows test + MSIX/ZIP build |
| Migration/DB | Bir local replay/pgTAP + bir remote list/dry-run/apply/post-check |
| Edge Function | Type-check/test + gerektiğinde tek activation/deploy |
| Release metadata | Changelog/manifest/tag identity; DB apply yok |

---

## 15. Beta ve stable akışının güncel kullanıcı deneyimi

### 15.1 Beta

Bugünkü fiilî adımlar:

1. Kod ve gerekiyorsa migration commit'i.
2. Otomatik DB validate.
3. Elle staging apply.
4. Edge değiştiyse ayrı activation.
5. Changelog ve release notes.
6. Benzersiz beta tag.
7. Release preflight.
8. Android configured suite/build.
9. Windows unconfigured suite/build.
10. İki platform başarılıysa prerelease.

Bu üç ayrı workflow ve aralarındaki manuel ilişki kullanıcıdan gizlidir.
“Beta çıkar” komutu basit görünür; ajan yanlış ilişki kurarsa bütün kapıları
her committe tekrar eder.

### 15.2 Stable

Güncel `release.yml`:

- tag push ile yalnız `beta-v*` dinler,
- stable için `workflow_dispatch` ister.

Stable girdileri:

- mevcut tag,
- channel,
- exact SHA,
- migration head,
- production confirmation,
- production evidence.

Bu, `.agents/AGENTS.md` içindeki:

> Yayın tamamen tag adından sürülür; elle flavor/env seçilmez.

anlatımıyla tam uyumlu değildir.

### 15.3 Çok sürtünme, eksik bağımsız onay

GitHub API doğrulaması:

- production Environment protection rules: boş,
- required reviewer: yok,
- prevent self-review: yok,
- `main` branch protection: yok.

`release-gate.ps1`:

- GitHub Actions ortamı,
- `production` environment adı,
- exact GO string,
- boş olmayan evidence string

kontrol eder.

Evidence'in gerçekten varlığını veya içeriğini doğrulamaz.
Environment'ın adı vardır, fakat bağımsız insan reviewer kapısı yoktur.

Bu nedenle sistem:

- kullanıcı açısından zor,
- fakat bağımsız approval açısından düşünüldüğü kadar güçlü değildir.

### 15.4 Güncel production hükmü

Yine de bu incident aralığında:

- production apply yok,
- production Edge deploy yok,
- yeni stable tag/release yok,
- v43 stable korunuyor,
- deploy contract production default false.

Mevcut stable için acil veri olayı kanıtı yoktur.

---

## 16. Kurallar ve yönetim dokümanları

### 16.1 Kurallar silinmedi

`beta-v4303` sonrası:

- kök `AGENTS.md` değişmedi,
- `.agents/AGENTS.md` değişmedi,
- worker skill değişmedi,
- planner skill değişmedi.

### 16.2 Gerçek problem: stale ve çelişkili kayıt

`progress.md`:

- üstte beta gerçeği `beta-v4303`,
- staging head `0068`,
- aktif lane `beta-v4305 hazırlanıyor`

yazıyor.

Gerçek:

- staging DB `0069`,
- `beta-v4305` tag'i atıldı,
- release başarısız,
- ajan durduruldu,
- aktif lane kapanmadı.

`docs/KALITE-PROGRAMI.md` kurtarma tabanı da `0068`de kalmış durumda.

`docs/AJAN-KULLANIM.md`:

- eski `v7/v8` anlatımı,
- canlı migration için SQL Editor yönlendirmesi

taşıyor ve güncel CLI/production kurallarıyla çelişiyor.

`app/pubspec.yaml`:

- hâlâ `1.0.43-beta.3+4303`.

Release workflow build name/number'ı tag'den override ettiği için bu bugünkü
doğrudan blocker değildir; fakat yerel görünen sürüm ile release metadata'sını
ayırarak hata riskini artırır.

### 16.3 Nihai yorum

Kurallar kaybolmadı.
**Operasyonel tek gerçek kaynağı yeniden güvenilirliğini kaybetti.**

---

## 17. Bildirim dışı kapsam drift'i

Kurtarma beta adayında doğrudan release blokajı olmayan fakat cihaz kabulünü
genişleten değişiklikler vardır:

### 17.1 Timer presentation

`a288461` v43 custom timer paneli için fallback davranışını geri getirmeyi
hedefliyor. Kod/contract testi vardır; gerçek Samsung cihaz kabulü yoktur.

### 17.2 Crown XP

`2b93c78` taç XP barını mutlak hedefe hizalar. Bildirim/release incident'ının
zorunlu parçası değildir.

### 17.3 Clock tools

`1bf619f`:

- Stopwatch,
- World Clock,
- StandBy

dosya/erişimlerini kaldırır. Kullanıcı görünür ürün değişikliğidir ve release
kurtarma adayının risk yüzeyini artırır.

### 17.4 Windows determinism

`fa4a168` timing testini deterministikleştirme yönünde doğrudur.
`beta-v4304` Windows full suite'i geçmiştir; fakat build ajan tarafından
iptal edildiği için güncel Windows release artefaktı yoktur.

---

## 18. Güvenlik ve veri durumu

### 18.1 Doğrulanan güvenli taraflar

- `0069` production'a uygulanmadı.
- Production Edge deploy yapılmadı.
- Yeni stable yayın yapılmadı.
- Service-role/private key repoya commit edilmedi.
- `env.cirepro.json` ignore kapsamında.
- `0069` kullanıcı session/XP/grup/başarım verisini silmiyor.
- Production default HOLD korunuyor.
- Beta/stable backend ayrımı devam ediyor.

### 18.2 Açık güvenlik/operasyon riskleri

- Production Environment bağımsız reviewer içermiyor.
- Main branch korumasız.
- Evidence string'i varlık/içerik doğrulaması yapmıyor.
- Health configured false-positive üretebilir.
- Remote full invariant coverage kaldırılmış durumda.
- Staging deployable kimlikleri tek manifestte değil.

---

## 19. Nihai öncelik tablosu

| Öncelik | Bulgu | Etki | Kanıt durumu |
|---|---|---|---|
| P0 | Firebase-configured test profilinde `notificationsEnabled()` kayıtsız plugin'e erişiyor | Aynı 9 test düşüyor; APK build başlamıyor | Kesin, yerelde yeniden üretildi |
| P0 | `514db21` gerçek zinciri test etmiyor | Yanlış yeşil test ikinci tag'i yaktı | Kesin |
| P0 | Yerel varsayılan aday profili Android CI profilini temsil etmiyor | “Yerelde yeşil” yanlış güven üretiyor | Kesin |
| P0 | İki eski pending delivery 21:24 boyunca hiç ilerlemedi | Retry worker kabul edilmeden beta anlamsız | Durum kesin; kök katman açık |
| P1 | Health kapısı çıktıyı yorumlamıyor | Donmuş/yaşlı queue ile success | Kesin |
| P1 | `configuration_status` yalnız satır varlığına bakıyor | Eksik config `configured` görünebilir | Kesin |
| P1 | Remote pgTAP canlı global queue'dan izole değil | Deterministik olmayan staging testi | Kesin |
| P1 | Remote pgTAP tamamen kaldırıldı | Staging invariant kanıtı aşırı zayıfladı | Kesin |
| P1 | Doğrulama tag'den sonra | 4304 ve 4305 numaraları yakıldı | Kesin |
| P1 | App-only fix'te staging apply tekrarlandı | Süre, log ve zihinsel gürültü | Kesin |
| P1 | Production Environment korumasız | Bağımsız owner approval yok | Kesin |
| P1 | Stable workflow ile kural anlatımı çelişkili | Kullanıcı hakimiyeti kayboluyor | Kesin |
| P1 | Staging activation “health” adımı queue claim ediyor | Salt-okunur sanılan çağrı iş yapıyor | Kesin |
| P2 | Staging Edge son kayıtlı SHA eski | İzlenebilirlik drift'i; bugünkü worker kökü değil | Kesin gerçek, düşük işlevsel öncelik |
| P2 | Progress/kalite/kılavuz/pubspec stale | Sonraki ajan yanlış gerçekle başlıyor | Kesin |
| P2 | Incident adayında ilgisiz ürün değişiklikleri var | Cihaz QA ve regresyon yüzeyi büyüyor | Kesin |
| P2 | Erken guard hatasında artifact upload ayrıca kırmızı | Log gürültüsü | Kesin |

---

## 20. Nihai kurtarma operasyonu

Bu bölüm uygulanabilir yürütme modelidir. Numaralar bağımlılıkları gösterir;
Faz 1–2 ile Faz 3 aynı anda başlar:

```text
Lane A: Faz 1 → Faz 2
        yerel profil eşliği + uygulama düzeltmesi

Lane B: Faz 3 → Faz 4/5
        salt-okunur retry teşhisi + güvenilir health/test kapıları

Lane A + Lane B yeşil
        ↓
Faz 6: GitHub'da tagsiz SHA Candidate Verify
        ↓
Faz 7: benzersiz beta tag'i + gerçek cihaz kabulü
```

Bu rapor bu fazları uygulamamıştır.

### Faz 0 — Freeze ve taban

1. `beta-v4304` ve `beta-v4305` tag'leri silinmez, taşınmaz, yeniden kullanılmaz.
2. `beta-v4306` henüz atılmaz.
3. Production/stable HOLD korunur.
4. App-only düzeltme için Database Gates staging apply çalıştırılmaz.
5. Yeni ürün özelliği bu incident adayına alınmaz.
6. Staging'deki iki pending delivery açıklanana kadar push “çalışıyor” denmez.

### Faz 1 — Kalıcı CI-equivalent aday profili

Amaç:

> Yerelde yeşil ile CI'da yeşil aynı şeyi ifade etsin.

Gerekli çıktı:

- güvenli placeholder'larla Android configured manifest şablonu,
- Windows/unconfigured manifest şablonu,
- tek komutlu candidate verification script'i,
- secret veya gerçek local env değeri loglamayan üretim.

Önemli adlandırma:

`app/env.ci.example.json`, mevcut negasyon kuralı sayesinde repoya alınabilir:

```gitignore
**/env.json
**/env.*.json
!**/env.*.example.json
```

Dolayısıyla bu ad için yeni bir gitignore istisnası gerekmez.

`tooling/fixtures/candidate-android-defines.example.json` gibi farklı bir konum
yalnız düzen/aitlik tercihi olabilir; ignore zorunluluğu değildir.

Mevcut `env.cirepro.json` geçici kanıttır; kalıcı çözüm değildir ve gerçek
Supabase yerel değerlerini taşıdığı için commit edilmemelidir.

Configured profil 17 release alanını; unconfigured profil 13 Windows alanını
semantik olarak temsil etmelidir. Test için gerçek Firebase credential gerekmez;
dört değerin dolu olması problemli dalı tetiklemeye yeterlidir.

Kabul:

- aynı komut bütün ajanlarca yerelde çalıştırılabilir,
- bugünkü committe deterministik olarak kırmızı,
- fix commitinde deterministik olarak yeşil,
- çıktı secret içermez.

### Faz 2 — Notification adapter sınırını düzelt

Gerekli tasarım:

- enjekte edilebilir local notification adapter,
- gerçek Android adapter,
- test/no-op adapter,
- capability sonucu,
- kontrollü error state.

Kaldırılması gereken:

- exception mesajı string prefix kontrolü,
- yarım initialize sonrası plugin'e tekrar erişim,
- yakalanmamış unawaited lifecycle future hatası.

Zorunlu testler:

1. Firebase unconfigured `snapshot`.
2. Firebase configured + fake plugin `snapshot`.
3. Configured + notification enabled true/false.
4. Configured + permission denied.
5. Adapter unavailable/test host.
6. Adapter init gerçek error.
7. `PushHealthController.synchronize`.
8. Auth user null/non-null.
9. `OnlineStudyRoomApp` root widget.
10. Bugünkü dokuz widget/V8 senaryosu.
11. `requestPermission`.
12. `showLocalTest`.
13. `showRemote`.
14. `showNudge`.

Kabul:

- configured profilde full suite yeşil,
- unconfigured profilde full suite yeşil,
- test hostunda exception yok,
- gerçek init error sessizce yutulmuyor.

### Faz 3 — Retry worker salt-okunur teşhis (Faz 1–2 ile paralel)

Bu iş app fix'ine bağlı değildir ve en uzun dış-sistem teşhis süresine sahiptir.
Faz 1 ile aynı anda başlatılır. Önce mutasyon yapılmadan:

1. cron job var/active/schedule,
2. son 20 cron run,
3. pg_net sonuçları,
4. runtime config alan doluluğu,
5. pending/retry/processing delivery ayrıntıları,
6. ilgili outbox type/event key,
7. cihaz disabled/preference durumu,
8. `available_at`,
9. attempts/updated_at

toplanır.

Karar ağacı:

```text
cron yok/inactive
  → cron kurulumu/activation düzelt

cron success ama HTTP yok
  → pg_net request/response ve endpoint

HTTP 401
  → runtime secret/Edge secret eşleşmesi

HTTP 404/5xx
  → Edge route/deploy/config

Edge 200 claimed=0
  → delivery eligibility/available_at/device preferences

claimed>0 ama durum kapanmıyor
  → provider auth/FCM/completion RPC
```

Yalnız kanıtlanan katman değiştirilir.

### Faz 4 — Health gate'i gerçek kapıya dönüştür

Zorunlu post-check:

- cron relation var,
- job var,
- job active,
- schedule doğru,
- son başarılı run belirlenen süreden yeni,
- son N run içinde tekrar eden hata yok,
- runtime config URL ve secret null değil,
- stuck lease 0,
- queue age eşiği altında veya açık fixture istisnası var,
- latest error sınıfı kabul edilebilir,
- ardışık iki gözlemde test delivery ilerliyor.

Health SQL salt-okunur kalmalıdır.

### Faz 5 — Remote test izolasyonu

Seçenekler:

1. Tam mutasyonlu pgTAP yalnız disposable local DB.
2. Remote staging için salt-okunur invariant paketi.
3. Gerekliyse ayrı sentetik kullanıcı/device namespace'i.
4. Claim testi için global oldest queue yerine açık outbox-bound test yolu.

Yapılmaması gereken:

- shared canlı queue'da `limit 1` global claim,
- cron race diye varsayıp tüm remote testi kaldırmak,
- test cleanup'ı gerçek kullanıcı delivery'lerine dokundurmak.

### Faz 6 — Tag öncesi GitHub Candidate Verify

Faz 1'in iki profilli Flutter doğrulaması yerelde tek komut ve kısa geri bildirim
olarak kalır. Android/Windows release build ve paket smoke'ları geliştirici
makinesine taşınmaz.

GitHub Actions'ta `workflow_dispatch` ile verilen tek immutable SHA için,
**tag/release/deploy oluşturmayan** bir candidate koşusu çalıştırılır:

1. release preflight validate-only,
2. configured full Flutter suite,
3. unconfigured full Flutter suite,
4. Android native/manifest testleri,
5. Android release build smoke,
6. Windows timing/platform testleri,
7. Windows release/MSIX/ZIP smoke,
8. changelog/release-notes identity,
9. migration head evidence,
10. gerekiyorsa Edge activation evidence.

Mevcut `release.yml` bu iş için doğrudan yeterli değildir: manuel girdide var
olan bir tag ister, o tag'i checkout eder ve başarılı sonunda GitHub Release
yayımlar. Bu nedenle ya ayrı bir `candidate-verify.yml` kurulmalı ya da mevcut
akışa açıkça yayın yapmayan, SHA checkout eden candidate modu eklenmelidir.

Candidate koşusu yalnız test/build artefaktı ve provenance manifesti üretir.
Başarılı koşudan sonra benzersiz tag aynı SHA'ya atılır. Mümkünse yayın,
doğrulanmış aynı artefaktları hash/provenance kontrolüyle terfi ettirir; yeniden
build edilecekse en azından SHA, env profili ve araç zinciri kimliği birebir
eşleşmelidir.

Candidate manifest:

```text
git SHA
channel
version/build
DB migration head
DB evidence run
Edge deployed SHA veya not-applicable
configured suite sonucu
unconfigured suite sonucu
Android build hash
Windows build hash
```

Hepsi yeşil olmadan tag oluşturulmaz.

### Faz 7 — Yeni beta ve gerçek cihaz kabulü

Ancak paralel Lane A (Faz 1–2), Lane B (Faz 3–5) ve ardından Faz 6 yeşil
olduktan sonra:

- yeni benzersiz `beta-v4306` veya o sıradaki kullanılmamış sıra,
- tag immutable,
- Android ve Windows tek release,
- release manifest `complete`,
- APK/MSIX/ZIP hash'leri,
- staging DB/Edge/app kimliği.

Gerçek cihaz kabulü:

- foreground FCM,
- background FCM,
- terminated-app FCM,
- local notification,
- self-test outbox,
- cihaz receipt,
- duplicate=0,
- geçici hata sonrası retry,
- invalid token,
- logout/unregister,
- timer notification start/stop,
- v43 presentation/fallback,
- Samsung cihaz,
- mümkünse Pixel/API karşılaştırması,
- en az 20 ölçümlü teslim,
- p95 hedefi,
- soak.

### Faz 8 — Stable ve yönetim

Beta kabulünden sonra:

- progress gerçekleri güncellenir,
- aktif lane kapatılır,
- kalite programı head/tag durumuna çekilir,
- ajan kullanım kılavuzu güncellenir,
- pubspec/tag metadata politikası netleştirilir,
- production Environment'a gerçek required reviewer eklenir,
- prevent self-review açılır,
- stable runbook tek kullanıcı komutu hâline getirilir,
- production migration/Edge/release yine backup, dry-run, soak ve somut GO ister.

---

## 21. Nihai kabul matrisi

Bir sonraki ajan “çözüldü” diyebilmek için:

### Yerel/CI parity

- [ ] Android configured profil kalıcı ve yeniden üretilebilir.
- [ ] Windows/unconfigured profil kalıcı ve yeniden üretilebilir.
- [ ] Gerçek secret loglanmıyor.
- [ ] Aynı komut yerel ve CI'da aynı semantiği çalıştırıyor.

### Flutter/plugin

- [ ] Bugünkü aynı 9 test configured profilde geçiyor.
- [ ] Unconfigured profil bozulmadı.
- [ ] Regresyon testi `initialize()` değil gerçek `snapshot` zincirini kapsıyor.
- [ ] App root lifecycle testi var.
- [ ] String bazlı `LateInitializationError` ayrımı yok.
- [ ] Gerçek adapter init hatası görünür.

### Retry worker

- [ ] Cron active ve schedule doğru.
- [ ] Son run kayıtları başarılı.
- [ ] Runtime config alanları dolu.
- [ ] pg_net/Edge cevap zinciri kanıtlı.
- [ ] İki eski pending delivery açıklanmış.
- [ ] Uygun bir delivery ardışık health ölçümünde ilerliyor.
- [ ] Duplicate yok.

### Database/staging

- [ ] Staging migration head `0069`.
- [ ] Remote post-check değerleri yorumluyor.
- [ ] Shared queue'ya mutasyonlu global fixture testi yok.
- [ ] Local pgTAP tam yeşil.
- [ ] Remote invariant paketi yeşil.

### Build/release

- [ ] Tag öncesi candidate verify yeşil.
- [ ] Android APK build yeşil.
- [ ] Windows MSIX/ZIP build yeşil.
- [ ] Tag daha önce kullanılmamış.
- [ ] Tek GitHub prerelease iki platform artefaktını içeriyor.
- [ ] Release manifest `complete`.

### Cihaz

- [ ] Samsung foreground/background/terminated.
- [ ] Retry gerçek cihazda.
- [ ] Timer start/stop.
- [ ] v43 görünüm/fallback.
- [ ] En az 20 ölçüm.
- [ ] Kullanıcı kabulü.

---

## 22. Kesinlikle yapılmaması gerekenler

- Aynı tag'i başka commit'e taşımak.
- `beta-v4304` veya `beta-v4305`i yeniden kullanmak.
- Configured profili yerelde çalıştırmadan yeni tag atmak.
- `notificationsEnabled`, `requestPermission`, `show...` metotlarına dağınık
  exception catch eklemek.
- Hata mesajı metnine göre test hostu tanımak.
- App-only fix için staging migration apply çalıştırmak.
- Worker teşhisi olmadan Edge'i tahminen yeniden deploy etmek.
- Edge SHA drift'ini tek başına worker kök nedeni saymak.
- İki pending satırı görmezden gelip health'i başarılı saymak.
- `configured` değerini singleton satırı varlığına indirgemek.
- Shared staging kuyruğunda global `limit 1` claim testi yapmak.
- Remote pgTAP'ın tamamını kalıcı olarak tek existence sorgusuyla değiştirmek.
- İki config profilini tek profile indirip coverage kaybetmek.
- WP-269'un iki-platform atomik finalization'ını geri almak.
- Release kolaylaşsın diye ortam ayrımı, RLS, dry-run veya production GO
  korumalarını kaldırmak.
- Environment adı var diye required reviewer varmış gibi davranmak.
- `env.cirepro.json` veya gerçek yerel Supabase değerlerini commit etmek.
- Aynı incident beta içinde yeni ilgisiz ürün değişikliği yapmak.

---

## 23. Bir sonraki ajana verilecek kısa görev metni

```text
Önce docs/BETA-YAYIN-ARIZA-NIHAI-RAPORU-2026-07-23.md dosyasını tamamen oku.
Yeni tag, release, DB apply, Edge deploy veya production işlemi yapma.

İki bağımsız işi yürüt:

1) Android CI ile aynı Firebase-configured dart-define profilini secret
loglamadan yerelde üreten kalıcı candidate verification aracını kur. Mevcut
aynı 9 testi bu profilde kırmızı olarak yeniden üret. AppNotificationCoordinator
platform adapter'ını enjekte edilebilir yap; string bazlı LateInitializationError
yutmayı kaldır; snapshot → PushHealthController → OnlineStudyRoomApp zincirini
test et. Configured ve unconfigured full suite yeşil olmadan tamamlandı deme.

2) Staging'de yalnız salt-okunur inceleme yap: cron.job active/schedule,
cron.job_run_details, pg_net sonucu, runtime config alan doluluğu ve iki pending
notification_delivery satırının status/attempts/available_at/updated_at/error
alanlarını çıkar. Kök katmanı kanıtlamadan mutasyon yapma.

Her iki işin kanıtını raporla. Sonra mevcut release.yml'yi tagsiz candidate
koşusu sanma: workflow_dispatch bugün mevcut tag ister ve release yayımlar.
Android/Windows build doğrulamasını GitHub'da exact SHA üzerinde, tag/release/
deploy üretmeyen ayrı candidate workflow veya mod ile çalıştır. beta-v4306
ancak bu koşu da yeşil olduktan sonra ayrı yayın adımıdır.
```

---

## 24. Kanıt indeksi

### Release

- `beta-v4303` Android başarı:
  https://github.com/manil-max/online-study-room/actions/runs/29956967730
- `beta-v4303` Windows başarısız:
  https://github.com/manil-max/online-study-room/actions/runs/29956967665
- `beta-v4304` başarısız:
  https://github.com/manil-max/online-study-room/actions/runs/30007806029
- `beta-v4305` başarısız:
  https://github.com/manil-max/online-study-room/actions/runs/30009302420

### Database Gates

- stale guard push:
  https://github.com/manil-max/online-study-room/actions/runs/30006956698
- stale guard manual:
  https://github.com/manil-max/online-study-room/actions/runs/30006967571
- `0069` local validate:
  https://github.com/manil-max/online-study-room/actions/runs/30007042924
- `0069` apply + remote pgTAP failure:
  https://github.com/manil-max/online-study-room/actions/runs/30007050182
- post-check tooling validate:
  https://github.com/manil-max/online-study-room/actions/runs/30007579826
- ilk read-only health snapshot:
  https://github.com/manil-max/online-study-room/actions/runs/30007588454
- ikinci health snapshot:
  https://github.com/manil-max/online-study-room/actions/runs/30009050419

### Edge activation

- Son kayıtlı staging activation:
  https://github.com/manil-max/online-study-room/actions/runs/29956832128

### Ana kaynak dosyalar

- `.github/workflows/release.yml`
- `.github/workflows/windows-release.yml`
- `.github/workflows/database-gates.yml`
- `.github/workflows/staging-push-activation.yml`
- `app/lib/core/config/firebase_push_config.dart`
- `app/lib/core/notifications/app_push_notification_service.dart`
- `app/lib/data/providers/push_notification_providers.dart`
- `app/test/widget_test.dart`
- `app/test/features/v8_critical_flows_test.dart`
- `app/test/core/app_notification_coordinator_test.dart`
- `supabase/migrations/0066_push_notification_delivery.sql`
- `supabase/migrations/0069_push_dispatch_retry_health.sql`
- `supabase/functions/dispatch-push/index.ts`
- `supabase/tests/005_push_delivery.test.sql`
- `tooling/supabase/DeployGuard.psm1`
- `tooling/supabase/remote.ps1`
- `tooling/release/release-preflight.ps1`
- `tooling/release/release-gate.ps1`
- `tooling/release/deploy-contract.json`
- `progress.md`
- `.agents/AGENTS.md`
- `docs/KALITE-PROGRAMI.md`
- `docs/AJAN-KULLANIM.md`

---

## 25. Önceki raporlar arasındaki anlaşmazlıkların nihai çözümü

| Tartışma | Nihai hüküm |
|---|---|
| Yerel/CI farkı OS mi? | **Hayır.** Ana fark dört Firebase define'ının doluluğu |
| Linux gerekli mi? | Hayır; bug Windows'ta configured profil ile birebir üretiliyor |
| `514db21` root cause'u çözdü mü? | Hayır; yalnız `initialize()` test edildi |
| Aynı 9 test mi? | Evet |
| Suite tamamen gereksiz iki kez mi koşuyor? | Hayır; configured ve unconfigured coverage farklı. Yürütme optimize edilebilir, iki profil korunmalı |
| Retry worker kesin bozuk mu? | Queue'nun ilerlemediği kesin; kök katman salt-okunur teşhis olmadan kesin değil |
| Retry konusu release P0 mı? | Evet; özelliğin kabulü kanıtlanmadan beta anlamsız |
| Edge deploy SHA eski mi? | Evet |
| Eski Edge retry'ı doğrudan bozuyor mu? | Kanıt yok; scheduled source eski claim fallback'inde de çalışır |
| Edge drift önceliği | P2 izlenebilirlik |
| Remote pgTAP'ı cron mu bozdu? | Kanıtlanmadı; global oldest claim + eski pending queue daha doğrudan açıklama |
| Remote pgTAP kaldırılması doğru mu? | Shared mutation yarışı kaldırılmalıydı; fakat bütün remote invariant coverage'ı kaldırmak aşırı düzeltme |
| WP-269 geri alınmalı mı? | Hayır; atomik iki-platform finalization korunmalı |
| Kurallar silindi mi? | Hayır |
| Production etkilendi mi? | Bu incident aralığında kanıt yok; v43 korunuyor |
| Süreç neden uzuyor? | Config parity yok + doğrulama tag sonrası + gate'ler sonucu değil komut çalışmasını ölçüyor |

---

## 26. Nihai sonuç

Bugünkü beta arızasının doğrudan kök nedeni artık yerelde ve CI'da aynı şekilde
kanıtlanmıştır:

> Firebase configured olduğunda uygulama kökündeki push health lifecycle'ı,
> native plugin registrant bulunmayan Flutter test hostunda doğrudan
> `FlutterLocalNotificationsPlatform.instance` erişimine giriyor.

`514db21` bu zincirin yalnız ilk `initialize()` halkasını yamadığı için aynı
dokuz hata devam etmektedir.

Ancak beta yayınını yalnız bu kod fix'iyle tekrar denemek doğru değildir.
Staging'deki iki eski pending delivery'nin 21 dakika boyunca hiç ilerlememesi,
retry worker kabulünün eksik olduğunu göstermektedir. Kök katman henüz belli
değildir; cron/pg_net/Edge/config/eligibility salt-okunur ayrıştırılmalıdır.

WP-269'un iki-platform atomik release modeli doğru bir kazanımdır. Sorun
kapının varlığı değil:

- CI profili yerelde yeniden üretilemeden tag atılması,
- değişiklik türüne bakmadan DB gate tekrarları,
- health değerlerinin yorumlanmaması,
- remote test izolasyonunun olmaması,
- ve kullanıcıya tek sade, kanıt-temelli komut yüzeyi sunulmamasıdır.

Proje çöpe atılacak veya topluca revert edilecek durumda değildir.
Stable v43 korunmalı; beta hattı kısa süre dondurulmalıdır. Configured test
profili ve notification adapter sınırı bir hatta düzeltilirken retry worker
ayrı hatta gerçek staging verisiyle salt-okunur kanıtlanmalıdır. İki hat da
yeşil olduktan sonra GitHub'da tagsiz SHA candidate verification çalışmalıdır.

**Yeni beta tag'i paralel Lane A (Faz 1–2), Lane B (Faz 3–5), ardından Faz 6
ve ilgili kabul maddeleri tamamlanmadan atılmamalıdır.**
