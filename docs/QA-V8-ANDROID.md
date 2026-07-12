# V8 Android QA Matrisi

Bu belge WP-40–46 için gerçek cihaz kanıtını standardize eder. Otomatik test
sonucu cihaz davranışının yerine geçmez. Her satır için cihaz modeli, Android/
One UI sürümü, beta build numarası, tarih, PASS/FAIL ve video/ekran kaydı yolu
yazılır. Test hesabı kullanılır; e-posta, token ve bildirim içeriğinde kişisel
veri görünüyorsa kayıt redakte edilir.

| ID | Senaryo | Samsung | Pixel | Kanıt / beklenen sonuç |
|---|---|---|---|---|
| V8-01 | Soğuk açılışta timer state restore | [ ] | [ ] | Timer/uygulama/bildirim aynı durum |
| V8-02 | Bildirimden 20 Başlat/Durdur | [ ] | [ ] | Uygulama öne gelmeden sıra bozulmaz |
| V8-03 | Kilit ekranı + 30 dk arka plan | [ ] | [ ] | Süre sapması kaydedilir, state kaybolmaz |
| V8-04 | Force-stop dışı process death/reopen | [ ] | [ ] | Çift session yok |
| V8-05 | Reboot sonrası restore | [ ] | [ ] | Restore/uyarı davranışı kaydedilir |
| V8-06 | Pil optimizasyonu açık/kapalı | [ ] | [ ] | OEM farkı ve kullanıcı uyarısı kaydedilir |
| V8-07 | Stats/leaderboard widget manuel yenileme | [ ] | [ ] | Son session sonrası ≤5 sn hedef |
| V8-08 | İnternetsiz ekle → bağlantı gelince sync | [ ] | [ ] | Session tam bir kez yazılır |
| V8-09 | Aynı hesap iki cihaz | [ ] | [ ] | Toplamlar/reconciliation farkı kaydedilir |
| V8-10 | Istanbul 23:59 → 00:01 | [ ] | [ ] | Bugün toplamı doğru güne geçer |
| V8-11 | Beta üstüne güncelleme / geri dönüş APK | [ ] | [ ] | Veri ve timer state korunur |

## Koşum notları

1. Build, cihaz ve ağ durumunu her videonun başında göster.
2. V8-02, V8-03, V8-05, V8-07 ve V8-09 stable kararından önce zorunludur.
3. P0 bulgusu beta dağıtımını durdurur; P1 bulgusu sahibi, workaround'u ve
   yeniden-test tarihi olmadan soak'a girmez.
4. Emulator yalnız `integration_test` için kullanılabilir; Samsung/Pixel kanıtı
   fiziksel cihazdan gelir.
