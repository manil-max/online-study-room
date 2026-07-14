# Android Widget R2 — Ürün Briefi ve Veri Sözleşmesi

> **WP:** WP-63
> **Durum:** Ürün briefi kaydedildi — uygulama kapsamı ayrı bir WP'de açılacak.
> **Son güncelleme:** 2026-07-14
> **Kanıt:** Mevcut envanter `Kodda doğrulandı`; aşağıdaki seçimler `Ürün kararı gerekiyor`.

## 1. Amaç

Android ana ekran widget'ları, uygulamayı açmadan tek bir öncelikli işi hızlandırmalı; aynı anda bütün istatistikleri sıkıştırmaya çalışmamalı. R2, küçük 1×1 yüzeyden başlayıp kullanıcı widget'ı büyüttükçe anlamlı ayrıntı açar.

## 2. Mevcut envanter — `Kodda doğrulandı`

| Yüzey | Mevcut davranış | R2 için anlamı |
|---|---|---|
| Sayaç | Native `Chronometer`; tek Başlat/Durdur eylemi uygulama kapalıyken native servise gider. | Canlı süre için Flutter'ın saniyelik yeniden çizimi gerekmez ve eklenmez. |
| Günlük özet | Bugün, hafta ve hedef serisi snapshot olarak gösterilir; kök dokunuş son kaydı tekrar çizer. | “Yenile” tek başına sunucudan veri çekme sözü değildir. |
| Grup sıralaması | En fazla üç satırlık snapshot gösterilir; kök dokunuş son kaydı tekrar çizer. | Gruba ait bilgilerin ana ekranda görünmesi gizlilik kararı ister. |
| Dijital saat | Native `TextClock` yüzeyi var. | Saat Merkezi ile mi yoksa çalışma odaklı widget'larla mı ele alınacağı seçilmeli. |
| Sıradaki alarm | Yerel native alarm aynasından sonraki alarmı gösterir. | Saat ürününe ait ayrı bir öncelik olarak ele alınabilir. |

Mevcut Flutter köprüsü üç çalışma widget'ını (`timer`, `stats`, `leaderboard`) kaydeder; Android tarafında ayrıca saat ve alarm provider'ları vardır. R2 bu ayrımı korur; veri kaynağı olmayan bir yüzeye sahte canlılık eklemez.

## 3. Ürün kararları — 2026-07-14

Kullanıcı, 1×1 Başlat/Durdur sayaçla başlayıp günlük hedef oranı, grup hedefi ve grup sıralamasını istemiştir. Tüm yüzeyler yeniden boyutlandırılabilir; içerik boyuta göre sadeleşir veya genişler.

| Karar | Seçim |
|---|---|
| Öncelik sırası | 1. Sayaç Başlat/Durdur · 2. Günlük hedef oranı · 3. Grup hedef oranı · 4. Grup sıralaması |
| Başlangıç boyutu | Her yüzey 1×1 eklenebilir olmalı; kullanıcı yatay/dikey büyüttükçe içerik uyarlanmalı. |
| Sayaç eylemi | 1×1'de gerçek native Başlat/Durdur; uygulama kapalıyken de çalışmalı. |
| Bilgi yoğunluğu | Küçük boyutta tek ana metrik/eylem; geniş boyutta etiket, ikinci metrik ve ayrıntı görünür. |
| İstatistik dokunuşu | Kök dokunuş ilgili uygulama ayrıntısını açar; “yenile” ancak gerçek yenileme etkisi varsa görünür. |
| Kilit ekranı | Güvenli varsayılan: çalışma, hedef ve grup verisi kilit ekranında gösterilmez. Ayrı kullanıcı kararı olmadan bu sınır genişletilmez. |
| Grup verisi | Kullanıcı grup widget'ını bilerek eklediğinde gösterilir; grubu olmayan kullanıcıda kişisel veriyle karışmaz ve anlamlı boş durum gösterir. |
| Görsel yön | Küçük ekranda okunabilir, minimal Odak Kampı kimliği; dekoratif unsur, ana metrik veya eylemi bastırmaz. |

### 3.1 Boyuta duyarlı içerik sözleşmesi

| Yüzey | 1×1 (varsayılan) | Orta/yatay boyut | Büyük boyut |
|---|---|---|---|
| Sayaç | Büyük `Başlat`/`Durdur` eylemi ve durum simgesi | Eylem + akan süre | Eylem + süre + mod/ders etiketi |
| Günlük hedef | Halka/oran ve yüzde | Oran + çalışılan/hedef dakika | Oran + dakika + hedefe kalan süre/seri bağlamı |
| Grup hedefi | Halka/oran ve yüzde | Oran + grup toplamı/hedefi | Oran + toplam + aktif katkı/uygun ikincil metrik |
| Grup sıralaması | Kendi sıra rozeti veya ilk sıradaki tek özet | İlk iki sıra ve kendi sıra | En çok üç sıra + kendi sıra; daha fazlası uygulamada |

