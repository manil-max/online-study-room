# Windows Masaüstü — Derleme ve Dağıtım (WP-11 + WP-28)

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

Metadata: `runner/Runner.rc` → ProductName **Odak Kampı**.

## MSIX (WP-28)

```powershell
cd app
# Önce release build
flutter build windows --release --dart-define-from-file=env.json
dart run msix:create --build-windows false
```

Yapılandırma: `pubspec.yaml` → `msix_config`  
- `identity_name: OdakKampi.App` (kalıcı)  
- `install_certificate: false`  
- `store: false` (sideload QA)  

Self-signed paket SmartScreen uyarısı verebilir (beklenen QA).  
Gerçek imza: PFX yalnız CI secret; repoya asla.

Sabit release asset adları (CI):

| Kanal | Dosya |
|---|---|
| stable | `odak-kampi-windows-stable.msix` |
| beta | `odak-kampi-windows-beta.msix` |
| portable | `odak-kampi-windows-{channel}.zip` |

## CI

`.github/workflows/windows-release.yml`

- Tag `vN` / `beta-vN` veya workflow_dispatch  
- analyze + test + windows release + MSIX + ZIP + SHA-256  
- Tag push’ta GitHub Release’e ekler  

Android APK: `.github/workflows/release.yml` (ayrı).

## Güncelleme

- Android: APK in-app (mevcut)  
- Windows: aynı GitHub API; **MSIX** asset + SHA-256; indirme sonrası `OpenFilex`  
- Store kanalı ileride ayrı identity planı (`docs/WINDOWS-RELEASE-GATE.md`)

## Kapı ve QA

- Kapı: `docs/WINDOWS-RELEASE-GATE.md`  
- Matris: `docs/QA-WINDOWS.md`  
- Ürün planı: `docs/WINDOWS-URUN-PLANI.md`  

## Mini pencere

Compact Focus: Ctrl+Shift+M / UI; bounds cold-start’ta restore edilmez (WP-27).
