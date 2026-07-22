# Windows QA Matrisi (WP-28)

## 0. 10 saniyelik geliştirme smoke kontrolü

Kod değişikliğinden hemen sonra, açık Windows uygulamasında görünür pencere ve
yeni ekran görüntüsü kanıtı almak için:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows_fast_smoke.ps1 -NoLaunch
```

Bu komut en fazla 10 saniye içinde açık `online_study_room` penceresine bağlanır,
pencereyi öne getirir ve şu iki kanıtı yeniler:

- `app/build/windows_fast_smoke.png` — kullanıcının anında bakacağı ekran görüntüsü
- `app/build/windows_fast_smoke.json` — PASS/FAIL, süreç, pencere boyutu ve süre

Uygulama açık değilse `-NoLaunch` parametresini kaldırmak, mevcut Release EXE'yi
başlatır. Smoke'un açtığı uygulamayı ardından kapatmak istersen `-CloseAfter`
eklenir. Eski `windows_smoke_screenshot.ps1` çağrısı da aynı denetimi, yalnız
açık uygulamaya bağlanarak sürdürür.

Hızlı görsel geliştirme döngüsü:

1. Yerel geliştirme manifestiyle uygulamayı Windows'ta çalıştır: `cd app; flutter run -d windows --flavor local --dart-define-from-file=env.json`.
2. Hot reload sonrası ikinci terminalde smoke komutunu `-NoLaunch` ile çalıştır.
3. Yeni PNG'yi aç; PASS çıktısı olmayan değişiklik görsel olarak doğrulanmış sayılmaz.

Bu kontrol **yalnız kabuk/başlatma kanıtıdır**: uygulama açılır, kapanmaz,
görünür pencere verir ve yeni screenshot alınır. Giriş, timer, senkronizasyon,
MSIX kurulum/güncelleme ve Store otomatik güncellemesi için aşağıdaki QA matrisi
ayrıca uygulanır.

`env.json` yerel kanal sözleşmesine uymuyorsa uygulama bilinçli olarak
`invalid_channel` / ilgili tanı ekranını gösterir; bu bir test PASS'i değildir.
InMemory ile hızlı yerel çalışma için `env.local.example.json` dosyasının güvenli
kopyası kullanılır; staging veya production hesabına bağlı bir `env.json` bu amaçla
değiştirilmez. Hosted backend testi ise WP-259'un Sandbox/VM + staging manifesti
akışında yapılır.

Bu belge Windows release / MSIX kanıtını standardize eder. Emulator veya yalnız
`flutter run` debug kanıt sayılmaz. Test hesabı; token/e-posta ekran kaydına girmez.

## 1. Artefakt kimliği

| Alan | Değer |
|---|---|
| ProductName | Odak Kampı |
| Package identity | `OdakKampi.App` (pubspec `msix_config`) |
| Stable MSIX asset | `odak-kampi-windows-stable.msix` |
| Beta MSIX asset | `odak-kampi-windows-beta.msix` |
| Portable ZIP | `odak-kampi-windows-{channel}.zip` |
| SHA-256 | `*.msix.sha256` / `*.zip.sha256` |
| Etiket | `vN` / `beta-vN` (`N` = build number) |

## 2. Kurulum / güncelleme / kaldırma

| ID | Senaryo | Sonuç | Kanıt |
|---|---|---|---|
| W-01 | Temiz Windows 11, standart kullanıcı, MSIX kur | PASS/FAIL | |
| W-02 | İlk açılış (login veya demo) | PASS/FAIL | |
| W-03 | Aynı identity ile daha yüksek build update | Veri kaybı 0 | |
| W-04 | Uninstall | Kalıntı/shortcut | |
| W-05 | Self-signed SmartScreen uyarısı (beklenen QA) | Not | |
| W-06 | Portable ZIP çalıştır (tüm Release klasörü) | PASS/FAIL | |

## 3. Platform matrisi

| ID | Senaryo | Sonuç |
|---|---|---|
| W-10 | 1366×768 %100 | |
| W-11 | 1920×1080 %125 | |
| W-12 | 1440p %150 / %200 | |
| W-13 | Sleep/resume | |
| W-14 | Multi-monitor taşınma | |
| W-15 | Offline → online oturum | |
| W-16 | Android + Windows aynı test hesabı (WP-64 ile) | |

## 4. Updater (uygulama içi)

| ID | Senaryo | Beklenen |
|---|---|---|
| W-20 | Stable build, GitHub’da daha yeni stable MSIX | Diyalog + indirme + `OpenFilex` MSIX |
| W-21 | Aynı/düşük build | Diyalog yok |
| W-22 | SHA-256 uyuşmazlığı | Kurulum yok, hata metni |

## 5. Güvenlik

- [ ] PFX / store password log’da yok  
- [ ] `env.json` / service_role release zip’inde yok  
- [ ] SHA-256 dosyası release’e eklendi  

## 6. Koşum notu

1. CI: `.github/workflows/windows-release.yml`  
2. Yerel: `docs/WINDOWS-RELEASE-GATE.md`  
3. WP-53 beyaz ekran ayrı debug; paketleme bu matristen bağımsız koşulabilir  

**Etiket:** matris şablonu `Kodda doğrulandı`; doldurulmuş satırlar `Cihazda doğrulanmalı`.
