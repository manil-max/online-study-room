# v57 Yapılacaklar — Ürün Güveni ve Mağaza Öncesi Son Büyük Tur
> 🔴 **TARIHSEL KAYIT — GUNCEL DEGIL (2026-08-10'da isaretlendi).**
> Bu dosya v57 yapilacaklar listesi icindir ve o tur KAPANDI. Buradaki "yapilacak",
> "acik" veya "karar bekliyor" ifadeleri artik gecerli DEGILDIR.
> Guncel durum: [`../progress.md`](../progress.md) ·
> baglayici urun kararlari: [`URUN-POLITIKALARI.md`](URUN-POLITIKALARI.md) ·
> kalite/yayin kurallari: [`KALITE-PROGRAMI.md`](KALITE-PROGRAMI.md).
> Silinmedi cunku baska belgeler hala buraya baglaniyor; icerik Git
> gecmisinde de duruyor.


> **Tarih:** 30 Temmuz 2026
> **Durum:** Ürün kapsamı ve kabul brief’i; teknik mimari/WP planı değildir
> **Ana kaynak:** [`V56-SAHIP-GERI-BILDIRIM-RAPORU.md`](V56-SAHIP-GERI-BILDIRIM-RAPORU.md)
> **Birleştirilen kaynaklar:** `RAKIPANALIZI.md`,
> `RAKIPANALIZI-DEGERLENDIRME.md`, `MODERASYON-PLANI.md`, `backlog.md`,
> `progress.md`, `KALITE-PROGRAMI.md`

## 1. v57’nin amacı

v57’nin amacı yeni özellik sayısını artırmak değil; kullanıcıların çalışma
süresine, mesajlarına, görevlerine ve güvenlik araçlarına güvenebildiği,
uygulama tarafında mağaza yayınına çok yaklaşmış bir ürün çıkarmaktır.

Mağaza hesabı, listeleme, ekran görüntüleri, mağaza formu ve yayın düğmesi ürün
sahibinde kalır. Uygulamanın kod, davranış, güvenlik, cihaz testi ve açıklanabilirlik
borçları ise bu kapsamda ele alınır.

v57 şu dört soruya “evet” demeden tamamlanmış sayılmaz:

1. Aynı hesap iki cihazda kullanıldığında tek ve doğru sayaç gerçeği var mı?
2. Kullanıcı ile yönetici arasındaki mesajlar kaybolmadan, yanlış yere düşmeden
   ve doğru okunmamış bilgisiyle çalışıyor mu?
3. Bir kullanıcı taciz veya kötü içerikle karşılaşırsa kolayca şikâyet edebiliyor
   ve yönetici bağlamlı, izlenebilir bir işlem yapabiliyor mu?
4. Günlük kullanımın temel akışları — ders, görev, seri, grup, istatistik,
   ayarlar ve widget — anlaşılır ve güvenilir mi?

## 2. Kaynaklar çatışırsa uygulanacak sıra

1. Bu belgedeki **30 Temmuz 2026 ürün sahibi kararları**.
2. `V56-SAHIP-GERI-BILDIRIM-RAPORU.md` içindeki gözlem ve kapsam kararları.
3. `KALITE-PROGRAMI.md` güvenlik, veri ve kalite kapıları.
4. Güncel kod ve çalışma zamanı kanıtı.
5. Rakip analizi.

Rakipte bulunan bir özellik sırf rakipte var diye yapılmaz. Rakip analizi yalnız
kullanıcı acısını ve kaçınılacak hataları gösterir.

## 3. Değişmez ürün ilkeleri

### 3.1 Sayaç güveni özelliklerden önce gelir

Yanlış sekiz saat, kaybolan oturum veya kendiliğinden başlayan sayaç kabul
edilemez. “Bazen oluyor” sınıfındaki hata, yeniden üretmesi zor diye düşük
öncelik sayılmaz.

### 3.2 Tek kullanıcı olayı, tek gerçek

Aynı hesabın telefon, tablet, bildirim, widget ve uygulama yüzeyleri farklı
durumlar uyduramaz. Kullanıcıya gösterilen çalışma durumu ile kaydedilecek
oturum birbirinden kopamaz.

### 3.3 Stop silmek değildir

Durdurma güvenli ve geri döndürülemez veri kaybı üretmeyen bir eylemdir.
Oturum silme ayrı, açık ve onaylı bir işlemdir.

### 3.4 Güvenlik yalnız buton değildir

Şikâyet etme, engelleme, dürtme susturma, inceleme bağlamı, yaptırım, denetim
izi ve itiraz bir sistem olarak ele alınır.

### 3.5 Zorlama ve kolektif ceza yok

Uygulama engelleme dayatılmaz. Bir grup üyesinin davranışı diğer üyelerin
emeğini veya serisini otomatik olarak yok etmez.

### 3.6 İlk mağaza kapsamı dar ve kaliteli

İlk sürüm yalnız Türkçe ve İngilizce sunulur. Altı Android widget yerine yalnız
yayın kalitesindeki 1×1 Başlat/Durdur widget’ı gösterilir. Hazır olmayan yüzey
özellik sayısını yüksek göstermek için yayımlanmaz.

---

## 4. Öncelik ve sıra

| Dalga | İçerik | Kapı |
|---|---|---|
| **A — P0 Güven** | Sayaç, feedback, mesaj, rozet ve grup çıkışı | Bitmeden yeni ürün işi stable’a girmez |
| **B — P0 Güvenlik** | Şikâyet, moderasyon, dürtme susturma, denetim | UGC mağaza kabulünün uygulama tarafı |
| **C — P1 Temel ürün** | Ders, görev, tarih aralığı, seri, e-posta | Günlük kullanım kabulü |
| **D — P1 Sadelik** | Ayarlar, diller, kamp ateşi, sekme başlıkları, widget | Görsel/IA kabulü |
| **E — Yayın kapısı** | Hesap silme, QA, gözlemlenebilirlik, regresyon | v57 release adayı |

Teknik plan bu dalgaları daha küçük WP’lere bölecektir. Bu belge WP numarası veya
dosya sahipliği vermez.

---

## 5. Dalga A — Çoklu cihaz sayaç gerçeği

### V57-A1 — Sayaç mimarisi uçtan uca incelenecek

**Yapılacak**

- Başlatma, aynalama, durdurma, oturum kesinleştirme ve yeniden açılma tek durum
  makinesi olarak ele alınacak.
- Uygulama içi düğme, Android bildirimi ve 1×1 widget aynı komut sözleşmesine
  bağlanacak.
- Kaynak cihaz ve ayna cihaz ayrımı kullanıcı davranışını değiştirmeyecek:
  onaylı Durdur global koşuyu bitirecek.
- Telefon/tablet uygulaması kapalı, arka planda, force-stop edilmiş ve yeniden
  açılmış durumları ayrı ayrı doğrulanacak.
- Her başlatma ve durdurmanın hangi cihaz/yüzeyden geldiği tanısal olarak
  açıklanabilir olacak.

**Yanlış anlaşılmaması için**

- Sorun yalnız “ayna cihazdaki Durdur butonu” değildir.
- Bir cihaza `false`, diğerine `true` yazıp ekranı düzeltmek çözüm sayılmaz.
- Sunucudaki koşu, cihazda görünen sayaç ve kesinleşmiş oturum aynı kimlikle
  uzlaştırılmalıdır.
- Eski veya gecikmiş bir komut yeni bir koşuyu durduramaz veya başlatamaz.

**Ürün kabulü**

1. Aynı hesaplı iki Android cihazda A’dan başlatma, B’den durdurma ve tersi
   en az 20 tekrarda doğru çalışır.
2. Durdurma bütün çevrimiçi cihazlarda en geç 5 saniyede görünür.
3. Tek koşu en fazla bir oturum ve bir kazanım sonucu üretir.
4. Aynı anda iki cihazdan Durdur çift kayıt oluşturmaz.
5. Eski Durdur komutu daha sonra başlayan koşuyu etkilemez.
6. Uygulama içi, bildirim ve widget kökenleri ayrı ayrı geçer.

### V57-A2 — Hayalet ve kendiliğinden başlayan koşular

**Yapılacak**

- v56’daki yaklaşık sekiz saatlik hayalet sayaç vakası için tekrar üretim matrisi
  kurulacak.
- “Kendiliğinden başladı” şüphesini kanıtlayacak olay geçmişi eklenecek.
- Cihaz açılışı, uygulama açılışı, eski push, çevrimdışı kuyruk ve gecikmiş
  komutların yeni koşu üretip üretmediği denetlenecek.
- Çalışıyor gösterilen fakat kayıt oturumu üretmeyecek durum kullanıcıya sessizce
  normal koşu gibi gösterilmeyecek.

**Ürün kabulü**

- Sekiz saatlik uyku senaryosunda kaynak cihazda durdurulan koşu diğer cihazda
  gece boyunca devam etmez.
- Açık kullanıcı eylemi veya belgelenmiş kurtarma nedeni olmadan sayaç başlamaz.
- Tanısal kayıtta her koşunun başlangıç nedeni okunabilir.
- Hayalet koşu saptanırsa kullanıcıya güvenli uzlaştırma sunulur; sahte süre
  otomatik olarak XP/seri/grup katkısına yazılmaz.

### V57-A3 — Çevrimdışı davranış

**Yapılacak**

- Ağ yokken yerel sayaç başlatılabilir ve durdurulabilir.
- Durdurma eylemi ağ bekliyor diye kullanıcıdan saklanmaz.
- Bağlantı geri geldiğinde daha önce bitmiş koşu diğer cihazda yeniden
  canlanmaz.
- Bekleyen komutlar tekrar çalıştırıldığında sonuç değişmez.

**Ürün kabulü**

- Uçak modunda başlat → durdur → uygulamayı kapat → ağı aç senaryosunda tek
  doğru oturum vardır ve diğer cihazda hayalet koşu yoktur.
- Çevrimdışı işlem durumu kullanıcıya anlaşılır Türkçe/İngilizce metinle görünür.

### V57-A4 — Bildirim hedefleme politikası

**Kesin ürün kuralı**

- **Cihaz bildirim testi:** yalnız testi başlatan cihaz.
- **Sayaç eşitleme sinyali:** kaynak dışındaki aynı hesaba ait ilgili cihazlar.
- **Hesap güvenliği:** bütün kayıtlı cihazlar.
- **Kullanıcı mesajı:** bütün uygun cihazlar; bir cihazda okununca rozet gerçeği
  hesap genelinde uzlaşır.
- **Grup/duyuru bildirimleri:** kullanıcının tercihleri ve grup bağlamına göre.

Bu ayrım otomatik test ve iki cihaz kabulüyle korunmalıdır.

---

## 6. Dalga A — Geri bildirim ve mesajlaşmanın yeniden ele alınması

### V57-B1 — Tek konuşma gerçeği

**Yapılacak**

- Kullanıcı ve yönetici aynı bilet için aynı kronolojik konuşmayı görecek.
- Kullanıcı mesajı, yönetici yanıtı, yönetici iç notu ve sistem olayı birbirine
  karışmayacak.
- Her mesaj doğru konuşma kimliğine bağlanacak; yanlış bilete düşemeyecek.
- Gönderim sırasında bağlantı koparsa mesajın durumu görünür olacak; sessizce
  kaybolmayacak.
- Ekli ve eksiz konuşmalar aynı güvenilirlikte çalışacak.

**Yanlış anlaşılmaması için**

- “Yeni mesajı listenin altına koymak” tek başına bu işi kapatmaz.
- İç not kullanıcının konuşmasına gönderilmemeli; kullanıcı yanıtı iç not
  ekranına düşmemelidir.
- Push bildirimi gelmesi mesajın konuşmada gerçekten okunabilir olduğunu
  kanıtlamaz.

**Ürün kabulü**

1. Kullanıcı → admin → kullanıcı şeklinde en az 10 mesajlık konuşmada sıra,
   gönderen ve içerik iki tarafta birebir aynıdır.
2. Yeni mesaj en geç 5 saniyede görünür veya açık bir “yeniden dene” durumu oluşur.
3. İç not kullanıcıya hiçbir kanaldan görünmez.
4. Başka kullanıcının konuşmasına erişim reddedilir.
5. Uygulama kapanıp açıldığında konuşma ve taslak davranışı tutarlıdır.

### V57-B2 — Okunmamış gerçeği ve rozet zinciri

**Yapılacak**

- Okunmamış sayısı mesajlardan türetilen tek bir hesap gerçeği olacak.
- Profil, Ayarlar, Geri Bildirim sekmesi ve cihaz bildirimleri aynı gerçeği
  gösterecek.
- Konuşmayı gerçekten açıp görünür mesajları okumak sunucu okundu bilgisini
  güncelleyecek.
- Arşivleme, filtreleme veya ekranı yenileme okunmamış sayısını yanlışlıkla
  artırmayacak.

**Ürün kabulü**

- Dört okunmamış mesajın tamamı okununca bütün rozetler en geç 5 saniyede sıfır olur.
- Bir konuşmayı açmak başka konuşmadaki okunmamışı silmez.
- İki cihazda birinde okuma yapılınca diğeri yeniden açıldığında doğru sayı gelir.
- Bildirim merkezini temizlemek mesajı okunmuş saymaz; konuşmayı okumak sayar.

### V57-B3 — Kullanıcı ve admin arayüzü

**Kullanıcı tarafı**

- “Gönder” ve “Geri bildirimlerim” ayrımı korunur.
- Konuşma ekranı sohbet gibi okunur; en yeni mesaj aşağıdadır.
- Gönderen, tarih, teslim/başarısızlık ve ek açıkça görünür.
- Hata durumunda yazılan metin kaybolmaz.

**Admin tarafı**

- Tek kutuda geri bildirim, destek sorusu ve ilgili kullanıcı iletişimi türle
  ayrılır.
- Liste; durum, tür, kullanıcı, son mesaj, okunmamış ve bekleme süresine göre
  filtrelenebilir.
- Kullanıcıya yanıt ve iç not farklı renk, etiket ve eylemle gösterilir.
- Bir kaydı açınca kim ne yazmış sorusunun cevabı ilk ekranda görünür.

---

## 7. Dalga B — Moderasyon ve kullanıcı güvenliği

### V57-C1 — Mesaj, profil, grup ve grup adı şikâyeti

**Yapılacak**

- Grup sohbetinde mesaja uzun basınca/bağlam menüsünde “Şikâyet et” görünür.
- Profil, grup ve grup adı şikâyet yolları kolay bulunur ve aynı neden
  sözleşmesini kullanır.
- Şikâyet anındaki içerik dondurulur; sonradan silinmesi kanıtı yok etmez.
- Mesaj şikâyetinde karar için gereken yakın konuşma bağlamı korunur.
- Şikâyetçiye kayıt alındığı ve sonucun nasıl izleneceği açıklanır.

**Kabul**

- Kullanıcı en fazla üç etkileşimde bir mesajı şikâyet edebilir.
- Şikâyet edilen kişi şikâyetçinin kimliğine erişemez.
- Aynı olayın yanlışlıkla tekrar gönderimi mükerrer kart seli üretmez.
- Başka grubun içeriğine sahte kimlikle şikâyet oluşturulamaz.

### V57-C2 — Admin kuyruğunun profesyonelleştirilmesi

**Kartta ilk bakışta**

- şikâyet edilen kişi/içerik;
- şikâyet eden;
- neden ve kısa açıklama;
- aynı hedefe gelen şikâyet sayısı;
- mevcut durum;
- ne kadar süredir beklediği

görülmelidir.

**Etkileşim kararı**

- Open / Under review / Closed seçenekleri kartın mevcut durum çipine
  basınca açılır.
- Üç nokta menüsü ikincil eylemler için kalır.
- Durum metni değişince kartların boyutu ve çevre yerleşimi zıplamaz.

**Ayrıntı ekranı**

- tam içerik;
- mesajın yakın bağlamı;
- hedefin şikâyet/yaptırım geçmişi;
- şikâyetçinin açıklaması;
- uygulanan işlem ve gerekçe;
- değişmez denetim zaman çizgisi

gösterilir.

### V57-C3 — Basamaklı ve geri alınabilir yaptırım

Yönetici yalnız “kalıcı yasak” seçeneğine mahkûm edilmemelidir:

1. uyarı;
2. görünen adı sıfırlama;
3. 24 saat yazma susturması;
4. 7 / 14 / 30 gün askı;
5. kalıcı askı.

Her işlem gerekçe ister, kullanıcıya anlaşılır sonuç gösterir, denetim izine
yazılır ve yetkili yönetici tarafından geri alınabilir. Engelleme veya şikâyet
tek başına otomatik kullanıcı cezası üretmez.

### V57-C4 — İçerik karantinası, öncelik ve kötü niyetli rapor

- Birbirinden bağımsız yeterli sayıda kullanıcı aynı içeriği kısa sürede
  şikâyet ederse içerik **silinmeden geçici gizlenebilir**.
- Nefret, tehdit, cinsel içerik ve yasa dışı içerik gibi ağır nedenler kuyruğun
  başına alınır.
- En eski açık kayıt ve çözüm süresi yöneticiye görünür.
- Sürekli reddedilen kötü niyetli şikâyetler otomatik yaptırım eşiğini
  manipüle etmemelidir.
- Otomasyon kullanıcı hesabını kendi başına kalıcı cezalandırmaz.

### V57-C5 — İtiraz, kanıt saklama ve denetim

- Yaptırım alan kullanıcı nedenini ve süresini görür.
- Uygun yaptırımlar için itiraz yolu vardır.
- Hesap silme, güvenlik kanıtını yok etmez; kişisel kimlik gerektiği ölçüde
  anonimleştirilerek olay kaydı korunur.
- Yönetici kendi işlem kaydını düzenleyemez veya silemez.

### V57-C6 — Kişiye özel dürtme susturma

- Üye menüsünde “Bu kişiden dürtme alma” bulunur.
- Ayar yalnız iki kullanıcı arasındaki dürtme teslimini etkiler.
- Sohbet, grup üyeliği, kamp ateşi, sıralama ve profil görünürlüğü değişmez.
- Engelleme ve dürtme susturma ayrı ayarlardır.
- Susturma geri alınabilir ve hesaplar arasında senkronlanır.

---

## 8. Dalga A/B — Grup işlemleri

### V57-D1 — Gruptan çıkışın anlık ve idempotent olması

**Yapılacak**

- İlk onaydan sonra çıkış düğmesi kilitlenir ve ilerleme görünür.
- Kullanıcı tekrar tekrar basamaz.
- Başarı geldiğinde grup listesi ve seçili grup aynı anda güncellenir.
- Hata varsa kullanıcı gruptan çıkmış gibi gösterilmez; anlaşılır yeniden deneme
  sunulur.
- Uygulama kapanıp açıldığında gerçek üyelik doğru görünür.

**Kabul**

- Normal ağda eylem sonucu en geç 2 saniyede görünür.
- On kez hızlı basma tek çıkış işlemi üretir.
- Birincil gruptan çıkış sonrası birincil grup durumu tutarlı uzlaşır.
- Grup yöneticisinin son üye/tek yönetici gibi özel durumları açıkça ele alınır.

### V57-D2 — Gereksiz grup bilgileri alanını kaldırma

- Gruplar sekmesinin en altındaki davet kodu açılır alanı kaldırılır.
- Davet kodu, yalnız paylaşım/yönetim amacı olan doğrudan bir ekranda bulunur.
- Normal üye, yetkisi olmayan yönetim eylemi görmez.

### V57-D3 — Engelleme, yasaklama ve üyelik kavramlarını karıştırmama

- **Engelleme:** iki kullanıcı arasındaki doğrudan etkileşimi keser; moderasyonu
  engellemez.
- **Dürtme susturma:** yalnız dürtmeyi kapatır.
- **Gruptan çıkarma:** kullanıcı davetle geri gelebilir.
- **Grup yasağı:** yönetici kaldırana kadar hiçbir davet yasağı delemez.
- **Yeni üye onayı:** yasaktan ayrı, gelecekte açılabilir grup ayarıdır.

---

## 9. Dalga C — Ders ve görev sistemi

### V57-E1 — Son seçilen dersin korunması

- Kullanıcı “Matematik” seçtiyse uygulama, cihaz veya sayaç yüzeyi kendiliğinden
  “Genel”e dönmez.
- Kullanıcı başka ders seçene veya seçili ders silinene kadar seçim korunur.
- Seçili ders silinirse “Genel”e güvenli dönüş ve kısa açıklama vardır.
- Aynı hesabın cihazları için yerel/hesap-geneli tercih kararı teknik planda
  netleştirilir; kullanıcıya sürpriz davranış üretilmez.

### V57-E2 — Her N günde tekrar

**Kesin kullanıcı senaryosu**

- Fizik pazartesi, Kimya salı, Biyoloji çarşamba başlar.
- Her görev `3 günde bir` tekrar eder.
- Fizik: pazartesi, perşembe, pazar…
- Kimya: salı, cuma, pazartesi…
- Biyoloji: çarşamba, cumartesi, salı…

**Davranış**

- Tamamlanan bugünkü örnek aktif listeden kalkar.
- Sonraki örnek sabit takvim döngüsünde görünür.
- Görevi geç tamamlamak bütün gelecekteki döngüyü kaydırmaz.
- Kaçırılan eski örnekler birikmez; bugünkü uygun örnek gösterilir.
- Saat/gün hesabı Europe/Istanbul sınırına göre yapılır.

Bu karar, “tamamladıktan üç gün sonra” kayan bir tekrar değil; örnekteki
Fizik–Kimya–Biyoloji düzenini koruyan **başlangıç tarihine sabit tekrar**dır.
Teknik plan başka bir mod önerecekse ayrı ürün seçeneği olarak sunmalıdır.

### V57-E3 — Görev bilgi mimarisi

- “Bugün”, “Tekrarlananlar” ve “Tamamlananlar” açıkça ayrılır.
- Tekrarlanan görevde “3 günde bir · sıradaki: 2 Ağustos” gibi anlaşılır bilgi
  görünür.
- Tek seferlik ve tekrarlanan görevin düzenleme ekranları gereksiz seçeneklerle
  birbirini boğmaz.
- Boş, gecikmiş ve tamamlanmış durumlar net görünür.

### V57-E4 — Satırdan tamamlama ve geri alma

- Görevin dairesi veya satır/metin alanı tamamlamayı tetikleyebilir.
- Düzenle/sil gibi eylemler ayrı bağlam menüsünde kalır.
- Tamamlama sonrası kısa süreli “Geri Al” sunulur.
- Tamamlananlar bölümünden görev yeniden açılabilir.
- Çift dokunma veya iki cihaz aynı görevi iki kez ödüllendiremez.

---

## 10. Dalga C — İstatistik ve seri

### V57-F1 — Özel tarih aralığı yalnız anlaşılır uçlarla değiştirilecek

- Başlangıç ve bitiş günlerinde görünür sürükleme tutamaçları bulunur.
- Başlangıç tutamacı yalnız başlangıcı, bitiş tutamacı yalnız bitişi değiştirir.
- Sıradan güne dokunmak aralığın başlangıcını sessizce başka yere taşımaz.
- Uçlar birbirini geçerse takas veya sınırlandırma davranışı açık ve tek tiptir.
- Sürükleme sırasında aralık canlı önizlenir.

**Kabul senaryosu:** 14–30 aralığının bitiş tutamacını 21’e sürüklemek kesin
olarak 14–21 üretir; 21–30 üretmez.

### V57-F2 — Seri yalnız hedef tamamlamayla ilerler

- Uygulamayı açmak, ekranda gezinmek veya sayacı yalnız başlatmak seri vermez.
- İlgili günlük hedef tamamlandığında seri bir artar.
- Bireysel hedef ve grup hedefi ayrı değerlendirilir.
- Hesap ve gün sınırı sunucu otoritesinde, Europe/Istanbul gününe göre belirlenir.

### V57-F3 — Üç görünür alev durumu

| Durum | Anlam | Görsel yön |
|---|---|---|
| **Tamamlandı** | Bugünkü hedef tamamlandı | Canlı kırmızı/turuncu alev |
| **Bugün bekliyor** | Seri sağlam; bugünkü hedef henüz tamamlanmadı | Soluk/gri alev |
| **Koruma günü** | Dün kaçırıldı; bugün tamamlanırsa seri kurtulur | Alev + belirgin koruma/“=” işareti |

**Kesin seri kuralı**

- Araya en fazla bir tamamlanmamış gün girebilir.
- Koruma gününde hedef tamamlanırsa seri sıfırlanmaz ve yalnız tamamlanan gün
  kadar artar.
- İki gün arka arkaya hedef tamamlanmazsa seri sıfırlanır.
- Bu koruma tekrar tekrar kullanılabilir; bir gün çalışıp bir gün ara veren
  kullanıcı, çalıştığı gün sayısı kadar seri biriktirebilir.
- Geçmişe sonradan manuel süre eklemek seri kuralını sessizce değiştirmez;
  bunun politikası teknik planda açıkça doğrulanır.

### V57-F4 — Grup ve bireysel seri görsel olarak ayrılacak

- İkisi aynı alev ailesini kullanabilir.
- Küçük kişi/grup işareti, çevre çizgisi veya renk ayrımıyla karışmaz.
- Grup serisi tek bir üyenin hatasıyla topluca yok olmaz; grup hedefinin
  kanonik tamamlanma kuralı ayrıca tanımlanır.

---

## 11. Dalga C/D — Ayarlar, hesap ve dil

### V57-G1 — Hakkında ve Güncellemeler tek alan

Tek ekranda:

- uygulama adı ve sürümü;
- güncelleme kontrolü;
- sürüm notları;
- gizlilik/koşullar/destek bağlantıları;
- gerektiğinde açılan teknik tanı bilgisi

bulunur. Ayarlarda “Versiyon ve Güncellemeler” ile “Hakkında” diye iki benzer
satır kalmaz.

### V57-G2 — Yalnız TR + EN

- Dil seçicisinde yalnız Türkçe ve İngilizce vardır.
- Almanca/Arapça dosyalar repoda korunur ancak çalışma zamanı destek listesine,
  mağaza beyanına ve ilk sürüm QA matrisine girmez.
- Türkçe olmayan sistem dili İngilizceye düşer.
- Daha önce Almanca/Arapça seçmiş test kullanıcısı güncellemede çökmez; İngilizce
  fallback alır.
- Android uygulama dışı yüzeyleri de yalnız TR/EN sözleşmesini izler.

### V57-G3 — Güvenli e-posta değiştirme

- Mevcut şifre veya yakın tarihli yeniden kimlik doğrulama gerekir.
- Yeni e-posta doğrulanmadan hesap adresi değişmez.
- Eski adrese güvenlik bildirimi gönderilir.
- İşlem yarım kalırsa kullanıcı eski e-postayla hesabına erişmeye devam eder.
- Başka cihazlardaki oturumların etkisi kullanıcıya açıklanır.
- Saldırganın yalnız açık bir oturumu ele geçirerek e-postayı sessizce
  değiştiremeyeceği doğrulanır.

### V57-G4 — Ayarlar rozet temizliği

Geri bildirim rozeti düzeltildikten sonra Ayarlar satırı ve Profil sekmesi
yalnız gerçek okunmamış varsa işaret gösterir. Birincil grup, bekleyen ödül ve
mesaj işaretleri birbirinin sayısını ezmez.

---

## 12. Dalga D — Görsel ve bilgi mimarisi

### V57-H1 — Kamp ateşi dört kişi

- Ateş varlığı tek başına biraz daha aşağı alınır.
- Hayvanların tamamı aşağı taşınmaz.
- Oturma yerleri daha dairesel görünür; iki çift karşılıklı masa izlenimi azalır.
- Üst hayvanlar/isimler yukarı alınarak isim–hayvan çakışması bitirilir.
- Değerler önce ürün sahibine parametrik önizleme olarak gösterilir, sonra
  sabitlenir.

### V57-H2 — Kamp ateşi sekiz kişi

- Dört kişilik değerler sekiz kişiye otomatik kopyalanmaz.
- Sekiz kişide isim, figür, ayak ve ekran kenarı çakışmaları ayrıca ölçülür.
- 1/4/8 kişi görünümleri gerçek telefon ekranında kabul edilir.

### V57-H3 — Alt sekmelerde gereksiz üst boşluğu kaldırma

- Araçlar, Gruplar, İstatistikler ve Profil’de yalnız sekme adını tekrar eden
  büyük başlık alanı kaldırılır.
- İçerik güvenli alanın hemen altında başlar.
- Grup değiştir ve kart düzenle gibi eylemler kompakt içerik eylemine taşınır.
- Ana sayfanın farklı ihtiyaçları ayrıca değerlendirilir; bütün sekmelere aynı
  kör kural uygulanmaz.
- Büyük yazı, ekran okuyucu, geri hareketi ve sistem durum çubuğu korunur.

### V57-H4 — Android widget seçicisini sadeleştirme

- Yalnız 1×1 Başlat/Durdur widget’ı yeni kullanıcıya sunulur.
- Diğer beş widget yayımlanan seçiciden çıkarılır, kaynak kodu hemen silinmez.
- Daha önce yerleştirilmiş eski widget güncellemede uygulamayı çökertmez.
- Tek kalan widget; boş, çalışan, durdurulmuş, uygulama kapalı ve cihaz yeniden
  başlatılmış durumlarda test edilir.

### V57-H5 — Grup bilgilerindeki davet kodu tekrarını kaldırma

Grup ekranının altındaki açılır “Grup bilgileri” alanı kaldırılır. Paylaşım
gereksinimi varsa davet kodu grup yönetimi/paylaşım eyleminde tek yerde yaşar.

---

## 13. Dalga E — Mağaza öncesi uygulama kapısı

### V57-Q1 — Hesap silme ve veri yaşam döngüsü

Mevcut açık kabul borcu kapatılmalıdır:

- silme isteği;
- vazgeçme;
- bekleme süresi;
- gerçek silme;
- yetkisiz çağrı reddi;
- tekrar deneme;
- mesaj, şikâyet kanıtı ve denetim kaydının doğru anonimleştirilmesi;
- kullanıcıya anlaşılır durum

staging ortamında kanıtlanır. Production’da gerçek kullanıcı silme işlemi ayrıca
somut ürün sahibi onayı gerektirir.

### V57-Q2 — Başarım, görev ve grup ilerlemesi kabul matrisi

- kronometre;
- geri sayım;
- Pomodoro;
- manuel süre;
- native/widget kaynaklı süre;
- iki cihaz;
- İstanbul gün sınırı;
- görev tamamla/geri al;
- bireysel ve grup serisi;
- XP ve başarım

aynı tabloda beklenen/gerçek sonuçla doğrulanır. Çift ödül veya kayıp katkı sıfır
olmalıdır.

### V57-Q3 — Çökme, donma ve sessiz hata gözlemi

- Yayın adayında çökme ve uygulama yanıt vermeme olayları sembolize edilmiş
  biçimde görülebilir olmalıdır.
- Sayaç, feedback ve moderasyonun kritik sessiz hataları tanısal olay üretmelidir.
- Kişisel mesaj içeriği, e-posta, erişim anahtarı veya hassas veri tanı kaydına
  yazılmaz.
- “Kullanıcı tarif edemediği için hata yok” yaklaşımı kabul edilmez.

### V57-Q4 — Zorunlu gerçek cihaz matrisi

En az:

- iki Android cihaz, aynı hesap;
- iki farklı kullanıcı hesabı;
- Samsung One UI ve mümkünse farklı üretici/Pixel davranışı;
- Wi‑Fi, mobil veri ve uçak modu;
- foreground, background, force-stop, reboot;
- bildirim ve widget;
- 23:59–00:01 Europe/Istanbul sınırı;
- uygulama güncellemesi;
- düşük pil/batarya optimizasyonu

senaryoları çalıştırılır.

### V57-Q5 — Regresyon ve eski veri güveni

- v56’dan v57’ye güncelleme kullanıcı oturumunu, ders seçimini, görevleri,
  grupları ve geçmiş süreyi kaybetmez.
- Büyük arayüz sadeleştirmelerinde işlev kaybolmaz.
- Pasifleştirilen AR/DE ve widget yüzeyleri eski kullanıcı ayarlarında çökme
  üretmez.
- Engelleme, rapor, grup çıkışı ve e-posta değişimi RLS/yetki sınırlarını aşmaz.

### V57-Q6 — Release kapısının yeniden kilitlenmesi

30 Temmuz salt-okunur kontrolde v56 için geçici açılmış olması gereken
`deploy_enabled` ve `release_enabled` bayraklarının sözleşme dosyasında hâlâ
`true` kaldığı görüldü.

- Yeni production veya stable işlemi yapılmadan önce iki bayrak güvenli HOLD
  durumuna döndürülmelidir.
- Kapatma sonrasında guard/preflight testleri kapının onaysız işlemi gerçekten
  reddettiğini kanıtlamalıdır.
- Bu yalnız doküman metni değiştirilerek “kapanmış” sayılamaz; sözleşmenin gerçek
  değerleri ve otomasyon davranışı birlikte doğrulanmalıdır.
- Her gelecek terfi, başarılı post-check’ten sonra aynı koşumda veya zorunlu
  finalizer adımında otomatik yeniden kilitlenmelidir.

---

## 14. Rakip analizinden v57’ye alınan kararlar

| Rakiplerdeki tekrar eden sorun | v57 karşılığı |
|---|---|
| Sahte/kayıp süre, stop çalışmıyor | V57-A1/A2/A3 |
| Mesaj yüklenmiyor, okundu yanlış | V57-B1/B2 |
| Rapor işlemiyor, engellenen etkileşiyor | V57-C1–C6 |
| Tekrarlanan görevler ve takvim bozuluyor | V57-E2/E3, V57-F1 |
| Hesap/e-posta değişiminde veri erişimi kaybı | V57-G3 |
| Boş veya çalışmayan widget | V57-H4 |
| Güncelleme sonrası karmaşık büyük UI | V57-H3 + regresyon kapısı |
| Sunucu yokken ürün ölüyor | V57-A3 |
| Yanlış ceza ve itirazsız moderasyon | V57-C3/C5 |

Rakip analizinden **alınmayan** yönler:

- zorunlu uygulama engelleme;
- sesli/görüntülü açık çalışma odaları;
- reklam ve odak sırasında açılan satın alma yüzeyleri;
- sözlük/hesap makinesi/flashcard gibi sınırsız araç yığını;
- bir kişinin hatasıyla bütün grubun kaybettiği kolektif ceza.

---

## 15. v57 çekirdeği yeşil olursa ele alınacak ikinci sıra

Bu maddeler kaybolmaz; ancak P0 sayaç/mesaj/güvenlik işlerinden önce başlamaz:

1. **Sıralamayı gizleme veya kişisel hedef modu.**
2. **Manuel oturum etiketi:** süre ve XP sayılır; geçmiş ve grup katkısında
   “elle eklendi” şeffaflığı bulunur.
3. **Sohbette alıntı/yanıt ve görsel:** moderasyon kanıt zinciriyle birlikte.
4. **Davet linki:** alan adı ve doğrulanmış Android App Link sonrası.
5. **Yeni üye onayı:** grup yasağından bağımsız grup ayarı.
6. **Ders klasörleri ve oturum bazlı çalışma kırılımı.**
7. **Sınav geri sayımı (D-Day):** araç yığınına girmeden YKS/KPSS bağlamına
   uygun küçük ürün.
8. **Masaüstü admin yerleşimi:** geniş ekranda liste + ayrıntı.
9. **AMOLED tema ve burn-in korumalı odak görünümü.**
10. **Çalışma dışı kategoriler:** ders toplamlarına karışmayan ayrı sınıf.

Bu liste v57 release kapısını otomatik olarak genişletmez. Çekirdek stabil değilse
sonraya kalır.

## 16. Bilinçli kapsam dışı

- Mağaza listeleme metni, ekran görüntüleri, fiyatlandırma formu ve yayın düğmesi:
  **ürün sahibi**.
- Tablet yatay yerleşiminin büyük yeniden tasarımı: önceki ürün kararıyla parkta.
- Almanca ve Arapça ürün desteği: dosyalar korunur, ilk yayın kapsamı dışı.
- Diğer beş Android widget’ın yeniden tasarımı: sonraki sürüm.
- Sesli/görüntülü açık çalışma odaları.
- Windows’taki ücretli SMTP’ye bağlı özel şifre sıfırlama genişletmesi, sağlayıcı
  kararı olmadan v57 Android kapısını bloke etmez.

## 17. Teknik plana geçmeden önce cevaplanmış ürün kararları

Teknik plan aşağıdakileri yeniden soru olarak açmamalıdır:

1. Ayna cihazdaki Durdur global koşuyu durdurur.
2. Sayaç kısa yamalarla değil mimari bütünlükle ele alınır.
3. Dürtme susturma engellemeden ayrı, kişi bazlı ayardır.
4. Grup sohbetinde mesaj bazlı şikâyet gerekir.
5. Admin durum seçenekleri kartın durum çipinden açılır; kart zıplamaz.
6. Tarih aralığı görünür uçları sürükleyerek ayarlanır.
7. Hakkında ve Güncellemeler birleştirilir.
8. İlk yayın yalnız TR + EN’dir; AR/DE silinmez, pasif kalır.
9. Son seçilen ders kullanıcı değiştirene kadar korunur.
10. N-gün görevi başlangıç tarihine sabit takvim döngüsü kullanır.
11. Görev satırı tamamlanabilir ve geri alınabilir.
12. Yalnız 1×1 Başlat/Durdur widget’ı yayımlanır.
13. Seri uygulamayı açmakla değil hedef tamamlamakla ilerler.
14. Seride bir günlük, tekrar kullanılabilir koruma vardır; iki ardışık kaçırma
    seriyi sıfırlar.
15. Bireysel ve grup serileri ayrı hesaplanır ve görsel olarak ayırt edilir.
16. Geri bildirim/mesajlaşma sistemi uçtan uca yeniden incelenir.

## 18. v57 “bitti” tanımı

v57 ancak aşağıdakilerin tamamı sağlandığında release adayıdır:

- P0 sayaç senaryolarında hayalet, çift oturum ve kayıp oturum yok;
- feedback mesajları doğru konuşmada ve okunmamış sayıları doğru;
- mesaj bazlı şikâyet ile admin inceleme/yaptırım akışı çalışıyor;
- grup çıkışı tek basışla güvenilir;
- ders ve görev tekrarları kalıcı ve anlaşılır;
- tarih aralığı ile seri davranışı ürün kararına uyuyor;
- yalnız TR/EN ve yalnız kaliteli widget yüzeyi yayımlanıyor;
- v56→v57 veri kaybı yok;
- otomatik testler, güvenlik testleri ve gerçek cihaz matrisi yeşil;
- kritik/ağır açık hata sayısı sıfır;
- ürün sahibi cihaz kabulü verdi.

Bu noktadan sonra belge teknik plana çevrilir; teknik plan her başlığı ayrı,
ölçülebilir WP’lere böler ve dosya/migration/ajan çakışmalarını ayrıca belirler.
