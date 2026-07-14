# Windows QA Matrisi (WP-28)

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
