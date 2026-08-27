# Odak Kampı Changelog

Sürüm notlarının kullanıcıya görünen ana kaynağı burasıdır. Uygulama içindeki
`app/assets/release_notes.json`, GitHub Release body ve Ayarlar > Güncelleme
notları ekranı bu metinle aynı kararları yansıtmalıdır.

## [v75 / 1.0.75+75] - 2026-08-27

> **v74'teki bildirim bozulmasi geri alindi. Deneysel dinamik panel artik
> yalniz gizli gelistirici bolumunden acilir; normal kullanici onu hic
> gormez.**

### Öne çıkanlar
- **Sayaç bildirimi yeniden normal.** v74'te bildirimde soldan sağa süzülen
  bir çubuk beliriyor, sayaç `00:00`'a düşüyor ve düğme kayboluyordu. O
  değişiklik geri alındı.
- **Deneysel yol artık varsayılan değil.** Dinamik panel (Android 16 canlı
  güncelleme) denemesi yalnızca Hakkında ekranındaki gizli geliştirici
  bölümünden açılabiliyor. Hiçbir şey seçmeyen kullanıcı çalışan paneli
  görür.

### Düzeltmeler
- Açık uçlu kronometreye eklenen belirsiz ilerleme çubuğu kaldırıldı.
- Terfi ölçümü artık yalnızca terfi gerçekten istendiğinde çalışıyor;
  istenmediği hâlde ölçüm yapıp cihaza yanlış bir karar yazma ihtimali
  kapandı.

### Doğrulama
- Yerel tam kalite kapısı: 20 kapı, 0 kırmızı.
- Veritabanı değişmedi; migration head `0136` olarak kalıyor.

### Bu sürümde ÇÖZÜLMEYENLER
- **Dinamik panel Galaxy S23'te görünmüyor ve sebebi artık ölçüldü:** sistem
  terfiyi *veriyor* (bayrak gerçekten yazılıyor) ama Samsung ortada hiçbir
  şey *çizmiyor* — ne durum çubuğu çipi ne Now Bar satırı. Hiçbir API
  sinyali bunu önceden söylemiyor. Bu yol şimdilik kapalı sayılıyor.
- **Sayaç bildirimi hâlâ kaydırılarak silinebiliyor** (Android 14 platform
  kararı). Silinirse sayaç görünmeden çalışmaya devam ediyor.
- Sıradaki alarm widget'ı yayında değil.

## [v74 / 1.0.74+74] - 2026-08-27

> **Sahibin cihazinda gorulen iki gorsel gurultu kalkti; dinamik panelin
> gorunmemesi icin en olasi eksik parca eklendi.**

### Öne çıkanlar
- **Sayaç bildirimi sadeleşti.** Sayacın yanındaki "FOCUS" yazısı kalktı —
  panel zaten yalnızca çalışırken var, o etiket tekrardı. Etiket artık
  sadece **molada** görünüyor, çünkü asıl ayırt edilmesi gereken durum o.
- **Durdur düğmesindeki kare işaret kalktı.** Bir "durdur" simgesi olması
  gerekiyordu ama öyle okunmuyordu; anlamı "Durdur" yazısı zaten taşıyor.
- **Dinamik panel için eksik parça eklendi.** Sayaç bildirimi artık Android
  16'nın canlı güncelleme yüzeylerinin beklediği ilerleme biçiminde
  gönderiliyor. Önceki sürümde sistem terfiyi veriyor ama ekranda çizecek
  bir şey bulamıyordu.

### Düzeltmeler
- Hedefi olan modlarda (pomodoro / geri sayım) durum çubuğu çipinin yazısı
  hiç gönderilmiyordu.
- Açık uçlu kronometre ilerleme bilgisi taşımıyordu; artık belirsiz ilerleme
  ile gönderiliyor (uydurma bir hedef süre yazılmıyor).

### Doğrulama
- Yerel tam kalite kapısı: 20 kapı, 0 kırmızı.
- Veritabanı değişmedi; migration head `0136` olarak kalıyor.

### Bu sürümde ÇÖZÜLMEYENLER
- **Dinamik panelin görünüp görünmeyeceği hâlâ ölçülmedi.** Bu sürümdeki
  değişiklik bir hipoteze dayanıyor: sistem terfiyi veriyordu ama bildirim,
  terfi yüzeyinin beklediği biçimde değildi. Doğrulanabileceği tek yer
  gerçek bir Android 16 telefon.
- **Sayaç bildirimi hâlâ kaydırılarak silinebiliyor** (Android 14 platform
  kararı). Silinirse sayaç görünmeden çalışmaya devam ediyor.
- Sıradaki alarm widget'ı yayında değil.

## [v73 / 1.0.73+73] - 2026-08-27

> **Dinamik panelin alti turdur cikmamasinin sebebi bulundu ve sebep
> platformda degil, bizim kodumuzdaydi: uygulama terfiyi hicbir cihazda
> hic istemiyordu.**

### Öne çıkanlar
- **Sayaç bildirimi artık dinamik panel isteyebiliyor.** Altı tur boyunca
  istemiyordu: bir mantık kısa devresi yüzünden "sistem bu bildirimi öne
  çıkarır mı?" sorusu hiç sorulmuyordu. Destekleyen bir telefonda bile panel
  çıkamazdı.
- **Cihazın verdiği kararı artık okuyabiliyorsunuz.** Hakkında ekranında,
  geliştirici bölümünde tek satır: *verdi* / *vermedi* / *henüz ölçülmedi*.
  Ölçüm her Başlat'ta yapılıyordu ama sonucunu kimse göremiyordu — dönüp
  duran döngünün asıl sebebi buydu.
- **Bildirim görünümü artık üç seçenekli:** Otomatik / Zengin panel /
  Live Update. Varsayılan **Otomatik**: telefonunuz ne yapabiliyorsa o.

### Düzeltmeler
- Geliştirici anahtarını bir kez açıp kapatmak dinamik paneli **kalıcı**
  kapatıyordu ve geri dönüşü yoktu. Üçüncü bir durum ("otomatik") yoktu;
  artık var ve varsayılan o.
- Ölçüm, bildirim sisteme ulaşmadan yapılıyordu ve bu yüzden hiçbir zaman
  sonuçlanmıyordu. Artık bildirim gönderildikten sonra ölçülüyor.
- Ölçüm hiç sonuçlanmazsa sayaç sade bildirimde takılı kalabilirdi; üç
  denemeden sonra bilinen çalışan panele dönülüyor.
- Liderlik kartının bazı testleri cihazın saatine bağlıydı ve gece belirli
  saatlerde yanlış gün için çiziyordu.

### Doğrulama
- Yerel tam kalite kapısı: 20 kapı, 0 kırmızı.
- CI yeşil (Android emülatör smoke dahil).
- Veritabanı değişmedi; migration head `0136` olarak kalıyor.

### Bu sürümde ÇÖZÜLMEYENLER
- **Dinamik panelin Galaxy S23'te gerçekten çıkıp çıkmadığı ÖLÇÜLMEDİ.**
  Değişen şey artık soruluyor olması ve cevabı ekrandan okuyabilmeniz.
- **Sayaç bildirimi hâlâ kaydırılarak silinebiliyor** (Android 14 platform
  kararı). Silinirse sayaç görünmeden çalışmaya devam ediyor.
- Sıradaki alarm widget'ı yayında değil.

## [v72 / 1.0.72+72] - 2026-08-27

> **v71 saha geri bildirimi tek turda kapatildi: bildirim paneli calisir
> haline dondu, dokuz widget ilk kez EKRANDA olculdu, liderlik gecmisi
> secili donemi cizmeye basladi.**

### Öne çıkanlar
- Sayaç bildirimi yeniden çalışıyor: sayaç akıyor ve Başlat/Durdur düğmesi
  yerinde. v71'de bildirimde "00:00" görünüyor, düğme hiç çizilmiyordu.
- Dokuz ana ekran widget'ı gerçek bir cihaz ekranında ölçüldü. Geri sayım
  widget'ı 1x1 boyutunda **tamamen boş** çiziliyordu — üç sınavı olan bir
  kullanıcıda hem kahraman sayı hem satırlar birden gizleniyordu.
- Sıralamada kırpılan şey artık **süre değil isim**. Widget'ın tek işi kimin
  ne kadar çalıştığını göstermek; v71'de kırpılan sayının kendisiydi.
- Liderlik geçmişi grafiği seçili dönemin dışına taşmıyor. Çarşamba günü
  "Hafta" seçiliyken grafik geçen haftanın günlerini de yarışa katıyor, bu
  yüzden üstteki sıralama listesiyle **farklı bir lider** gösterebiliyordu.

### Düzeltmeler
- Boştaki bildirimin başlığı sabit "00:00" metniydi; gerçek bir durum
  cümlesine bağlandı.
- Bildirim eylemleri ikonsuz ekleniyordu ve bazı yüzeylerde hiç çizilmiyordu.
- Açık/koyu tema: bildirim panelinin rengi ölçülerek düzeltildi. Sabit beyaz
  yazmak açık gölgede metni, tema niteliği yazmak koyu gölgede düğmeyi
  kaybettiriyordu.
- 1x1 kartın köşe yarıçapı kutunun tamamını yiyordu.
- Saat widget'ı 2x2'de yerin beşte birini boş bırakıyordu.
- "Yıl" veya "Tümü" seçiliyken liderlik geçmişi, dönem doluyken bile
  "kayıt yok" diyebiliyordu.

### Doğrulama
- Yerel tam kalite kapısı: 20 kapı, 0 kırmızı.
- CI yeşil.
- Widget'lar gerçek `AppWidgetHost` ile 1x1 / 2x1 / 2x2 / 3x2 boyutlarında
  çizdirilip ölçüldü — kırpılan karakter sayısı tek tek sayıldı.
- Veritabanı değişmedi; migration head `0136` olarak kalıyor.

### Bu sürümde ÇÖZÜLMEYENLER
- **Dinamik panel hâlâ çalışmıyor** ve sebebi ölçüldü: uygulamanın isteği
  eksiksiz, ancak test edilen Android 16 sistem görüntüsünde terfiyi çizen
  arayüz bileşeni bulunmuyor. Uygulama artık bunu fark edip çalışan panele
  düşüyor — v71'de fark etmediği için arada kalıyordu.
- **Sayaç bildirimi hâlâ kaydırılarak silinebiliyor** (Android 14 platform
  kararı). Silinirse sayaç görünmeden çalışmaya devam ediyor.
