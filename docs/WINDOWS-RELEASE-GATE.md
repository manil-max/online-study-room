# Windows Release Kapısı (WP-28)

Android `release.yml` ile paralel ama **ayrı** Windows hattı. Stable ZIP/EXE
imzasız dağıtım **stable sayılmaz**.

## Kanallar

| Kanal | Artefakt | İmza | Güncelleme |
|---|---|---|---|
| Geliştirme | `build/windows/.../Release` klasörü veya ZIP | Yok | Elle |
| Beta | `odak-kampi-windows-beta.msix` (+ sha256) | Self-signed QA veya test cert | In-app MSIX (prerelease etiket) |
| Stable sideload | `odak-kampi-windows-stable.msix` | Güvenilir kod imzası (secret) | In-app MSIX |
| Stable Store (öneri) | Store MSIX | Store imzası | Store update (ayrı identity planı) |

**Identity:** `OdakKampi.App` / publisher bir kez yayınlandıktan sonra kalıcıdır.
Store ve sideload identity’lerini plansız karıştırma.

## Gizli bilgiler (repoya girmez)

| Secret | Kullanım |
|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | `env.json` CI (dart-define) |
| `SENTRY_DSN` | opsiyonel |
| `WINDOWS_PFX_BASE64` + şifreler | *(ileride)* gerçek imza; yoksa self-signed |
| Store/Azure | Store kanalı açılınca |

## Yerel komutlar

```powershell
cd app
flutter pub get
flutter analyze
flutter test --dart-define-from-file=env.json --concurrency=1
flutter build windows --release --dart-define-from-file=env.json --build-number=8
# MSIX (pubspec msix_config; install_certificate: false)
dart run msix:create --build-windows false
```

Self-signed MSIX kurulumunda Windows SmartScreen / developer mode uyarısı **beklenen** QA davranışıdır.

## CI tetik

```text
git tag v8 && git push origin v8          # stable Windows + Android tag
git tag beta-v9 && git push origin beta-v9
# veya Actions → Windows Release → Run workflow
```

## Kapı kontrol listesi (stable sideload)

- [ ] `flutter analyze` 0  
- [ ] `flutter test` yeşil  
- [ ] Windows release build  
- [ ] MSIX üretildi + SHA-256  
- [ ] ZIP portable üretildi + SHA-256  
- [ ] GitHub Release asset adları sabit (`odak-kampi-windows-stable.msix`)  
- [ ] Temiz VM: install → launch → update → uninstall (`docs/QA-WINDOWS.md`)  
- [ ] Log’da secret yok  
- [ ] Rollback planı: aynı identity, daha yüksek bilinen-iyi build  

## Geri alma

Kötü sürüm: kullanıcıya bir önceki bilinen-iyi MSIX; forward-fix ile daha yüksek build.
Identity/publisher değiştirilmez.

## İlişki

| WP | Not |
|---|---|
| WP-27 / WP-53 | Shell/IA; 53 park (beyaz ekran debug ayrı) |
| WP-28 | Bu kapı — paket + CI + updater Windows kolu |
| Android release.yml | APK; Windows dosyalarına dokunmaz |
