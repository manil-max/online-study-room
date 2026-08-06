# v58 Ürün Sahibi Geri Bildirim Raporu

> **Tarih:** 6 Ağustos 2026
> **Kaynak:** v58 stable yayınının ardından ürün sahibinin cihaz izlenimleri
> **Amaç:** Gözlemi kaybetmeden, belirti ile teşhisi karıştırmadan kaydetmek
> **Durum:** 🟢 **HAM KAYIT TAMAM (11 madde + 1 sahip düzeltmesi).** Bölüm 3 sahibin sözleridir;
> kök neden veya çözüm iddiası içermez. Kök neden çalışması 4. bölümde,
> iş paketleri `progress.md`'dedir.

## 1. Kapsam

Bu rapor `docs/V56-SAHIP-GERI-BILDIRIM-RAPORU.md` ve
`docs/V57-SAHIP-GERI-BILDIRIM-RAPORU.md` ile aynı sözleşmeyi izler: önce sahibin
söylediği aynen yazılır, sonra normalize edilmiş belirti kaydı gelir. Sahibin
cümlesi ile ajanın yorumu **hiçbir yerde birbirine karışmaz**.

### 1.1 Bu turun kendine özgü zemini

- **v58 stable 2026-08-01 23:32'de yayınlandı** (aday `3ede412`, release `9365895`,
  tag `v58`, production migration head `0119`).
- 🔴 **v58'in fiziksel cihaz kabulü hiç yapılmadı.** Sahip açık emirle
  ("kod bittiyse yayına çıkar, sorumluluk bende") iki-cihaz/OEM kabulünü yayın
  sonrasına bıraktı. Yani bu rapordaki maddeler, v58'de *düzeltildiği iddia
  edilen* ama cihazda hiç doğrulanmamış işlerin ilk gerçek sınavıdır.
- v58 içeriğinin büyük kısmı v57 geri bildiriminin cevabıdır: WP-477 (V57-N01) ·
  479 (N02) · 480 (N03) · 481 (N04-N05) · 482 (N06) · 483 (N07) · 484 (N08) ·
  485 (N09-N10) · 487 (N11) · 488 (N12).
- **Önceden kayda geçmiş ilk şüphe listesi:** WP-482 sayaç/widget çoklu cihaz
  senkronu (migration `0119` lease recovery grace) ve `0117` yönetici mesajı
  realtime + push zinciri.

### 1.2 Her madde için sorulacak ayırt edici soru

Bir belirti v57'de de vardıysa iki ihtimal ayrılır ve **rapor bunu iddia etmez,
yalnız işaretler**:

- **(a) Düzeltme hiç ulaşmadı** — cihazdaki sürüm gerçekten v58 mi, kontrol edilir.
- **(b) Düzeltme ulaştı ama yetmedi/yanlıştı** — kod var, davranış hâlâ yanlış.

## 2. Kanıt sınıfları

| Sınıf | Anlamı |
|---|---|
| **Doğrudan gözlem** | Sahip cihazda açıkça gördü |
| **Şüpheli belirti** | Güçlü izlenim var; henüz kesin değil |
| **Ürün isteği** | Mevcut davranış hata olmasa bile istenen yeni davranış |
| **Ürün kararı** | Sahibin bağlayıcı kararı; tartışmaya açık değil |
| **Regresyon şüphesi** | v57'de yoktu / düzeltilmişti, v58'de görünüyor |

---

## 3. Ham kayıt (sahibin kendi ifadesi)

> Aşağıdaki dokuz madde sahibin yazdığı metnin **anlamı korunarak** alınmış
> kaydıdır. Yorum, teşhis ve çözüm önerisi bu bölüme girmez.

### V58-N01 — Yeniden başlatma sonrası iki gün süren yavaşlık ve grup ekranı yenilenmesi

"Öncelikle telefonu açıp kapadıktan sonra 2 gün boyunca sürekli her uygulamayı
açınca 7-8 sn sürdü açılması ve gruplar kısmında da sürekli ekran yenilenip
geliyordu ama şu an geçti. Neden oldu bilmiyorum, neden 2 gün sonra geçti yine
bilmiyorum."

### V58-N02 — Açılışta yanlış boş durum: "create group" yazısı ve kaybolan taç

"Şu an sadece currently studying kısmı falan da 'create group' filan yazısı
çıkıyor, sonra düzeltiyor. Taç gidiyor listede, geri geliyor."

### V58-N03 — Seri işlevi çalışmıyor

"Seri işlevi çalışmıyor dendi."

*(Ekran görüntüsü 3: sayaç kartının sol üstünde gri alev, `0`, "Henüz seri yok",
"Kişisel"; aynı ekranda bugün 1sa 42dk 50sn ve günlük hedef %57.)*

### V58-N04 — Arayüzde sorunlar (ekran görüntüleri)

"Bir de UI'da sorunlar var, fotolara bak."

Sahibin eklediği üç ekran görüntüsünde görünenler (yalnız **görünen** kayıt,
teşhis değil):