- Sıradaki alarm widget'ı yayında değil.

## [v71 / 1.0.71+71] - 2026-08-22

> **İstatistikler artık her dönemde farklı bir ekran; dokuz ana ekran
> widget'ı baştan tasarlandı; sayaç bildirimi dinamik panele hazırlandı.**

### Öne çıkanlar
- İstatistiklerde Gün / Hafta / Ay / Yıl / Tümü / Özel seçenekleri artık
  gerçekten farklı içerik getiriyor. Daha önce altısı da aynı kartları
  seriyor, yalnız sayılar değişiyordu.
- Zamanda gezinme dönem şeridinden çıkıp kendi çubuğuna taşındı: sol ok,
  başlık, sağ ok ve takvim düğmesi. Takvim düğmesi her dönemde farklı
  açılıyor — yılda takvim değil yalnızca yıl listesi çıkıyor.
- Gün görünümü yeni: o günün oturum çizelgesi, saat profili, oturum sayısı,
  en uzun oturum ve hedef durumu. Grup sekmesinde o günün üye sıralaması
  en üstte.
- Grup değiştirme üstteki "Grup" sekmesine taşındı; tarih aralığının
  altındaki avatar + isim + Değiştir satırı kaldırıldı.
- Dokuz ana ekran widget'ı baştan tasarlandı. İlk kez gerçek görsel
  taşıyorlar — önceki hâlde dokuz düzende tek bir ikon bile yoktu.
  Hepsi 1×1'e kadar iniyor; küçük kutuda yalnız o widget'ın çekirdeği kalıyor.
- Widget seçicisinde beş widget aynı adla görünüyordu, artık her birinin
  kendi adı var.

### Düzeltmeler
- Geçmiş bir döneme gidildiğinde dört kart seçili dönemi yok sayıyordu:
  günlük dağılım, oturum dağılımı, liderlik geçmişi ve grup eğilimi başlıkta
  geçen haftayı yazıp grafikte bu haftayı çiziyordu. Dördü de düzeltildi.
- "Geçen ay" seçildiğinde oturum dağılımı grafiği tamamen boş çıkıyordu.
- Grup hedef göstergesi hangi güne gidilirse gidilsin bugünü anlatıyordu.
- Sayaç widget'ındaki rakamlar %45 yatay eziliyordu; sıkıştırma yerine
  küçük kutuda bilgi düşürülüyor, rakam artık büyük ve okunur.
- İnternet bağlıyken açılışta çıkan yanlış "İnternet yok" uyarısı kaldırıldı.
- Tek bir geçici ağ hatası oturum akışını kalıcı olarak öldürüyordu; bu
  olduğunda uygulama o oturum boyunca giriş durumunu bir daha güncellemiyordu.

### Doğrulama
- Yerel tam kalite kapısı: 20 kapı, 0 kırmızı.
- CI: 7 işin 7'si yeşil — Linux tam test paketi, Windows entegrasyon,
  Windows golden testleri, iki Android emülatör smoke turu, Edge Function
  tip denetimi ve backend sözleşme kapısı.
- Migration 0136 staging ve production'a uygulandı, post-check her ikisinde
  de `0136 | 0136 | 0136` verdi.

### Bu sürümde ÇÖZÜLMEYENLER
- **Sayaç bildirimi hâlâ kaydırılarak silinebiliyor.** Android 14'ten beri
  bu bir platform kararı ve engellenemiyor. Şu an bildirim silinirse sayaç
  görünmeden çalışmaya devam ediyor; bunun düzgün karşılığı sonraki sürümde.
- **Dinamik panel cihazda doğrulanmadı.** Altyapı bu sürümde hazırlandı
  (özel görünüm terfi yolundan çıkarıldı) ama gerçek telefonda görülmedi.
- Sıradaki alarm widget'ı boyutlandırmayı öğrendi ama hâlâ yayında değil.
- Sınav geri sayımı widget'ı 30 dakikaya kadar bayat kalabiliyor.

## [v70 / 1.0.70+70] - 2026-08-13

> **Saha geri bildirimindeki sayaç, profil, kamp ateşi, başarım ve yönetim
> paneli sorunları tek kalite turunda ele alındı.**

### Öne çıkanlar
- Ana ekran ve bildirim üzerinden başlatılan sayaç artık son seçili dersi
  koruyor. Genel de ders listesinde normal bir satır ve istenirse silinebiliyor.
- Başkasının profilinde güncel günlük seri görünüyor; ünvan, yer varsa adın
  yanında, yoksa hemen altında duruyor.
- Kamp ateşindeki adlar hayvanlarıyla merkezlendi. Çevrimdışı durumu ve aktif
  çalışma kronometresi kişi kartındaki boş alana taşındı.
- Kadim Üye ve Metronom altı kademeye çıktı. Kusursuz Ay ödülleri iki katına
  yükseldi; Alevli Seri artık güncel seriyi canlı gösterip seri bozulunca sıfırlanıyor.
- Yönetim paneli masaüstünde yatay rail ve master-detail düzenine geçti;
  mobil gezinme, filtreler, arşiv ve yaptırım akışları toparlandı.
- İlk açılışta daha önce dil seçilmemişse Sistem, Türkçe veya English
  doğrudan tanıtım ekranından seçilebiliyor.

### Düzeltmeler
- Ana ekran widget'ları daha kompakt, okunur ve yeniden boyutlanabilir hale
  getirildi. 1×1 sayaç rakamı büyüdü, standart sayaç 2×1'e sığdı ve grup
  hedefindeki yinelenen yüzde kaldırıldı.
- Yönetim panelinin geri tuşu ayarlara sıçramak yerine panel içindeki gerçek
  geçmişi izliyor; uzun alt sekme etiketi ortalanıyor.

### Doğrulama
- Temiz yerel PostgreSQL kurulumu 66 test dosyasında 950 pgTAP iddiasıyla geçti.
- Stable yayın, uzak ortam terfisi ve tag sahip komutuna kadar kilitli tutuluyor.

## [v69 / 1.0.69+69] - 2026-08-12

> **Sayaç ve ana ekran widget'ları artık gerçekten boyuta göre tasarlanıyor.**
> Bu tur, beta geri bildirimindeki “kocaman kutuda düz metin”, tek sınav,
> küçük sayaç rakamı ve uygulama içindeki sözde “minimal” görünüm sorunlarını
> birlikte kapatıyor.

### Öne çıkanlar
- Uygulama içindeki yeni **Kompakt sayaç** 116 px; ızgara hücresi de 118 px'e
  iner. Eski “Minimal” artık yaptığı işi söyleyen **İnce halka** adında.
- Android ana ekranında yeni minimal sayaç var. En küçük 1×1 boyutta bütün
  yüzey başlat/durdur; ders hafızası korunuyor, uygun boyutta ders seçilebiliyor.
- Sınav widget'ı tek sınav yerine üç sınav gösteriyor. Görev, sıralama,
  istatistik ve grup widget'ları renkli bar/yay diliyle yeniden tasarlandı;
  boş içerikte gereksiz dev kutu kalmıyor.
- **Kadim Üye** ve **Metronom** başarımları eklendi. Metronom günlük seriden
  farklı olarak haftada beş hedef gününü sayıyor; birkaç kaçırılan gün bütün
  ilerlemeyi sıfırlamıyor.

### Düzeltmeler
- Manuel süre/hedef seçicide 9→10 veya 59'a geçince rakam artık küçülmüyor;
  değerler sabit 22sp, düğmeler en az 48×48 dp.
- Minimal widget'ın testi yalnız `00:00` ölçüyordu; gerçek `00:00:00` çalışma
  biçimi de kapsandı. Punto içerik uzunluğuna göre oynayan auto-fit değil,
  kutu boyutuna bağlı sabit basamaklarla belirleniyor.
- Grup ayarlarında üyeler ilk ekrana taşındı; tanıtım ekranı hedef/ad/hayvan/
  sayaç yenilemelerinde yeniden parlamıyor; kamp ateşi ve profil yolları düzeldi.
- Profil başlığı ve taç alanı sadeleşti. Başka birinin profilinde büyük XP barı
  ve altı renkli şerit kaldırıldı; taç ve toplam XP tek erişilebilir satırda.
- Widget metinleri cihaz diline takılı kalmak yerine uygulamada seçilen dili
  izliyor. Gizli başarımlar artık yanlışlıkla “Bronz” yazmıyor.
- `1337 Elite` aktif katalog, çeviri, fixture ve ürün belgelerinden kaldırıldı.

### Doğrulama
- Yerel tam kapı: 25 kontrol, 21 geçti, 0 kırmızı, 4 ortam-bağımlı atlama.
- GitHub CI tüm işleriyle yeşil; veritabanı zinciri 65 dosya / 922 pgTAP
  assertion ile gerçek PostgreSQL'de geçti.
- `0134` staging ve production'a sırayla uygulandı; iki post-check de
  yerel/uzak/uygulanmış head'i `0134` gösterdi.

## [v68 / 1.0.68+68] - 2026-08-11

> **Ana ekran widget'ları turu.** İki kaynak: beta testçisinin *"Sınav geri
> sayımında telefon ve tablette ayrı ayarlanması gerekiyor / Senkron değil"* +
> *"Bunun widget hâli de gelsin"* geri bildirimi ve sahibin *"task widget'ı ve
> sınava geri sayım widget'ı da olsun… üzerine tıklayınca uygulamada o bölüm
> açılsa güzel olur… task widget'ında yaptıklarını oradan işaretleseler"*
> emri.

### Öne çıkanlar
- **Görev widget'ı**: kutucuğa dokununca görev uygulama kapalıyken bile
  işaretlenir. Dört parça: ayna, iyimser çizim, kalıcı bekleyen kuyruk ve
  mutlak-durum koruması (kuyruk *toggle* değil `done:true/false` taşır, iki kez
  işlense de işaret geri dönmez).
- **Sınav geri sayımı cihazlar arası senkron**. "Senkron değil" bir tercih
  kusuru değildi: kod ölçüldü, ortada bir sunucu tablosu **hiç yoktu**.
- **Yayında yedi widget**: sayaç, geri sayım, görevler, saat, günlük hedef,
  grup hedefi, grup sıralaması. Alarm bilerek dışarıda (30 dk bayat kalabilir).
- **Dokununca ilgili bölüm açılır** — sıcak ve soğuk başlatma ayrı ayrı
  ölçüldü.

