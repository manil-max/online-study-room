# Windows Release Kapısı (WP-28 · WP-568 · WP-578)

Android `release.yml` ile paralel ama **ayrı** Windows hattı.

## 🔴 Birincil dağıtım yolu ZIP'tir (WP-578 kararı)

Windows'ta kullanıcıya giden **birincil** artefakt taşınabilir ZIP'tir. MSIX
üretilmeye devam eder ama **ikincildir ve şu an kurulamaz**: `pubspec.yaml`
`msix_config`'te sertifika yok, bu yüzden `msix` paketi pub.dev'de herkese açık
dağıtılan test sertifikasını kullanır ve `publisher:` anahtarını kendi
öznesiyle (`CN=Msix Testing, O=Msix Testing Corporation, S=Some-State, C=US`)
ezer. Windows böyle bir paketi `0x800B010A` ile **reddeder**.

Gerçek imzalı MSIX bir kod imzalama sertifikası **satın alma kararı** gerektirir
(`Ürün kararı gerekiyor`). O karar gelene kadar MSIX satırları "kurulamaz"
olarak okunur.

## Kanallar

| Kanal | Birincil artefakt | İkincil (kurulamaz) | Güncelleme |
|---|---|---|---|
| Geliştirme | `build/windows/.../Release` klasörü | — | Elle |
| Beta | `odak-kampi-windows-beta.zip` (+ sha256) | `odak-kampi-windows-beta.msix` | Uygulama içi ZIP (prerelease etiket) |
| Stable sideload | `odak-kampi-windows-stable.zip` (+ sha256) | `odak-kampi-windows-stable.msix` | Uygulama içi ZIP |
| Stable Store (öneri) | Store MSIX | — | Store update (ayrı identity planı) |

Uygulama içi güncelleme **yalnız ZIP asset'ini** arar
(`app/lib/features/updater/updater_service.dart`). Kurulamayan MSIX'i indirip
kullanıcıyı hata ekranına götürmek yerine hiç indirmez.

**Identity:** `OdakKampi.App` / publisher bir kez yayınlandıktan sonra kalıcıdır.
Store ve sideload identity'lerini plansız karıştırma.

## Gizli bilgiler (repoya girmez)

| Secret | Kullanım |
|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | `env.json` CI (dart-define) |
| `SENTRY_DSN` | opsiyonel |
| `WINDOWS_PFX_BASE64` + şifreler | *(ileride)* gerçek imza; yoksa `msix` paketinin herkese açık test sertifikası → paket **kurulamaz** |
| Store/Azure | Store kanalı açılınca |

## Yerel komutlar

```powershell
cd app
flutter pub get
flutter analyze
flutter test --dart-define-from-file=env.json --concurrency=1
flutter build windows --release --dart-define-from-file=env.json --build-number=8

# Birincil artefakt: taşınabilir ZIP (MSIX hariç Release klasörünün tamamı).
$release = 'build/windows/x64/runner/Release'
Compress-Archive -Path (Get-ChildItem $release | Where-Object { $_.Extension -ne '.msix' }).FullName `
  -DestinationPath odak-kampi-windows-stable.zip -Force

# İkincil (şu an kurulamaz) MSIX; --version zorunlu, bkz. app/windows/DAGITIM.md
dart run msix:create --build-windows false --version 1.0.8.0
```

🔴 **Düzeltme (WP-568/WP-578).** Burada eskiden "self-signed MSIX kurulumunda
Windows SmartScreen / developer mode uyarısı **beklenen** QA davranışıdır"
yazıyordu. **Yanlıştı.** Test sertifikasıyla imzalanmış MSIX bir uyarı değil
**sert blok** üretir (`0x800B010A`) ve hiçbir kullanıcıda kurulmaz.
Kullanıcıdaki karşılığı: güncelleme ~40 MB iner, kurulum hiç başlamaz.

Taşınabilir ZIP'te bu sorun yoktur: arşivde paket imzası aranmaz, dosyalar
çıkarılır ve `online_study_room.exe` çalışır. İlk çalıştırmada SmartScreen
"bilinmeyen yayımcı" uyarısı çıkabilir — *bu* gerçekten bir uyarıdır ve
kullanıcı geçebilir.

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
- [ ] **ZIP portable üretildi + SHA-256** (birincil yol)
- [ ] GitHub Release asset adları sabit (`odak-kampi-windows-stable.zip` + `.sha256`)
- [ ] Uygulama içi güncelleme: indir → SHA-256 doğrula → yönerge ekranı
- [ ] Temiz VM: arşivi boş klasöre çıkar → çalıştır (`docs/QA-WINDOWS.md`)
- [ ] MSIX üretildi + SHA-256 *(ikincil; imzasızken kurulamaz — kabul kriteri değil)*
- [ ] Log'da secret yok
- [ ] Rollback planı: bir önceki bilinen-iyi ZIP

### 🔴 Bilinen blok — stable Windows işi şu an düşer

`windows-release.yml` imza kapısı stable kanalda **fail-closed**: paket test
sertifikasıyla imzalanmışsa iş `throw` eder. İş düştüğü için `upload-artifact`
hiç koşmaz — yani **ZIP de yayınlanmaz**. Bu kapı WP-568'in kasıtlı kararıdır ve
WP-578 ona dokunmadı.

Stable Windows ZIP çıkarmak için ikisinden biri gerekir:

1. Gerçek kod imzalama sertifikası (satın alma kararı), ya da
2. Repo değişkeni `WINDOWS_ALLOW_TEST_SIGNING=true` — MSIX yine kurulamaz ama iş
   düşmez ve ZIP yayınlanır.

Beta kanalında böyle bir blok yok; kapı yalnız stable'da tetiklenir.

## Geri alma

Kötü sürüm: kullanıcıya bir önceki bilinen-iyi **ZIP**; forward-fix ile daha
yüksek build. MSIX kolu açıldığında identity/publisher değiştirilmez.

## İlişki

| WP | Not |
|---|---|
| WP-27 / WP-53 | Shell/IA; 53 park (beyaz ekran debug ayrı) |
| WP-28 | Bu kapı — paket + CI + updater Windows kolu |
| Android release.yml | APK; Windows dosyalarına dokunmaz |
