# Odak Kampı Changelog

Sürüm notlarının kullanıcıya görünen ana kaynağı burasıdır. Uygulama içindeki
`app/assets/release_notes.json`, GitHub Release body ve Ayarlar > Güncelleme
notları ekranı bu metinle aynı kararları yansıtmalıdır.

## [beta-v4304 / 1.0.43-beta.4+4304] - 2026-07-23

> **Cihaz kabul betası — güvenilir bildirim tekrarı ve v43 ürün sözleşmesi.** Yalnız staging ortamını kullanır; stable uygulamayı ya da production verisini etkilemez.

### Düzeltmeler
- **Başarısız uzaktan bildirimler otomatik yeniden denenir.** Kuyruk sağlığı artık tekrar deneme zamanı, bekleyen iş sayısı, en eski iş yaşı ve hata sınıfını gösterir.
- **Sayaç bildirimi v43 sözleşmesinde kalır.** Desteklenmeyen yolda güvenli standart fallback korunur; Now Bar/promoted deneyi stable görünümü değiştirmez.
- **Araçlar sade kaldı.** Alarm, Timer ve Görevler korunur; Kronometre, Dünya Saati ve yatay StandBy kaldırıldı.
- **Taç XP çubuğu mutlak toplamı gösterir.** Örneğin `25k / 75k`; kademe içi yanıltıcı sayı göstermez.

### Test notları
- Bu beta `0069` staging migration head'ini gerektirir ve stable uygulamayla yan yana kurulur.
- Bildirim Merkezi > Bildirim Sağlığı'ndan foreground, background ve uygulama kapalıyken uzaktan self-test çalıştır; retry sonucu ve bildirim hata sınıfını kaydet.
- Sayaç bildirimi Başlat/Duraklat/Durdur aksiyonlarını, yatay/dikey yönü ve uygulama kapalıyken Durdur eylemini ayrıca doğrula.

## [beta-v4303 / 1.0.43-beta.3+4303] - 2026-07-22

> **Düzeltme betası — kabul edilen sayaç paneli ve güvenilir uzaktan bildirim testi.** Yalnız staging ortamını kullanır; stable uygulamayı ya da production verisini etkilemez.

### Düzeltmeler
- **Sayaç bildirimi stable tasarımına döndü.** Tek satırda akan süre ve büyük Başlat/Durdur düğmesi geri geldi; beta-v4302'de yanlışlıkla görünen başlıklı eski/standart kart ile promoted ongoing denemesi kaldırıldı.
- **Uzaktan bildirim tek yola alındı.** FCM mesajı uygulama önde, arka planda veya kapalıyken aynı uygulama bildirimini üretir; test artık Android'in arka planda farklı davranan sistem kartına bağlı değildir.
- **Self-test bekleme penceresi 25 saniye oldu.** Veritabanı tetikleyicisi, Edge Function ve FCM ilk çağrı gecikmelerinde sahte kırmızı sonuç verme riski azaltıldı.

### Test notları
- Bildirim Merkezi > Bildirim Sağlığı > Uzaktan test ile sırasıyla uygulama açık, arka planda ve ekrandan kaldırılmış halde dene.
- Sayaç başlatıldığında bildirim merkezinde yalnız alttaki stable tasarımındaki saat + büyük eylem paneli görünmelidir.

## [beta-v4302 / 1.0.43-beta.2+4302] - 2026-07-22

> **Beta test sürümü — güvenilir bildirim temeli ve Android canlı sayaç yüzeyi.** Bu sürüm yalnız staging test ortamına gider; stable kullanıcıları ve production verisi etkilenmez.

### Öne çıkanlar
- **Uygulama bildirimleri için gerçek teslim omurgası hazır.** Dürtme, duyuru ve güncelleme bildirimleri cihaz kaydı, teslim kuyruğu, tekrar engeli ve görünür sağlık/self-test adımlarıyla takip edilir.
- **Android çalışma bildirimi sade ve sistemle uyumlu.** Akan süre, başlık ve Başlat/Durdur aksiyonları standart ongoing bildirimde kalır; uygun Android/Samsung cihazlarında canlı yüzey için promoted ongoing isteği yapılır.
- **Profil daha tutarlı.** Seçili gizli başarımlar artık yanlış turuncu yerine kendi mor gizli rozet rengini korur.

### Düzeltmeler ve değişiklikler
- Araçlar alanından kullanılmayan **Dünya, Kronometre ve Saat** panelleri kaldırıldı. Alarm, Timer ve Görevler korunur; yatay StandBy deneyimi değişmez.
- FCM token yenilenmesi, çıkış, iki cihaz, bildirim tercihi ve sessiz saatler için güvenli cihaz kaydı/temizliği eklendi.
- Bildirim Merkezi'ne gerçek uzaktan self-test eklendi: yalnız sunucunun kabulünü değil, cihazın mesajı almasını en fazla 10 saniyede doğrular; aksi halde nedeni görünür kılar.
- Özel Android bildirim şablonu kaldırıldı; eski Android sürümlerinde standart güvenli geri dönüş korunur. Samsung Now Bar görünümü cihaz/firmware iznine bağlıdır, garanti edilmez.

### Test notları
- Bu beta yalnız **staging backend** kullanır ve stable uygulamayla yan yana kurulabilir.
- İlk kurulumda Bildirim Merkezi > Bildirim Sağlığı'ndan uzaktan self-test çalıştırılmalı; foreground, arka plan ve uygulama kapalı senaryoları ayrı ayrı denenmelidir.
- Uygulama kapatıldıktan sonra sayaçtan Durdur'a basıp oturumun tek kez kaydedildiğini; kilit ekranında akan sürenin ve aksiyonların göründüğünü kontrol et.

## [v43 / 1.0.43+43] - 2026-07-21

> **Kararlı (stable) sürüm.** beta-v4301 içeriği herkese açılıyor: sayaç toplamı (durdurma çift sayımı + ölü zaman), çevrimdışı kuyruk kopyaları, 3 saatlik saat kayması, sıralama seri rozeti, manuel ekleme çakışması ve XP yeniden fiyatlandırma.

### Öne çıkanlar
- Durdur'a bastığın an toplam artık hiç zıplamıyor; kayıt yazılırken de yazıldıktan sonra da **aynı sayı**.
- Çalışma kayıtlarındaki ve sohbetteki saatler **3 saat geri** gösteriyordu; düzeldi.
- Beş başarımın XP değerleri yükseltildi, düzeltme **geriye dönük** — kazanılmış kademeler de yeni değere çıkar.

### Notlar
- Sunucu tarafı `0065` migration'ı **bu sürümden önce** production'a uygulanmalıdır.
- Tüm XP değişiklikleri artış yönündedir; kimsenin XP'si veya tacı düşmez.
- GitHub sideload **stable** APK; in-app güncelleme stable kullanıcılara gider.


## [beta-v4301 / 1.0.43-beta.1+4301] - 2026-07-21

> **Beta test sürümü — sayaç toplamı, saat gösterimi ve XP ekonomisi.** v42 stable'dan sonraki ilk beta. Sayaç durdurma bug'ının kalan (ekran) katmanı, çevrimdışı kuyruk kopyaları, 3 saatlik saat kayması ve beş başarımın yeniden fiyatlandırılması.

### Öne çıkanlar
- Durdur'a bastığın an toplam artık hiç zıplamıyor; kayıt sunucuya yazılırken de yazıldıktan sonra da **aynı sayı** görünüyor.
- Çalışma kayıtlarındaki ve sohbetteki saatler **3 saat geri** gösteriyordu; düzeldi.
- Beş başarımın XP değerleri yükseltildi ve düzeltme **geriye dönük**: daha önce kazandığın kademeler de yeni değere yükseliyor.