### 🔴 "Yeşil ama ölçmüyor" — bu turda sekiz kez
1. `resizeMode` altı sağlayıcıda **ölü bayraktı**: `onAppWidgetOptionsChanged`
   hiçbirinde override edilmemişti, ekranda hiçbir şey değişmiyordu.
2. **Köprünün çağrı yeri yoktu** (WP-704): 20/20 yeşil test ölü kodu
   koruyordu, çünkü hepsi köprüyü kendisi başlatıyordu. Sabotaj: 20 yeşil /
   1 kırmızı.
3. **Katalog kapısı eksik kümeyi ölçüyordu**: "allowlist bayrağını okuyor"
   yeşildi çünkü *bazı* kartlar okuyordu; yayına alınan iki widget kullanıcının
   kataloğunda hiç görünmüyordu.
4. **`ROUTE_TASKS` dikişte kaldı** (WP-706): iki ajan da dosyayı diğerinin
   sahip yolu sayıp dokunmadı, sabit tanımlıydı ama hiç kullanılmıyordu.
5. **Genel kapı, yayın listesi büyüyünce ölçmeyi bıraktı** (WP-708): dört
   widget yayına girince israf geri açıldı (sayaç turu 0 → 4). Kapı gevşetilmedi,
   koşul anahtar başına bağlandı.
6. **`saveSnapshot` ilk satırda dönüyordu**: manifest açılmasaydı dört widget
   sonsuza kadar native yedek metin gösterirdi.
7. **`stats_title` / `stats_today` / `stats_week`** tanımlı ama hiçbir
   sağlayıcı okumuyor — artık hiç yazılmıyor.
8. **`number_stepper` taşması 800 dp'de ölçülüyordu**; mevcut test dosyası
   360 dp'deki 8 px taşmayı yorumunda itiraf edip hiçbir iddiaya bağlamamıştı.

