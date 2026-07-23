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

Yerel/InMemory ilk açılışındaki “Yenilikler” penceresini kapatıp ana ekranı
yakalamak için yalnız testte `-DismissInitialDialog` eklenebilir. Bu parametre
varsayılan olarak kapalıdır; giriş/üretim kullanıcısına ait pencerelerde otomatik
tuş gönderilmez.

Hızlı görsel geliştirme döngüsü:

1. Mevcut `env.json`u oturum sonunda geri yükleyen yerel çalışma aracını başlat: `powershell -ExecutionPolicy Bypass -File .\scripts\windows_local_dev.ps1`.
2. Hot reload sonrası ikinci terminalde smoke komutunu `-NoLaunch` ile çalıştır.
3. Yeni PNG'yi aç; PASS çıktısı olmayan değişiklik görsel olarak doğrulanmış sayılmaz.

İlk Release kabuğu doğrulaması için aynı araç `-BuildOnly` ile çalıştırılır;
ardından `windows_fast_smoke.ps1 -CloseAfter` çalışır. Araç, local InMemory
manifestini yalnız Flutter komutu sürerken kullanır ve varsa önceki `env.json`u
SHA-256 kontrolüyle geri yükler. Kullanıcı komut sürerken `env.json`u değiştirirse
veri kaybı riski almadan geri yüklemeyi durdurur ve temp yedek yolunu bildirir.

Windows test hedefinde ana sayfa → Gruplar → Profil navigasyonunu doğrudan
koşturmak için: `powershell -ExecutionPolicy Bypass -File .\scripts\windows_local_dev.ps1 -IntegrationTest`.
Bu, in-memory test kullanıcısıyla gerçek Windows test bağlamında gezinmeyi
doğrular; gerçek hesap girişi, sayaç kaydı veya sunucu senkronu yerine geçmez.

Bu kontrol **yalnız kabuk/başlatma kanıtıdır**: uygulama açılır, kapanmaz,
görünür pencere verir ve yeni screenshot alınır. Giriş, timer, senkronizasyon,
MSIX kurulum/güncelleme ve Store otomatik güncellemesi için aşağıdaki QA matrisi
ayrıca uygulanır.

Not: Flutter Windows hedefi `--flavor` kabul etmez; yerel kanal `CHANNEL=local`
manifest değeriyle seçilir. Bu nedenle Windows komutlarına `--flavor local`
eklenmez.

`env.json` yerel kanal sözleşmesine uymuyorsa uygulama bilinçli olarak
`invalid_channel` / ilgili tanı ekranını gösterir; bu bir test PASS'i değildir.
InMemory ile hızlı yerel çalışma için `env.local.example.json` dosyasının güvenli
geçici kopyası kullanılır; staging veya production hesabına bağlı bir `env.json`
kalıcı olarak değiştirilmez. Hosted backend testi ise WP-259'un Sandbox/VM +
staging manifesti akışında yapılır.

Bu belge Windows release / MSIX kanıtını standardize eder. Emulator veya yalnız
`flutter run` debug kanıt sayılmaz. Test hesabı; token/e-posta ekran kaydına girmez.

### WP-273 yerel otomatik kanıtı (2026-07-23)

- `timer_background_reconcile_test.dart` içindeki RTT yarışı, duvar saatiyle beklemek yerine yerel-emission ve ağ-tamamlanma kapılarıyla sürülür; hedef grup 20 ardışık koşumda geçti.
- Tam Flutter paketi, analiz ve yerel Windows release EXE derlemesi geçti.
- Yerel MSIX + portable ZIP, SHA-256 manifestiyle `app/build/wp273-windows-dry-run/` altında üretildi. Bu bir yayın değildir.
- Temiz VM kurulum/güncelleme/kaldırma senaryoları gerçek Windows cihazında ayrıca doğrulanmalıdır.

### WP-273 mevcut makine paket smoke (2026-07-23)

- Önceden kurulu `OdakKampi.App` `1.0.0.0`, imzası geçerli yerel MSIX ile `1.0.0.8`e yükseltildi; paket durumu `Ok` oldu.
- Paketli uygulama AppUserModelId üzerinden açıldı ve süreç çalışır durumda doğrulandı.
- Portable ZIP geçici bir klasöre açıldı; `online_study_room.exe` bulundu ve başlatıldı.
- Bu makine temiz VM değildir; mevcut kullanıcı verisini silmemek için kaldırma adımı koşturulmadı. Bu nedenle W-01/W-04 ve temiz-VM kabulü hâlâ açıktır.

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

Temiz hedefte iki-sürümlü MSIX koşumu için ayrıntılı ve redacted kanıt prosedürü:
[`WINDOWS-VM-QA.md`](WINDOWS-VM-QA.md).

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
