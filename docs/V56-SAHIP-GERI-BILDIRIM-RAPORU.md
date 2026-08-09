# v56 Ürün Sahibi Geri Bildirim Raporu
> 🔴 **TARIHSEL KAYIT — GUNCEL DEGIL (2026-08-10'da isaretlendi).**
> Bu dosya v56 sahip geri bildirimi icindir ve o tur KAPANDI. Buradaki "yapilacak",
> "acik" veya "karar bekliyor" ifadeleri artik gecerli DEGILDIR.
> Guncel durum: [`../progress.md`](../progress.md) ·
> baglayici urun kararlari: [`URUN-POLITIKALARI.md`](URUN-POLITIKALARI.md) ·
> kalite/yayin kurallari: [`KALITE-PROGRAMI.md`](KALITE-PROGRAMI.md).
> Silinmedi cunku baska belgeler hala buraya baglaniyor; icerik Git
> gecmisinde de duruyor.


> **Tarih:** 30 Temmuz 2026
> **Kaynak:** v56 stable sürümünün ürün sahibi ve sınırlı kullanıcı saha gözlemleri
> **Amaç:** Gözlemleri kaybetmeden, belirti ile teşhisi birbirine karıştırmadan sonraki
> ürün ve teknik planlamaya güvenilir girdi sağlamak
> **Durum:** Ürün geri bildirim kaydıdır; kök neden veya teknik çözüm iddiası içermez

## 1. Yönetici özeti

v56 indirilebiliyor ve kurulabiliyor. Sürümdeki iyileştirmelere rağmen üç alan
yayın güveni açısından henüz yeterli değildir:

1. **Çoklu cihaz sayaç doğruluğu:** Ayna cihazdan durdurma, kendiliğinden çalışma
   şüphesi, aralıklı eşitleme ve sekiz saatlik hayalet sayaç vakası aynı mimari
   yüzeyin farklı belirtileridir. Kısa yamalar yerine uçtan uca durum modeli
   incelenmelidir.
2. **Geri bildirim ve mesajlaşma:** Okunmamış işaretleri temizlenmiyor, mesajların
   doğru konuşmaya düşmediği veya geciktiği düşünülüyor ve kullanıcı ile yönetici
   aynı konuşma gerçeğini güvenilir biçimde göremiyor.
3. **Moderasyon ve kullanıcı güvenliği:** Şikâyet sistemi teknik olarak genişledi
   ancak kullanıcı ve yönetici deneyimi hâlâ yeterince anlaşılır, hızlı ve güven
   verici değil. Grup sohbetinde tek bir mesajı şikâyet etme gibi temel güvenlik
   yolu eksik veya keşfedilemiyor.

Görevler, seri sistemi, ayarlar, kamp ateşi, sekme başlıkları ve widget kapsamı
için de açık ürün kararları verilmiştir. Bunlar aşağıda yanlış anlaşılmayacak
biçimde kaydedilmiştir.

## 2. Kanıt sınıfları

| Sınıf | Anlamı |
|---|---|
| **Doğrudan gözlem** | Ürün sahibi veya kullanıcı davranışı cihazda açıkça gördü |
| **Tek kullanıcı vakası** | Gerçek vaka var; tekrar üretim ve kapsam ölçümü gerekir |
| **Şüpheli belirti** | Olmuş olabileceğine dair güçlü izlenim var; henüz kesin değil |
| **Ürün isteği** | Mevcut davranış hata olmasa bile istenen yeni ürün davranışı |
| **Kapsam kararı** | İlk mağaza sürümünde tutulacak veya çıkarılacak yüzey |

Bu rapordaki hiçbir “şüpheli belirti” otomatik olarak kök neden kabul edilmemelidir.

---

## 3. Çoklu cihaz sayaç ve bildirim güveni

### V56-S01 — Ayna cihazdaki bildirimden durdurma kaynak cihazı durdurmuyor

- **Sınıf:** Doğrudan gözlem · kritik
- **Senaryo:** Sayaç birinci cihazda başlatılıyor. İkinci cihaz koşuyu aynalıyor.
  İkinci cihazın bildirimindeki **Durdur** eylemine basılıyor.
- **Gözlenen:** Ayna cihazın yüzeyi duruyor ancak sayacı asıl başlatan cihaz
  çalışmaya devam ediyor.
- **Beklenen:** Hesapta tek bir çalışma gerçeği olmalıdır. Herhangi bir cihazdan
  verilen onaylı Durdur komutu aynı global koşuyu bütün cihazlarda bitirmelidir.
- **Not:** Uygulama içi, bildirim ve widget eylemleri ayrı ayrı doğrulanmalıdır;
  birinin çalışması diğer ikisinin çalıştığını kanıtlamaz.

### V56-S02 — Sayaç bazen kendiliğinden çalışıyor olabilir

- **Sınıf:** Şüpheli belirti · kritik aday
- **Gözlenen:** Kullanıcı açık bir başlatma eylemi hatırlamadığı hâlde sayaç
  çalışıyor gibi görünebiliyor.
- **Kesinlik:** Ürün sahibi yüzde yüz emin değil; olay kaydı olmadığı için bugün
  doğrulanamıyor.
- **Beklenen:** Her başlatmanın görülebilir bir kaynağı olmalı; eski komut,
  bildirim tekrarı, cihaz açılışı veya gecikmiş eşitleme yeni koşu doğurmamalıdır.
- **İhtiyaç:** Başlatma kaynağı, cihaz, zaman ve koşu kimliği tanısal kayıtta
  izlenebilmelidir.

### V56-S03 — Eşitleme aralıklı olarak kararsız

- **Sınıf:** Doğrudan genel gözlem · yüksek
- **Gözlenen:** S01 dışında da her zaman oluşmayan senkron gecikmeleri veya
  durum uyuşmazlıkları görülebiliyor.
- **Beklenen:** Aynı hesabın iki cihazı; başlatma, çalışma, durdurma ve yeniden
  açılma sonrasında tek ve tutarlı durumu göstermelidir.
- **Not:** “Bir kez çalıştı” kabul kanıtı değildir. Tekrarlı, yaşam döngülü ve
  çevrimdışı senaryolar gerekir.

### V56-S04 — Sekiz saatlik hayalet çalışma, fakat oturum kaydı yok

- **Sınıf:** Tek kullanıcı vakası · kritik
- **Senaryo:** Kullanıcı sayacı tablette başlatıp yine tabletten durduruyor ve
  uyuyor. Aynı hesap telefonda da açık.
- **Gözlenen:** Sabah telefonda yaklaşık sekiz saat çalışan sayaç görülüyor.
  Telefon kullanıcı tarafından başlatılmamış. Durdurulduğunda sekiz saatlik
  çalışma kaydı oluşmuyor; sayaç yalnız görünürde çalışmış gibi davranıyor.
- **Risk:** İki ayrı gerçek birbirinden kopmuş olabilir:
  1. cihazda gösterilen canlı sayaç durumu,
  2. sunucuda kesinleşen çalışma oturumu.
- **Beklenen:** Hayalet süre oluşmamalı. Çalışan bir koşu ya güvenilir biçimde
  kesinleştirilmiş oturum üretmeli ya da açıkça “uzlaştırma gerekli” durumunda
  görünmelidir. Sessizce sekiz saat dönüp sonra hiçbir iz bırakmamalıdır.
- **Kullanıcı verisi:** Kullanıcı bu süreyi yanlış olduğu için silmeyi düşünmüş,
  ancak zaten kayıt oluşmamış. Herhangi bir veri düzeltmesi yapılmadan önce olay
  yeniden üretilmeli ve kayıtlar incelenmelidir.

### V56-S05 — Bildirim testi hesabın açık olduğu bütün cihazlara gidiyor

- **Sınıf:** Ürün davranışı incelemesi · orta
- **Gözlenen:** Bir cihazdan bildirim testi başlatılınca aynı hesabın açık olduğu
  bütün cihazlara bildirim geliyor.
- **Değerlendirme ihtiyacı:** Bu her bildirim türü için doğru davranış değildir.
- **Önerilen ürün kuralı:**
  - cihaz tanı/test bildirimi yalnız testi başlatan cihaza gider;
  - güvenlik ve hesap olayları bütün kayıtlı cihazlara gidebilir;
  - sayaç eşitleme sinyali kaynak cihaz dışındaki ilgili cihazlara gider;
  - kullanıcı mesajı bildirimi hesap genelinde gidebilir ancak açılan cihazda
    okunduğunda diğer cihazlardaki rozetler uzlaştırılır.

### Sayaç alanı için sonuç

Bu beş kayıt tek tek yamanmamalıdır. v57 teknik planından önce çoklu cihaz sayaç
mimarisinin; komut üretimi, sunucu otoritesi, cihaz aynası, bildirim/widget
eylemleri, çevrimdışı kuyruk, uygulama yaşam döngüsü ve oturum kesinleştirme
birlikte incelenmelidir.

---

## 4. Geri bildirim, mesajlaşma ve okunmamış işaretleri

### V56-F01 — Okunmamış işaretleri bütün mesajlara bakılmasına rağmen kalıyor

- **Sınıf:** Doğrudan gözlem · yüksek
- **Gözlenen:** Geri bildirim konuşmalarının tümü açılıp okunmasına, ekranların
  kapatılıp yeniden açılmasına rağmen Profil ve Ayarlar üzerindeki işaret
  temizlenmiyor. Görünürde dört okunmamış bildirim kalıyor.
- **Beklenen:** Kullanıcı konuşmayı gerçekten gördüğünde ilgili mesajlar okunmuş
  sayılmalı; Profil → Ayarlar → Geri Bildirim zincirindeki bütün işaretler aynı
  gerçeğe göre en geç birkaç saniye içinde temizlenmelidir.
- **Risk:** Yerel rozet, sunucu okundu bilgisi ve push bildirimi birbirinden
  bağımsız ilerliyor olabilir.

### V56-F02 — Mesaj yanlış konuşmaya düşüyor veya hiç düşmüyor olabilir

- **Sınıf:** Şüpheli fakat tekrarlayan belirti · kritik aday
- **Gözlenen:** Yazılan bazı mesajların yanlış yere düştüğü, bazı mesajların
  konuşmada görünmediği veya geciktiği düşünülüyor. Ürün sahibi tam teknik
  senaryoyu tarif edemiyor ancak kullanıcı deneyimi güven vermiyor.
- **Beklenen:** Kullanıcı ve yönetici aynı biletin aynı kronolojik konuşmasını
  görmelidir. İç not, kullanıcıya gönderilen yanıt ve sistem olayı görsel ve
  davranışsal olarak kesin biçimde ayrılmalıdır.
- **Yanlış çözüm uyarısı:** Yalnız liste sırasını veya rozet sayısını düzeltmek
  yeterli değildir; konuşma kimliği ve mesaj yönlendirme gerçeği doğrulanmalıdır.

### V56-F03 — Kullanıcı ve admin deneyimi bütünsel olarak zayıf

- **Sınıf:** Ürün değerlendirmesi · yüksek
- **Gözlenen:** Kim ne yazmış, hangi mesaj kullanıcıya gitti, hangi kayıt iç not,
  konuşmanın güncel durumu ne gibi temel bilgiler hızlı okunamıyor.
- **Beklenen:**
  - tek konuşma zaman çizgisi;
  - gönderen rolü ve görünen adı;
  - okunma/teslim durumu;
  - eklerin güvenilir açılması;
  - iç not ile kullanıcı yanıtının keskin ayrımı;
  - arşivleme ve yeniden açma;
  - hatada kaybolmayan taslak ve görünür yeniden deneme.

### V56-F04 — Sistem baştan uçtan uca denetlenmeli

- **Sınıf:** Ürün sahibi talimatı
- **Karar:** Geri bildirim sistemi yalnız mevcut hatalara küçük düzeltmeler
  eklenerek kapatılmayacak. Kullanıcı oluşturma → admin bildirimi → admin okuma
  → yanıt → kullanıcı teslimi → okunmuş işareti → arşiv akışı baştan sona
  incelenecek.

---

## 5. Moderasyon, şikâyet ve güvenlik

### V56-M01 — Admin şikâyet kuyruğu hâlâ yeterince okunabilir değil

- **Sınıf:** Doğrudan ürün değerlendirmesi · yüksek
- **Gözlenen:** Yönetici kartlarında kim kimi, hangi içerik için ve hangi bağlamda
  şikâyet etmiş hızlıca anlaşılamıyor.
- **Beklenen:** Kart özeti tek bakışta hedef, şikâyetçi, içerik türü, neden,
  şikâyet sayısı, zaman ve mevcut durumu göstermeli; ayrıntıda tam içerik,
  konuşma bağlamı, geçmiş şikâyetler ve yaptırımlar bulunmalıdır.

### V56-M02 — Durum değiştirme üç nokta menüsünde saklanmamalı

- **Sınıf:** Ürün isteği
- **Mevcut davranış:** Open / Under review / Closed seçenekleri üç nokta
  menüsünden değiştiriliyor.
- **İstenen:** Kart üzerindeki mevcut durum rozeti/düğmesine basınca durum
  seçenekleri doğrudan açılmalı.
- **Görsel kural:** Durum metinlerinin uzunluğu değiştiğinde kart yüksekliği,
  eylem hizası ve çevredeki kartlar zıplamamalıdır.

### V56-M03 — Grup sohbetinde tek mesajı şikâyet etme yolu gerekli

- **Sınıf:** Ürün isteği · mağaza güvenliği için yüksek
- **İstenen:** Kullanıcı bir mesaja uzun basarak veya bağlam menüsünü açarak
  doğrudan o mesajı şikâyet edebilmelidir.
- **Kanıt kuralı:** Şikâyet anındaki mesaj içeriği ve gerekli yakın konuşma
  bağlamı korunmalı; mesaj sonradan silinse bile inceleme kanıtı kaybolmamalıdır.
- **Güvenlik kuralı:** Şikâyet edilen kullanıcı şikâyetçinin kimliğini görmemelidir.

### V56-M04 — Kişi bazında yalnız dürtmeyi susturma

- **Sınıf:** Yeni ürün isteği
- **Problem:** Kullanıcı bir grup üyesini tamamen engellemek istemiyor; yalnızca
  o kişiden dürtme almak istemiyor.
- **İstenen:** Grup üyesi menüsünde **“Bu kişiden dürtme alma”** seçeneği.
- **Sınır:** Bu ayar engelleme değildir; sohbeti, kamp ateşini, sıralamayı,
  üyeliği veya moderasyon yetkisini değiştirmez.
- **Beklenen:** Susturulan kişi dürtmeyi göndermeye çalıştığında alıcıya bildirim
  gitmez; diğer etkileşimler normal sürer. Ayar geri alınabilir olmalıdır.

### V56-M05 — Güvenlik sistemi profesyonel ürün standardında ele alınmalı

- **Sınıf:** Kalıcı ürün ilkesi
- **Karar:** Uygulama öğrencilere fayda sağlamayı amaçladığı için taciz, spam,
  nefret söylemi ve kötüye kullanımı yalnız rapor butonu koyarak yönetmiş
  sayılmaz. İnceleme bağlamı, basamaklı yaptırım, denetim izi, yanlış rapora
  karşı koruma, geri alma/itiraz ve makul müdahale süresi birlikte tasarlanmalıdır.

---

## 6. Grup deneyimi

### V56-G01 — Gruptan çıkış gecikiyor ve kullanıcı tekrar tekrar basıyor

- **Sınıf:** Doğrudan gözlem · yüksek
- **Gözlenen:** “Gruptan çık” eylemi anında sonuç vermiyor. Kullanıcı birkaç kez
  basıyor; uygulamayı kapatıp açtıktan veya birkaç dakika sonra üyelik kalkmış
  görünüyor.
- **Beklenen:** İlk basıştan sonra düğme yeniden basılamaz hâle gelmeli, işlem
  durumu görünmeli ve başarıyla tamamlanınca kullanıcı anında grup dışına
  yönlendirilmelidir. Hata varsa üyelik sessizce değişmemeli ve yeniden deneme
  sunulmalıdır.
- **Veri kuralı:** Birden fazla basış birden fazla çıkış isteği veya tutarsız
  üyelik üretmemelidir.

### V56-G02 — Grup bilgileri altındaki davet kodu açılır alanı kaldırılmalı

- **Sınıf:** Ürün kararı
- **İstenen:** Gruplar sekmesinin en altındaki “Grup bilgileri” açılır alanı ve
  oradan gösterilen davet kodu kaldırılmalıdır.
- **Not:** Davet koduna gerçekten ihtiyaç duyulan yönetici/paylaşım akışında
  daha doğrudan ve kontrollü bir yer kullanılmalıdır; genel ekranın altında
  tekrarlanan alan olmamalıdır.

---

## 7. Kamp ateşi görsel geri bildirimi

### V56-C01 — Dört kişilik düzende isimler hayvanlarla çakışıyor

- **Sınıf:** Doğrudan gözlem
- **Gözlenen:** Dört kişilik yerleşimde özellikle üstteki hayvanların isimleri
  figürlerle veya diğer öğelerle çakışıyor.
- **İstenen:** Üst sıradaki isim/figür grubu biraz yukarı alınmalı; isimler
  hiçbir hayvanın üzerine binmemelidir.

### V56-C02 — Yalnız kamp ateşi biraz daha aşağı inmeli

- **Sınıf:** Görsel ürün isteği
- **İstenen:** Ateş varlığı birkaç piksel daha aşağı alınmalıdır.
- **Kesin sınır:** Bu hareket hayvanları veya bütün kompozisyonu aşağı taşımaz;
  yalnız kamp ateşi hareket eder.

### V56-C03 — Hayvan oturma düzeni daha dairesel olmalı

- **Sınıf:** Görsel ürün isteği
- **Gözlenen:** Dört kişilik düzen iki çiftin karşılıklı masada oturması gibi
  görünüyor.
- **İstenen:** Hayvanlar ateş çevresinde daha doğal bir halka/dairesel dağılım
  vermeli; karşılıklı iki çift izlenimi azalmalıdır.

### V56-C04 — Sekiz kişilik görünüm ayrıca doğrulanmalı

- **Sınıf:** Kabul borcu
- **Not:** Ürün sahibi sekiz kişilik düzeni bu turda kesin değerlendirmedi.
  Dört kişilik düzeltme sekiz kişiye körlemesine uygulanmamalıdır.

---

## 8. İstatistik tarih aralığı

### V56-I01 — Tarih hücreleri düzeldi, etkileşim hâlâ kafa karıştırıyor

- **Sınıf:** Doğrudan gözlem
- **Olumlu:** Gün numaraları artık okunuyor.
- **Problem:** Kullanıcı hangi ucu değiştirdiğini anlayamıyor. Örneğin 14–30
  aralığı 14–21 yapılmak istenirken 21’e basmak 21–30 sonucunu üretiyor; dokunma
  sürekli başlangıç tarihini değiştiriyor gibi algılanıyor.
- **Ürün kararı:** Aralık değişimi görünür uç tutamaçlarını **sürükleyerek**
  yapılmalıdır. Takvimde sıradan bir güne dokunmak seçili aralığı beklenmedik
  biçimde yeniden bağlamamalıdır.
- **Beklenen:** Başlangıç tutamacı yalnız başlangıcı, bitiş tutamacı yalnız
  bitişi değiştirir; uçlar kesişirse davranış açık ve tutarlı olur.

---

## 9. Ayarlar, dil ve hesap

### V56-A01 — “Versiyon ve Güncellemeler” ile “Hakkında” birleştirilmeli

- **Sınıf:** Ürün kararı
- **Gözlenen:** İki ayrı giriş aynı kavramın parçaları gibi duruyor ve gereksiz.
- **İstenen:** Tek bir **Hakkında ve Güncellemeler** alanında uygulama sürümü,
  güncelleme kontrolü, sürüm notları ve gerektiğinde açılan teknik tanı bilgisi
  birlikte sunulmalıdır.

### V56-A02 — İlk mağaza sürümünde yalnız Türkçe ve İngilizce

- **Sınıf:** Kesin kapsam kararı
- **İstenen:** Almanca ve Arapça dosyaları silinmeyecek ancak yayımlanan ürünün
  dil seçicisinden, desteklenen dil listesinden ve mağaza beyanından çıkarılacak.
- **Fallback:** Cihaz dili Türkçe değilse İngilizce açılmalıdır.
- **Yanlış yorumlanmaması için:** Bu karar çeviri dosyalarını repodan silmek
  değildir; dilleri ürün açısından pasif hâle getirmektir.

### V56-A03 — E-posta değiştirme güvenli biçimde eklenmeli

- **Sınıf:** Yeni ürün isteği
- **Beklenen profesyonel akış:**
  1. kullanıcı yakın zamanda yeniden kimliğini doğrular veya mevcut şifresini girer;
  2. yeni e-posta adresine doğrulama gönderilir;
  3. eski e-posta adresine güvenlik bildirimi gider;
  4. doğrulama tamamlanmadan hesap e-postası değişmiş sayılmaz.
- **Not:** Yalnız açık oturuma güvenmek veya yalnız yeni adresi yazıp kaydetmek
  yeterli güvenlik değildir.

---

## 10. Ders ve görev deneyimi

### V56-T01 — Seçilen ders kalıcı olmalı

- **Sınıf:** Kullanıcı isteği
- **Gözlenen:** Uygulama her açıldığında ders seçimi “Genel”e dönüyor.
- **İstenen:** Kullanıcı özel bir ders seçtiyse kendisi değiştirene kadar o ders
  seçili kalmalıdır.
- **Edge case:** Seçili ders silinirse güvenli biçimde “Genel”e dönülmeli ve
  kullanıcıya kısa bilgi verilmelidir.

### V56-T02 — Her N günde tekrarlanan görev

- **Sınıf:** Yeni ürün isteği
- **Örnek:** Fizik, Kimya, Biyoloji görevleri birer gün arayla başlar ve her biri
  üç günde bir tekrar görünür.
- **İstenen davranış:**
  - tekrar aralığı kullanıcı tarafından gün cinsinden seçilir;
  - tamamlanan bugünkü örnek aktif listeden kalkar;
  - bir sonraki örnek belirlenen döngü gününde görünür;
  - sabit üçlü düzen bozulmamalı; eski tamamlanmış örnekler yeniden açılmamalı;
  - geçmişte kaçırılan örnekler yığılıp kullanıcıyı boğmamalıdır.

### V56-T03 — Tekrarlanan görevler ayrı ve anlaşılır bölümde olmalı

- **Sınıf:** Bilgi mimarisi isteği
- **İstenen:** Günlük ve periyodik tekrarlanan görevler normal tek seferlik
  görevlerden görsel olarak ayrılmalıdır. Kullanıcı görevin ne zaman yeniden
  geleceğini görebilmelidir.

### V56-T04 — Görev satırının tamamı tamamlanabilir olmalı ve geri alma bulunmalı

- **Sınıf:** Kullanılabilirlik isteği
- **İstenen:** Yalnız soldaki küçük daire değil, görev metni/satırı da
  tamamlamayı tetikleyebilmelidir.
- **Koruma:** Yanlış dokunma için kısa süreli Geri Al eylemi ve tamamlananlar
  bölümünden yeniden açma bulunmalıdır.

---

## 11. Alt sekme üst boşluğu

### V56-N01 — Tekrarlanan büyük üst başlık alanları kaldırılmalı

- **Sınıf:** Ürün kararı
- **Gözlenen:** Araçlar, Gruplar, İstatistikler ve Profil sekmelerinde yalnız
  sekme adını tekrarlayan büyük üst alan ekran yüksekliğini gereksiz tüketiyor.
- **İstenen:** Alt navigasyon zaten bağlamı verdiği için tekrar eden başlıklar
  kaldırılmalı veya içerikle bütünleşen kompakt başlığa dönüştürülmelidir.
- **Eylem yerleşimi:**
  - Grup değiştir, içerik alanının kompakt üst eylemine taşınır.
  - Kartları düzenle, ana sayfa içeriğine yakın ve erişilebilir kalır.
  - Sistem durum çubuğu/güvenli alan kaldırılmaz.
- **Kabul:** İçeriğe ayrılan dikey alan artmalı; geri, erişilebilirlik ve büyük
  yazı davranışları bozulmamalıdır.

---

## 12. Android ana ekran widget kapsamı

### V56-W01 — İlk sürümde yalnız 1×1 Başlat/Durdur widget’ı yayınlanmalı

- **Sınıf:** Kesin kapsam kararı
- **Gözlenen:** Altı widget’tan yalnız 1×1 Başlat/Durdur widget’ı yayın kalitesinde.
- **İstenen:** Diğer beş widget ilk mağaza sürümünün widget seçicisinden çıkarılmalıdır.
- **Yanlış yorumlanmaması için:** Kodları ve varlıkları hemen silinmeyecek;
  gelecekte yeniden tasarlanmak üzere pasif tutulacaktır.
- **Güvenli geçiş:** Eski widget’ı ana ekranına koymuş kullanıcı güncellemede
  çökme veya sonsuz boş kutu görmemelidir.

---

## 13. Seri sistemi — kesin ürün tanımı

### V56-R01 — Seri yalnız hedef tamamlanınca ilerler

- **Sınıf:** Kesin ürün kararı
- **Yanlış davranış:** Uygulamayı yalnız açmak seri kazandırmaz.
- **Doğru davranış:** O günün bireysel veya grup hedefi tamamlandığında ilgili
  seri bir artar.

### V56-R02 — Bir günlük koruma/pause hakkı

- **Sınıf:** Yeni ürün mekanizması
- **İstenen semantik:**
  - kullanıcı hedefi tamamladığı gün canlı renkli alev görür;
  - yeni gün başlamış, hedef henüz tamamlanmamışsa soluk/gri alev görünür;
  - bir önceki gün kaçırılmış ama seri hâlâ kurtarılabilir durumdaysa alev
    üzerinde belirgin bir **koruma/“=”** işareti görünür;
  - kullanıcı bu kurtarma gününde hedefi tamamlarsa seri sıfırlanmaz ve yalnız
    tamamlanan gün sayısı kadar ilerler;
  - iki gün üst üste hedef tamamlanmazsa seri sıfırlanır.
- **Tekrarlanabilirlik:** Kullanıcı her seferinde araya en fazla bir boş gün
  koyarak bu korumadan tekrar yararlanabilir. Böylece bir gün çalışıp bir gün
  ara veren kullanıcının serisi, yalnız çalıştığı günler sayılarak devam eder.

### V56-R03 — Bireysel ve grup serileri karıştırılmamalı

- **Sınıf:** Görsel ve semantik ürün kararı
- **İstenen:** İki seri aynı temel alev metaforunu kullanabilir ancak renk,
  çevre çizgisi, küçük grup/kişi işareti veya benzeri net bir ayrımla hangi
  serinin gösterildiği anlaşılmalıdır.
- **Hesap kuralı:** Bireysel hedefi tamamlamak grup serisini, grup hedefini
  tamamlamak bireysel seriyi otomatik ilerletmez.

---

## 14. Rakip analizinden bu geri bildirimi güçlendiren dersler

| Kullanıcı bulgusu | Rakip yorumlarındaki karşılığı | Ürün sonucu |
|---|---|---|
| Hayalet/yanlış sayaç ve eşitleme | Süre kaybı veya sahte süre en ağır terk sebebi | Sayaç P0; kozmetik işlerden önce |
| Mesaj düşmüyor, rozet temizlenmiyor | Sohbet yüklenmiyor, okundu sayısı yanlış | Tek konuşma ve okundu gerçeği |
| Moderasyon yetersiz | Şikâyet çalışmıyor, engellenen yazmaya devam ediyor | Uçtan uca güvenlik sistemi |
| Görev tekrarları | Tekrarlanan görev/takvim bugları yoğun şikâyet alanı | Tekrar motoru testle korunmalı |
| Büyük üst boşluk/karmaşık ekran | Büyük UI regresyonları kullanıcı kaybettiriyor | Sadeleştirme, ölçülü geçiş |
| E-posta değiştirme | Hesap ve yıllarca biriken veriye erişim kaybı | Güvenli e-posta değişimi |
| Yalnız kaliteli widget’ı tutma | Boş veya güncellenmeyen widget kötü yorum getiriyor | Eksik yüzeyi yayınlamama |

## 15. v57’ye aktarılacak öncelik

### P0 — Yayın güvenini engelleyenler

1. Çoklu cihaz sayaç mimarisi ve hayalet koşular.
2. Geri bildirim konuşma gerçeği ve kalıcı okunmamış işaretleri.
3. Mesaj bazlı şikâyet ve kullanılabilir admin moderasyon kuyruğu.
4. Gruptan çıkışın güvenilir ve tek işlem hâline gelmesi.

### P1 — İlk mağaza sürümünü olgunlaştıranlar

1. Ders seçiminin kalıcılığı ve N-gün görev tekrarı.
2. Seri koruma modeli.
3. Tarih aralığı sürükleme davranışı.
4. Ayarlar birleştirmesi, yalnız TR+EN, tek kaliteli widget.
5. Kamp ateşi dört/sekiz kişilik yerleşim.
6. Sekme üst boşluklarının azaltılması.
7. Güvenli e-posta değiştirme.

## 16. Kabul yaklaşımı

Bu rapordaki hiçbir bulgu yalnız “kod yazıldı” diye kapanmaz. Her madde:

1. ölçülebilir ürün kabulüne;
2. otomatik regresyon testine;
3. uygun olduğunda iki gerçek Android cihaz denemesine;
4. hata/çevrimdışı/uygulama kapalı senaryosuna;
5. ürün sahibi kabulüne

bağlanmalıdır. v57 teknik planı bu raporu kaynak alacak, ancak kök nedenleri kod
ve çalışma zamanı kanıtı olmadan varsaymayacaktır.