1. **Ekran görüntüsü 1 — ana ekran.** Başlık İngilizce ("Currently studying")
   ama sağdaki rozet Türkçe: "2 aktif". Kartın ikinci üye satırı ("Minik Kuş")
   alttan kesik. "Trend" kartında sol eksenin en üst iki etiketi üst üste binmiş
   ("12" ve "10h" iç içe). Sayaç kartının altında geniş boş alan var.
2. **Ekran görüntüsü 2 — grup ekranı, Members listesi.** Eylem simgesi olan
   üyelerin adı tek harfe düşmüş: "B...", "S...", "A...". Yalnız eylem simgesi
   **olmayan** satır (M.Anıl · Last Second Savior · Admin) adı tam gösteriyor.
3. **Ekran görüntüsü 3 — sayaç kartı üstü.** Seri rozeti ("0 · Henüz seri yok ·
   Kişisel") ile altındaki "Bugün" yazısı üst üste biniyor.

### V58-N05 — Geri sayım çökmeye sebep oluyor, pomodoro uygulamayı arkaya atıyor

"Geri sayım direkt crash'e sebep oluyor. Zorla durdurdum falan, öyle oldu; ancak
uygulama hata veriyor. Pomodoroda da aynı şekilde; zaten start'a basar basmaz
alta atıyor."

### V58-N06 — Grup başarımları çift sayıyor (Leader Wolf)

"Leader Wolf gibi grup başarımlarında sorun var. Çift saydı mesela, tek grup
seçili olmasına rağmen, bu hafta."

### V58-N07 — Grupta aktif çalışma bazen görünmüyor

"Bazen grupta aktif çalışmada bug oluyor, gözükmüyor."

### V58-N08 — Diğer cihazda açık kalan koşu saat biriktiriyor, Durdur toplamı değiştirmiyor

"Mesela telefondan açıp kapatıyoruz ama tablette de aynı hesap açık; orada açık
mı kalıyor anlamadım. Sonrasında telefondan girince 4-5 saat süre birikmiş
oluyor. Stop diyorum, toplam sürede değişmiyor. İşleyişte olmayan bir bug."

### V58-N08-EK — Sahibin düzeltmesi: süre kaybolmuyor, hayalet koşu var

*(2026-08-06, ilk kaydın ardından sahip düzeltti. Ajanın "kaybolan 4-5 saat"
okuması **yanlıştı**; aşağısı sahibin kendi ifadesidir.)*

"Kaybolan 4-5 saat yazmışsın ama aslında orada kaybolmuyor. Zaten kendi kendine
diğer cihazdan kronometre başlatıyor, ya da başlatılmış gibi oluyor, bilmiyorum.
Ben normalde kendi telefonumdan kapatıp açıyorum. Sonrasında, atıyorum, uyudum;
sabah bir kalkıyorum, telefonu bir açıyorum, 10 saat kronometre olmuş telefondan.
Ama telefondan durdur'a basıyorum, diyor ki 'diğer cihazdaki kronometreyi
durduracaksınız' diye bir uyarı veriyor, evet diyorum ama hiçbir şey olmuyor.
Yani burada aslında kayıp değil bu zaman; yani çalıştığım zaman kaybolmuyor."

**Bu kaydın üç ayrı iddiası var:**

1. Gerçek çalışma süresi **kaybolmuyor** — sahip kendi telefonunda normal
   başlat/durdur yapıyor ve o süre yazılıyor.
2. Diğer cihazda **kendiliğinden** bir kronometre çalışıyor ya da çalışıyor gibi
   görünüyor; sabah telefonda **10 saatlik** bir koşu beliriyor.
3. Telefondan Durdur → "diğer cihazdaki kronometre durdurulacak" onayı → evet →
   **hiçbir şey olmuyor**; hata mesajı da bildirilmedi.

### V58-N09 — Bildirim sayacı ve ayna cihaz senkronunda kalıntı sorunlar

"Bildirim sayaç + ayna cihazda senkron problemleri, daha az da olsa, var hâlâ."

### V58-N10 — Ana ekranın en üstü durum çubuğuyla çakışıyor, seri rozeti fazla büyük

"Bak fotoya, hem aşırı yukarıda, bildirim panelinde işaretlerle çakışıyor. Bir de
streak kısmı bu kadar büyük olmasına gerek yok; 'Personal' yazısı ve diğer 'no
streak yet' falan gerek yok, dümdüz alev yanında sayı yeter zaten."

*(Ekran görüntüsü 4: kart durum çubuğunun hemen altında başlıyor; seri rozeti saat
ve bildirim simgeleriyle aynı hizaya kadar çıkmış, altındaki "Today" yazısının
üstüne biniyor.)*

### V58-N11 — Listelerde satırlar aşağı kayıyor

"Listelerde bu dikey sıkışıklığı çözmek için ne yaptın bilmiyorum ama 'currently
studying' kısmında falan aşağı kayıyorlar."

---

## 4. Normalize edilmiş belirti kaydı

> Bu bölüm ham kaydı sınıflandırır. **Kök neden analizi bu raporda değil,
> `docs/V58-TEKNIK-ANALIZ-RAPORU.md` dosyasındadır**; iş paketleri henüz
> kesilmedi.

| Kod | Belirti | Sınıf | v57'de var mıydı | Öncelik |
|---|---|---|---|---|
| V58-N01 | Reboot sonrası 2 gün boyunca ~7-8 sn açılış + grup ekranı sürekli yenileniyor; kendiliğinden geçti | Doğrudan gözlem (artık tekrar etmiyor) | Bildirilmedi | Yüksek |
| V58-N02 | Veri yüklenirken "grup yok / create group" ve tacsız avatar gösteriliyor, sonra düzeliyor | Doğrudan gözlem | Bildirilmedi | Yüksek |
| V58-N03 | Seri her zaman `0` / "Henüz seri yok" | Doğrudan gözlem | V57-N04'ün devamı (rozet artık görünüyor, **değer** işlemiyor) | Kritik |
| V58-N04 | Beş ayrı yerleşim/dil kusuru (bkz. bölüm 3) | Doğrudan gözlem | V57-N01 (dil) ve V57-N11 (üye satırı) ile aynı aile | Yüksek |
| V58-N05 | Geri sayım ve pomodoro çökme/uygulamanın arkaya atılması | Doğrudan gözlem | Bildirilmedi | **Kritik** |
| V58-N06 | `alpha_wolf_weekly` tek haftada 2 sayıyor | Doğrudan gözlem | Bildirilmedi | Orta |
| V58-N07 | Grup yüzeyinde aktif çalışma bazen görünmüyor | Şüpheli belirti | V56/V57'de benzer kayıt var | Orta |
| V58-N08 | Diğer cihazda hayalet koşu birikiyor (10 sa); aynadan Durdur **etkisiz** | Doğrudan gözlem | V57-N06'nın komşusu | **Kritik** |
| V58-N08-EK | 🔴 Sahip düzeltmesi: **gerçek çalışma süresi kaybolmuyor**; sorun sahte/hayalet koşu ve işlemeyen Durdur | Doğrudan gözlem (ajan okumasını düzeltir) | — | **Kritik** |
| V58-N09 | Bildirim sayacı + ayna senkronunda kalıntı sapma | Şüpheli belirti | V57-N06 kısmen | Orta |
| V58-N10 | Ana ekran üst güvenli alanı taşımıyor; seri rozeti gereğinden büyük | Doğrudan gözlem + **ürün kararı** | **V57-N12'nin (üst şerit kaldırıldı) yan etkisi** | Yüksek |
| V58-N11 | Liste satırları aşağı kayıyor / sığmıyor | Doğrudan gözlem | V57-N11 ailesinin devamı | Orta |

### 4.1 Bu turda sahibin bağlayıcı kararları

1. **Grup başarımı yalnız SEÇİLİ gruptan sayılır.** "Hangi grup seçili ise ondan
   sayılsın." Yani `alpha_wolf_weekly` gibi grup metrikleri kullanıcının tüm
   gruplarını toplamaz; aktif/seçili grubun değeri gösterilir.
2. **Seri rozetinde hiç yazı olmayacak:** yalnız **alev + sayı**. Durum metni
   ("Henüz seri yok / No streak yet") ve kapsam etiketi ("Kişisel"/"Personal")
   birlikte kaldırılacak. Sahibin gerekçesi: *"grup kısmında grup streak yazıyor,
   oradan anlaşılır zaten"* — kapsamı rozet değil, **bulunduğu bağlam** söyler.
3. **Seri davranışı V57'de kararlaştırıldığı gibidir; değişmedi.** Kanonik metin
   `docs/V57-SAHIP-GERI-BILDIRIM-RAPORU.md` V57-N04/N05'tir:
   - **Durum 1** — dün ve önceki gün yapılmamış, seri sıfırlanmış: **gri soluk
     alev + `0`**.
   - **Durum 2** — dün yapılmamış ama ondan önceki gün yapılmış (duraklatma):
     **pause işareti**. Bugün de yapılmazsa seri `0` olur; yapılırsa Durum 3'e
     geçer. **Koruma hakkı sınırsızdır.**
   - **Durum 3** — o günün hedefine ulaşılmış: **renkli/canlı alev**.
   - Aynı model **grup hedefi** için de geçerlidir.

V57'nin diğer kararları (ünvan seçicinin buton yanında açılması, ana ekranda üst
şerit olmaması) yürürlüktedir ve **değişmemiştir**.

## 5. Bu rapor ne değildir


- Kök neden iddiası değildir (bölüm 3 için).
- Kapsam kararı değildir; WP kesimi `progress.md`'de yapılır.
- Cihaz kabulü değildir; her düzeltmenin kendi kabul kanıtı olur.
- v58'in doğrulama borcunun kapanışı değildir; bu rapor o borcun ta kendisidir.
