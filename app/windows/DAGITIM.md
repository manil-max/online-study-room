# Windows Masaüstü — Derleme ve Dağıtım (WP-11 + WP-28 + WP-568)

Odak Kampı Windows sürümü **Flutter masaüstü** uygulamasıdır. “Windows widget”
ayrı bir OS bileşeni değildir; Compact Focus mini penceresi `lib/core/desktop/`
altındadır.

## Gereksinimler

- **Visual Studio 2022** + **Desktop development with C++** (MSVC, Windows SDK, CMake)
- Flutter stable; `flutter doctor` → Visual Studio satırı yeşil
- `app/env.json` (commit edilmez) — `SUPABASE_*` vb.

## Yerel release derleme

```powershell
cd app
flutter config --enable-windows-desktop
flutter pub get
flutter analyze
flutter test --dart-define-from-file=env.json --concurrency=1
flutter build windows --release --dart-define-from-file=env.json
```

Çıktı klasörü (birlikte dağıt):

```
app\build\windows\x64\runner\Release\
  online_study_room.exe
  flutter_windows.dll, eklenti DLL'leri
  data\
```

EXE metadata: `runner/Runner.rc` → ProductName **Odak Kampı**. Sürüm alanları
`FLUTTER_VERSION*` üzerinden `--build-name` / `--build-number` bayraklarından
gelir, yani CI'da tag'den türer; bayrak verilmezse `pubspec.yaml` `version:`
kullanılır.

## MSIX

```powershell
cd app
# Önce release build
flutter build windows --release --dart-define-from-file=env.json
# 🔴 --version ZORUNLU: pubspec'teki `msix_version` bir YER TUTUCUDUR, gerçek
# sürüm değildir (CI onu her koşumda komut satırından ezer). Bayraksız
# koşarsan paket o bayat değerle damgalanır ve CI paketinin üstüne kurulmaz.
dart run msix:create --build-windows false --version 1.0.<build>.0
```

Yapılandırma: `pubspec.yaml` → `msix_config`
- `identity_name: OdakKampi.App` (stable; **yayınlandıktan sonra kalıcı**)
- `install_certificate: false`
- `store: false` (sideload QA)

### 🔴 İmza gerçeği (yanlış bilinen konu)

`msix_config`e sertifika verilmediğinde paket, `msix` paketiyle birlikte
pub.dev'den herkese açık dağıtılan test sertifikasıyla (parola `1234`)
imzalanır. Bu durumda `publisher:` alanı **ölü anahtardır**: `msix` paketi onu
sertifikanın kendi öznesiyle ezer
(`CN=Msix Testing, O=Msix Testing Corporation, S=Some-State, C=US`).

Sonuç, eskiden burada yazdığı gibi bir “SmartScreen uyarısı” **değildir**.
Windows güvenilmeyen imza zincirini reddeder (`0x800B010A`) ve paket **hiç
kurulmaz**; kullanıcı yalnızca hata görür. Uygulama içi güncelleme de tam bu
noktada yarım kalır: dosya iner, kurulum başlamaz.

Bu yüzden `windows-release.yml` **stable kanalda fail-closed**: paket test
sertifikasıyla imzalanmışsa iş durur. Bilerek geçmek için repo değişkeni
`WINDOWS_ALLOW_TEST_SIGNING=true`. Gerçek imza için PFX yalnız CI secret;
repoya asla.

### Kanal başına paket kimliği (WP-568)

Beta ve stable Android'de ayrı `applicationId` kullanır (AGENTS.md §4.1).
Windows'ta da ayrılır; yoksa beta kurulumu stable'ı sessizce ezer ve beta paket
sürümü daha yüksek kaldığı için kullanıcı bir daha stable'a dönemez.

| Kanal | Identity | Görünen ad | Paket sürümü |
|---|---|---|---|
| stable | `OdakKampi.App` | Odak Kampı | `1.0.<patch>.0` |
| beta | `OdakKampi.App.Beta` | Odak Kampı (Beta) | `1.0.<patch>.<sıra>` |

Paket sürümü tek yerden türer: `version_name` ve `build_number` birbirini
doğrular, ayrışırsa iş paketleme başlamadan durur. Stable'da dördüncü alan `0`
bırakılır — Store gönderimi bunu şart koşar.

> **Bir kerelik geçiş:** WP-568 öncesi kurulmuş bir beta paketi `OdakKampi.App`
> kimliğini taşır ve yeni beta yanına ayrı uygulama olarak kurulur. Eskisi elle
> kaldırılmalıdır.

Sabit release asset adları (CI):

| Kanal | Dosya |
|---|---|
| stable | `odak-kampi-windows-stable.msix` |
| beta | `odak-kampi-windows-beta.msix` |
| portable | `odak-kampi-windows-{channel}.zip` |

ZIP, Release klasörünün MSIX **hariç** tamamıdır (MSIX de o klasöre yazıldığı
için eskiden arşiv kendi kurulumunun kopyasını taşıyordu).

## CI

`.github/workflows/windows-release.yml` — **yeniden kullanılabilir** iş akışı
(`workflow_call`). Kendi başına tetiklenmez ve **kendi başına GitHub Release
yayınlamaz**; `release.yml` onu tag'den türeyen kanal/sürüm/backend girdileriyle
çağırır ve artefaktları Release'e ekler.

Adımlar: analyze → test (golden dahil) → kanal/backend fail-closed guard →
`flutter build windows` → sürüm/kimlik sözleşmesi → MSIX → **paketin kendi
`AppxManifest.xml`'inden kimlik/sürüm doğrulaması** → imza kapısı → ZIP →
SHA-256 → `platform-manifest.json`.

Windows işi düşerse Android sürümü yine yayınlanır (`finalize_android`);
Release yalnız Windows artefaktı olmadan çıkar.

Android APK/AAB: `.github/workflows/release.yml` (ayrı).

Kapı sözleşmesi: `app/test/features/updater/windows_packaging_wp568_test.dart`
(uygulamanın aradığı asset adı ↔ CI'ın ürettiği ad ↔ Release'e eklenen ad).

## Güncelleme

- Android: APK in-app (mevcut)
- Windows: aynı GitHub API; **MSIX** asset + SHA-256; indirme sonrası `OpenFilex`
- Store kanalı ileride ayrı identity planı (`docs/WINDOWS-RELEASE-GATE.md`)

## Kapı ve QA

- Kapı: `docs/WINDOWS-RELEASE-GATE.md`
- Matris: `docs/QA-WINDOWS.md`
- Temiz kurulum/güncelleme: `docs/WINDOWS-VM-QA.md`

## Mini pencere

Compact Focus: Ctrl+Shift+M / UI; bounds cold-start'ta restore edilmez (WP-27).
