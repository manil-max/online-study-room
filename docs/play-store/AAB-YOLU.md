# Play AAB yolu — üretim, imzalama, indirme

> **WP-527.** Play Console yeni uygulamada APK kabul etmez, **AAB** ister.
> Bu dosya AAB'nin nasıl üretildiğini, nasıl imzalandığını ve sahibin dosyayı
> nereden alıp Console'a yükleyeceğini anlatır.
> Kapıların genel durumu: `docs/play-store/PLAY-RELEASE-GATE.md`.
> Console adımları: `docs/play-store/YAYIN-PLANI.md`.

---

## 1. AAB ne zaman üretilir

**Yalnız stable yayında.** `.github/workflows/release.yml` içindeki `android`
işi, `vNN` tag'iyle koşan turda APK'dan sonra üç adım daha çalıştırır:

| Adım | Ne yapar |
|---|---|
| `Play AAB env dosyasi (DISTRIBUTION_CHANNEL=play)` | `env.json`'dan `env.play.json` türetir |
| `Play AAB derle (yalniz stable)` | `flutter build appbundle --release --flavor play` |
| `Play AAB artefaktini paketle` | AAB'yi `flutter-apk/` altına taşır, SHA-256 üretir, `platform-manifest.json`'a ekler |

Üçü de `if: needs.preflight.outputs.channel == 'stable'` ile korunur.
**Beta turunda AAB üretilmez** — beta GitHub sideload kanalıdır, Play'e girmez.

## 2. `env.play.json` neden ayrı dosya

`env.json` içindeki `DISTRIBUTION_CHANNEL` değeri `github`. Play derlemesinde
bu değer **`play`** olmalı (uygulama içi APK indirme/kurma yolu kapanır —
Play politikası şartı, `app/lib/core/config/distribution_channel.dart`).

Aynı anahtarı hem `--dart-define-from-file` hem `--dart-define` ile vermek
yerine **ayrı bir dosya** üretiliyor: iki bayrak çakıştığında hangisinin
kazandığı `flutter_tools` iç detayıdır ve sürümle değişebilir; ayrı dosyada
belirsizlik yok.

Dosya `env.json`'un birebir kopyasıdır, **yalnız** `DISTRIBUTION_CHANNEL`
farklıdır. `LEGAL_BASE_URL` dahil bütün anahtarlar aynen taşınır. Workflow
adımı bunu derleme anında `assert` ile kanıtlar:

- `assert base['DISTRIBUTION_CHANNEL'] == 'github'` — APK env'i beklendiği gibi
- `assert base['LEGAL_BASE_URL']` — yasal adres Play derlemesinde de var
- `assert again == base` — APK'nın `env.json`'u Play adımından etkilenmedi
- `drop(play) == drop(base)` — iki dosya tek anahtar dışında birebir aynı

`env.play.json` repoya girmez; `.gitignore:9` (`**/env.*.json`) kapsar.

> Not: `play` flavor'ı ayrıca Flutter tarafından `FLUTTER_APP_FLAVOR=play`
> enjekte edilerek derlenir. Define unutulsa bile kanal `play`'e düşer
> (`distribution_channel.dart:105`). Ayrı env dosyası bunun **yedeği** değil,
> açık niyetidir; ikisi birden var.

## 3. İmzalama

`release.yml`'deki `İmzalama anahtarını hazırla` adımı, APK ve AAB için **aynı**
anahtarı hazırlar — Play için ikinci bir keystore yok:

```
KEYSTORE_BASE64  → base64 -d → app/android/key.jks
STORE_PASSWORD / KEY_PASSWORD / KEY_ALIAS → app/android/key.properties
```

`app/android/app/build.gradle.kts` `release` buildType'ı `key.properties`
yoksa **derlemeyi durdurur** (debug imzasına düşmez). Yani imzasız/debug imzalı
bir AAB üretilemez.

### Play App Signing ile ilişki

Play Console'a yüklediğin AAB'yi imzalayan `key.jks` **upload key**'dir.
Google, uygulamayı kullanıcıya dağıtırken kendi tuttuğu **app signing key** ile
yeniden imzalar. Pratik sonuçları:

- Upload key kaybolursa uygulama ölmez — Console'dan upload key sıfırlama
  talebi açılır. (GitHub sideload APK'sında böyle bir kurtarma **yoktur**;
  `key.jks` orada kalıcıdır, `AGENTS.md §2`.)
