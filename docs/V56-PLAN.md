# v56 Planı

> İki kaynaktan birleşti: sahibin **v55 cihaz testi notları (2026-07-28)** ve
> [MODERASYON-PLANI.md](MODERASYON-PLANI.md) Faz A.
> "Kök neden" işaretli maddeler kod okumasıyla doğrulandı, tahmin değil.
> Son kullanılan WP: 411.

---

## 1. Cihaz testi ham notları

Sahibin kendi ifadesiyle; yorum eklenmedi.

### Sayaç
- Ayna cihazda **uygulama içi** durdurma tuşu çalışıyor ✅
- **Bildirimden** durdurunca diğer cihazda durmuyor ❌
- **Android ana ekran widget'ından** durdurunca diğer cihazda durmuyor ❌

### Arayüz
- Tanıtım turunda ana ekran tanıtımı beğenilmedi → sadece **edit kısmı** gösterilsin
- İstatistiklerde **period tanıtımı kaldırılsın** (önceki istek geri alındı)
- Kamp ateşi olmamış: **yeşil alanın yüksekliği çok az**, isimler üst üste biniyor,
  mevcut px değeri **2 katına** çıkmalı
- Kamp ateşi için **PC'den mobil ekranı ayarlayabileceği bir önizleme ekranı** isteniyor —
  PC tarafında böyle bir ayar ekranı vardı, değerler oradan geliyordu; mobil için de aynısı
- **Tarih seçme bozuk** (ekran görüntüsü var): görüntü bozuk, çalışmıyor
- Başarımlar: **Lokomotif** ve **Source of Inspiration** anlaşılmıyor
  - Source of Inspiration → dürttükten sonra kaç dakika içinde derse başlaması gerekiyor?
  - Lokomotif → "o gün içinde ilk çalışmaya başlayan" mı demek? net değil
- Başarım ekranında iki yenileme vardı, ekran kayıyordu → v55'te çözülmüş olabilir (doğrulanacak)
- Sürüm notları: en üstte kimlik var, altında beta 4402 var; **liste baya uzun**

### Destek — internetsiz testler
- İnternet kapalı → uygulama **5 sn**'de açıldı (sahip sorun görmüyor, izlenecek)
- Senkron koptu, başarımlar/taç gitti (beklenen)
- İnternetsiz sayaç başlat → interneti aç → **diğer cihazda sayaç 0'dan saymaya başladı**;
  kapatınca otomatik düzeldi, toplam süre doğru yazdı (küçük sorun)
- **Asıl gariplik:** internetsiz kronometre başlat → **interneti açmadan önce durdur**
  (yerelde toplam süre kaydedildi) → sonra interneti aç →
  ayna cihazda toplam süreler eşitlendi **ve sayaç kendiliğinden açıldı, 00:01'den saymaya başladı**.
  Dahası: ilk cihazda stop'a basınca *"diğer cihazdaki duracak"* uyarısı geldi —
  yani ayna cihaz elle başlatılmış gibi davranıyor, oysa ona dokunulmadı.