Widget hiçbir boyutta metni kesmez veya yalnız küçültülmüş tam layout göstermez. Launcher'ın desteklediği 1×1 dışındaki ara boyutlarda en yakın yoğunluk kuralı seçilir.

## 4. Veri ve etkileşim sözleşmesi

Bu tablo, kararlar alındığında uygulama WP'sinin değişmeyecek ürün sözleşmesidir. `TBD` alanı onay olmadan kodlanmaz.

| Seçilen yüzey | Gösterilecek alanlar | Veri kaynağı | Yenileme olayı | Dokunuş | Boş/hata/offline metni |
|---|---|---|---|---|---|
| Sayaç | Başlat/Durdur, durum ve boyuta göre süre/mod | Native timer durumu + son snapshot | Başlat/Durdur, uygulama uzlaştırması, widget ekleme | Eylem = gerçek native Başlat/Durdur; kök = uygulamada Odak | Hazır: `Çalışmaya başla` |
| Günlük hedef | Oran, yüzde; genişte dakika ve kalan hedef | Son kaydedilmiş kişisel istatistik snapshot'ı | Oturum ekleme/düzenleme/silme, sync, Istanbul gün sınırı | Kök = uygulamada günlük istatistik/hedef | Hedef yok: `Günlük hedefini belirle` |
| Grup hedefi | Oran, yüzde; genişte grup toplamı/hedefi | Son kaydedilmiş ortak grup hedef snapshot'ı | Grup/membership/hedef değişimi, sync, Istanbul gün sınırı | Kök = uygulamada Grup | Grup yok: `Bir gruba katıl`; hedef yok: `Grup hedefi belirlenmedi` |
| Grup sıralaması | Boyuta göre kendi sıra veya en çok üç satır | Son kaydedilmiş ortak grup snapshot'ı | Grup/membership değişimi, sync, Istanbul gün sınırı | Kök = uygulamada grup sıralaması | `Sıralama oluşunca burada görünür` |

**Zaman ve tazelik ilkesi:** Android, periyodik widget güncellemesini kısa aralıkta garanti etmez. Bu nedenle canlı sayaç yalnız native `Chronometer`/sistem zamanı ile akar; istatistik ve sıralama yalnız anlamlı olaylarda yenilenir. Kök dokunuş ilgili uygulama ayrıntısını açar. Gerçek veri yenilemeyen bir “Yenile” düğmesi eklenmez.

## 5. Gizlilik ve erişilebilirlik tabanı

- Varsayılan olarak widget, yalnız cihazın kilit ekranı/launcher görünürlüğüne uygun en az kişisel bilgiyi gösterir. Grup adı, üye adı, sıralama ve ayrıntılı çalışma verisi için yukarıdaki ayrı karar zorunludur.
- E-posta, token, davet kodu, tam oturum geçmişi veya başka kullanıcıların hassas bilgisi widget'a girmez.
- Kritik metin kontrastı WCAG AA; dokunulabilir eylemler en az 48 dp olmalıdır.
- Her seçilen yüzey koyu/açık sistem teması, Android dynamic color ve font ölçeğinde doğrulanır.

## 6. Platform sınırları

- OEM launcher'ları aynı piksel düzenini garanti etmez; kabul, işlev ve okunabilirlik üzerinden yapılır.
- WorkManager/periyodik güncelleme kısa aralıkta canlı süre amacıyla kullanılmaz.
- Uygulama kapalıyken yalnız native receiver/service'in desteklediği eylemler güvenilir kabul edilir.
- Lock-screen widget desteği Android sürümü ve OEM'e göre değişir; uygulanacak yüzey cihaz matrisiyle ayrıca doğrulanır.

## 7. R2 uygulama WP'sine geçiş kapısı

Yeni uygulama WP'si ancak şunların tamamı yazılı olduğunda açılır:

1. Öncelik, 1×1 başlangıç boyutu ve büyüyen içerik kuralları.
2. Her yüzeyde gösterilecek alanlar ve dokunuşların gerçek sonucu.
3. Kilit ekranı/grup verisi gizlilik kuralı.
4. Boş/hata/offline metni ve veri tazeliği ilkesi.
5. Cihaz QA için en az bir Samsung/One UI ve bir Pixel/AOSP hedefi.

Ürün sözleşmesi WP-63 ile teslim edildi. Uygulama kapsamı WP-68'dir; Flutter/Kotlin/manifest değişiklikleri yalnız o WP'nin sahipliği altında yapılır.
