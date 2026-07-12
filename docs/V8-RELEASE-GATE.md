# V8 Stable Release Gate

> Durum: **NO-GO — kanıtlar eksik.** Bu belge, stabil sürüm kararı için tek
> kontrol listesidir; kutuların işaretlenmesi tek başına yayın yetkisi vermez.
> Son karar ürün sahibinindir.

## Sürüm kimliği

| Alan | Değer |
|---|---|
| Sürüm adı / build numarası | — |
| Git commit / tag | — |
| APK SHA-256 | — |
| İmza / paket kimliği doğrulaması | — |
| Karar tarihi ve sahibi | — |

## Zorunlu kanıtlar

| Kapı | PASS koşulu | Kanıt | Durum |
|---|---|---|---|
| Kritik yol | Uygulama kapalıyken 20 bildirim Başlat/Durdur; çift session yok | `docs/QA-V8-ANDROID.md` V8-02 | [ ] |
| Widget | Timer aksiyonu çalışır; stats/leaderboard oturumdan sonra ≤5 sn yenilenir | V8-07 + video | [ ] |
| Cihaz çeşitliliği | Samsung ve Pixel üzerinde cold-start, kilit ekranı, reboot, pil optimizasyonu | V8-01/03/05/06 | [ ] |
| Senkron | Offline outbox, iki cihaz ve Istanbul gün sınırı doğrulanır | V8-08/09/10 | [ ] |
| Telemetri | Beta ortamında PII'siz breadcrumb ve opt-out kanıtı | `docs/OBSERVABILITY-V8.md` | [ ] |
| Otomasyon | Tam test paketi, analyze ve imzalı Android release build yeşil | CI / terminal çıktısı | [ ] |
| Güvenlik | WP-38 migration/Edge Function/RLS matrisi yeniden kontrol edildi | Backend kanıtı | [ ] |
| Soak | En az üç gün; P0=0, açık P1 listesi/kararı var | `docs/V8-SOAK-RAPORU.md` | [ ] |
| Rollback | Aynı imza ile ileri build numaralı geri-dönüş paketi hazır | `docs/V8-ROLLBACK.md` | [ ] |

## Kesin NO-GO koşulları

- P0 veya kullanıcı verisi kaybı riski açık kalırsa.
- Bildirim/widget eylemi uygulama kapalıyken çalışmazsa.
- Samsung veya Pixel kritik-yol videosu yoksa.
- Aynı paket kimliği ve imzayla kurulabilir rollback paketi hazır değilse.
- Soak süresi üç günü tamamlamadıysa.

## Karar kaydı

| Tarih | Karar | Gerekçe | Ürün sahibi |
|---|---|---|---|
| — | GO / NO-GO | — | — |

Yalnız bütün kapılar PASS olduktan sonra sürüm adı, tag ve dağıtım kanalı
belirlenir. Bu belge PASS olmadan “yayınlandı” yazılmaz.
