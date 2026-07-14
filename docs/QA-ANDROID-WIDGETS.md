# Android Widget QA Matrisi — R2 Şablonu

> **WP:** WP-68 uygulaması
> **Durum:** Kod ve otomatik doğrulama tamam; fiziksel cihaz matrisi bekliyor.
> **Kanıt etiketi:** Android debug build ve Flutter testleri geçti. Bu dosyadaki Samsung/Pixel senaryoları henüz çalıştırılmadı — `Cihazda doğrulanmalı`.

## 1. Test kaydı

| Alan | Kayıt |
|---|---|
| Uygulama sürümü / build | Debug APK — yerel build başarılı |
| Widget uygulama WP'si | `WP-68` |
| Test tarihi / uygulayan | 2026-07-14 / Codex (otomatik) |
| Samsung/One UI cihazı + Android sürümü | `TBD` |
| Pixel/AOSP cihazı + Android sürümü | `TBD` |
| Launcher / dynamic color durumu | `TBD` |
| Koyu/açık sistem teması | `TBD` |
| Font ölçeği / ekran yoğunluğu | `TBD` |
| Test hesabı / test grubu | Redakte edilmiş `TBD` |
| Video / ekran görüntüsü bağlantısı | `TBD` |

## 1a. Otomatik doğrulama kaydı

| Kontrol | Sonuç |
|---|---|
| Hedef widget testleri | PASS — 6 test |
| Tam Flutter test paketi | PASS — 342 test |
| Android debug APK derlemesi | PASS |
| Fiziksel Samsung / Pixel matrisi | `Cihazda doğrulanmalı` |

## 2. R2 kabul matrisi

Bir yüzey briefte seçilmediyse `Uygulanamaz` işaretlenir. Her başarısız satır, kök neden ve tekrar adımıyla ayrı bug/debug WP'sine bağlanır.

| # | Senaryo | Beklenen ölçülebilir sonuç | Samsung | Pixel | Kanıt |
|---|---|---|---|---|---|
| 1 | Widget ekleme | Seçilen boyutta launcher'a eklenir; boş/başlangıç hali anlamlıdır, çökme yoktur. | `TBD` | `TBD` | `TBD` |
| 2 | Koyu/açık tema | Kritik metin okunur; arka plan/ikon kontrastı korunur. | `TBD` | `TBD` | `TBD` |
| 3 | Dynamic color | Seçilen sistem rengi okunabilirliği bozmaz; marka rengi zorla taşmaz. | `TBD` | `TBD` | `TBD` |
| 4 | Font ölçeği | %100 ve %130'da taşma/kesilme 0; seçilen eylem görünür kalır. | `TBD` | `TBD` | `TBD` |
| 4a | Yeniden boyutlandırma | 1×1, yatay/orta ve büyük desteklenen boyutlarda doğru yoğunluk kuralı seçilir; küçültülmüş tam layout, kesik metin veya ölü alan 0'dır. | `TBD` | `TBD` | `TBD` |
| 5 | Sayaç başlat/durdur | Seçilmişse uygulama kapalıyken 20 ardışık eylemde state ve widget metni tutarlıdır; çift oturum 0'dır. | `TBD` | `TBD` | `TBD` |
| 6 | Canlı süre | Seçilmiş sayaçta native süre akar; Flutter kaynaklı saniyelik redraw yoktur. | `TBD` | `TBD` | `TBD` |
| 7 | Oturum sonrası özet | Seçilmiş kişisel özet, oturum kaydı/sync sonrası briefteki tazelik sözleşmesine uyar. | `TBD` | `TBD` | `TBD` |
| 7a | Günlük/grup hedef oranı | 1×1'de yüzde/halka, geniş boyutta doğru dakika/toplam bilgisi görünür; Istanbul gün sınırında oran doğru hesaplanır. | `TBD` | `TBD` | `TBD` |
| 8 | Grup verisi | Seçilmişse üyelik/grup değişiminden sonra doğru ve yetkili snapshot görünür; grubu olmayan kullanıcıda güvenli boş durum vardır. | `TBD` | `TBD` | `TBD` |
| 9 | Manuel yenile | Briefte seçilen gerçek davranış gerçekleşir; sahte tazelik iddiası yoktur. | `TBD` | `TBD` | `TBD` |
| 10 | Offline → online | Eski snapshot açıkça bayat/son bilinen veri olarak davranır veya briefteki boş durum görünür; ağ gelince uzlaştırılır. | `TBD` | `TBD` | `TBD` |
| 11 | Uygulama cold start / force-stop | Seçilmiş eylemde platformun desteklediği davranış korunur; desteklenmeyen durumda kullanıcı yanlış yönlendirilmez. | `TBD` | `TBD` | `TBD` |
| 12 | Telefon yeniden başlatma | Widget yeniden başlatma sonrası eklenmiş kalır; timer/alarm seçilmişse sözleşmedeki doğru native durum görünür. | `TBD` | `TBD` | `TBD` |
| 13 | Kilit ekranı gizliliği | Briefte izin verilmeyen kişisel/grup verisi kilitliyken görünmez. | `TBD` | `TBD` | `TBD` |
| 14 | Erişilebilirlik | Her eylem ≥48 dp; TalkBack etiketi anlamlı; hareketli içerik varsa reduce-motion tercihi uygulanır. | `TBD` | `TBD` | `TBD` |
| 15 | Gün sınırı | Europe/Istanbul gün değişiminde gün/seri alanları briefteki kurala göre yenilenir. | `TBD` | `TBD` | `TBD` |

## 3. Çıkış kapısı

- Seçilmiş her senaryo Samsung ve Pixel üzerinde PASS ya da platform farkı belgeli olmalıdır.
- P0/P1 hata 0; açık P2'ler kullanıcı kabulünde görünürdür.
- Video/görüntü kanıtı test hesabı, e-posta, token veya hassas grup bilgisini içermez.
- Ürün sahibi, briefteki yüzey/etkileşim/gizlilik kararının karşılandığını kabul eder.

Bu kapılar sağlanmadan uygulama WP'si `Tamamlandı` durumuna taşınmaz.
