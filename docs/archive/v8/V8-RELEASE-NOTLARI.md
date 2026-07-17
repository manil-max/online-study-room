# Odak Kampı V8 — Taslak Sürüm Notları

> **Yayınlanamaz taslak.** Sürüm adı, build numarası, tarih ve içerik ancak
> `V8-RELEASE-GATE.md` bütün zorunlu kapıları PASS olduğunda kesinleşir.

## Güvenilirlik çalışmaları

- Sayaç, bildirim ve Android widget yüzeyleri için tek durum kaynağı çalışması.
- Oturum/istatistik senkronizasyonunda canonical projection ve offline outbox
  uzlaştırması.
- Kritik akışlar için integration test altyapısı ve Samsung/Pixel QA matrisi.
- PII göndermeyen hata/senkron gözlemlenebilirliği için Sentry altyapısı.
- İstatistik ve grup ekranlarında küçük kullanım kolaylığı düzenlemeleri.

## Henüz doğrulanmayanlar

Bu taslak, bildirim/widget arka plan eylemleri, gerçek cihaz davranışı, beta
soak ve rollback kanıtının tamamlandığını iddia etmez. WP-41/42 için uygulama
kapalıyken eylem davranışını etkileyen düzeltme devam etmektedir; tamamlanıp
Samsung ve Pixel'de doğrulanmadan bu notlar yayınlanmaz.

## Güncelleme notu

- Güncelleme, mevcut imzalı uygulamanın üstüne normal Android güncellemesi
  olarak kurulmalıdır.
- Sorun halinde uygulamayı kaldırmadan önce destek yönergesini bekleyin; eski
  ve daha düşük build numaralı APK mevcut uygulamanın üstüne kurulamayabilir.

## Sürüm bilgileri

| Alan | Değer |
|---|---|
| Sürüm | — |
| Build | — |
| Yayın tarihi | — |
| APK SHA-256 | — |
| Bilinen açık P1'ler | — |