- Yine de `key.jks`'in çevrimdışı bir kopyası sahipte durmalı.
- Play'in gösterdiği SHA-1/SHA-256 parmak izleri **app signing key**'e aittir;
  Supabase/Firebase tarafına parmak izi girilecekse Console'daki
  *App integrity → App signing* sayfasındaki değer kullanılır, yerel
  `key.jks`'inki değil.

> ⚠️ **Aynı paket adı, farklı imza.** `play` flavor'ı stable ile aynı
> `applicationId`'yi kullanır (`com.manilmax.online_study_room`,
> `build.gradle.kts:159`). GitHub'dan kurulmuş stable sürüm bizim `key.jks`
> imzasını, Play sürümü Google'ın app signing key imzasını taşır. Android
> **imza değişen güncellemeyi reddeder**: Play sürümü GitHub sürümünün üzerine
> kurulamaz, önce kaldırmak gerekir (yerel veri gider). Bugün stable'ı 3 kişi
> GitHub'dan kullanıyor — Play'e geçişte bu kişilere önce kaldır/yeniden kur
> denmelidir. `Cihazda doğrulanmalı`.

## 4. Sahip: AAB'yi nereden alıp nereye yükleyecek

1. `vNN` tag'i atıldıktan sonra workflow biter; GitHub → **Releases** → o
   sürümün sayfası.
2. Assets listesinden iki dosyayı indir:
   - `app-play-release.aab` ← **Console'a yüklenecek dosya budur**
   - `app-play-release.aab.sha256` ← doğrulama karması
3. İstersen doğrula (PowerShell):
   ```powershell
   Get-FileHash .\app-play-release.aab -Algorithm SHA256
   ```
   Çıkan değer `.sha256` dosyasındaki ile aynı olmalı.
4. Play Console → uygulaman → **Test ve yayınla** → ilgili kanal (kapalı test /
   üretim) → **Yeni sürüm oluştur** → AAB'yi sürükle-bırak.

`app-release.apk` **Play'e yüklenmez** — o GitHub sideload sürümüdür.

> Yükleme otomatik **değildir**. Bilinçli karar: Play'e otomatik yükleme
> servis hesabı + Play Developer API anahtarı ister; o anahtar repoya/CI'a
> girmeden önce ayrı bir sahip kararı gerekir. Bu turda kurulmadı.

## 5. Kapı: adım gerçekten duruyor mu

`tooling/release/release-preflight.ps1` stable kanalda `release.yml` kaynağını
tarar ve şunların hepsini arar; biri yoksa **yayın başlamadan** durur:

- `flutter build appbundle --release --flavor play … --dart-define-from-file=env.play.json`
- `if: needs.preflight.outputs.channel == 'stable'`
- `DISTRIBUTION_CHANNEL='play'`
- `assert base['LEGAL_BASE_URL']`
- `assert again == base`
- `app-play-release.aab` · `sha256sum app-play-release.aab`
- `release-assets/android/*.aab`

Bu kapının kendisi `tooling/release/release-preflight.tests.ps1` içinde **kırık
girdiyle** sınanır: yukarıdaki parçaların her biri tek tek silinmiş bir
workflow kopyasında kapı kırmızı düşmeli, bozulmamış kopyada yeşil kalmalı.
Sebebi: bu repoda "kural yazılıydı ama çağıran yoktu" hatası iki kez üretime
çıktı (v59 boş sürüm notları). Çağrılmayan kapı kapı değildir.

## 6. Yerelde elle AAB üretmek

CI'daki ile aynı sonucu almak için (imzalama için `app/android/key.properties`
+ `key.jks` yerelde bulunmalı):

```powershell
cd app
# env.json'dan Play env'i turet
python -c "import json;b=json.load(open('env.json'));b['DISTRIBUTION_CHANNEL']='play';json.dump(b,open('env.play.json','w'))"
flutter build appbundle --release --flavor play `
  --build-name=1.0.61 --build-number=61 `
  --dart-define-from-file=env.play.json
```

Çıktı: `app/build/app/outputs/bundle/playRelease/app-play-release.aab`.
(CI bu yolu sabit yazmaz, `find build/app/outputs/bundle -name '*.aab'` ile
bulur; AGP çıktı yolunu değiştirse bile tur kırılmaz, yalnız yayınlanan ad
`app-play-release.aab` olarak sabittir.)

`CHANNEL=stable` + `APP_ENVIRONMENT=production` şarttır: `play` flavor'ı için
Gradle kapısı (`build.gradle.kts:36` `validateEnvironmentIdentity`) production backend'i zorunlu tutar, yani
elle üretilen AAB de yanlışlıkla staging'e bağlanamaz.