### Destek — geri bildirim akışı
- Öneri gönderildi, admin hesabından cevap yazıldı → **sistem çalışıyor** ✅
- Mesajlaşmada **yeni mesajlar üste** yazılıyor — alışılmışın dışında
- Geri bildirim bildirimi geldi ama kullanıcıda Duyurular'a **düşmedi**
  (madde 6'da düzeltildi: ~2 dk sonra geldi)
- Geri bildirim gönder ekranı mobilde: konu + açıklama + **3 buton alt alta**
  (Geri bildirimlerim, İptal, Gönder) + klavye açık → yazılan metin zor görünüyor
  → **2 buton olsun, yan yana: İptal ve Gönder**
- Ayarlardaki **"Send feedback" → "Feedback"** olsun, içinde **2 sekme**:
  *Gönder* ve *Geri bildirimlerim* (liste, tarih sıralı, en yeni en üstte)
- Mesaj gelince WhatsApp/Instagram gibi **renkli rozet** olsun
- Profil ve Ayarlar'da **kırmızı nokta yoktu**; sadece push geliyordu, kendisi girip gördü
- Başarımlarda da: yukarıdan bildirim geliyor ama **başarımlar ekranında rozet yok**

### Destek — SSS
- Giriş ekranında "Frequently asked questions" yanına **(SSS)** eklensin
- Konumu **Sign up'ın altına, en alta** taşınsın
- Soru gönderme kısmına **foto eklenebilsin**

### Güvenlik ve moderasyon
- **Bildir** kısmına foto eklenebilsin
- Bildirdikten sonra **ne bildirdiğini göremiyor** (admin kuyruğu işi, zaten planda)
- **Engellenen kullanıcı hâlâ görünüyor:** tablolarda çıkıyor ve **profili açılıyor**;
  kamp ateşinde de görünüyor
- Rozet ~2 dk sonra Duyurular + Geri bildirim + Ayarlar + Profil'e düştü → **gecikme var**

---

## 2. v56 iş paketleri

### Blok A — Bozuk olanlar (öncelik: en yüksek)

**WP-412 — Tarih aralığı seçici gün hücresi**
*Kök neden bulundu:* [draggable_date_range_picker.dart:445](../app/lib/features/stats/widgets/draggable_date_range_picker.dart:445)
gün hücresine `'$day'` yazıyor. `day` bir `DateTime`; Dart bunu `2026-07-01 00:00:00.000`
olarak metne çeviriyor. 40×40 dairenin içine sığmayınca taşıp üst üste biniyor.
Doğrusu `'${day.day}'`.
Düzeltme sonrası sürükleme işlevi yeniden denenecek — "çalışmıyor" şikâyeti taşan
dokunma hedeflerinden kaynaklanıyor olabilir.
**DoD:** hücrede yalnız gün sayısı; widget testi hücre metnini doğrular (ekran görüntüsü değil, metin eşitliği).

**WP-413 — Engelleme yaptırımının eksik yüzeyleri**
Engelleme şu an her yüzeyi kapsamıyor. Kapsanacaklar: istatistik/liderlik tabloları,
sosyal profil erişimi, arama sonuçları, grup üye listeleri.
Kamp ateşi ayrı ele alınır (aşağıdaki soru 2).
**DoD:** her yüzey için iki uçlu test — A→B ve B→A; yeni yüzey eklendiğinde testin
kırılmasını sağlayan ortak süzgeç noktası.

### Blok B — Sayaç senkron güveni

**WP-414 — Bildirim ve widget aksiyonları senkronu tetiklemiyor**
Uygulama içi durdurma ayna cihaza gidiyor, bildirim ve ana ekran widget'ından
durdurma gitmiyor. Yani senkron yolu yalnız UI katmanına bağlı; native aksiyon
yolları aynı SSOT'a yazmıyor.
**DoD:** üç giriş noktası (uygulama içi, bildirim, widget) tek ortak yola bağlanır;
her biri için ayrı sözleşme testi — biri koparsa test kırmızı düşer.

**WP-415 — Çevrimdışı biten koşu ayna cihazda hayalet koşu doğuruyor**
İki belirti aynı kökten geliyor gibi görünüyor:
1. Çevrimdışı başlatılan koşu, çevrimiçi olunca ayna cihazda **0'dan** saymaya başlıyor
2. Çevrimdışı **başlatılıp durdurulan** koşu, çevrimiçi olunca ayna cihazda
   **aktif koşu olarak canlanıyor** — kullanıcı hiç dokunmadığı hâlde
Muhtemel neden: senkronda yalnız "başlat" olayı taşınıyor, "durdur" olayı ya taşınmıyor
ya da zaman damgası karşılaştırması yapılmadan uygulanıyor.
**DoD:** çevrimdışı başlat+durdur → çevrimiçi ol senaryosu iki uçlu testte;
ayna cihazda aktif koşu **doğmamalı**, yalnız toplam süre eşitlenmeli.

### Blok C — Arayüz

**WP-416 — Kamp ateşi düzeni + mobil parametrik önizleme**
Sıra önemli: **önce önizleme, sonra kod.**
1. PC'deki ayar ekranının mobil karşılığı yapılır — yeşil alan yüksekliği, isim yazı boyutu,
   satır aralığı, hayvan boyutu parametrik
2. Sahip değerleri seçer (başlangıç noktası: yeşil alan yüksekliği **2×**)
3. Seçilen sayılar sabitlenir ve **teste bağlanır**
**DoD:** isim çakışması ve alt sıra kesilmesi için düzen testi; sahibin seçtiği
sayılar testte sabit değer olarak durur.

**WP-417 — Tanıtım turu sadeleştirme**
- Ana ekran turu: yalnız **edit** adımı kalsın, gerisi çıksın
- İstatistikler: period tanıtımı **tamamen kaldırılsın**
**DoD:** tur adım sayısı testte sabitlenir; adımların hiçbirinde iki tıklanabilir öğe çakışmaz.

**WP-418 — Başarım açıklamalarını netleştir**
- *Source of Inspiration*: dürtme sonrası kaç dakikalık pencere olduğu açıklamada yazsın
- *Lokomotif*: koşulu düz Türkçe/İngilizce ile yazılsın
- Tarama: koşulu ölçülebilir biçimde yazılmamış başka başarım kalmasın
**DoD:** her başarımın açıklaması eşiği/penceresi içerir; boş veya belirsiz açıklama testte kırılır.

**WP-419 — Sürüm notları listesi**
Liste çok uzun; beta sürümleri stable kullanıcıya gösterilmemeli (bkz. soru 1).
**DoD:** stable kanalda yalnız stable sürümler; liste sayfalanır veya son N sürümle sınırlanır.

### Blok D — Destek ve geri bildirim

**WP-420 — Feedback ekranı yeniden düzeni**
- Ayarlardaki ad: **"Send feedback" → "Feedback"**
- İki sekme: **Gönder** · **Geri bildirimlerim** (tarih sıralı, en yeni üstte)
- Gönderme formunda **iki buton, yan yana**: İptal · Gönder
  (üçüncü buton sekmeye taşındığı için kalkıyor)
- Klavye açıkken yazılan metin görünür kalmalı
- Mesajlaşmada **yeni mesaj alta** eklensin (şu an üste ekleniyor)
**DoD:** mobil dar ekranda klavye açıkken metin alanı görünür; mesaj sırası testte sabit.

**WP-421 — Rozet zinciri ve gecikmesi**
Rozet Profil → Ayarlar → Feedback → Başarımlar zincirinde görünmeli.
Şu an ~2 dk gecikmeli düşüyor; push ile rozet aynı olaydan beslenmeli.
**DoD:** okunmamış mesaj/başarım varken zincirdeki her seviye rozet gösterir;
okununca zincir temizlenir.

**WP-422 — SSS giriş ekranı yerleşimi**
- Etiket: "Frequently asked questions **(SSS)**"
- Konum: **Sign up'ın altında, en altta**
**DoD:** giriş ekranı yerleşim testi; oturum açmadan SSS'ye erişim korunur.

### Blok E — Foto ekleme

**WP-423 — Destek sorusuna ve şikâyete foto**
*İyi haber:* ek altyapısı kısmen var — `submitFeedback` zaten `attachmentBytes` /
`attachmentExt` alıyor ([admin_repository.dart:143](../app/lib/data/repositories/admin_repository.dart:143)),
`avatars` bucket'ı ve storage politikaları mevcut. Şikâyet tarafına uzatılacak.
Dikkat edilecek: foto ekleri kendisi kötüye kullanım aracıdır — boyut sınırı,
tür doğrulaması ve admin tarafında güvenli görüntüleme gerekir.
**DoD:** ek boyut/tür sınırı sunucuda zorlanır; admin kuyruğunda ek görüntülenebilir.

### Blok F — Moderasyon admin tarafı (Faz A)

[MODERASYON-PLANI.md](MODERASYON-PLANI.md) Faz A'dan devralındı.

**WP-424 — Kuyrukta kimlik okunabilirliği**
Ad + avatar göster, ID gizle. Kural: *gösterilen ad, işlem yapılan ID, loglanan ikisi birden.*
Hem şikâyet eden hem edilen için. ID kopyalanabilir küçük metin olarak kalır.

**WP-425 — Şikâyet detay ekranı**
Tam içerik kopyası (şu an 3 satırda kesiliyor) + çevre mesajlar (bağlam) +
hedefin şikâyet ve yaptırım geçmişi + şikâyetçinin serbest açıklaması.
Sahibin *"ne bildirmiş göremiyorum"* şikâyetinin doğrudan karşılığı.

**WP-426 — Basamaklı yaptırım**
Uyar · Adı sıfırla · Sustur 24 saat · Askıya al **7 / 14 / 30 gün** · Kalıcı.
Karttan tek tık, gerekçe zorunlu, denetim kaydına yazılır, tek tıkla geri alınır.
`ban_duration` saat kabul ediyor: 168h / 336h / 720h.
Şu anki tek seçenek 876000h (100 yıl) — sahip kararı ile basamaklandırılıyor.

**WP-427 — Tekilleştirme**
Aynı hedefe gelen şikâyetler tek kartta, sayaç rozetiyle.

**WP-428 — İçerik şikâyetinde admin push**
`_enqueue_support_ticket_admin_push` eşdeğeri `ugc_reports` insert'üne bağlanır.
**Mağaza uyum maddesi:** Apple 1.2 şikâyetlere 24 saat içinde işlem istiyor;
bildirim gelmeden bu garanti edilemez.

---

## 3. v56 dışında bırakılanlar

Moderasyon Faz B ve C olduğu gibi v57'ye kalıyor: eşik tabanlı otomatik karantina,
kötü niyetli şikâyetçi ölçümü, SLA panosu, toplu işlem, rol katmanı,
grup yöneticisine devir, itiraz akışı, kanıt saklama (`on delete cascade` düzeltmesi),
denetim kaydı değişmezliği.

İzlenecek, henüz WP değil:
- Çevrimdışı açılışta 5 sn gecikme
- Başarım ekranındaki çift yenileme / kayma (v55'te çözülmüş olabilir)

---

## 4. Başlamadan önce netleşmesi gereken iki şey

**1. Sürüm notları.** "En üstte kimlik var, altında beta 4402" ile tam olarak ne
görüldüğü net değil. Varsayım: stable kanalda eski beta sürümleri de listeleniyor
ve liste bu yüzden uzuyor. Doğruysa çözüm: stable kullanıcıya yalnız stable sürümler.

**2. Kamp ateşinde engellenen kullanıcı.** Tasarım gereği engellenen kişi kamp
ateşinden **silinmemeli, anonimleşmeli** (katılımcı sayısı bozulmasın diye).
Cihazda adıyla mı görünüyor, yoksa anonim mi? Adıyla görünüyorsa hata,
anonimse doğru davranış ve WP-413 kapsamı dışında.