### Düzeltmeler
- Kalıcı red artık 38 saniye dönen çark değil (13 kullanıcı sağlayıcısında
  depoya 11 kez gidiyordu, 1'e indi). Geçici ağ hatalarında yeniden deneme
  açık kaldı ve ayrı iddiayla ölçülüyor.
- Grup hedefi/sıralama gerçek değeri gösteriyor; hedef serisi satırı gerçek
  sayıya bağlandı (ölü `AndroidWidgetSnapshot.stats` kurucusu canlandırıldı).
- `number_stepper` 360 dp taşması, `dday_card` yalan yorumu, `_AppealCard`
  kart dili.

### Notlar
- 🔴 `0133` için pgTAP hiç koşmadı (Docker motoru bu hostta kalkmıyor);
  25 iddialık SQL testi yazıldı ama çalıştırılmadı.
- Widget ve izinler ekranı uzadı: 7 kart, izin ayarları altta.

## [v67 / 1.0.67+67] - 2026-08-11

> **Yönetim paneli sıfırdan yazıldı.** Sahibin dört şikâyetinin dördü de kodda
> ölçüldü: şikâyete eklenen ekran görüntüsü hiç gösterilmiyordu (sunucu
> gönderiyor, istemci atıyordu), karar 8 adım sürüyordu ve kanıtla karar
> hiçbir an aynı ekranda değildi, kısıtlama üç ayrı yerde iki farklı listeyle
> yapılıyordu, düğmelerin ne yaptığı yazmıyordu ("Arşivle" düğmesinin üstünde
> "Tamamlandı" yazıyordu).

### Öne çıkanlar
- Kanıt + karar tek ekranda; karar tek dokunuş, 10 saniye geri alınabilir.
- Kalıcı yasak ve hesap silme e-posta yazdıran teyit ister (sahip kararı).
- Yaptırım tek kanonik basamak listesinden; vakadan kişinin dosyasına tek
  dokunuşla geçiliyor.
- 7 sekme 3 yüzeye indi; 1280 px'te iki, 1600 px'te üç bölme, telefonda tek
  ekran. Hiçbir işlev kaldırılmadı.

### Düzeltmeler
- Yönetici, üyesi olmadığı grubun üye listesini görebiliyor (üye atabiliyordu
  ama kimleri atacağını göremiyordu).
- "Üye at" artık elle kimlik istemiyor.
- Denetim kaydı işlemi kimin yaptığını yazıyor.
- Boş arama sonucunda filtreyi temizleyen kontrol var.
- Özet ızgarası genişliğe göre 2/4/6 sütun.
- Gruplar sekmesindeki tekrar eden satır kalktı; sıralama kartı 47 px kısaldı,
  seri işareti büyüyüp sağ tarafa alındı.

### Notlar
- Üye listesi üretimde ancak yönetim fonksiyonları yeniden yayınlandıktan
  sonra çalışır.

## [v66 / 1.0.66+66] - 2026-08-11

> **Windows sürümü artık masaüstü için tasarlandı.** Uygulama pencerenin
> gerçek genişliğini görmüyordu: 1100–1650 px arasında her zaman 1100 px
> sanıyor, üstünde ise arayüzü yeniden dizmek yerine 1,5 kat büyütüyordu.
> Sahibin "mobilin penceresi gibi olmuş" tarifi bunun birebir karşılığıydı.
> Ölçek kaldırıldı ve on üç ekran ailesi masaüstü düzenine bağlandı.

### Öne çıkanlar
- Geniş ekranda içerik yan yana diziliyor; kırılım noktaları artık gerçekten
  tetikleniyor (640 / 1008 / 1200 / 1600).
- Etiket–değer satırları okunabilir genişlikte. En kötü ölçüm 2488 px'ti;
  sert tavan artık 600 px (gövde yazısı 15 px, WCAG 1.4.8'in 80 karakteri).
- Kartlar içeriğine göre boyutlanıyor; tek sayı taşıyan 2360 px'lik kartlar
  kalktı.

### Düzeltmeler
- Ödül kutlaması ve ödül şeridi üst menüyü örtmüyor.
- Ayarlar geniş pencerede başlık listesi + içerik olarak açılıyor.
- Giriş/kayıt ekranı geniş pencerede iki panele ayrılıyor.
- Windows'ta teslim edilemeyen bildirim ayarları gerekçeli olarak kapalı.
- Widget ve izinler sekmesi Windows'ta kurulamayacak bir widget'ı vaat
  etmiyor; çalışmayan dört düğme kaldırıldı.
- Telefonda istatistik kartlarındaki taşma düzeldi.

### Notlar
- Telefon görünümü değişmedi; bu tur tamamen masaüstü düzeniyle ilgili.

## [v65 / 1.0.65+65] - 2026-08-10

> **Sayaç artık senin seçtiğin modda başlıyor.** Ana ekran widget'ından ya da
> bildirimden Başlat'a bastığında pomodoro veya geri sayım seçimin korunuyor —
> eskiden kronometre başlatıyor, mola hiç gelmiyor ve uygulamayı açtığında
> seçimin silinmiş oluyordu. Aynı turda ana ekran kartlarının parmağı takması
> ve küçük kartlarda içeriğin kesilmesi kapandı.

### Öne çıkanlar
- Widget/bildirim Başlat'ı kullanıcının seçtiği modu başlatıyor; seçim artık
  sessizce silinmiyor.
- Ana ekran kartları sığan içerikte kaydırma jestini yutmuyor (haftalık ritim,
  sayaç, sıralama); küçük hücrelerde kırpma kalmadı.
- Seri işareti her temada okunuyor; seri duraklamadaysa ayrı bir duraklatma
  işareti çiziliyor.

### Düzeltmeler
- Geri sayım kartındaki kalem simgesi düzenleme penceresini açıyor.
- Kart artık yalnız sınav demiyor; adı "Geri sayım".
- Var olan görevi tekrarlıya çevirmek onu Bugün listesinden düşürmüyor.
- Molada "Çalışmaya dön" sonrası widget sayacı durmuş göstermiyor.
- Çalışma kaydı silinince günlük seri de geri gidiyor.
- Başkasının profilinde kazanılmış kademeler görünüyor; kendi profilinde seri,
  aktif gün ve rekorlar var. Gizli başarımlar gizli kalır.
- Kazanılmış rozetin altında çıplak sıfır yok.
- Sıkça sorulan sorularda dokuz yanlış cevap düzeltildi, altı yeni madde eklendi.

### Notlar
- Windows sürümü yeniden çıkıyor; v63 ve v64'te paket üretilememişti ve sebebi
  uygulamada değil yayın kontrolündeydi.

## [v64 / 1.0.64+64] - 2026-08-10

> **Silinen çalışma artık gerçekten siliniyor.** Bir çalışma kaydını
> sildiğinde ondan gelen XP, başarım ve taç da geri gidiyor — eskiden kayıt
> gidiyor, kazanım kalıyordu. Aynı turda "en uzun seri" rekorunun ne anlama
> geldiği düzeltildi.

### Yenilikler
- **Çalışma kaydını silmek kazanımı da geri alır.** XP, başarım kademeleri ve
  taç, kalan gerçek çalışmana göre yeniden hesaplanır. Bu artık kendiliğinden
  olur; bir şey yapman gerekmez.
- **"En uzun seri" artık günlük hedefine bağlı.** Eskiden o gün bir saniye
  kayıt olması seriyi sürdürmeye yetiyordu — yani rekor gerçek bir şey
  ölçmüyordu. Artık hedefini tutturduğun ardışık günleri sayıyor. "Aktif gün"
  ayrı bir kutucuk olarak duruyor.

### Düzeltmeler
- **Başarımlar ekranı gezerken kendi kendine yenilenmiyor.** Liste birkaç
  saniyede bir başa dönüyordu; üstelik her yenilemede arka planda gereksiz bir
  kayıt işlemi yapılıyordu.
- **Rekorlardaki "en iyi" değeri gerçek çalışmanı gösteriyor.** Sildiğin bir
  oturumun rekoru ekranda kalmaya devam ediyordu.
- **"Aktif gün" sayacı** artık sıfır saniyelik günleri saymıyor; yan yana
  duran iki kutucuk aynı sayıyı göstermiyor.
- **Seri hesabı yaz saati uygulanan cihazlarda kayıyordu** — bazen çalışılmayan
  bir gün seriyi birleştiriyor, bazen gerçek seri sessizce kırılıyordu.
- **Windows sürümü yeniden üretiliyor.** v63'te Windows paketi çıkmamıştı ve
  Windows'ta "güncellemeleri kontrol et" hata veriyordu.

## [v63 / 1.0.63+63] - 2026-08-09

> **Sessizce kaybolan işler artık kaybolmuyor.** Bu turda bağımsız bir denetim
> yapıldı ve ortaya çıkan yirmiden fazla kusurun ortak deseni şuydu: bir şey
> başarısız oluyor ama kimse söylemiyor. En ağırı hesap silmeydi — sayacı bir
> kez çalıştırmış neredeyse herkes hesabını silemiyordu.

### Yenilikler
- **Sınav geri sayımı büyüdü.** Artık en fazla üç tarih ekleyebilirsin, her
  birine istersen ad verirsin (YKS, AYT, deneme…), sırayı sen belirlersin.
  Birini öne çıkarırsan o büyük görünür, diğerleri altında durur. Düzenleme
  kartın kendisinde: karta dokun, pencere açılsın.
- **İnternet yokken uygulama hemen açılıyor.** Bağlantısızken açılışta
  yaklaşık yirmi saniye dönen çember bekliyordu.
- **Sayacı rutinin mi başlattı, sen mi?** Günlük artık bunu söylüyor.

### Düzeltmeler
- **Hesap silme gerçekten çalışıyor.** Sayacı bir kez çalıştırmış, bildirim
  almış ya da bir grupta aktif olmuş hesaplarda silme isteği takılı kalıyordu.
- **Ayarların kaydedilemezse artık söyleniyor.** Günlük hedef, ad, avatar,
  kamp hayvanı ve ünvan, bağlantı koptuğunda hiçbir uyarı vermeden eski
  haline dönüyordu. Aynısı sohbet mesajı, dürtme ve sessize alma için de
  geçerliydi.
- **Uygulamanın ilk saniyelerinde yapılan ayar değişiklikleri** ekranda
  "kaydedildi" görünüp hiçbir yere yazılmıyordu.
- **Durduğun oturumun kaydedilmeden kaybolabildiği durum kapatıldı.**
- **Seri alevi** bazı durumlarda bugünün durumunu yanlış gösteriyordu; ayrıca
  gece yarısı gün değişince kendini yenilemiyordu.
- **"Geçen hafta" özeti** Türkiye dışındaki saat dilimlerinde sekiz gün
  sayıyordu.
- **Windows'ta hatırlatma alarmları hiç kurulmuyordu.**
- **Windows'ta şifre sıfırlama** "gönderildi" diyordu ama göndermiyordu.
- **Bildirimdeki "Çalışmaya dön" düğmesi** pomodoro turunu ilerletmiyordu.
- **Sayaç bildirimi** mola/çalışma geçişinde eski süreyi göstermeye devam
  edebiliyordu.
- **Bildirim izni kapalıyken** sayaç arka planda görünmez çalışıyordu; artık
  durumu söylüyor.
- **İstatistik ekranında hiç grubu olmayan kullanıcı** boş bir ekranda
  kalıyordu; artık gruba katılma yolu var.
- **Renk okunabilirliği:** bazı temalarda okunması zor kalan yazı ve rozetler
  düzeltildi.
- **Kazara yeniden başlatma** — durdur ve başlat aynı yerdeki aynı düğme
  olduğu için sayaç istemeden yeniden başlatılabiliyordu.

### Altyapı
- **Aylık çalışma raporu e-postası anahtarı** gönderim hiç başlamadığı halde
  açık geliyordu. Artık kapalı geliyor ve ekran gönderimin başlamadığını
  söylüyor.
- **Windows sürümü Microsoft Store üzerinden dağıtılabilir hale getirildi.**
- **Ürün politikaları yazıya döküldü:** kalıcı ücretsiz ve reklamsız · zorlama
  yok (uygulama engelleme, mola cezası, kolektif ceza yok) · bir düzen
  değişirse eskisi seçenek olarak kalır.

## [v62 / 1.0.62+62] - 2026-08-08

> **Sayacı durdurmak artık anlık.** Sahip v60 kabulünde *"durduruluyor yazıyor
> ama gene 2-3 sn bekleniyor"* demişti; kök neden ölçüldü ve kaldırıldı. Aynı
> turda Play Console'un ilk gönderimde bloke ettiği iki izin de düştü.

### Yenilikler
- **Durdur anında duruyor.** Kayıt önce telefona yazılıyor, sunucuya gönderme
  arkada sürüyor. Ölçüm: sunucu hiç cevap vermezken `stop()` **16-18 ms**
  içinde dönüyor (önce: 5 saniyede bile dönmüyordu).
- **Çevrimdışı biriken çalışma süreleri artık takılmıyor.** Kuyruktaki tek bir
  kalıcı hata, arkasındaki bütün oturumları sonsuza dek bloke ediyordu.
- **Bağlantı kopup geri gelince listeler kendini tazeliyor.** İstatistik ve
  liderlik tablosu, yeni bir değişiklik gelene kadar donuk kalıyordu.

### Düzeltmeler
- **Telefonun saati geri alınınca biten oturum sessizce siliniyordu.** 40
  dakikalık çalışma uyarı bile vermeden yok oluyordu; artık kaydediliyor.
- **Doğru şifreye "mevcut şifre hatalı" deniyordu.** Ağ hatası şifre hatası
  sayılıyordu; artık ağ hatası ağ hatası diyor.
- **Uzun hata metinleri yarıda kesiliyordu** ("The new password cannot be th…").
  Düzeltme tek tek alanlara değil temaya yazıldı.
- **Şifre sıfırlamada çıkmaz sokak kapandı.** Hiçbir zaman gelmeyen bir kodu
  isteyen düğme artık çizilmiyor (SMTP gelince bayrakla açılır).
- **Hesap silme isteğinin iptal düğmesi kayboluyordu** durum sorgusu
  başarısız olunca; 14 günlük pencerede iptal edilemez hale geliyordu.
- **Grup kurma, katılma ve davet kodu yenilemede** bekleme göstergesi eklendi;
  iki kez basmak iki kayıt üretmiyor.
- **Sohbette engelleme, ağ hatası anında sessizce devre dışı kalıyordu.**
- **Büyük sistem yazısı seçen kullanıcı** grupsuz ekranda "Kodla katıl" ve
  "Grupları keşfet" düğmelerine ulaşamıyordu; ekran kaydırılmıyordu.
- **Koyu temalarda gecikmiş görev rozetleri okunamıyordu** (kontrast 2.1-2.9).
- **"Bugün özeti" başlığı** dar telefonda varsayılan yazı ölçüsünde bile
  taşıyordu.

### Altyapı
- **Play sürümü artık fotoğraf, video, müzik ve tam alarm izni istemiyor.**
  İlk gönderimde Console bu ikisini bloke etti; ikisi de düşürüldü. Alarm
  çalışmaya devam ediyor, Android 14+ kullanıcısı bir kez izin ekranı görüyor.
- **Cihaz yedeği kapatıldı** (`allowBackup=false`): oturum anahtarı artık
  Google Drive yedeğine ve cihaz-cihaz transferine girmiyor.
- **Hiç kullanılmayan bir eklenti** Play paketine ikinci bir foreground
  service ve dışa açık bir açılış alıcısı sokuyordu; kaldırıldı.
- **Hesap silme artık geri bildirim ve şikayet eklerini de siliyor**; silinen
  grupların fotoğrafı sunucuda sahipsiz kalıyordu.
- Kalıcı kapılar: Play izin sözleşmesi (kaynak + birleştirilmiş çıktı),
  tek foreground service sözleşmesi, `allowBackup` sözleşmesi.

## [v61 / 1.0.61+61] - 2026-08-08

> **Dil düzeltmeleri ve mağaza hazırlığı.** Sahip sahada "arayüz İngilizceyken
> SSS Türkçe geliyor" dedi; kök neden tarandı ve aynı sınıftan üç hata birden
> kapandı. Ayrıca Play Store yolu için gereken parçalar bu sürümde.

### Yenilikler
- **Uygulamanın adı telefonun diline uyuyor.** İngilizce cihazda *Focus Camp*,
  Türkçe cihazda *Odak Kampı*. Daha önce herkeste sabit Türkçe adı yazıyordu.
- **SSS'de dil başına 33 soru var** (önceden 13). Başlangıç, sayaç modları,
  günlük hedef, kamp ateşi, ad sınırı, dürtme susturma, veri indirme, hesap
  silme ve daha fazlası.
- **Gizlilik politikası ve hesap silme sayfaları yayında.** Uygulama içindeki
  Yasal Merkez artık gerçek bir adres gösteriyor.

### Düzeltmeler
- **Arayüz İngilizceyken SSS içeriği Türkçe geliyordu.** Dil tercihi üç
  değerli (sistem / İngilizce / Türkçe) ama kod iki değere daraltıyor ve
  "sistem"i sessizce Türkçe sayıyordu.
- **Bildirimler cihazın dilini kullanıyordu.** Uygulamada İngilizce seçen
  ama telefonu Türkçe olan kullanıcı bildirimleri Türkçe alıyordu.
- **Elle süre eklerken açılan takvim herkeste Türkçeydi.**
- **Hesap silme production'da hiç işlenmiyordu.** İstek kaydediliyor, 14 gün
  geçiyor ve hiçbir şey silinmiyordu; silici yalnız staging'e bağlanmıştı.

### Altyapı
- Kaynak kodu tarayan kalıcı bir kapı eklendi: dil tercihini iki değere
  daraltmak ve ekrana sabit dil vermek artık testte kırmızı düşürür.
- Play için AAB (app bundle) üretimi ve onu zorlayan preflight kapısı.
- Yasal metinler `docs/legal/*.md`'den statik siteye üretiliyor; uygulamanın
  koddan istediği adreslerin gerçekten yayınlandığı ölçülüyor.

## [v60 / 1.0.60+60] - 2026-08-08

> **Saha geri bildirimi sürümü.** v59 sonrası sahibin bildirdiği on madde ve
> denetimde çıkan altı ek bulgu kapandı. Ağırlık gruplar sekmesi, sohbet ve
> sayaç durdurma davranışında.

### Yenilikler
- **Sohbet tam ekran açılıyor.** Mesajlar artık kart içinde sabit yüksekliğe
  sıkışmıyor; klavye açıkken yazma alanı üstte kalıyor.
- **Grup değiştir düğmesi grup adının yanına indi.** Gruplar sekmesinin
  tepesindeki ayrı şerit kalktı, kamp ateşi yukarı geldi.
- **Kamp ateşinde arkadaşını dürtebilirsin.** Hayvanına dokununca açılan
  sayfada Dürt düğmesi var; karşı taraf çalışıyorsa odağı korunuyor.
- **Taç kademeleri Başarımlar ekranından da açılıyor.** Rütbe adı + toplam
  puan satırına ya da renkli kademe şeridine dokunmak yeterli.
- **SSS artık Ayarlar'ın en altında**, kendi "Yardım" bölümünde. Önce Hakkında
  ekranına girmek gerekmiyor.
- Ada karakter sınırı geldi: kişi adı 24, grup adı 30.

### Düzeltmeler
- **Sayacı durdurmak bazen üç saniye bekliyordu.** Durdurma artık arka plandaki
  raporlamayı beklemiyor; düğme de gri kalmak yerine dönen halka ve
  "Durduruluyor…" gösteriyor.
- **Kartın üstünden kaydırınca sayfa kaymıyordu.** İçerik karta sığdığında kart
  artık kaydırma hareketini yutmuyor; taştığında kart içinde kayıyor ve
  hiçbir satır kaybolmuyor.
- Bugün özeti kartı bazı yerleşimlerde hiç çizilmiyordu.
- Kamp ateşinde hiç çalışmayan bir dokunma davranışı kaldırıldı.
- Grup ayarlarındaki ikinci sohbet kartı kaldırıldı.

### Notlar
- Bu sürümün maddeleri `docs/qa/V59-FIELD-FEEDBACK.md` içinde dosya ve satır
  kanıtlarıyla kayıtlıdır.

## [v59 / 1.0.59+59] - 2026-08-07

> **Kararlılık ve okunabilirlik sürümü.** Geri sayım/pomodoro açılış çökmesi,
> "yükleniyor" ile "kayıt yok" karışması ve grafik/liste okunabilirliği kapandı.
>
> ⚠️ Bu kayıt **sonradan** eklendi (v60 hazırlığında, 2026-08-08). v59 etiketi
> 2026-08-07'de atıldı ama ne burada ne `app/assets/release_notes.json`'da
> kaydı yoktu; uygulama içindeki "Güncelleme notları" ekranı bu sürüm için
> **boş** göründü. Kalıcı önlem aynı turda eklendi: yayın ön denetimi artık
> etiketin bu iki kaydını arıyor ve yoksa fail-closed durur.

### Yenilikler
- Sayaç tanılama kaydı okunabilir hâle geldi (aralıklı hataların kanıtı için).
- Seri rozeti sadeleşti: yalnız alev ve sayı; büyük yazı ölçeğinde de üst üste
  binmiyor.
- Kalan İngilizce arayüz metinleri çevrildi.

### Düzeltmeler
- **Geri sayım ve pomodoro açılışta çöküyordu.** Yerel ayar tipi uyuşmazlığı
  düzeltildi.
- **Kartlar veri gelirken "kayıt yok" / "0 dk" gösteriyordu.** Artık önce yer
  tutucu, sonra gerçek veri görünüyor; çevrimdışında ayrı mesaj çıkıyor.
- Aktif üye kartında sığmayan üye kayboluyordu; kart artık kaydırılabiliyor.
- Üye listesinde uzun adlar tek harfe iniyordu.
- Trend ve dağılım grafiklerinde eksen sayıları üst üste biniyordu.
- Ana ekranın üstü çentikli telefonlarda durum çubuğunun altına giriyordu.
- Grup detayında üye listesi sürekli yenilenip yükleniyora düşüyordu.
- Grup başarımları birden fazla grubu birlikte sayıyordu.
- Gün hedefi tamamlama serisi hiç yazılmıyordu; geçmiş kayıtlar da tamamlandı.

## [v58 / 1.0.58+58] - 2026-08-01

> **Senkron ve saha güveni sürümü.** v57 sonrası geri bildirimler sayaç,
> widget, profil, dürtme ve yönetici akışlarında cihazsız regresyonlarla kapandı.

### Yenilikler
- Countdown ve Pomodoro ana ekran widget'ı artık hedef süreden aşağı sayıyor;
  kronometre davranışı değişmeden korunuyor.
- Profil değişiklikleri hesap akışına anında yansıyor; ünvan seçimi kompakt menüye
  taşındı ve grup satırı uzun ünvanlarda şişmiyor.
- Seri göstergesi kişisel ve grup ilerlemesini daha açık ayırıyor; görev tekrar
  metinleri seçilen aralığı doğrudan söylüyor.
- Yönetici yanıtları realtime yenileniyor ve kullanıcıya push üretiyor; ana ekran
  SSS içeriği sunucudan yönetilebiliyor.
- Yönetici duyuruları alan bazlı doğrulama, güvenli hedef seçimi ve açık silme
  onayı kullanıyor.

### Düzeltmeler
- Daha önce görülmüş bir sayaç snapshot'ı, yerel ayna eksikse yeniden uygulanıyor;
  “başta görünüp sonra kaybolma” yolu kapandı.
- Kısa heartbeat gecikmesi açık çalışmayı bitirmiyor; yaşam döngüsü geçişlerinde
  anlık heartbeat ve sınırlı kurtarma penceresi kullanılıyor.
- Dürtme hataları gerçek nedenini gösteriyor; susturma ve çalışan kişiyi dürtme
  yolları sessiz kalmıyor.
- Ana ekrandaki tekrarlanan üst şerit kaldırıldı; düzenleme uzun basmayla açılıyor.

### Notlar
- Çoklu cihaz sayaç düzeltmesi için iki cihazın da v58'e güncellenmesi gerekir.
- Bu sürüm sunucu şeması `0119`u gerektirir; production hazırlığı tamamlanmadan
  uygulama yayımlanamaz.
- Fiziksel iki-cihaz ve OEM kabul testi, proje sahibinin kararıyla stable yayın
  üzerinde yapılacaktır.

## [v57 / 1.0.57+57] - 2026-08-01

> **Güven ve ilerleme sürümü.** Sayaç, geri bildirim, moderasyon, görevler,
> seriler ve sosyal profil aynı turda daha açıklanabilir ve güvenli hâle geldi.

### Yenilikler
- **Sayaç hareketleri tek sözleşmede.** Uygulama, bildirim ve ana ekran widget’ı
  aynı başlatma/durdurma gerçeğini kullanıyor; gecikmiş bir cihaz komutu yeni bir
  çalışmayı değiştiremiyor.
- **Geri bildirim gerçek bir konuşma.** Kullanıcı ve yönetici aynı kronolojik
  akışı görüyor; iç notlar kullanıcı mesajlarından ayrılıyor ve okunmamış
  işaretleri profil ile ayarlarda aynı gerçeği izliyor.
- **Moderasyon kararları izlenebilir.** Şikâyet bağlamı korunuyor; yaptırımlar
  basamaklı, geri alınabilir ve itiraz süreci denetim iziyle birlikte çalışıyor.
- **Görevler ve seriler daha anlaşılır.** Her N günde yinelenen görevler sabit
  takvim fazını koruyor; görev satırından tamamlama/geri alma yapılabiliyor ve
  seri alevi kişisel ilerleme ile grup katkısını ayırıyor.
- **Başarımlar profil ünvanı olabiliyor.** Kazandığın bir başarımı seçip
  profilinde ve grup üye listesinde gösterebilir, istediğinde kaldırabilirsin.
- **Dürtme odağı bölmüyor.** Çalışan kişi dürtülemiyor; aynı kişiye bekleme
  süresi 20 dakika ve İlham Kaynağı yalnız gerçekten çalışmaya dönüşen
  dürtmeleri sayıyor.
- **Yayın yüzeyi sadeleşti.** İlk mağaza kapsamı Türkçe ve İngilizceyle, tek
  yayın kalitesindeki 1×1 Başlat/Durdur widget’ıyla sınırlandı.

### Düzeltmeler
- Çevrimdışı bitmiş veya bayat bir sayaç komutunun diğer cihazda hayalet çalışma
  başlatması engellendi; tanısal kayıtlar hassas veri sızdırmadan nedeni gösteriyor.
- Şikâyetin yanlış kişiye ya da bağlama bağlanabildiği hedefleme boşlukları kapandı.
- Gruptan çıkış tekrar denendiğinde çift işlem üretmiyor; ayrılan üyenin geçmiş
  çalışma ve ilerleme kayıtları korunuyor.
- E-posta değiştirme yeniden doğrulamaya bağlandı; seçili ders hesap yaşam
  döngüsünde korunuyor.
- Özel tarih aralığı uçları güvenli sıralanıyor; kamp ateşi yerleşimleri ve
  tekrarlanan üst başlıklar sadeleştirildi.
- Hesap silme isteğinin zamanlanması, tekrar çalıştırılması ve denetim kaydı
  güvenli hâle getirildi.

### Notlar
- Bu sürüm yeni sunucu davranışları gerektirir; sunucu hazırlığı tamamlanmadan
  uygulama yayımlanmamalıdır.
- Güncellemeden sonra uygulamayı bir kez kapatıp açmak önerilir.
- Stable yayın kimliği `1.0.57+57` olarak ayrılmıştır; aynı derleme numarası
  başka bir kod için yeniden kullanılmayacaktır.

## [v56 / 1.0.56+56] - 2026-07-28

> Sahibin v55 saha testinden çıkan bulgular ve moderasyon yönetici tarafının
> ilk fazı. PLAN 4 Faz O–S beş paralel lane ile indi; on yedi iş paketi
> (WP-412…WP-428) tek turda kapandı. Şema `0094`ten `0100`e taşındı — altı
> adımın hepsi eklemeli ya da mevcut fonksiyonu aynı imzayla değiştiriyor,
> bu yüzden sahadaki v55 istemcileri apply sırasında kırılmaz.

### Yenilikler
- **Sayaç eşitlemesi üç giriş noktasını da kapsıyor.** Eskiden yalnız uygulama içi Durdur karşı cihaza gidiyordu; bildirim ve ana ekran widget'ından durdurmak yerel kalıyordu. Üçü de tek sözleşmeye bağlandı ve her biri ayrı iki uçlu testle korunuyor.
- **Şikâyet kuyruğu okunabilir hâle geldi.** Yönetici artık ham kimlik yerine ad ve avatar görüyor; şikâyetin tam içeriği, çevresindeki konuşma ve hedefin geçmişi tek ekranda. Aynı kişi hakkındaki şikâyetler tek satırda toplanıyor ve yeni vaka bildirim düşürüyor.
- **Basamaklı yaptırım.** Tek seçenek olan kalıcı yasağın yerine altı basamak geldi: uyar, adı sıfırla, 24 saat sustur, 7/14/30 gün askıya al, kalıcı. Hepsi gerekçe zorunlu, denetim kaydına yazılıyor ve tek tıkla geri alınabiliyor.
- **Şikâyet ve destek sorusuna fotoğraf eki.** Ekler public olmayan ayrı bir alanda tutuluyor; boyut ve tür sunucuda doğrulanıyor, yalnız yönetici açabiliyor.
- **Geri bildirim ekranı ikiye ayrıldı.** Gönder ve Geri bildirimlerim sekmeleri; okunmamış yanıt profil, ayarlar ve geri bildirim adımlarının hepsinde işaret gösteriyor.
- **Kamp ateşi yeniden dengelendi.** Yeşil alan iki katına çıktı ve mobil için parametrik önizleme aracı eklendi; kalabalık sahnede isimler üst üste binmiyor, alt sıradaki hayvanlar kesilmiyor.

### Düzeltmeler
- **Özel tarih aralığı takvimi.** Gün hücreleri gün sayısı yerine `DateTime` nesnesinin tamamını basıyordu; hücreler taşıyor, takvim okunmuyordu.
- **Çevrimdışı biten koşu hayalet koşu doğuruyordu.** İnternet yokken başlatılıp durdurulan çalışma, bağlantı gelince karşı cihazda kendiliğinden aktif hâle geliyordu. Terminal niyet artık korunuyor ve 24 saatten bayat komut yeniden oynatılmıyor.
- **Engelleme yalnız bazı yüzeyleri kapsıyordu.** Engellenen kişi tablolarda adıyla görünüyor ve profili açılabiliyordu; süzgeç sunucuya taşındı. Kamp ateşindeki anonimleştirme davranışı bilerek korundu.
- **Sürüm notlarındaki derleme kartı.** Kanal, commit ve şema bilgisi son kullanıcının gördüğü ilk ekranda duruyordu; Ayarlar > Hakkında altına taşındı ve stable kanalda beta sürümler listelenmiyor.
- **Dört dilde eksik çeviri.** İngilizce, Almanca ve Arapça cihazlarda ayna durdurma diyaloğu, SSS soru formu ve şikâyet metni Türkçe kalıyordu. Bu kusur v55 ile birlikte yayınlanmıştı.
- **Yönetici bildirimi hiç üretilmiyordu.** Yeni şikâyet için kurulan tekilleştirme koşulu, satır tetikleyicisinin deyim sonunda çalışması yüzünden hiçbir durumda tutmuyordu. Koşul yeniden yazıldı.
- **Tanıtım turu ve başarım açıklamaları.** Tur kısaltıldı (ana ekranda tek adım, istatistik turu kaldırıldı); başarım açıklamaları koşulu ve süresini açıkça yazıyor.

### Bu sürümde olmayanlar
- Sayaç eşitlemesi yalnız Android ve kronometre içindir; Pomodoro, geri sayım ve Windows dahil değildir. Eşitlemeyi denemek için iki cihazda da v56 gerekir.
- Tablet yatay yerleşimi ele alınmadı.
- Masaüstünde altı haneli kodla şifre sıfırlama hâlâ çalışmıyor.
- Moderasyonun ikinci fazı (otomatik karantina, kötü niyetli şikâyetçi ölçümü, rol katmanı, itiraz akışı) v57'ye bırakıldı; plan `docs/MODERASYON-PLANI.md`.

## [v55 / 1.0.55+55] - 2026-07-28

> Mağaza yayınından önceki son büyük tur. PLAN 3 Faz K (cihaz geri bildirimi ve
> arayüz borcu) ile Faz L (moderasyon, destek ve güvenlik) bu sürümle kapandı;
> on dört iş paketi tek turda indi. Şema `0089`dan `0094`e taşındı — beş adımın
> hepsi eklemeli ya da mevcut fonksiyonu aynı imzayla değiştiriyor, bu yüzden
> sahadaki v54 istemcileri apply sırasında kırılmaz.

### Yenilikler
- **Engelleme artık sunucuda zorlanıyor.** Eskiden engelleme yalnız görünümü etkiliyordu; dürtme mutasyonu engeli hiç bilmiyordu. Artık `send_nudge` iki yönü birden kesiyor: engellenen kişi gönderemez, engelleyen de gönderemez. Kamp ateşinde engellenen kişi sahneden silinmiyor — kimliği gizleniyor, katılımcı sayısı bozulmuyor.
- **Şikâyet akışı tamamlandı.** Şikâyet dört yüzeyden açılabiliyor (sohbet mesajı, sosyal profil, grup, grup adı) ve gönderim sonrası kullanıcıya inceleme bilgisi veriliyor.
- **SSS ekranı.** Sunucudan beslenen, yayın kontrollü soru-cevap listesi. Giriş yapmadan açılıyor, uçak modunda yedek içerik gösteriyor, TR ve EN.
- **Tek destek kutusu.** Soru, geri bildirim ve şikâyet aynı listede tür etiketiyle toplanıyor; yeni bilet admin cihazına bildirim düşürüyor.
- **Grup yasağı ve davet kodu yenileme.** Yönetici bir üyeyi kalıcı yasaklayabiliyor; yasak, davet kodu ve açık grup katılımının ikisinde de sunucuda zorlanıyor. Davet kodu tek dokunuşla yenileniyor.
- **Herkese açık ad süzgeci.** Görünen ad ve grup adı sunucu tarafında süzülüyor; harf oyunlu varyantlar da yakalanıyor.
- **Başarım açıklamaları.** Katalogdaki her başarım artık gerçek eşik cümlesiyle nasıl kazanıldığını söylüyor.
- **Sürüklenebilir tarih aralığı.** İstatistiklerde özel aralık, takvimin iki ucu sürüklenerek seçiliyor; aralık bırakma anında uygulanıyor.

### Düzeltmeler
- **Ayna cihazda Durdur global durduruyor.** İki cihaz açıkken ikincisinden Durdur'a basmak yalnız o cihazın görüntüsünü durduruyordu; koşu sunucuda açık kalıyordu. Artık koşuyu gerçekten bitiriyor.
- **Widget ve bildirimde boş sayaç biçimi.** Boştayken statik `00:00:00` yazıyordu, koşarken `Chronometer` `00:00` biçimine geçiyordu; ikisi arasında biçim atlaması görünüyordu. Artık ikisi de tutarlı.
- **Tanıtım turu.** Ana ekran turunda üst üste binen tıklanabilir öğeler ayrıldı; tur sıfırlama artık hem ekran turlarını hem ipuçlarını birlikte sıfırlıyor.
- **Ayarlar bilgi mimarisi.** Bölüm sırası sahibin istediği düzene alındı ve testte sabitlendi; istatistik dönem çubuğu sadeleşti.
- **Kamp ateşi kompozisyonu.** Ateş aşağı indirildi ve dikey ayrım yeniden dengelendi; en kalabalık grupta isimlerin üst üste binmediği testle kilitlendi.
- **Sürüm notu ayrımı.** Kullanıcıya gösterilen notlarda teknik satır kalmadı; yasak kelime içeren bir taslak eklenirse sözleşme testi kırmızı düşüyor. Teknik geçmiş ayrı dosyada tutuluyor.

### Notlar
- Sayaç eşitlemesi hâlâ yalnız Android ve kronometre modunu kapsıyor; Pomodoro, geri sayım ve Windows dahil değil.
- Tablet yatay yerleşimi bu sürümde de ele alınmadı.
- Masaüstünde 6 haneli kod ile şifre sıfırlama hâlâ çalışmıyor (free tier e-posta şablonu kilidi).
- Android simge etiketi ve Windows uygulama adı yerelleştirilmiyor; İngilizce cihazda simge altında yine "Odak Kampı" yazar, uygulama içi başlık "Focus Camp" olur.

## [v54 / 1.0.54+54] - 2026-07-28

> 🔴 **Sayaç eşitlemesi v52 ve v53'te de çalışmıyordu; o sürümlerin notları
> bunu yanlış vaat etti.** Bu turda kök neden sonunda bulundu ve kanıtlandı:
> uygulama, sunucunun tanımadığı bir "kaynak" adı gönderiyordu; bu yüzden
> özellik ilk yazıldığından beri **tek bir başlatma komutu bile** sunucuya
> ulaşmamıştı. Hata sessizce yutulduğu ve işlem geri sarıldığı için sunucuda
> iz bile bırakmıyordu — aylardır görünmez kalmasının sebebi buydu. Ayrıca
> uygulama içindeki Durdur düğmesi hiçbir zaman sinyal üretmiyordu. Production
> şeması `0089`a taşındı.

### Düzeltmeler
- **Çoklu cihaz sayaç senkronu artık gerçekten çalışıyor.** İstemci ile sunucunun kaynak sözlüğü ayrışmıştı ve aradaki çeviri kodda hiç yazılmamıştı; her başlatma komutu sunucu tarafından reddediliyordu. Çeviri eklendi, uygulama içi Durdur da artık sinyal üretiyor ve koşu kimliğini taşıyor. Üç ucu (native üretici, uygulama sabiti, sunucu listesi) birbirine karşı ölçen bir test eklendi ki bir daha sessizce ayrışmasın.
- **Kamp ateşinde gündüz/gece saatleri düzeldi.** Gündoğumu ve günbatımı yıl boyu sabitti (06:30 / 18:30) ve gerçek güneşten **2,5 saate kadar** sapıyordu: yazın ortalık aydınlıkken sahne geceye geçiyor, kışın güneş battıktan sonra bir saat daha gündüz kalıyordu. Artık her gün için hesaplanıyor; sapma ±13 dakika.
- **Kamp ateşi kompozisyonu.** Gökyüzü üstten kırpıldı, kart kısaldı; oturma halkası genişledi, böylece kalabalıkta isimler üst üste binmiyor. Marşmelov çubuğu genişleyen halkada ateşe yetişemiyordu, boyu halkayla birlikte ayarlanıyor.
- **Yeni duyuru artık fark ediliyor.** İşaret yalnız Ayarlar'ın *içindeki* Duyurular satırında duruyordu; Ayarlar'ı açmayan kullanıcı duyuruyu hiç görmüyordu. Profil sekmesinde ve Profil'deki Ayarlar satırında da görünüyor.
- **Geri bildirim yazışması.** Liste en eski mesajda takılı kalıyordu; artık açılışta ve her yeni mesajda sona kayıyor. Yönetici tarafında "İç Notlar" bir sohbet gibi göründüğü için kullanıcıya yazıldığı sanılıyordu; kullanıcıya giden yol ayrıldı, öne alındı ve iç notlar kapalı bir yüzey olduğunu açıkça yazıyor.
- **Tanıtım turu onarıldı.** Hedef ekran dışındaysa tur boş bir yeri işaret ediyordu; artık hedefi görünür alana kaydırıyor, kaydırdıkça takip ediyor ve hedefi bulunamayan adımı sessizce ortalamak yerine atlıyor.
- **Başarımlar ekranı sadeleşti.** Büyük birincil grup bloğu sağ üstteki tek ikona taşındı. Grup seçilmemişse uyarı üç yerde birden görünüyor ve seçim yapılınca üçü de kayboluyor.

### Notlar
- Bu sürüm migration taşır; production şeması `0088` → `0089` (ölen cihazın koşusunu kapatan süpürücü). Şema değişmedi, yalnız dakikalık bir zamanlanmış görev eklendi.
- 🔴 Eşitleme için **her iki cihazda da v54** ve bildirim kaydının yapılmış olması gerekir. Eski sürümde kalan cihaz senkron olmaz.
- Sayaç senkronu şimdilik **Android** ve **kronometre** modunu kapsar; Pomodoro, geri sayım ve Windows dahil değildir.
- Cihaz uykudayken bildirim/widget üzerinde sayaç kendiliğinden başlamaz; uygulama açılınca durum sunucudan eşitlenir.
- Ayna cihazdan durdurmak koşuyu yerel olarak durdurur; koşunun sahibi başlatan cihazdır.
- Kamp ateşi gündüz/gece hesabı **konum izni istemez**, bu yüzden Türkiye enlemine göre yaklaşıktır.
- Tablet yatay yerleşimi bu sürümde ele alınmadı (bilinçli).
- Masaüstünde 6 haneli kod ile şifre sıfırlama hâlâ çalışmıyor.

## [v53 / 1.0.53+53] - 2026-07-27

> **Sayaç eşitlemesi tamamlandı.** v52 komutun cihazdan sunucuya gitmesini
> düzeltmişti, ama sunucudaki değişikliği diğer cihaza haber veren parça hiç
> devrede değildi — bu yüzden v52'de de eşitleme görmediniz. Eksik halka bu
> sürümde kuruldu. Production şeması `0088`e taşındı.

### Düzeltmeler
- **İki cihazın sayacı artık gerçekten eşitleniyor.** Bir cihazda başlattığın veya durdurduğun çalışma, diğer cihaza anında haber ediliyor. v52'de bu haber hiç üretilmiyordu: sunucu kaydı güncelliyor ama ikinci cihaza sinyal göndermiyordu, o yüzden diğer cihaz ancak uygulamayı kapatıp açtığında durumu görebiliyordu.
- **Bildirim gecikse veya kaybolsa bile eşitleme tutuyor.** Uygulama ekranda açıkken sayaç durumu düzenli olarak sunucudan doğrulanıyor. Gelen bildirim hiçbir zaman doğrudan sayaç olarak uygulanmıyor; her zaman sunucudaki güncel kayıt okunuyor, böylece gecikmiş eski bir bildirim sayacını geri saramıyor.
- **Bu tur pil harcamıyor.** Doğrulama turu yalnız uygulama ekranda açıkken çalışır; arka plana alındığında durur, öne döndüğünde geri gelir.

### Notlar
- Bu sürüm migration taşır; production şeması `0087` → `0088`.
- Eşitleme için **her iki cihazda da v53** ve bildirim kaydının yapılmış olması gerekir; bildirim izni verilmemiş bir cihazda senkron çalışmaz.
- Sayaç senkronu şimdilik **Android** ve **kronometre** modunu kapsar; Pomodoro, geri sayım ve Windows dahil değildir.
- Admin ↔ kullanıcı yazışmasındaki iki sorun bu sürümde de ele alınmadı (sahip kararı).
- Masaüstünde 6 haneli kod ile şifre sıfırlama hâlâ çalışmıyor.

## [v52 / 1.0.52+52] - 2026-07-27

> **Çalışırken çevrimdışı görünme ve sayaç senkronu.** v51'de aktiflik
> yaklaşık 80 saniye sonra düşüyordu ve iki cihazın sayacı eşitlenmiyordu;
> ikisinin de kök nedeni bulundu ve düzeltildi. Production şeması `0087`ye
> taşındı.

### Düzeltmeler
- **Sayaç çalışırken artık aktiflikten düşmüyorsun.** Canlı durumun süresi düzenli olarak tazeleniyordu, ama tazeleme yalnız kaydın bir kopyasına işleniyor, başkalarının okuduğu kopyaya işlenmiyordu. Bu yüzden yaklaşık 80 saniye sonra hem kendi cihazında hem başkalarında "çalışmıyor" görünüyordun. **Bu düzeltme sunucu tarafındadır: v51'de de geçerlidir, güncelleme beklemeden çalışır.**
- **İki cihazın sayacı artık eşitleniyor.** Bir cihazda başlattığın çalışma sunucuya ancak uygulamayı kapatıp yeniden açtığında bildiriliyordu. O ana kadar diğer cihaz koşuyu göremiyor (`00:00:00`), üstelik ikinci bir sayaç başlatabiliyordun. Başlatma ve durdurma artık anında bildiriliyor.
- Çoklu cihaz sayaç senkronu sunucu tarafında da açıldı; v51'de istemci açıktı ama sunucu her komutu reddediyordu.

### Notlar
- Bu sürüm migration taşır; production şeması `0085` → `0087`.
- Aktiflikten düşme düzeltmesi sunucu tarafındadır; v51 kullanıcıları da faydalanır. Sayaç eşitlemesi için v52 gerekir.
- Sayaç senkronu için cihazın bildirim kaydının yapılmış olması gerekir; bildirim izni verilmemiş bir cihazda senkron çalışmaz.
- Sayaç senkronu şimdilik kronometre modunu kapsar.
- Admin ↔ kullanıcı yazışmasındaki iki sorun bu sürümde ele alınmadı (sahip kararı).
- Masaüstünde 6 haneli kod ile şifre sıfırlama hâlâ çalışmıyor.

## [v51 / 1.0.51+51] - 2026-07-27

> **Canlı durum ve çoklu cihaz turu.** Presence sunucuya hiç yazılamıyordu;
> bu düzeltildi ve aynı sürümde çoklu cihaz sayaç senkronu **açıldı**.
> Migration yok: production şeması `0085`te kalır.

### Düzeltmeler
- **Sayacı başlatınca artık grup arkadaşların da seni "çalışıyor" görüyor.** Uygulama, sunucudaki tabloda olmayan bir alanı yazmaya çalıştığı için canlı durum kaydı sessizce reddediliyordu; kendi ekranında görünüyordun çünkü o bilgi cihazında tutuluyordu. v49 ve v50 bu hatayı taşıyor.
- Canlı durum yazımı başarısız olursa bu artık sessiz kalmıyor, kayda geçiyor.
- Kamp ateşi sahnesi aynı girdiyle her seferinde aynı çiziliyor (marşmelov kızarması artık sahnenin saatinden hesaplanıyor).

### Yenilikler
- **Çoklu cihaz sayaç senkronu açıldı.** Aynı hesapla telefon ve tablette çalışırken sayaç iki cihazda da görünür ve birinden durdurulabilir.
- Canlı durum artık üyesi olduğun **bütün** gruplarda görünür, yalnız o an seçili olanda değil.

### Notlar
- Bu sürümde migration yoktur; production şeması `0085`te kalır.
- Çoklu cihaz özelliği uzaktan kapatılamaz; sorun çıkarsa kapatan yeni bir sürüm gerekir.
- Ekipteki herkes v51'e geçmeli: eski sürümde kalanlar yeni sürümdekileri eksik görebilir.
- Masaüstünde 6 haneli kod ile şifre sıfırlama hâlâ çalışmıyor (ücretsiz plan e-posta şablonu kilidi).

## [v50 / 1.0.50+50] - 2026-07-27

> **v49 saha düzeltmeleri.** Sahibin cihazda bildirdiği üç maddeden ikisi
> uygulama tarafında, biri sunucu yapılandırmasında kapatıldı. Migration yok:
> production şeması `0085`te kalır. V3 rollout flag'leri yine kapalıdır.

### Düzeltmeler
- Şifre sıfırlama e-postasındaki bağlantı artık uygulamayı açıyor. Bağlantı production projesinin ayarı yüzünden `localhost:3000`'e düşüyordu; sunucu tarafında düzeltildi ve **uygulama güncellemesi gerekmeden** herkes için geçerli oldu.
- Kamp ateşi sahnesinde ateşin altındaki koyu/gri zemin lekesi kaldırıldı; ateş doğrudan çimenin üstünde duruyor.
- Uyarı rozetleri artık tema paletinden bağımsız: kırmızı ağırlıklı bir tema seçildiğinde "birincil grup seçilmedi" uyarısı ve Profil sekmesindeki nokta kaybolmuyor.

### Güvenlik ve güvenilirlik
- Auth redirect allowlist'ine yalnız uygulamanın kendi scheme'leri eklendi; joker veya üçüncü taraf adres yok (open-redirect koruması).
- Uyarı rengi zemine göre türetilir ve WCAG AA kontrastı 15 hazır temanın hepsinde testle kilitlenmiştir.
- Sayaç, bildirim ve widget sıcak yolu bu sürümde değiştirilmedi.

### Bilinen açıklar
- Masaüstü/Windows'taki 6 haneli kod ile şifre sıfırlama, Supabase ücretsiz planı e-posta şablonunu kilitlediği için hâlâ çalışmıyor. Android bağlantı yolu çalışır.
- Sayaç çalışırken kullanıcının grupta "aktif" listesinden düşmesi bu sürümde **düzeltilmedi**; önce ölçüm yapılacak (WP-354).
- Çoklu cihaz sayaç senkronu bu sürümde de kapalıdır.

## [v49 / 1.0.49+49] - 2026-07-27

> **Kararlı aday.** Birincil grup sözleşmesi, Forest Cabin tema kapağı ve
> telefon kamp ateşi kompozisyonu production `0085` terfisiyle birlikte gelir.
> V3 global timer/presence/timer-sync rollout flag'leri bu sürümde kapalıdır.

### Yenilikler
- Birincil grup seçimi hesap genelinde korunur; yeni oturum ve grup ilerlemesi yalnız başlangıçtaki primary gruba yazılır.
- Forest Cabin tema kartı, seçilen açık/koyu paletin baskın scaffold ve surface renklerini doğrudan gösterir.
- Telefon kamp ateşi sahnesinde düşük ateş, geniş oturma halkası, küçük/uzak hayvanlar ve ağaçsız arka plan kullanılır.

### Güvenlik ve güvenilirlik
- Primary seçim cooldown'ı ve stale-revision reddi sunucu tarafında uygulanır; preference geçmişi istemci tarafından yazılamaz.
- Production migration zinciri additive kalır; rollback şema düşürme yerine flag-off ve ileri düzeltmeyle yapılır.
- Mevcut sayaç, bildirim ve widget sıcak yolu değiştirilmez.

### Notlar
- Bu stable aday production backend ve migration head **0085** gerektirir.
- V3 global timer, presence projection ve timer-sync rollout flag'leri kapalı kalır.
- Fiziksel Android/Windows kabulü ve 5 hesaplık senaryolar yayın sonrasında gerçek cihazda doğrulanmalıdır.

## [beta-v4402 / 1.0.44-beta.2+4402] - 2026-07-26

> **Beta aday.** Çoklu grup presence, birincil grup attribution ve çoklu cihaz
> global timer altyapısı staging'e taşındı. Yeni V3 yolları bu ilk adayda
> kapalıdır; mevcut sayaç, bildirim ve widget akışı regresyon matrisiyle korunur.

### Yenilikler
- Kullanıcının canlı presence'i aktif olduğu bütün gruplara server-derived projection olarak yansıyabilecek altyapı eklendi.
- Birincil grup seçimi, session/progression attribution'ını tek gruba sabitleyecek server sözleşmesine bağlandı.
- Aynı hesabın telefon/tablet cihazları için global timer command, snapshot, revision ve timer-sync sinyal altyapısı eklendi.

### Güvenlik ve güvenilirlik
- Grup attribution cutover yapılandırması RLS arkasına alındı; istemcinin doğrudan erişimi kapalıdır.
- Staging ve production legacy run envanterinde açık `running`/`paused` çalışma bulunmadığı doğrulandı.
- Timer-sync, presence projection ve global timer rollout flag'leri varsayılan olarak kapalıdır; mevcut bildirim/widget/sayaç sıcak yolu değişmeden kalır.

### Notlar
- Bu beta **staging** backend ve migration head **0084** ile çalışır.
- İlk kabul turunda bildirimden/widget'tan cold start, uygulama kapalıyken stop, 8 saat drift ve iki cihaz senaryoları özellikle test edilecek.
- Production'a migration, flag veya stable yayın yapılmadı.
- Golden görsel testleri baseline'larının üretildiği Windows runner'ında tutulur;
  Android yayın hattı platformdan bağımsız tam fonksiyonel testi çalıştırır.

## [beta-v4309 / 1.0.43-beta.9+4309] - 2026-07-25

> **Beta aday.** Yeni Özellik Turu Aşama A'nın kapanan dokuz iş paketi tek turda cihaz testine gidiyor.
> Kamp ateşi sahnesinin yenilenmesi bu sürümde **yok** — bir sonraki betaya kaldı (F-09).

### Yenilikler
- **Kendi temanı oluştur sihirbazı:** renk, tipografi, biçim, atmosfer ve his adım adım seçiliyor; cihaza kayıtlı üç özel tema yuvası var.
- **Görünüm ekranı yeniden düzenlendi.**
- **Profil tacı yeniden çizildi** (sahip onaylı geometri: 5 uç · span 50° · tip 1.63 · inci 0.10 · kavis 0.50) ve **altın kademeden itibaren** avatarın çevresinde kademe rengiyle ölçekli bir aura görünüyor.
- **Bildirim, izin ve rapor ayarları tek yerde toplandı.**
- **Kart boyutu paneli** ekranın altına sabitlendi; düzenlerken kaybolmuyor.
- **Yazı tipleri uygulamanın içinde geliyor** (Inter · Literata · JetBrains Mono, ADR-4); APK'ya +1.02 MB ekledi, görünüm cihaz fontuna bağlı değil.

### Düzeltmeler
- Şifremi unuttum bağlantısı Android'de açılıyor; Windows için kod ile doğrulama yolu eklendi.
- Almanca ve Arapça seçiliyken İngilizce/Türkçe kalan ekranlar çevrildi: hesap silme, güncelleme, bildirim kanalları, yapılandırma tanısı, ana ekran kart ipucu, en verimli saat.
- Görev bitiş tarihindeki ay adı artık uygulamanın dilinden geliyor (sabit Türkçe ay listesi kaldırıldı).
- Bildirim kanallarının sistem ayarlarında görünen açıklaması artık kanal adının kopyası değil.
- Windows'ta alarm ekleme ekranı gereksiz uyarı penceresi açmıyor.

### Notlar
- Bu beta **staging** backend ve migration head **0070** ile çalışır (`tooling/release/deploy-contract.json`).
- Bu turda **iki beta** kararı yürürlüktedir: beta 1 = bu sürüm; beta 2 = kamp ateşi (WP-295/299/300) + admin işleri.
- 🔴 **Test sırasında kamp ateşi ekranında takılma olup olmadığına özellikle bakılmalı** — WP-295/299'un `p95 ≤ 16.7 ms` / jank ≤ %1 bütçesi bu turda ölçülüyor.
- ⚠️ Şifre sıfırlama akışının test edilebilmesi için önce **staging Supabase panel adımı** gerekir (`docs/SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md`).

## [v45 / 1.0.45+45] - 2026-07-23

> **Kararlı sürüm.** v44 adayındaki bildirim tanısı ve One UI sayaç biçimi production sözleşmesiyle yayımlanır.

### Düzeltmeler
- Uzak self-testin bilinçli 20 saniyelik cooldown'ı artık teslim hatası gibi gösterilmez.
- Aynı kişiye sık dürtme denemesinde 10 dakikalık kural görünür.
- Sayaç bildirimi bir saatin altında `MM:SS`, bir saatten sonra `H:MM:SS` kullanır; çift saat öneki ve dar görünümde kesilen son hane giderildi.

### Notlar
- Bu sürüm production backend ve mevcut production migration head'i (`0065`) ile çalışır.
- GitHub sideload stable APK; uygulama içi güncelleme stable kullanıcılara gider.

## [v44 / 1.0.44+44] - 2026-07-23

> **Kararlı sürüm.** Bildirim tanısı ve One UI sayaç biçimi stable kullanıcılara açılır.

### Düzeltmeler
- Uzak self-testin bilinçli 20 saniyelik cooldown'ı artık teslim hatası gibi gösterilmez.
- Aynı kişiye sık dürtme denemesinde 10 dakikalık kural görünür.
- Sayaç bildirimi bir saatin altında `MM:SS`, bir saatten sonra `H:MM:SS` kullanır; çift saat öneki ve dar görünümde kesilen son hane giderildi.

### Notlar
- Bu sürüm production backend ve mevcut production migration head'i (`0065`) ile çalışır.
- GitHub sideload stable APK; uygulama içi güncelleme stable kullanıcılara gider.

## [beta-v4308 / 1.0.43-beta.8+4308] - 2026-07-23

> **Tanı netliği betası.** Staging ortamındadır; stable uygulamayı ve production verisini etkilemez.

### Düzeltmeler
- **Uzaktan self-test cooldown'ı artık hata diye gösterilmez.** Yeni test isteği sunucu tarafından bilinçli olarak 20 saniye sınırlandığında, ekran teslim timeout'u yerine bekleme bilgisini gösterir.
- **Dürtme cooldown mesajı görünür.** Aynı kişiye tekrar dürtüldüğünde genel “beklenmeyen hata” yerine 10 dakikalık kural açıklanır.
- **Sayaç biçimi sadeleşti.** One UI bildiriminde alt-saatte `MM:SS`, bir saatten sonra `H:MM:SS` görünür; `00:1:00:59` gibi çift saat öneki ve dar görünümde son hanenin kesilmesi olmaz.

### Test notları
- Remote self-test istekleri arasında en az 20 saniye bırak; cooldown mesajı teslim başarısızlığı değildir.
- P1–P6 kabulünü beta-v4307 ile aynı staging backend üzerinde sürdür; bu aday yalnız hata sınıflandırması/mesajını değiştirir.
- Sayaçta `59:55` → `1:00:05` geçişini hem dar hem geniş bildirim görünümünde kontrol et.

## [beta-v4307 / 1.0.43-beta.7+4307] - 2026-07-23

> **Cihaz kabul betası — güvenilir bildirim tekrarı, v43 ürün sözleşmesi ve güvenli test hostu.** Yalnız staging ortamını kullanır; stable uygulamayı ya da production verisini etkilemez.

### Düzeltmeler
- **Staging uzaktan bildirim transportu onarıldı.** Retry worker'ın gerektirdiği `pg_net` artık `0070` migration zincirinin parçasıdır; eksik transport health/post-check tarafından yeşil gösterilmez.
- **Başarısız uzaktan bildirimler otomatik yeniden denenir.** Kuyruk sağlığı artık tekrar deneme zamanı, bekleyen iş sayısı, en eski iş yaşı ve hata sınıfını gösterir.
- **Sayaç bildirimi v43 sözleşmesinde kalır.** Desteklenmeyen yolda güvenli standart fallback korunur; Now Bar/promoted deneyi stable görünümü değiştirmez.
- **Araçlar sade kaldı.** Alarm, Timer ve Görevler korunur; Kronometre, Dünya Saati ve yatay StandBy kaldırıldı.
- **Taç XP çubuğu mutlak toplamı gösterir.** Örneğin `25k / 75k`; kademe içi yanıltıcı sayı göstermez.
- **Android hedefli test hostu güvenlidir.** Kayıtlı yerel-bildirim platformu olmayan test hostu uygulama açılışını bozmaz; gerçek cihazdaki başka platform başlatma hataları gizlenmez.

### Test notları
- Bu beta `0070` staging migration head'ini gerektirir ve stable uygulamayla yan yana kurulur.
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