### Düzeltmeler
- **Durdurma çift sayımı (P0).** Oturum veritabanına yazılırken (yerel önbellek + ağ gidiş-dönüşü) geçen sürede sayaç hâlâ "çalışıyor" göründüğü için canlı süre ikinci kez toplanıyordu — 1 saatlik çalışma 2 saat görünüyordu. Ekranın "gösterdiğim sayıyı dondur" mekanizması da bu hatalı değeri yakalayıp gün boyu kilitliyordu. Ekran artık kendi gösterdiği sayıyı geri okumuyor; sayaç durumu kaydın yerleşip yerleşmediğinden bağımsız tek bir toplam üretiyor.
- **Ölü zaman.** Arka planda bildirimden Durdur'a basıp uygulamayı 5 dakika sonra açınca, aradaki boşluk çalışma süresine ekleniyordu.
- **Çevrimdışı kuyruk kopyaları (P1).** Bir oturum gönderilemezse başarılı olanlar da kuyrukta kalıp her açılışta yeniden yazılıyordu (her açılışta bir kopya daha). Kuyruk toptan silindiği için, gönderim sürerken eklenen yeni oturum da kaybolabiliyordu. Artık her kayıt benzersiz kimlik taşıyor ve kuyruktan yalnız gerçekten işlenenler düşürülüyor.
- **Saat gösterimi 3 saat geri.** Veritabanı zaman damgaları UTC olarak okunup doğrudan basılıyordu; Türkiye kalıcı UTC+3 olduğu için 16:00'daki çalışma 13:00 yazıyordu. Çalışma kayıtları ve sohbet mesajları düzeldi. Oturum düzenleme ekranı da gece yarısına yakın kayıtlarda **yanlış günü** açıyordu.
- **Sıralamadaki ateş rozeti kaldırıldı.** Aynı ikon sayaç kartında "hedef tutturma serisi", grup sıralamasında "üst üste çalışılan gün" anlamına geliyordu. Grup tarafında hedef serisi hesaplanamadığı için (herkesin günlük hedefi bilinmez) rozet düzeltilemezdi; kaldırıldı. Grup hedefi başlığındaki ateş korundu — o gerçekten hedef serisi.
- **Manuel süre çakışması.** Sayaç çalışırken bugüne manuel süre eklemek aynı dakikaları iki kez sayıyordu; engellendi. Geçmiş günlere ekleme serbest (o kayıtlar 23:59:59'da bittiği için canlı oturumla kesişemez).

### Ekonomi
- **XP yeniden fiyatlandırma (geriye dönük).** Maratoncu, Çelik İrade, Günün Kahramanı, Ateş Harlı ve Lokomotif başarımlarının XP değerleri yükseltildi. Kazanılmış kademeler, henüz toplanmamış ödüller ve profil XP/taç kademesi birlikte güncellenir. **Tüm değişiklikler artış yönündedir — kimsenin XP'si veya tacı düşmez.**

### Notlar
- Beta test sürümü (staging backend); stable kullanıcılara gitmez.
- Sunucu tarafı `0065` migration'ı gerektirir. Uygulama yayınlanmadan **önce** staging'e uygulanmalıdır; aksi hâlde ekranda yeni XP değeri yazıp sunucu eskisini verir.


## [v42 / 1.0.42+42] - 2026-07-20

> **Kararlı (stable) sürüm.** beta-v42 serisindeki sayaç durdurma yarışları, hata yönetimi ve gerçek kök neden düzeltmeleri (boş kimlik onarımı). Herkese (stable kanal).

### Öne çıkanlar
- Bildirimden/widget'tan başlatılan sayaç uygulama içi Durdur ile GERÇEKTEN duruyor. Boş kimlik bug'ı giderildi.
- Kronometrede Durdur'a ard arda basınca toplam sürenin birden fazla artması (çift/çoklu sayım) engellendi (tek oturum).
- Kayıt hatasında sayaç yine durur; oturum çevrimdışı kuyruğa alınıp sonra gönderiliyor.

### Notlar
- GitHub sideload **stable** APK; in-app güncelleme stable kullanıcılara gider.


## [beta-v4206 / 1.0.42-beta.6+4206] - 2026-07-20

> **Beta test sürümü — sayaç durdurma bug'ının GERÇEK kök nedeni.** Tam senkronizasyon tetkiki sonrası; WP-233/241/243 turları yanlış katmanı (reconcile yarışı) düzeltiyordu, asıl neden farklıydı. beta-v4205/4204'ten geliyorsan oturumun korunur.

### Düzeltmeler

- **Bildirimden/widget'tan başlatılan sayaç uygulama içi Durdur ile durmuyordu — GERÇEK kök neden (D1, P0).** Arka plandaki native sayaç servisi, sunucu-doğrulaması olmayan HER başlatmayı (bildirim/widget/uygulama içi) boş bir "koşu kimliği" (`liveRunToken=""`) ile kaydediyordu. Uygulama bu boş kimliği geçerli sanıp (`"" != null`) durdurma anında sunucuya boş kimlikle "finalize" isteği atıyor, istek hata verince durdurma akışı yarıda kesiliyor ve sayaç hiç durmuyordu (oturum da yazılmıyordu). Artık boş kimlik tek noktada yok sayılıyor (`_normalizeRunToken`); native ne yazarsa yazsın uygulama onu doğrulanmış sanmıyor. **Bu, stable v39'da olmayan; kurtarma sürecinde eklenen ölü "doğrulanmış oturum" özelliğinin durdurma yoluna sızmasından kaynaklanıyordu.** Önceki betaların neden farklı davrandığı da bununla açıklanıyor (v4204'ün zaman penceresi uygulama-içi başlatmayı tesadüfen koruyordu; v4205 onu kaldırınca uygulama-içi de bozuldu).
- **Ard arda Durdur = çift/çoklu sayım (D2, P0).** Durdurma, oturumu kaydederken ağ cevabını beklerken sayaç hâlâ "çalışıyor" göründüğü için, bu pencerede her ek Durdur basışı aynı aralığı bir kez daha kaydedip toplam süreyi şişiriyordu. Artık devam eden bir durdurma varken ikinci giriş reddediliyor (tek oturum).
- **Kayıt hatasında sayaç yine durur (D4).** Kayıt/gönderim hata verse bile sayaç durduruluyor; oturum çevrimdışı kuyruğa alınıp sonra gönderiliyor. Önceden tek bir hata "durdurulamıyor"a dönüşüyordu.
- **Saat hassasiyeti taşıyıcısı (D3).** Uygulama içi başlatmanın mikrosaniyeli zamanı ile native servisin milisaniyeli zamanı arasındaki fark, her yankıda gereksiz "durum yeniden benimseme" tetikleyip yukarıdaki zehirin taşıyıcısı oluyordu; karşılaştırma artık milisaniye granülerliğinde.

### Test notları

- Öncelikli doğrulamalar: (1) bildirimden/widget'tan Başlat → uygulama içi Durdur GERÇEKTEN durduruyor mu; (2) kronometre çalışırken Durdur'a hızlı 3-4 kez bas → toplam yalnız bir kez artıyor mu; (3) çalışırken uygulamayı kapat-aç → Durdur.
- Bu düzeltmeler, önceki turların kaçırdığı cihaz gerçeğini (native'in yazdığı boş kimlik) taklit eden deterministik regresyon testleriyle korunuyor (`timer_background_reconcile_test.dart` WP-245/246/247). Testler artık `token: ''` fikstürü kullanıyor — bu, üç betayı da CI'da yakalardı.
- Yalnız istemci beta adayı; production deploy/migration içermez.

## [beta-v4205 / 1.0.42-beta.5+4205] - 2026-07-20

> **Beta test sürümü — sayaç durdurma yarışı deterministik düzeltme.** beta-v4204/4203’ten geliyorsan oturumun korunur; aynı ayrı test ortamı kullanılıyor.

### Düzeltmeler

- **Bildirimden/widget'tan başlatılan sayaç uygulama içi Durdur ile durmuyordu (P1).** Kök neden: beta-v4204'te durdurma yarışını 1.5 sn'lik bir zaman penceresiyle bastırıyorduk; bu heuristik hem bazı gerçek bildirim/widget aksiyonlarını yutuyor (durdurup hemen yeniden başlatınca sayaç dirilmiyordu) hem de "bazen çalışıyor bazen çalışmıyor" belirsizliği yaratıyordu. Artık **içerik-temelli, deterministik**: her başlatmanın benzersiz başlangıç anı (epoch-ms) ile "native durdurma diske düşmeden gelen gecikmiş yankı" ile "gerçekten yeni bir başlatma" kesin ayırt ediliyor. Zaman penceresi tamamen kaldırıldı → gerçek aksiyonlar bir daha yutulmuyor.
- **Uzlaşma sırası.** Native durum bildirimleri tek işleme birleştiriliyor ve bir tur çalışırken yeni bildirim gelirse, tur bitince prefs taze okunup bir tur daha çalışıyor (son durum asla düşmüyor; beta-v4204 birleştirmesi bayat sonuç döndürebiliyordu).

### Test notları

- Öncelikli doğrulamalar: (1) bildirimden/widget'tan Başlat → uygulama içi Durdur — gerçekten duruyor mu; (2) Durdur → hemen bildirimden yeniden Başlat — yeni sayaç benimseniyor mu; (3) hızlı ard arda Başlat/Durdur.
- Bu düzeltme artık deterministik otomatik regresyon testiyle korunuyor (`timer_background_reconcile_test.dart` WP-243 grubu): gecikmiş yankı sayacı diriltmiyor + farklı-ms yeni başlatma benimseniyor.
- Bu kayıt yalnız istemci beta adayıdır; production deploy/migration içermez.

## [beta-v4204 / 1.0.42-beta.4+4204] - 2026-07-20

> **Beta test sürümü — sayaç yarışı düzeltmesi.** beta-v4203/4202’den geliyorsan oturumun korunur; aynı ayrı test ortamı kullanılıyor.

### Düzeltmeler

- **Sayaç başlat/durdur yarışı (P1).** Uygulama içi Başlat/Durdur ile arka plandaki sayaç servisi arasında bir yarış vardı: hızlı ard arda işlemlerde büyük sayaç bazen hiç artmıyor, durdurunca durmuyor ya da toplam süre çift/eksik yazılıyordu (uygulamayı kapatıp açınca düzeliyordu). Native servisin gönderdiği "durum değişti" bildirimleri sıra-dışı işlenip Dart tarafındaki sayaç durumunu eziyordu. Artık: (1) uygulama kendi Başlat/Durdur'unu yaptıktan sonra kısa bir süre native kaynaklı yeniden-uzlaşma bastırılıyor, (2) eş zamanlı uzlaşmalar tek işleme birleştiriliyor.
- **Bildirimden başlatma.** Bildirim panelinden başlatılan çalışma, uygulama önplandayken de doğru yansıyor ve uygulama içinden durdurulabiliyor (beta-v4203'te bu tam çözülmemişti; asıl kök neden yukarıdaki yarıştı).

### Test notları

- Öncelikli doğrulamalar: (1) hızlı ard arda Başlat/Durdur — büyük sayaç her seferinde düzgün başlıyor/duruyor mu; (2) bildirimden Başlat → uygulama içi Durdur; (3) 3 sn çalış → Durdur → toplam tam 3 sn artıyor mu (çift/eksik yok); (4) "uygulamayı kapatıp açınca düzeliyor" durumu artık yok.
- Bu yarış cihaza özgü olduğundan otomatik test tam yakalayamaz; cihaz doğrulaması esastır.
- Bu kayıt yalnız istemci beta adayıdır; production deploy/migration içermez.

## [beta-v4203 / 1.0.42-beta.3+4203] - 2026-07-20

> **Beta test sürümü — beta-v4202 saha bulguları düzeltmeleri.** beta-v4202’den geliyorsan oturumun korunur; aynı ayrı test ortamı kullanılıyor, yeniden hesap açman gerekmez.

### Öne çıkanlar

- **Bildirimden başlatılan çalışma artık uygulama içinden durdurulabiliyor.** Uygulama önplandayken bildirim panelinden başlattığın sayaç, uygulama içindeki Durdur’a basınca gerçekten duruyor (eskiden sessizce yok sayılıyordu → oturum süresi yazılmıyordu).
- **Grafik eksenleri düzeltildi.** Trend ve grup grafiklerine Y ekseni ölçeği eklendi; alt eksende yer oldukça artık her günün numarası görünüyor (eskiden 2–3 gün atlıyordu).
- **Taç kademeleri görünür.** Tacına dokununca tüm rütbeler ve her biri için gereken XP eşiği (Bronz → Immortal) açılıyor.

### Düzeltmeler

- **Sayaç çift-sayım.** Kronometreyi durdurunca bugünkü toplam bir an fazla (ör. 2 saat yerine 3 saat) görünüp sayacı kapat-aç yapınca düzeliyordu; giderildi.
- **Yanıltıcı başarım ilerlemesi.** Çelik İrade / Günün Kahramanı gibi tek seferlik “kişisel rekor” başarımlarında birikmeyen ilerleme çubuğu kaldırıldı; yerine en iyi değer gösteriliyor.
- **İç kararlılık.** Başarım ilerleme tetikleyicisindeki bir yarış durumu kapatıldı; iki kırık test yeşile alındı (toplam 645 test).

### Test notları

- Test ortamı beta-v4202 ile aynı (migration head `0064`). Öncelikli doğrulamalar: (1) bildirimden Başlat → uygulama içi Durdur; (2) 1 saat kayıtlı + 1 saat kronometre → Durdur’da tam 2 saat (3 değil), kapat-aç gerekmeden; (3) grafiklerde her günün numarası + trend grafiklerinde Y ekseni; (4) taça dokununca kademeler.
- Bu kayıt yalnız istemci beta adayıdır; production deploy/migration içermez.

## [beta-v4202 / 1.0.42-beta.2+4202] - 2026-07-20

> **Beta test sürümü — kurtarma paketi.** Bu beta iki büyük değişiklik getiriyor: (1) beta artık **kendi ayrı test veritabanına** bağlanıyor, (2) 6 kademeli ekonomi ve süre kaynağı eşitliği ilk kez birlikte test ediliyor. Aşağıdaki "Önce bunu oku" bölümünü atlama.

### ⚠️ Önce bunu oku — kurulum değişti

- **Telefonundaki beta kendini günceller.** Beta zaten kararlı sürümden ayrı bir uygulamaydı; bu sürüm onun üstüne normal güncelleme olarak iner. Silip yeniden kurmana gerek yok, kararlı sürüme de dokunmaz.
- **Beta artık test veritabanına bağlanıyor.** Eskiden beta gerçek (canlı) veritabanını kullanıyordu; artık ayrı bir test ortamı kullanıyor. Bu, beta'da yapılan hiçbir denemenin gerçek kullanıcı verisine dokunamaması için yapıldı.
- **Güncellemeden sonra oturumun kapanır ve sıfırdan hesap açman gerekir.** Eski girişin canlı veritabanına aitti, test veritabanında geçerli değil. Mevcut hesabın ve bütün geçmiş verin **kararlı sürümde güvende duruyor**, silinmedi.
- **Sürüm numarası biçimi değişti.** Beta numaraları artık `patch*100 + sıra` olarak yazılıyor (`beta-v4202` = 1.0.42'nin 2. betası). Bu, aynı numaranın iki farklı yapıya verilmesini engellemek için.

### Öne çıkanlar

- **Bütün süre kaynakları artık eşit.** Manuel giriş, uygulama kronometresi, geri sayım, Pomodoro ve bildirim/widget'tan başlatılan çalışma; kişisel istatistik, grup istatistiği, XP ve başarımlara **aynı şekilde** sayılır. Önceden bazı kaynaklar bazı hesaplamaların dışında kalıyordu.
- **Ödül zinciri tamamlandı.** Alfa, Kamp Ateşi, Lokomotif, Lider Kurt ve Mola Düşmanı başarımlarında ilerleme → aday → bekleyen ödül → topla akışı uçtan uca çalışır.
- **6 kademeli ekonomi.** Kademeler Elmas, Zümrüt ve Immortal ile genişledi; taç eşikleri `0 / 20.000 / 75.000 / 200.000 / 500.000 / 1.000.000` XP.
- **XP barı artık dürüst.** Barın doluluğu ile üstündeki yazı aynı matematiği gösterir; ekran okuyucu için açıklama eklendi.

### Test notları

- Test veritabanı migration seviyesi: `0064`. Bu beta yalnız o seviyeyle çalışır; uyuşmazlıkta uygulama sessizce yanlış veri göstermek yerine açılışta durur.
- Öncelikli test edilecekler: aynı süreyi beş farklı yoldan (manuel / kronometre / geri sayım / Pomodoro / widget) girip **aynı** istatistik ve XP sonucunu aldığını doğrulamak; ödül topladıktan sonra XP'nin iki kez artmadığını görmek; gece 23:59 → 00:01 geçişinde günün doğru dönmesi.
- Bulduğun sorunu `progress.md` içindeki aktif QA kaydına yaz.

## [beta-v41 / 1.0.41+41] - 2026-07-19

> **Beta test sürümü (ara düzeltme).** beta-v40 saha testinden çıkan üç hata düzeltildi. Kademe/XP/renk ekonomisi ve Alpha Wolf revizyonu bu pakette **yoktur**; sonraki betaya bırakıldı. XP davranışı değişmez (hâlâ shadow).

### Düzeltmeler
- **Grup fotoğrafı yüklenmiyordu:** "direct deletions from storage tables is not allowed" hatası giderildi. Eski avatarı silen veritabanı trigger'ı (0049) kaldırıldı; eski nesne temizliği artık istemci tarafında Storage API ile yapılır (migration `0054`).
- **Başarımlar sayfası her ~4 sn'de kendini yeniliyor ve ekran zıplıyordu:** Ödül banner'ının 4 sn'lik yoklama döngüsü kaldırıldı; ödül durumu artık olay bazlı (oturum bitince / topla sonrası) güncellenir. Scroll konumu korunur.
- **Yanlışlıkla tetiklenen aşağı-çek-yenile:** Uygulama geneli pull-to-refresh jesti kaldırıldı (veri realtime/olay bazlı tazelenir).
- **"Manuel süre ekle" ve "Günlük hedef" diyaloglarında** saat alanı İngilizce'de yanlışlıkla "Clock" yazıyordu; artık "Hours" (DE "Stunden", AR "ساعات").

### Test notları
- Grup fotoğrafı düzeltmesi için canlı Supabase'de `0054` migration'ı uygulanmalıdır (toplam `0047`–`0054`).
- Bu bir ara beta'dır; 6-kademe (Elmas/Zümrüt/Immortal), XP dengesi, taç eşikleri ve Alpha Wolf değişiklikleri **sonraki beta**da gelecek.

## [beta-v40 / 1.0.40+40] - 2026-07-19

> **Beta test sürümü.** v39'dan sonraki başarımlar, günlük görevler, grup avatarları ve doğrulanmış sayaç altyapısı bu pakette ilk kez birlikte cihaz testine açılır. XP ekonomisi hâlâ shadow modundadır; WP-219 aktive edilmemiştir.

### Öne çıkanlar
- **Başarımlar ve ödüller:** Gerçek ilerleme, **28/30 Kusursuz Ay kuralı** (sabit eşik 28 hedef günü), bekleyen ödül/Topla akışı ve ödül bildirimi eklendi. 27 günden az hedef tamamlanan aylar Kusursuz Ay sayılmaz; önceden verilmiş XP/rozet geri alınmaz.
- **Günlük görevler:** Görevler hesaba bulutta kaydolur, cihazlar arasında eşitlenir ve İstanbul gün sınırında yeniden açılır.
- **Gruplar:** Özel grup avatarı ve Alfa, Kamp Ateşi, Lokomotif grup metriği altyapısı eklendi.
- **Sayaç güvenliği:** Sunucu-izinli canlı oturum ve native sayaç köprüsü shadow modunda ölçülür. Bildirim/widget'tan saf-native başlatılan çalışma istatistiğe sayılır; bu beta döneminde XP davranışı değiştirilmez.
- **Gezinme:** Ana Sayfa dışındaki dört ana sekmeye yeniden dokunmak listeyi başa döndürür.

### Test notları
- Canlı Supabase'de `0047`–`0053` migration'ları uygulanmış olmalıdır.
- Bu sürüm beta içindir; cihaz testi sonucunu `progress.md`deki aktif QA kaydına göre kaydet.

## [v39 / 1.0.39+39] - 2026-07-19

> **Kararlı (stable) test sürümü.** v38’de görülen grafik renk çakışması giderildi.

### Öne çıkanlar
- **Grup istatistikleri:** Renkler artık sabit 10’lu paletten dönmüyor. Mevcut grup üye sayısına göre renk çemberine eşit aralıklarla dağıtılıyor; küçük/büyük gruplarda her üyenin rengi ayrıdır.
- Üye renk haritası donut ve liderlik geçmişi tarafından ortak kullanılır; katkı veya sıralama değişmesi rengi değiştirmez.

### Notlar
- GitHub sideload **stable** APK; in-app güncelleme stable kullanıcılara gider.

## [v38 / 1.0.38+38] - 2026-07-19

> **Kararlı (stable) test sürümü.** v37 cihaz geri bildirimiyle grup grafik renkleri hizalandı, sayaç bildirimi eski tek satır düzenine döndü.

### Öne çıkanlar
- **Grup istatistikleri:** Üye katkısı donut'u ve liderlik geçmişi artık aynı kişi için aynı rengi kullanır; sıralama değişse bile renk sabit kalır.
- **Sayaç bildirimi:** One UI'da alta taşınan `Break / Stop` sistem aksiyonları kaldırıldı. Bildirim tekrar tek satırda solda `00:MM:SS`, sağda doğrudan **Başlat/Durdur** düğmesini gösterir.

### Notlar
- Bu sürüm Samsung bildirim panelinde gerçek cihaz testi içindir; Başlat/Durdur, uygulama kapalıyken çalışma ve 00:MM:SS görünümü doğrulanmalıdır.
- GitHub sideload **stable** APK; in-app güncelleme stable kullanıcılara gider.

## [v37 / 1.0.37+37] - 2026-07-19

> **Kararlı (stable) test sürümü.** Grup hedefi özetini görünür kılar ve sayaç bildirimini saat uygulaması gibi yalın hâline döndürür.

### Öne çıkanlar
- **Grup hedefi:** Günlük hedef göstergesinin yanında artık bugün aktif üye sayısı, hedefe kalan süre ve günün lideri görünür. Hedef tamamlandığında kalan süre yerine “Tamamlandı” gösterilir.
- **Sayaç bildirimi:** Büyük, canlı `HH:MM:SS` paneli varsayılan olarak geri geldi; dolgu başlık/gövde metni kaldırıldı. Başlat/Durdur/Mola sistem aksiyonları olarak görünür.

### Notlar
- İlk cihaz testi için Samsung bildirim panelinde açık/koyu tema, Başlat/Durdur/Mola ve uygulama kapalıyken sayaç akışı kontrol edilmelidir.
- GitHub sideload **stable** APK; in-app güncelleme stable kullanıcılara gider.

## [v36 / 1.0.36+36] - 2026-07-19

> **Kararlı (stable) sürüm.** Manuel süre gece-yarısı düzeltmesi + istatistik ekranı sadeleştirme/yenileme. Herkese (stable kanal).

### Öne çıkanlar
- **Manuel süre gece yarısı düzeltmesi:** "Bittiği ana göre" — bugün eklerken `bitiş = şu an`, `başlangıç = şu an − süre`; artık gelecek-bitiş yok ve gece 00:0x'te eklenen süre yanlışlıkla yeni günün başına yığılmıyor, gerçekten çalışılan güne (dün akşamı) sayılıyor. Geçmiş gün seçilince o günün sonuna yazılır.
- **İstatistik / Kişisel sadeleşti:** gereksiz "Dönem Toplamları", "Rekorlar" ve "Günlük Hedef" bölümleri kaldırıldı; trend + seçili tarih aralığı grafiklerine **eksen/ölçek** eklendi; Insight (radar) etiketleri düz/okunur.
- **İstatistik / Gruplar yenilendi:** mükerrer ikinci hedef kartı kaldırıldı; üye katkısı donut'una **isim+renk legend**; **liderlik geçmişi artık sıralama çizgi grafiği** (Y=sıra, X=zaman, üye başına çizgi — lig sıralaması tarzı); grup trendi tek grafiğe indirildi.

### Notlar
- GitHub sideload **stable** APK; in-app güncelleme stable kullanıcılara gider.
- Liderlik sıralama grafiği `group_daily_totals`'tan hesaplanır (ek RPC yok).

## [v35 / 1.0.35+35] - 2026-07-18

> **Kararlı (stable) sürüm.** v29'dan bu yana biriken tüm beta çalışması (v30–v34) + Görevler kartı tasarım cilası tek stable sürümde toplanır. Herkese (stable kanal) yayınlanır.

### Öne çıkanlar
- **Görevler** özelliği: Araçlar sekmesinde tam liste (tarih **veya** kalan süre), en yakın bitiş üstte, kalan süreye göre aciliyet rengi, gecikenler kırmızı “Gecikti”.
- **Ana ekran “Görevler” kartı yenilendi**: her satırda kalan-süre rozeti (3g · 5s · 12dk · Gecikti · Süresiz), düzenli ayraçlı liste, başlıkta aktif sayaç, tüm satıra dokunup işaretleme.
- **İstatistikler** sadeleşti: tek satır dönem seçici + kompakt kıyas; grup ekranında sıralama en üstte.
- **Profil**: gerçek taç tasarımı (renkli halka + taç, ~%18 büyütüldü); gereksiz oyunlaştırma öğeleri temizlendi.
- Ana ekran ızgara yoğunluğu herkeste sabit 32 (seçici kaldırıldı).
- **Geri bildirim gönderimi onarıldı** (canlı 0046 trigger düzeltmesi).
- Arapça/Almanca çeviriler tamamlandı; Araçlar → “kalan süre” doğru etiket.

### Notlar
- GitHub sideload **stable** kanal APK'si (`app-release.apk`); in-app güncelleme stable kullanıcılara gider.
- Görevler cihazda `user_tasks_v2` prefs; XP bağı yok.
- Canlı DB: 0039–0041 + 0044–0046 uygulanmış olmalı.

## [beta-v34 / 1.0.34+34] - 2026-07-18

> **Beta test sürümü.** Cihaz listesi: `docs/qa/BETA-v34-TEST.md`.

### Highlights
- Yeni: Görevler — Araçlar sekmesi (eski Saat); tarih veya kalan süre; aciliyet rengi; gecikti kırmızı.
- Ana ekran “Görevler” kartı: renkli liste + tek dokunuşta işaretleme.
- Taç tasarımı biraz büyütüldü.
- Geri bildirim onarımı (canlı 0046 trigger).

### Notes
- Görevler prefs `user_tasks_v2`; XP yok.
- Push sonrası CI: tag `beta-v34` → GitHub beta APK.

## [beta-v33 / 1.0.33+33] - 2026-07-18

> **Beta test sürümü.** Cihaz listesi: `docs/qa/BETA-v34-TEST.md` (v33 yönlendirir).  
> Canlı: **0039–0041** + **0044–0046**.

### Highlights
- İstatistik dönem seçici sadeleşti (tek yatay satır + kompakt kıyas).
- Grup istatistiği: sıralama en üstte; hedef göstergesi özetle dolduruldu.
- Profil: gerçek taç tasarımı (renkli halka + taç) + taç ilerleme (XP) çubuğu.
- Geri bildirim hatası artık ayrıntı (kod) gösteriyor (teşhis).

### Notes
- Feedback hâlâ patlarsa snackbar “Detay: kod” satırını kaydet.
- Push sonrası CI: tag `beta-v33` → GitHub beta APK.

## [beta-v32 / 1.0.32+32] - 2026-07-18

> **Beta test sürümü.** Cihaz listesi: `docs/qa/BETA-v33-TEST.md` (v32 listesi yönlendirir).  
> Canlı: **0039–0041** (analitik RPC) + **0044–0045** (feedback ensure + PostgREST schema reload).

### Highlights
- Geri bildirim gönderimi onarıldı (PostgREST şema önbelleği / 0045).
- İstatistik başlığı sadeleşti (tek satır dönem + kompakt kıyas).
- Ana ekran ızgara yoğunluğu herkeste sabit 32 (seçici kaldırıldı).
- Profil sadeleşti (level/quest/streak/freeze/total kaldırıldı; başarımlar kaldı).
- Yeni: Ana ekrana Görevler kartı (günlük/haftalık, tik/üstü çizme).

### Notes
- Home dashboard kart ekleme kullanıcı tercihi; density seçeneği yok.
- Push sonrası CI: tag `beta-v32` → GitHub beta APK.

## [beta-v31 / 1.0.31+31] - 2026-07-18

> **Beta test sürümü.** Cihaz listesi: `docs/qa/BETA-v32-TEST.md` (v31 listesi yönlendirir).  
> Canlı: **0039–0041** (analitik RPC) + **0044** (feedback ensure).

### Highlights
- Klasik istatistik ListView; sürükle-ızgara ve beta toggle kaldırıldı.
- Sabit bölümler: gauge, area, radar, katlı scatter, detaylı geçmiş; dönem yıl/özel + kıyas.
- Grup: katkı donut, liderlik serisi, gauge.
- Feedback net hata mesajları + ensure migration.
- Başarımlar başlık taşması; Gruplar nested-scroll; de/ar l10n iyileştirme.

### Notes
- Home dashboard sürükle-bırak kullanıcı tercihi olarak korundu.
- Push sonrası CI: tag `beta-v31` → GitHub beta APK.

## [beta-v30 / 1.0.30+30] - 2026-07-18

> **Beta test sürümü.** Canlıda **0039–0043** migration’ları uygulanmış olmalı.
> Onay tick list: `docs/qa/BETA-v30-ONAY-LISTESI.md` · ayrıntılı adımlar: `docs/qa/BETA-TEST-KILAVUZU.md`.

### Highlights
- **Yeni istatistik ekranı (Beta):** Ayarlar’dan aç/kapa; ızgara, kart ekle/çıkar/boyut, dönem yıl/özel + kıyas.
- **Grup analitiği RPC:** üye katkı payı + liderlik serisi (`get_user_day_totals` / contribution / leaderboard).
- **Gamification:** seviye eğrisi, görev vitrini, kozmetik + istemci yazım koruması (0042/0043).
- **Dil:** Arapça / Almanca + RTL altyapı (baseline çeviri).
- **Onboarding / dışa aktarma / akıllı hatırlatma** paketleri bu hatta.

### Fixes
- Analitik migration `start_time` (0039/0040 doğru kolon; 0041 yedek).
- Feedback: oturum/RLS hataları debug log + net oturum mesajı (WP-168).
- Timer test FakeTimer dispose sızıntısı (WP-167).
- Onboarding per-user; export PII strip; RTL directional (WP-166).

### Notes
- Flag **kapalı** varsayılan: eski İstatistik ListView birebir. Test için Ayarlar’dan Beta’yı aç.
- Widget/bildirim SSOT (WP-134–137) hâlâ **cihaz onayı** bekliyor.
- Stable v30 Play kapısı ayrı; bu tag yalnız **githubBeta** sideload APK.

## [v29 / 1.0.29+29] - 2026-07-16

> **Stable — Android ≤13 sayaç FGS çökmesi (WP-103).**

### Highlights
- Android 10–13’te kronometre başlat/durdur uygulama kapanması giderildi.
- Servis API 29–33 `dataSync`, 34+ `specialUse`; manifest `dataSync|specialUse`.

### Fixes
- specialUse-only beyan + DATA_SYNC runtime uyumsuzluğu (IllegalArgumentException).

### Notes
- API 33: başlat → arka plan → durdur; 0 çökme.

## [v28 / 1.0.28+28] - 2026-07-16

> **Stable — gece yarısı saat kartı + hızlı pull-to-refresh.**

### Highlights
- Gece yarısından sonra Ana Sayfa dünün süresini dondurmaz (Europe/Istanbul gün).
- Aşağı çekerek yenileme kritik veriyi ~2 sn içinde bitirir.

### Fixes
- StudyTimerCard freeze yalnız aynı Istanbul gününde (WP-102).
- Pull-to-refresh dar kritik liste + kısa timeout.

### Notes
- Gece yarısı sonrası saat toplamı + bir ekranda pull-to-refresh.

## [v27 / 1.0.27+27] - 2026-07-15

> **Stable — saat başına 50 XP + senkron güvenilirliği (WP-100/101).**  
> Ayrıntı: `release_notes.json` v27 girdisi.

### Highlights
- Her tamamlanan çalışma saati 50 XP (önceden 10).
- Manuel süre ekleme ana sayfa toplamını hemen günceller.
- Pull-to-refresh timeout; widget start presence yeniden yazımı.

## [beta-v26 / 1.0.26+26] - 2026-07-15

> **Beta — tercihler, açılış bildirimleri ve uygulama dili düzeltmeleri.**

### Fixes
- **Aylık e-posta tercihi kalıcı:** Anahtarı kapattığında ekran eski profil
  verisi gelene kadar geri açılmaz; kaydetme başarısız olursa önceki değer geri
  yüklenir.
- **Açılıştaki eski dürtmeler sessiz:** Dinleyici açılmadan önce oluşturulmuş
  dürtmeler artık uygulamayı açınca yerel bildirim üretmez. Uygulama açıkken
  gelen yeni dürtme ise yalnızca bir kez gösterilir.
- **Ayarlar > Uygulama dili:** Sistem varsayılanı, Türkçe ve İngilizce seçenekleri
  eklendi. Seçim hemen uygulanır, yeniden açılıştan sonra korunur ve `sa/dk/sn`
  ile `h/m/s` süre kısaltmalarını da aynı dile göre belirler.

### Test odağı
- Aylık e-posta anahtarını kapatıp Ayarlar'dan çıkıp geri gir; kapalı kalmalı.
- Uygulamayı tamamen kapatıp eski dürtmeler varken aç; eski kayıtlar bildirim
  olarak gelmemeli. Ardından uygulama açıkken yeni bir dürtme gönder.
- Ayarlar'dan uygulama dilini Türkçe ve İngilizce yap; metinler ve istatistik
  süreleri anında değişmeli, uygulamayı kapatıp açınca seçim korunmalı.

## [beta-v25 / 1.0.25+25] - 2026-07-15

> **Beta — Türkçe süre kısaltması düzeltmesi.**

### Fixes
- **Türkçe süreler artık Türkçe:** grafik, istatistik, hedef, kayıt ve sayaç
  kartlarında `4h 5m` yerine `4sa 5dk`; saniye değerinde `40sn` görünür.
- **İngilizce kompakt kaldı:** İngilizce arayüz bilinçli olarak `4h 5m` ve
  `40s` kullanır; uzun `hours/minutes` etiketleri grafiğe geri dönmez.

### Test focus
- Telefonun uygulama dilini Türkçe yap; Ana Sayfa ve İstatistikler'de `sa/dk/sn`,
  ardından İngilizce'de `h/m/s` kaldığını kontrol et.

## [beta-v24 / 1.0.24+24] - 2026-07-15

> **Beta — Kanıtlı One UI bildirim düzenine dönüş ve evrensel yenileme.**

### Fixes
- **Geçmişteki satır geri geldi:** Dil paketi öncesinde kullanılan `timer_notification.xml`
  geri yüklendi: solda canlı sayaç, sağda tek **Başlat/Durdur** düğmesi.
- **Asıl neden giderildi:** `WP-80`'de dinamik panel uygunluğu için silinen özel
  görünüm geri getirildi. Bu, çeviri paketiyle ilişkili değildi.
- **Aşağı çekerek yenile:** Tüm uygulama route'larında dikey listeyi aşağı çekmek,
  güncel oturum/istatistik, grup, ders, bildirim, presence ve başarım verisini
  yeniden ister; uygulamayı kapatıp açmak gerekmez.
- **Belirgin beta paketi:** Launcher adı artık **Odak Kampı BETA TEST**. Mevcut
  beta ikonundaki BETA şeridi adaptive-icon kırpılsa bile paket stable'la karışmaz.

### Test odağı
- Samsung One UI'da bildirimde eski yatay görünümü; uygulamayı açmadan **Durdur**
  ve **Başlat** eylemlerini dene.

## [v22 / 1.0.22+22] - 2026-07-15

> **Stable — Bildirim ve İngilizce bağlam düzeltmeleri.**

### Fixes
- **Sade odak bildirimi:** Çalışırken sistem başlığı altında yalnız canlı sayaç
  ve **Durdur**; boşta yalnız `00:00:00` ve **Başlat** görünür. Eski açıklama
  satırları ile Mola eylemi kaldırıldı.
- **İngilizce süre metinleri:** Başarımlarda `6 Clock` yerine `6 hours`, kademe
  satırlarında `Level 1`; grafiklerde uzun süre adları yerine `4h 5m` biçimi.
- **Başarım ayrıntıları:** Tıklanan başarımlar, aktif dilde tam cümleli koşulları
  gösterir. Açılmış gizli başarımlar koşulunu açıklar; kilitli olanlar sır kalır.

### Test odağı
- Samsung One UI'da odak sayacını başlat/durdur; bildirimde sistem başlığı
  dışında yalnız sayaç ve tek eylem olduğunu doğrula.
- İngilizce ve Türkçe'de Başarımlar ekranını aç; kademe koşullarının anlamlı
  cümleler olduğunu ve grafik sürelerinin `4h 5m` biçiminde kaldığını doğrula.

## [v21 / 1.0.21+21] - 2026-07-15

> **Stable — Global grup erişimi.** Açık gruplar keşfedilebilir; gizli gruplar
> davet koduyla sınırlı kalır.

### Highlights
- **Açık grup keşfi:** Grupları keşfet ekranında açık gruplar aranabilir,
  üyelik kapasitesi ve günlük hedefi görülebilir; tek eylemle katılınabilir.
- **Grup gizliliği:** Yeni grup oluştururken veya yönetici ayarından **Gizli**
  (davet kodu gerekir) ya da **Herkese açık** seçilebilir.
- **Global dil zemini:** Bu yüzey İngilizce ve Türkçe çalışır; desteklenmeyen
  sistem dilleri İngilizceye düşer.

### Security
- Keşif kartları davet kodu, üye listesi, kullanıcı profili ve grup çalışma
  verisi göstermez. Katılım ve kapasite denetimi sunucu tarafında yapılır.

### Notes
- Açık/özel grup migration'ı yayın öncesinde Supabase'e uygulanmıştır.
- Sorun görürsen grup adı, cihaz modeli ve uygulama sürümüyle bildir.

## [beta-v20 / 1.0.20+20] - 2026-07-15

> ⚠️ **Beta test sürümü.** Bu paket stable değildir; bildirim teslimi ve dinamik
> sayaç paneli düzeltmeleri gerçek Android cihazda doğrulansın diye yayımlanır.

### Fixes
- **Açılışta güncelleme bildirimi:** Uygulama açılırken Android sistem bildirimi
  oluşturulmaz; güncelleme anahtarı yalnız uygulama içi güncelleme penceresini
  yönetir.
- **Dürtme patlaması:** Uygulama kapalıyken gelen eski dürtmeler açılışta topluca
  bildirim üretmez. Uygulama açıkken canlı gelen yeni dürtme yalnız bir kez görünür.
- **Dinamik panel uygunluğu:** Sayaç bildirimi özel şablon yerine standart Android
  canlı kronometre, **Mola** ve **Durdur** eylemlerini kullanır; OEM canlı paneli
  için uygun yüzey budur.

### Test odağı
- Uygulamayı açarken Android sisteminde güncelleme bildirimi görünmediğini doğrula.
- Uygulama kapalıyken gönderilmiş dürtmelerin açılışta patlamadığını; uygulama
  açıkken yeni dürtmenin bir kez geldiğini doğrula.
- Sayacı başlatıp uygulamayı görev listesinden kapat; bildirimde süre, Mola ve
  Durdur'u dene. Destekleyen cihazda canlı panel/Now Bar/HyperOS terfisini kaydet.

### Notes
- OEM canlı paneli Android sürümü ve üretici politikasına bağlıdır; standart canlı
  bildirim ve kontroller tüm desteklenen Android sürümlerinde çalışmalıdır.

## [beta-v19 / 1.0.19+19] - 2026-07-14

> ⚠️ **Beta test sürümü.** Bu paket stable değildir; dinamik sayaç paneli ve
> Android izin yönetimi gerçek cihazda doğrulansın diye yayımlanır.

### Highlights
- **Dinamik sayaç paneli:** Bildirim genişletildiğinde canlı süre, **Mola** ve
  **Durdur** kontrolleri gösterilir. Mola sonunda **Çalışmaya dön** kullanılabilir.
- **App kapalı kontrol:** Bildirim eylemleri Flutter ekranının açılmasını
  beklemeden native foreground service tarafından işlenir.
- **İzinleri geri alma:** Widget ve izinler ekranında dört izin için **Kapat**
  düğmesi ilgili Android ayarına gider; ekrandaki rehber, ayarı nasıl geri
  alacağını açıklar.

### Test odağı
- Samsung One UI ve Pixel’de uygulamayı görev listesinden kapatıp panelden
  Başlat/Durdur/Mola dene.
- Bildirim, kesin alarm, pil istisnası ve tam ekran alarm için **Kapat** →
  sistem ayarı → anahtarı kapat → uygulamaya dön akışını dene.

### Notes
- OEM'e göre dinamik panel görünümü ve ayar başlıkları değişebilir.
- Sorun varsa stable yerine bu beta sürümünün numarası ve cihaz modeliyle bildir.

## [v8 / 1.0.18+8] - 2026-07-13

> **Stable — Güven Sürümü.** beta-v8…v18 hattının ürün paketi. Windows masaüstü bu sürüme dahil değil.

### Highlights
- **Native sayaç:** App kapalıyken bildirim/widget Başlat–Durdur; akan süre; oturum kaydı.
- **Saat Merkezi:** Alarm (app kapalı çalar), timer, kronometre, dünya saati, StandBy; timer/krono çalışma oturumuna yazılır.
- **Başarım 3.0:** Server-authoritative XP; taç sıralama/aktif/sohbet/istatistik/profil fotoğrafında; profilde Başarılar üstte.
- **Tema Stüdyosu:** 15 atmosfer (Buzul, Kamp Ateşi, Gelecek Neon, Yumuşak…); anında uygula.
- **IA:** Widget/izinler Ayarlar’da; Ana Sayfa’ya tekrar basınca en üste kayar; avatar zoom.

### Notes
- **XP sıfırlama:** Genel yayın için `0028_xp_reset_general_launch.sql` Supabase SQL Editor’da **bir kez** çalıştırılmalı (tag öncesi/hemen sonrası). Çalıştırılmazsa mevcut XP kalır.
- Sorun olursa bir sonraki stable (v9+) hotfix olarak çıkar.
- Windows (MSIX/IA) ayrı program; bu APK Android stable.

## [beta-v18 / 1.0.18+18] - 2026-07-13

### Highlights
- Taç rütbesi artık profil dışında da görünür: sıralama, aktif üyeler, sohbet, istatistik, grup üyeleri, profil fotoğrafı.
- Profil sırası: **Başarılar** üstte, altında Çalışma kayıtları → Ayarlar.
- Saat: Widget/izinler Ayarlar’a taşındı (ayrı sekme yok); Ana Sayfa sekmesine tekrar basınca en üste kayar.
- Atmosfer temaları: Buzul, Yumuşak Krem, Gelecek Kenarı + Türkçe aile adları (15 tema).

### Notes
- v8 stable’a gömüldü; ayrı beta paketi gerekmez.

## [beta-v17 / 1.0.17+17] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v16 alarm app-kapalı çalmama + hub/widget düzeltmeleri.

### Alarm güvenilirlik

- **`setAlarmClock`:** Doze ertelemesini azaltan saat-uygulaması API’si.
- **Her tetikte fullScreen bildirim + Activity** (app kapalıyken Activity tek başına yetmiyordu).
- **İzin sihirbazı:** Bildirim, kesin alarm, pil, tam ekran — Widget sekmesi + alarm eklerken.
- Exact izni yoksa artık sessizce yutulmuyor; inexact yedek kuruluyor.

### Saat hub

- **6 sekme tek satır:** Widget · Saat · Alarm · Timer · Krono · Dünya (kaydırma yok).
- **En sol: Widget** — ana ekran widget listesi + izin durumu.
- **Saat = çalışma birleşik:** Büyük saat + çalışma oturumu Başlat/Durdur + Mod/ders.

### Widget

- Yeni: **Dijital saat** (TextClock), **Sıradaki alarm**.
- Mevcut: çalışma sayacı, istatistik, sıralama.

## [beta-v16 / 1.0.16+16] - 2026-07-13

> ⚠️ **Beta test sürümü.** Saat Merkezi + native alarm güvenilirlik (P0). Cihaz QA odaklı.

### Saat Merkezi (yeni)

- **6 sekmeli Saat Merkezi:** Saat · Dünya · Alarm · Timer · Kronometre · Odak.
- **Epoch zaman motoru:** Süre duvar saati farkından; Doze/frame atlamaya dayanıklı.
- **Alarm 2.0:** Tekrar günleri, sonrakini atla, anti-snooze (matematik), kademeli ses,
  erteleme, exact alarm izin uyarısı.
- **Native alarm (P0):** `AlarmManager` + kilit ekranı `AlarmRingActivity`;
  varsayılan alarm sesi ile 30 sn crescendo; Kapat / Ertele native.
- **Boot / timezone:** Yeniden başlatma ve saat dilimi değişiminde alarm/timer
  mirror'dan yeniden planlanır.
- **Çoklu timer:** Preset'ler, +1/+5 dk, app kill sonrası bitiş için native schedule.
- **Dünya saati:** Gündüz/gece kartları + ofset etiketi.
- **Kronometre:** Tur, en hızlı/yavaş highlight, kopyala.
- **StandBy:** Yatay masa saati, gece kırmızı ton, burn-in kayması.

### Not

- Çalışma sayacı (Odak / native StudyTimer) ayrı kaldı; bu beta kişisel saat ürününü dener.
- SQL 0025–0027 canlıda olmalı; 0028 yalnız genel yayın. Bu beta XP sıfırlamaz.

## [beta-v15 / 1.0.14+15] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v14 görünüm rötuşunun küçük düzeltmesi.

### Görünüm

- **Bildirimdeki süre tam görünüyor:** Rakamlar çok büyük olduğu için son saniyeler
  (`00:00:` gibi) kırpılıyordu; boyut biraz küçültülüp düğmeye yer açıldı, artık tüm
  `HH:MM:SS` sığıyor.

## [beta-v14 / 1.0.13+14] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v13 cihazda sorunsuz çalıştı; bu sürüm yalnız görünüm rötuşu.

### Görünüm

- **Ana ekran widget'ı sadeleşti:** Artık yalnız akan saat + tek Başlat/Durdur düğmesi
  (başlık ve durum yazısı kaldırıldı).
- **Bildirim/widget düğmesi yumuşadı:** Başlat/Durdur düğmesinin köşeleri yuvarlatıldı
  (pill görünümü).

## [beta-v13 / 1.0.12+13] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v12'de cihazda görülen **açılış çökme döngüsü** giderildi + sayaç bildirimi durak-saati görünümüne yaklaştırıldı.

### Kritik düzeltme

- **Açılış çökme döngüsü giderildi:** beta-v12'de uygulama kapalıyken bildirim/widget
  Durdur'a basınca native servis çöküyor, ardından uygulama her açılışta ~1 sn sonra
  kapanıyordu ("this app has a bug"). Sebep: foreground servis `START_STICKY` ile
  boş komutla yeniden başlatılıp `startForeground` çağrılmadan Android 12+ zaman
  aşımına düşüyordu. Servis artık `START_NOT_STICKY` + her komut yolunda güvenli
  `startForeground`; bildirim aksiyonları arka planda `getForegroundService` kullanır
  (arka plan servis başlatma yasağına takılmaz). Her komut ayrıca sessiz toparlanma
  (try/catch) ile sarıldı — hiçbir durumda uygulamayı çökertmez.

### Görünüm

- **Sayaç bildirimi durak-saatine yaklaştırıldı:** "Boş kutu" yerine büyük, akan
  `HH:MM:SS` rakamları + tek Durdur/Başlat düğmesi. *Not: Android 12+ standart bildirim
  başlığındaki uygulama adını sistem çizer; özel görünümle bile kaldırılamaz. Uygulama
  adı olmayan yüzen kapsül (referans görsel) OEM "canlı bildirim" / Android 16 Live
  Update yoludur — sıradaki adım.*

### Bilinen / sıradaki

- Bildirimin uygulama-adı olmayan **dinamik panel/kapsül** görünümü (HyperOS "Live
  notifications" / Samsung "Now Bar" / Android 16 Live Updates) OEM'e bağlı ayrı iş
  paketidir; bu sürümde standart (uygulama-adı başlıklı) canlı bildirim kullanılır.

## [beta-v12 / 1.0.11+12] - 2026-07-13

> ⚠️ **Beta test sürümü.** Sayaç bildirimi ve ana ekran widget'ı **native** altyapıya taşındı; beta-v11'in R1/R2 düzeltmelerini de içerir.

### Yenilikler / Düzeltmeler

- **Ana ekran widget'ı ve bildirim artık uygulama tamamen kapalıyken de çalışıyor:**
  Sayaç bildirimi ve widget artık native bir Android servisiyle yönetiliyor. Widget'taki
  **Başlat/Durdur** ve bildirimdeki buton, uygulamayı hiç açmadan çalışır. Süre bildirimde
  ve widget'ta native olarak akar (saniyede bir uygulama güncellemesi yok → pil dostu).
- **Oturum kaydı güvende:** Uygulama kapalıyken yaptığın Başlat/Durdur'lar bir kuyruğa
  yazılır; uygulamayı açtığında her çalışma aralığı sunucuya doğru biçimde kaydedilir
  (arka arkaya durdur/başlat oturum sayımını bozmaz).
- **beta-v11 dahil:** Bildirimde gövde yazısı yok + Durdur↔Başlat kalıcı toggle.

### Bilinen / sıradaki

- Native bildirimin cihazın **dinamik paneline** (HyperOS "Live notifications" / Samsung
  "Now Bar") terfisi OEM'e bağlıdır; desteklenmeyen cihazda düz ama temiz canlı bildirime düşer.

## [beta-v11 / 1.0.10+11] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v10 cihaz geri bildirimine göre sayaç bildirimi iki noktada elden geçirildi.

### Düzeltmeler

- **Bildirimde gövde yazısı kalktı (saat uygulaması gibi):** Sayaç bildiriminde artık
  "Odak Kampı çalışıyor" alt satırı yok; yalnız akan `HH:MM:SS` süre ve buton görünür.
- **Durdur↔Başlat kalıcı toggle:** Bildirimdeki **Durdur**'a basınca bildirim artık
  kaybolmaz; süre kaydedilir ve buton **Başlat**'a döner (`00:00:00`). Uygulamayı hiç
  açmadan **Başlat** ile yeni bir oturuma devam edebilirsin; her Durdur ayrı bir oturum
  olarak doğru kaydedilir (arka arkaya durdur/başlat oturum sayımını bozmaz).

### Bilinen / sıradaki

- Bildirimin cihazın **dinamik paneline** (HyperOS "Live notifications" / Samsung "Now Bar")
  native kronometre gibi terfi etmesi ayrı bir adımda ele alınacak (WP-51).
- **Ana ekran widget'ı** ve widget üzerindeki Başlat/Durdur bir sonraki beta'da aynı
  mantıkla elden geçirilecek (WP-42).

## [beta-v10 / 1.0.9+10] - 2026-07-13

> ⚠️ **Beta test sürümü.** Sayaç bildirimi tamamen yeniden yapıldı.

### Düzeltmeler

- **Artık TEK bildirim, canlı akan saat ve Durdur butonu:** Sayaç çalışırken tek bir
  bildirim çıkar; başlığında saniye saniye akan `HH:MM:SS` süre ve altında **Durdur**
  butonu bulunur. Önceki çift bildirim (biri düz "arka planda korunuyor", biri ayrı
  kronometre) kaldırıldı — tek, temiz, saat uygulaması gibi.
- **Durdur uygulama tamamen kapalıyken de çalışır:** Bildirimdeki Durdur'a basınca
  sayaç, uygulamayı açmadan durur; oturum gerçek durdurma anıyla kaydedilir (uygulamayı
  sonra açsan bile aradaki süre yanlış eklenmez).

### Bilinen / sıradaki

- **Ana ekran widget'ı** ve widget üzerindeki Başlat/Durdur bir sonraki beta'da
  aynı mantıkla elden geçirilecek (WP-42).

## [beta-v9 / 1.0.8+9] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v8 cihaz geri bildirimine göre düzeltmeler.

### Düzeltmeler

- **Sayaç bildirimi artık tek ve canlı:** Sayaç çalışırken bildirimde saniye saniye
  akan `HH:MM:SS` kronometre baskın olarak görünür. Önceden servisin düz "arka planda
  korunuyor" bildirimi öne çıkıp canlı bildirimi gizliyordu; artık düz servis
  bildirimi en dibe alındı, üstte tek canlı kronometreli bildirim kalıyor (sessiz).
- **Kamp ateşi sahnesi kısaldı:** Gruplar sekmesindeki kamp ateşi çok uzundu ve
  üstte/altta gereksiz boşluk kaplıyordu; sahne kısaltıldı.

### Bilinen / sıradaki

- Bildirim ve widget'taki **Başlat/Durdur butonlarının uygulama tamamen kapalıyken**
  işlenmesi bir sonraki beta'da (arka plan komut işleme). Şu an bu butonlar uygulama
  açık/açılırken çalışır.

## [beta-v8 / 1.0.7+8] - 2026-07-12

> ⚠️ **Beta test sürümü.** "Odak Kampı Beta" olarak ayrı kurulur. Bu sürümdeki
> native arka plan sayaç, bildirim ve widget davranışı gerçek cihazlarda test
> ediliyor; cihaz/OEM'e göre değişebilir. Geri bildirim bekleniyor.

### Öne çıkanlar

- **Güvenilir arka plan sayacı (V8-A):** Uygulama kapalıyken de çalışan native
  zamanlayıcı ve foreground service; cihaz yeniden başlasa bile aktif sayaç
  geri yüklenir.
- **Canlı bildirim:** Kalıcı bildirimde akan `HH:MM:SS` kronometre ve uygulamayı
  açmadan **Başlat/Durdur**.
- **Widget paritesi:** Ana ekran widget'ında canlı kronometre, olay bazlı
  istatistik/sıralama beslemesi, açık/koyu tema ve Android 12+ dynamic color.
- **Senkronizasyon denetimi (V8-B):** Aynı toplam artık her ekranda tutarlı;
  çevrimdışı açılan oturum tekrar bağlanınca **bir kez** yazılır; gün sınırı
  (Europe/Istanbul) tek kaynaktan.
- **İstatistik sırası:** Sıralama (leaderboard) artık grup günlük trendinin
  **üstünde**, özet kartlarının hemen altında.
- **Gruplar sekmesi:** Kamp ateşi en üstte; davet kodu alttaki açılır "Grup
  bilgileri" paneline taşındı; kamp ateşi yerleşme animasyonu hızlandı ve
  sistemdeki **"animasyonları azalt"** ayarına uyar (batarya dostu).

### Notlar

- Native arka plan sayacı, bildirim aksiyonları ve widget davranışı cihaz pil
  optimizasyonuna ve OEM kısıtlarına bağlıdır; force-stop sonrası garanti değildir.
- Yeni sunucu migration'ı yoktur; v7 ile aynı şema (0020–0023) yeterlidir.

## [v7 / 1.0.6+7] - 2026-07-12

### Öne çıkanlar

- **Bildirim Merkezi:** Dürtme, çalışma hatırlatıcıları, alarm/zamanlayıcı, duyuru,
  güncelleme ve sessiz saatler artık tek ekrandan yönetiliyor.
- **Çalışma hatırlatıcıları:** Seçtiğin saat ve günlerde yerel bildirimle hatırlatma
  kurabilirsin.
- **Sessiz saatler:** Belirlediğin aralıkta dürtme ve hatırlatıcı bildirimleri susturulur.
- **Sosyal Profil 2.0 ve Başarı Yolculuğu:** Kademeli başarılar, XP ve taç vitrini.
- Beş sekmeli yapı netleşti (Ana Sayfa / Saat / Gruplar / İstatistik / Profil);
  Ayarlar'daki tekrar eden "Ana Sayfa" grubu kaldırıldı.

### Düzeltmeler

- Duyurular Bildirim Merkezi'nde okundu takibiyle listelenir.
- Bildirim türleri ve cihaz izin durumu tek yerde açıkça görünür.

### Notlar

- Hatırlatıcı ve alarmlar Android'de yerel bildirimdir; cihaz izni gerekir ve uygulama
  tamamen kapalıyken tam-zamanlı teslim garanti edilmez.
- Bildirim Merkezi'nin sunucu tarafı özellikleri (hatırlatıcı ve duyuru okundu kaydı)
  için `0023_notification_center.sql` ve önceki `0020–0022` migration'ları canlı
  Supabase şemasına uygulanmalıdır.

## [v6 / 1.0.5+6] - 2026-07-11

### Düzeltmeler

- Sayaç bildirimindeki başlıkta artık takılı kalan “0 sn” yerine canlı ilerleyen
  saat (HH:MM:SS) gösterilir.
- Grup adı, hedefi veya davet kodu değiştirildiğinde liste anında tazelenir;
  değişikliği görmek için uygulamayı kapatıp açmak gerekmez.
- Kimse dürtmese bile tekrar tekrar gelen sahte “... seni dürttü” bildirimi
  giderildi; her dürtme yalnızca bir kez bildirilir.
- Bildirim ya da ana ekran widget'ındaki Durdur/Başlat komutu, uygulama kapalıyken
  basıldıysa artık uygulama açılışında da işlenir (önceden yalnız arka plandan öne
  gelişte çalışıyordu).

### Notlar

- Uygulama tamamen kapalıyken Durdur/Başlat'ın ve widget canlı saatinin anında
  çalışması için bir foreground service gerekir; bu ayrı bir iş paketi olarak
  cihaz üzerinde test edilerek eklenecektir.

## [v5 / 1.0.4+5] - 2026-07-11

### Öne çıkanlar

- Android saat, bildirim ve widget deneyimi sadeleştiriliyor.
- Sürüm geçmişi, tek seferlik “Yenilikler” penceresi ve Ayarlar içinden geçmiş
  güncelleme notları eklendi.
- Yeni ikon/branding, tema paleti ve V5 release hazırlıkları ayrı iş paketleriyle
  takip ediliyor.

### Düzeltmeler

- GitHub Release, repo dokümanı ve uygulama içi notlar için tek kaynak prensibi
  kuruldu.

### Notlar

- Push/FCM yoktur. Güncelleme bildirimi uygulama açıldığında yapılan yerel
  GitHub release kontrolüyle best-effort çalışır.

## [v4 / 1.0.3+4] - 2026-07-11

### Öne çıkanlar

- Görünen uygulama adı Odak Kampı olarak netleştirildi.
- Canlı sayaç yüzeyleri, sade bildirim akışı ve grup ekranı hiyerarşisi V4
  hazırlığına alındı.
- Grup sohbeti ve grup ayarlarına erişim daha anlaşılır hale getirildi.

### Düzeltmeler

- Gamification profili yokken başarılar kartı güvenli varsayılan veriyle
  görünür kalır.
- Ana ekrandan yönetilen sayaç ayarlarının ayarlarda tekrarlanması sadeleştirildi.

## [v3 / 1.0.2+3] - 2026-07-10

### Öne çıkanlar

- Kalıcı Android sayaç bildirimi ve bildirim izni altyapısı eklendi.
- Dürtme bildirimleri ve bildirim tercihleri ayarlara bağlandı.
- Grup/presence ve canlı çalışma yüzeyleri daha güvenilir hale getirildi.

### Düzeltmeler

- Uygulama yeniden açıldığında aktif sayaç durumunun wall-clock süreyle toparlanması
  iyileştirildi.
- Demo/offline akışlar için repository davranışları güçlendirildi.

## [v2 / 1.0.1+2] - 2026-06-27

### Öne çıkanlar

- Ana sayfa kart düzeni ve çalışma odası deneyimi geliştirildi.
- Odak/pomodoro sayaç davranışları daha okunur hale getirildi.
- İstatistik ve grup hedefi yüzeyleri sonraki sürümlere zemin olacak şekilde
  toparlandı.

### Düzeltmeler

- Kart taşmaları ve temel responsive düzen sorunları azaltıldı.
- Provider/repository sınırları test edilebilirlik için netleştirildi.

## [v1 / 1.0.0+1] - 2026-06-21

### Öne çıkanlar

- İlk Odak Kampı yayını.
- Odak oturumu başlatma, durdurma ve temel çalışma takibi yayınlandı.
- Profil, grup ve temel istatistik ekranları eklendi.
- Supabase bağlı ve Supabase'siz demo kullanım için temel mimari kuruldu.

## [beta-v1 / 1.0.0-beta+1] - 2026-07-11

### Öne çıkanlar

- Stable ve beta release kanalları ayrıldı.
- Beta APK adı ve GitHub prerelease akışı ayrı takip edilmeye başladı.
