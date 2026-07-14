# Windows Performans Tabanı — WP-70

> Durum: Ölçüm altyapısı geliştiriliyor.
> Kanıt etiketi: `Cihazda doğrulanmalı` — gerçek Windows release koşumu gerekir.

## Amaç

Windows uygulamasının boşta bellek tüketimi ve hafif donma bildirimini, tekrar edilebilir ve hassas veri içermeyen yerel bir ölçüm tabanına dönüştürmek. Bu WP bir optimizasyon yapmaz; hangi düzeltmenin gerekli olduğunu kanıtlar.

## Ölçüm sözleşmesi

- Release artefaktı çalıştırılır; debug/profile sonucu kabul edilmez.
- Her koşumda pencerenin görünmesine kadar geçen süre, 60 saniyelik boşta CPU, Working Set ve private bytes örneklenir.
- En az beş temiz koşum kaydedilir; önceden açık uygulama kapatılır.
- Çıktı yalnız sürüm etiketi, örnek zamanları ve sayısal sayaçları içeren JSON'dur. Kullanıcı hesabı, e-posta, token, mutlak dosya yolu veya ekran içeriği yazılmaz.
- Rapor p50/p95 değerlerini ve ölçümün sınırlarını (antivirüs, ilk açılış, güç modu, makine) belirtir.

## Koşum

```powershell
cd C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room
flutter build windows --release --dart-define-from-file=app/env.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/windows_performance_baseline.ps1
```

- Betik önce aynı uygulamanın açık instance'ını reddeder; var olan süreci kapatmaz.
- Her koşumda yalnız kendi açtığı pencereyi kapatır. Sonuçlar gitignore altındaki `app/build/windows-performance-baseline/` dizinine yazılır.
- `-ValidateOnly` ile release exe, hash ve parametreler koşum yapmadan doğrulanır.

## İlk gerçek taban — 2026-07-14

| Metrik | p50 | p95 |
|---|---:|---:|
| Pencere görünme süresi | 384 ms | 437 ms |
| Working Set | 84.23 MB | 85.91 MB |
| Private bytes | 91.79 MB | 93.03 MB |

- Koşum: Windows 11 Home, temiz release artefaktı, 5 ayrı açılış ve koşum başına 60 sn boşta örnek.
- Artefakt SHA-256: `eadd9eb029a6266af4df6c4906b44bb31c31373bfce66f5d90f9ac7db7c6cdfd`.
- Yerel, gitignore altındaki kanıt: `app/build/windows-performance-baseline/baseline-20260714-124822.json`.
- Sonuç: Bildirilen 300–400 MB boşta bellek bu kontrollü release koşumunda tekrar üretilemedi. Bu nedenle rastgele bellek/UI optimizasyon WP'si açılmadı. Aynı şikâyet tekrarlandığında aynı artefakt/çalışma modu ile betik koşturulmalı; yalnız tekrar üretilebilen bütçe ihlali için düzeltme WP'si açılır.

## Sonuç yorumlama

- Bu ölçüm yalnız aday kök nedenleri daraltır; Working Set tek başına bellek sızıntısı kanıtı değildir.
- Bütçe ihlali veya tekrarlanabilir pencere gecikmesi saptanırsa, ilgili Flutter/Windows IA kodu için ayrı bir düzeltme WP'si açılır.
- Her değer gerçek makineye özgüdür; ürün kararı için ikinci bir Windows 11 makinesinde tekrar gerekir.
