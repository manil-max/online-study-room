# Lansman öncesi tartışma notu

> **Bu bir plan DEĞİLDİR.** Sahip 2026-07-28'de "önce not al, önce konuşalım, ben diyene
> kadar planlamasına geçme" dedi. Burada yalnız (a) v54 cihaz testinden çıkan bulgular,
> (b) sahibin istediği revizeler, (c) benim mağaza için eklediklerim ve (d) cevabı sahipten
> gelmesi gereken sorular duruyor. WP numarası verilmedi, iş bölünmedi, sıra belirlenmedi.
>
> Bağlam: Google Play doğrulaması **alındı**, Microsoft Store doğrulaması **alındı**.
> Ana odak Play. Hedef: mümkün olan en kısa sürede yayın.

---

## A. v54 cihaz testinden çıkan bulgular

Numaralar sahibin test listesindeki başlıklarla aynı.

### A1. Aynalayan cihazdan Durdur, global koşuyu durdurmuyor — 🔴 KODDA DOĞRULANDI

Sahibin gözlemi: telefondan başlattı, tablet aynaladı, **tabletten** Durdur dedi →
tablet durdu, telefon devam etti. Üstelik tabletten **yeni bir oturum açabildi**.

Kök neden `app/lib/data/providers/study_providers.dart:1548`:

```dart
// WP-343 mirror yalnız başka cihazın sunucu-gerçeğini gösterir. Bu
// cihazda session/finalize üretmek ek XP ve çift oturum demektir.
if (state.isGlobalTimerMirror) {
  _finish();
  return;
}
```

`_finish()` yalnız **yerel** yüzeyleri kapatır: sunucuya stop komutu gitmez, global run
`running` kalır, origin cihaz haberdar olmaz. Ayrıca `_finish()` ayna bayrağını temizlediği
için cihaz artık "boşta" sayılır ve ikinci bir başlatmayı kabul eder.

Bu bir kaza değil, **yazılmamış bir yarım**: mimari belge bunu zaten tarif ediyor —
`docs/GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md §16.4` "Sunucuda global run
durur / Online cihazlar stop olur" diyor. Ayna cihazın Durdur'u o yola bağlanmamış.

Konuşulacak: ayna Durdur global mi olsun yoksa "Bu cihazda gizle" mi? İkisi ayrı düğme mi?
Ve ikinci oturum açılmasını client mı engellesin, sunucudaki tek-aktif invariant'ı mı
reddetsin (reddederse kullanıcıya ne denir)?

### A2. Kamp ateşi gece/gündüz — AÇIK, henüz test edilmedi

Sahip o saatlere gelmedi. Test edildi diye kapatılmayacak.

### A3. Kamp ateşi kompozisyon revizeleri — kırpma beğenildi, iki düzeltme

1. Kamp ateşinin kendisi **biraz aşağı** alınmalı.
2. Sağdaki ve soldaki hayvanlar birbirine çok yakın; **alttakinin ismi üsttekinin üstüne
   biniyor**. Aynı taraftaki alt/üst koltuk arasındaki dikey ayrım artmalı.

Bu kozmetik → `gorsel-is-once-onizleme-sonra-kod` kuralı geçerli: önce parametrik önizleme
karesi, sahip sayıyı seçer, sonra kod.

### A4. Yeni geri bildirim gelince admin'e bildirim gitmiyor

WP-374 yazışmayı düzeltti ama **tetikleyici yok**: kullanıcı bilet/mesaj gönderince
yöneticiye push düşmüyor, admin panele girip bakmadan haberi olmuyor.

### A5. Duyuru sinyali — sorun yok

### A6. Tanıtım turu revizeleri

- **Çakışma:** ana ekran turunda "kartları düzenle" adımında sağ üstteki **Skip yazısı ile
  edit butonu üst üste** geliyor. Aynı çakışma gruplar turundaki "grubu değiştir" adımında da var.
- **Çapasız adım çirkin:** "campfire, goal and ranking are here" gibi ekran tanıtan adımlar
  ekranın **tam ortasına** düşüyor; en üst şeridi karartma denemesi de garip görünüyor.
- **Sayaç yanıltıcı:** "1 of 2" → "2 of 2", sonra kamp ateşinde "1 of 1" diye yeniden başlıyor.
  Gruplar bölgesi **tek dizi** olmalı. Sahip: "of 3 olsun, hatta of 2 olsun — kamp ateşini
  tanıtmaya gerek yok."
- **Silinecek:** profil turu tamamen gereksiz ("her şey zaten açık, eklemek için eklenmiş").
- **Kırpılacak:** istatistiklerde today/week'in tarihi değiştirdiği zaten belli.
- **Metinler:** sahip açıklama metinlerini **kendisi yazacak**; ben yerleri hazırlayacağım.

### A7. Başarımlar ekranı — sorun yok

### A8. Widget/bildirimde 00:00:00 → 00:01 sıçraması — 🔴 KODDA DOĞRULANDI

Sahip: "00:00:00'a başlayınca 00:01'e dönüyor, bu çirkin; direkt 00:00 olsa daha iyi.
Saat kısmında 1:00:00 oluyor zaten, orada değişiklik gerekmiyor. **Yalnız widget ve
bildirimde**; uygulama içindeki sayaç HH:MM:SS kalsın."

Sebep biçim tutarsızlığı:

- Boştayken statik metin `"00:00:00"` yazılıyor —
  `StudyWidgetProviders.kt:95` ve `StudyTimerService.kt:471`.
- Koşarken devreye Android'in **`Chronometer`**'ı giriyor (`setChronometer`,
  `StudyWidgetProviders.kt:86`, `StudyTimerService.kt:445`). `Chronometer` bir saatin altında
  `MM:SS`, üstünde `H:MM:SS` basar.

Yani `00:00:00` → `00:01` sıçraması, üç parçalı boş metinden iki parçalı canlı biçime
geçiştir. Boş metin `"00:00"` olursa hem sıçrama biter hem saatli biçim kendiliğinden doğru
kalır. Uygulama içi sayaç bu koddan beslenmediği için etkilenmez.

---

## B. Sahibin istediği yeni işler

### B1. "Kartları düzenle" için ilk-giriş eğitimi
Ana ekranda kart düzenleme moduna **ilk kez** giren kullanıcıya güzel bir tanıtım.
Sonraki girişlerde çıkmaz.

### B2. Ayarlar'a Destek / SSS bölümü
Şu an yalnız "bize yaz" var. Sahip hazır soru-cevap istiyor: en çok kafa karıştıran şeyler
önceden yazılı olsun, kullanıcı sormadan cevabı bulsun. Yanına biraz da **yazılı bilgi**
(nasıl yapılır anlatımı) girecek.
Sahibin açıkça takıldığı örnek: **Android ana ekran widget'ı nasıl eklenir**, bunu metinle
nasıl anlatacağımızı bilmiyor.

### B3. Başarım açıklamaları
Bazı başarımlarda yeterli bilgi yok; nasıl kazanıldığı yazılmalı.

### B4. Ayarlar sırası yeniden düzenlensin
Sahibin istediği sıra: en üstte **Görünüm**, altında **Bildirimler**, "hesabımı yönet" türü
şeyler **daha aşağıda**, **Hakkında + Legal en altta**.

### B5. Kullanıcı engelleme yok, "engellenen kullanıcılar" ekranı var
Ekran mevcut ama **engelleme fiili yok**. Sahip: "bunu konuşmalıyız — nasıl ekleyelim,
ekleyince ne olacak? Sanırım mağazaya çıkabilmek için eklemiştik."
(Doğru tahmin — ayrıntı C1'de.)

🔴 **DÜZELTME (2026-07-28, planlama turunda koda bakıldı): bu madde yanlıştı.**
Yukarıdaki satırlar sahibin gözlemine dayanarak yazıldı, koda bakılmadan.
Engelleme **ve şikâyet ikisi de var ve uçtan uca kurulu**:

- `supabase/migrations/0038_ugc_moderation.sql` — `user_blocks`, `ugc_reports`
  tabloları; `block_user`, `unblock_user`, `report_ugc` RPC'leri.
- `app/lib/features/safety/` — `block_user_action.dart` (onaylı engelle),
  `blocked_users_screen.dart`, `report_sheet.dart`.
- Çağrı yerleri: `class_chat_card.dart:217,228` ve
  `social_profile_screen.dart:120,128`.
- Admin tarafı: `admin_reports_tab.dart`.

Sahibin bunları bulamamasının sebebi **keşfedilebilirlik**: engelle/şikâyet yalnız
sohbet ve sosyal profil menüsünden erişiliyor. Ayrıca mevcut davranış F2 kararına
**uymuyor** — kamp ateşi engelleneni tamamen siliyor (`campfire_scene.dart:111-116`),
oysa karar "kimliği gizler, sayıyı gizlemez" diyor; sıralamada "Engellenen kullanıcı"
satırı yok; dürtme engellemeyi hiç kontrol etmiyor.

➡️ Bu yüzden iş "sıfırdan engelleme yaz" değil, **WP-389 (F2'ye uydur ve görünür kıl)**
ve **WP-390 (şikâyeti tamamla)** oldu. Ders: sahibin gözlemi bir **belirti**dir,
teşhis değildir — koda bakmadan nota yazılmamalıydı.

### B6. Sürüm notları kullanıcıya göre yazılsın
Güncelleme bildirimiyle içeriye **migration** gibi teknik satırlar sızıyor. Kullanıcının
gördüğü metin tamamen kullanıcı odaklı olmalı; iç değişiklikler ayrı yerde kalmalı.

### B7. İstatistiklerde "değişim" düğmesi kaldırılsın
Tarih aralığı düğmelerinin en sağındaki değişim/delta düğmesi neredeyse tek bir şeyi
etkiliyor, varsayılanı zaten kapalı → tamamen kaldırılsın.

### B8. Özel tarih aralığında takvim uçlarını sürükleme
Custom seçilince takvim açılıyor; seçili iki uç kahverengi, aradaki günler mavi. Şu an tarih
yalnız sağ üstteki edit düğmesinden giriliyor. Sahip **uçlardaki işareti tutup sürükleyerek**
aralığı ayarlayabilmek istiyor.

---

## C. Benim eklediklerim — mağaza için gerçek engeller

Sahibin listesinde olmayan ama Play/Store incelemesinde **yayını durdurabilecek** maddeler.
Sıra, "bunu atlarsak yayın gecikir" ağırlığına göre.

### C1. Play UGC politikası — B5'i zorunlu kılan şey
Uygulamada kullanıcı üretimi içerik var (görünen ad, grup adı, grup içi görünürlük, dürtme).
Play bu durumda üçünü birden ister: **içerik/kullanıcı şikâyet etme**, **kullanıcı engelleme**,
ve moderasyon taahhüdü. B5 kozmetik bir eksik değil, **politika gereği**.
Konuşulacak: engelleyince ne oluyor — kamp ateşinde görünmez mi, sıralamadan düşer mi,
dürtemez mi, aynı gruptaysa ne olur, çift taraflı mı?

### C2. Foreground service beyanı
Sürekli çalışan bir foreground service kullanıyoruz. Play, FGS için ayrı bir **beyan formu +
kullanımı gösteren video** istiyor ve yanlış tür seçimi doğrudan ret sebebi. Hangi türü beyan
ettiğimiz (`specialUse` mi başka mı) yayından önce netleşmeli.

### C3. Hesap silme — uygulama içi **ve** web adresi
Hesap açılabilen her uygulamada Play, silme talebi için **dışarıdan erişilebilir bir URL**
istiyor. WP-276 uygulama içi tarafı ele almıştı; web tarafı ve Data Safety formundaki
karşılığı ayrı iş.

### C4. Gizlilik politikası + kullanım şartları, yayında bir adreste
Play listeleme formunda zorunlu alan. Türkiye'deki kullanıcılar için KVKK aydınlatma metni de
aynı yere girer.

### C5. Kapalı test şartı
Yeni geliştirici hesaplarında Play, production'dan önce **12 test kullanıcısı / 14 gün kapalı
test** isteyebiliyor. Hesabın bu şarta tabi olup olmadığı takvimi doğrudan belirler —
yayın tarihini buna göre konuşmalıyız.

### C6. Özel SMTP — bunu atlarsak lansman günü kayıt kırılır
Supabase ücretsiz katmanın yerleşik e-posta göndericisi saatte birkaç mesajla sınırlı.
Mağazadan gelen ilk kalabalıkta **kayıt/doğrulama e-postaları kuyruğa girip düşer**.
Masaüstündeki 6 haneli şifre sıfırlama kodunun çalışmama sebebi de aynı kısıt.
Bu bir "iyi olurdu" değil, **lansman ön koşulu**.

### C7. Ücretsiz katman sınırları
Gerçek kullanıcı yüküyle bağlantı/depolama sınırları ve projenin uykuya geçme davranışı
lansmanı riske atar. Yedek yok kararı zaten alınmıştı; burada tekrar sormuyorum, yalnız
kullanıcıların gerçek verisi girdiğinde riskin büyüdüğünü not düşüyorum.

### C8. Çökme/ANR raporlaması
Şu an cihazda ne çöktüğünü **göremiyoruz**; sahip tarif etmezse bilmiyoruz. Mağazada bu
körlük pahalı. Play Console'un vitals'ı bir şey verir ama sembolize edilmiş rapor için
ayrı bir araç gerekir.

### C9. İsim/grup adı süzgeci
Görünen ad ve grup adı herkese açık. Küfür/istismar süzgeci olmadan tek bir ekran görüntüsü
mağaza şikâyetine dönebilir.

### C10. Sıralama güvenilirliği
Liderlik tablosu var; cihaz saatiyle oynayan biri süre şişirebilir. Sunucu tarafı doğrulama
zaten mimari belgede (§16.5) tarif edilmiş ama sıralamaya bağlanmamış. Yayından önce mi
sonra mı, konuşulur.

### C11. Mağaza görselleri ve listeleme metni
İkon, öne çıkan görsel, telefon ekran görüntüleri, içerik derecelendirme anketi, hedef kitle
beyanı. **Tablet ekran görüntüsü** de isteniyor — tablet yerleşimi parked olduğu için buranın
nasıl geçileceğini konuşmalıyız.

### C12. Mağazada hangi diller "destekleniyor" denecek
AR/DE katalogları var ama cihazda kabul edilmedi. Mağazada dil beyan edilirse eksik çeviri
kötü yorum getirir. Önerim: ilk yayında **yalnız TR + EN** beyan etmek.

### C13. İzin hazırlığı (permission priming)
Bildirim izni ve **pil optimizasyonu muafiyeti** — özellikle Xiaomi/Samsung cihazlarda arka
plan sayacının en büyük düşmanı bu. Kullanıcı bunu kendi bulamaz; onboarding'de anlatılmalı.
Bu aynı zamanda B2'nin (SSS) en çok sorulacak maddesi.

### C14. Uygulama içi değerlendirme istemi
Play'in in-app review API'si. Birkaç başarılı oturumdan sonra bir kez sorulur. Erken
puan toplamanın en ucuz yolu.

---

## D. "Kullanıcı görüp de anlayamaz" listesi

Sahip sordu: *"sence bizim neleri anlatmamız lazım kullanıcılara, direkt görüp de
anlayamayacakları ne var?"* B2'deki SSS'nin iskeleti bu olabilir.

**Kimse kendi bulamaz — mutlaka anlatılmalı:**
1. **Ana ekran widget'ı var ve nasıl eklenir** (ana ekrana uzun bas → Widget'lar → Odak Kampı).
2. **Bildirim panelinden sayaç kontrol edilebilir** (durdur/devam et).
3. **Pil optimizasyonu kapatılmazsa** bazı telefonlar sayacı öldürür — nasıl kapatılır.
4. **Çoklu cihaz senkronu var**, ne yapar ve **ne yapmaz** (uyuyan cihaz otomatik başlamaz,
   yalnız kronometre, yalnız Android).
5. **Birincil grup ne işe yarar** — hangi grubun ilerlemene/başarımlarına sayıldığı.
6. **Dürtme** ne yapar, karşı tarafa bildirim gider mi.
7. **Seri (streak) kuralları** — gün ne zaman biter, neyle kırılır, saat dilimi.
8. **XP ve seviye** neyle kazanılır.
9. **Başarım koşulları** (B3 ile aynı iş).
10. **Grup üyeleri seni ne kadar görüyor** — adın, bugünkü süren, o anki durumun.

**Görünce anlaşılır, anlatmaya gerek yok:**
- Tema/görünüm ayarları, today/week tarih değiştirmesi (sahip zaten böyle dedi),
  profil ekranı (turu siliniyor).

**Kararsızım, sahibe sormalı:**
- Pomodoro / geri sayım / kronometre farkını anlatmak gerekir mi, yoksa denenince mi anlaşılır?
- Kart düzenleme (B1) turla mı anlatılsın, yoksa ilk girişte tek bir ipucu balonu mu yetsin?

---

## E. Cevabı sahipten gelmesi gereken sorular

1. **Ayna cihazda Durdur ne yapsın?** (A1) Global durdursun mu, yoksa "bu cihazda gizle" mi
   olsun; ikisi ayrı düğme mi?
2. **Engelleme ne yapsın?** (B5/C1) Engellenen kişi kamp ateşinde/sıralamada görünmez mi,
   dürtemez mi, aynı gruptaysa ne olur, çift taraflı mı?
3. **SSS nerede yaşasın?** (B2) Uygulamaya gömülü sabit metin mi (yeni sürüm gerekir), yoksa
   sunucudan gelsin mi (sürüm çıkmadan güncellenir)? Benim önerim: sunucudan, gömülü yedekle.

Ayrıca A3'te ne demek istediğini doğru anladığımdan emin olmam gerekiyor: aynı taraftaki
**alt ve üst hayvanın dikey arası** açılsın, böylece alttakinin ismi üsttekinin üstüne
binmesin — doğru mu?

---

## F. Sahip kararları — 2026-07-28

E bölümündeki üç soru cevaplandı. Karar metni budur; tartışma yeniden açılmaz.

### F1. Ayna cihazda Durdur → **global durdurur**
Sahip kararı. Ayrı "bu cihazda gizle" düğmesi yok.

Konuşmada eklenen iki koşul:
- Origin cihaz **neden durduğunu göstermeli** ("Diğer cihazda 21:14'te durduruldu").
  §16.4 bunu zaten öneriyor; olmazsa kullanıcı sayacın kendiliğinden düştüğünü sanar.
- Ayna cihazda Durdur **onay ister** ("Bu, diğer cihazdaki sayacı da durduracak"),
  çünkü yanlış dokunuş başka cihazdaki oturumu bitiriyor.

### F2. Engelleme → çift taraflı etkileşim kesme
Sahip kararı: engellenen kişiyle **hiçbir işlem iki yönde de** gerçekleşmez (dürtme dahil).

Tartışmada netleşen kural ve üç istisna:

- **Kural: engelleme kimliği gizler, sayıyı gizlemez.** Engellenen kişi kamp ateşinde
  isimsiz nötr siluet, sıralamada "Engellenen kullanıcı" satırı olarak kalır; tıklanamaz,
  profili açılmaz, dürtülemez. Gerekçe: grup toplamı ve sıralama sunucuda ortak hesaplanıyor;
  kişiyi tamamen silersek üye sayısı ve rakamlar cihazdan cihaza tutmaz.
- **İstisna 1 — moderasyon muaf.** Grup yöneticisinin görme/çıkarma yetkisi ve uygulama
  admin/destek hattı engellemeden etkilenmez. Aksi hâlde bir üye yöneticiyi engelleyerek
  atılmaktan kurtulur.
- **İstisna 2 — üyelik engellenmez.** Engelleme gruba girişi/üyeliği kesmez, yalnız doğrudan
  etkileşimi keser. Aksi hâlde biri istemediği kişileri sessizce gruplardan dışlayabilir.
- **Eksik yarı: şikâyet.** Play engelleme + şikâyet ikisini birden istiyor (C1). Engelleme
  "beni rahatsız etmesin", şikâyet "siz inceleyin" demek.

### F3. SSS → sunucudan beslenen, uygulama içi ekran
Sahip kararı: önerilen yol kabul. Sahibin sorusunun cevabı: **kullanıcı siteye gitmiyor**,
ekran uygulamanın içinde (duyurular gibi); "sunucudan" yalnız metnin veritabanından okunması
demek, amacı sürüm çıkarmadan cevap düzeltebilmek.

Üç ek şart:
- **Giriş yapmadan erişilebilir olmalı** ve giriş ekranında bağlantısı bulunmalı. En çok
  ihtiyaç duyulacak madde "giremiyorum"; giriş duvarının arkasında kalırsa tam gerektiği
  anda kapalı olur.
- **Gömülü yedek metin**: ağ yoksa boş ekran değil, uygulamayla gelen kopya.
- **TR + EN birlikte** (C12 ile tutarlı).

Sahip ayrıca: SSS'de cevabı olmayan soru için kullanıcı **soru sorabilsin**, gelen sorulardan
SSS büyütülsün. Açık kutu mağaza ölçeğinde spam çeker → **hız sınırı** olmadan açılmaz.

### F4. Tek admin kutusu — tartışmada çıkan asıl karar adayı
Üç ayrı ihtiyaç aynı yere düşüyor: geri bildirim (A4), SSS'de olmayan soru (F3),
kullanıcı şikâyeti (C1/F2). Üçünü ayrı sistem kurmak yerine **tek kutu + tür alanı**
(geri bildirim / soru / şikâyet), admin panelinde tek liste + filtre. A4'teki eksik bildirim
tetikleyicisi bir kez yazılır, üçü birden kullanır.

Üstüne döngü: soru gelir → admin cevaplar → cevabı **tek dokunuşla SSS'ye taşır**.
Sahibin "insanlar sordukça ekleriz" dediği şey elle kopyala-yapıştır olmaktan çıkar.

### F5. İlk açılış tanıtımı
Sahip: son adımda "detaylı bilgi için SSS" yönlendirmesi olsun. Ayrıca sahip tanıtımı
görmek için sil-yükle yapmak zorunda kalmamalı.

🔴 **Kontrol edildi — sahip haklı, gerçekten sil-yükle gerekiyor.** İki ayrı bayrak var ve
Ayarlar düğmesi yalnız birini siliyor:

- Ayarlar → "Tanıtım turlarını sıfırla" (`settings_screen.dart:271`) →
  `TourController.resetAll()` → `resetToursForUser` yalnız `kTourKeyPrefix` ile başlayan
  **ekran turu** anahtarlarını siler (`core/tour/tour_prefs.dart:37`).
- İlk açılış tanıtımı ayrı anahtarda: `onboarding.completed_v1.<userId>`
  (`features/onboarding/onboarding_prefs.dart:12`).

`OnboardingNotifier.reset()` **zaten yazılmış** ve yorumunda "Test / ayarlardan yeniden
göster" diyor (`onboarding_prefs.dart:63`) ama Ayarlar'da onu çağıran hiçbir yer yok —
yalnız testlerden erişiliyor. Yani düğmenin ilk açılış akışını da kapsaması küçük bir
bağlama işi; yeni mekanizma yazılmayacak.

---

## G. Grup moderasyonu ve admin erişimi — 2026-07-28 ikinci tur

Sahip F2'yi (engelleme) onayladı ve **şikâyeti de kapsama aldı**. Üstüne dört soru sordu.

### G1. PC'den admin erişimi → 🔴 **zaten var**
Sahip masaüstü admin uygulaması istedi ("sistem nasıl olur bilmiyorum").

Kodda doğrulandı: admin girişi yalnız `isAdmin` ile korunuyor
(`features/profile/settings_screen.dart:138`) ve `features/admin` altında **hiçbir platform
kontrolü yok** (`Platform.is*` / `kIsWeb` geçmiyor). Windows sürümü zaten çıkıyor, dolayısıyla
admin hesabıyla Windows'ta panel açılıyor.

Eksik olan **sistem değil, masaüstü yerleşimi**: geniş ekranda liste+detay yan yana, klavye
gezinmesi, taranabilir tablo. Uyarlama işi, yeni ürün değil.

Flutter web **önerilmiyor**: foreground service, ana ekran widget'ı, bildirim ve alarm
eklentilerinin hepsine web sahte karşılığı yazmak gerekir. Tek bir admin ekranı için bütün
uygulamayı web'de derlenir hâle getirmek en pahalı yol.

### G2. Gruptan atarken yasaklama → evet, iki ayrı eylem
Pro app deseni (Discord, Telegram "Remove and ban", Slack):
- **Çıkar (kick):** gider, davetle geri gelebilir.
- **Yasakla (ban):** gider ve hiçbir yolla geri gelemez.

İki şart:
- **Yasak listesi + kaldırma.** Öfkeyle verilen yasak ertesi gün geri alınmak istenir;
  listesi olmayan yasak sistemi destek yükü üretir.
- **Sunucuda uygulanır**, katılma RPC'sinde. İstemcide düğme gizlemek yetmez.

### G3. Davet kodu sıfırlama → evet, ama yasağın yerine geçmez
Gerekçe: sızan kod geri alınamaz; ekran görüntüsü olarak paylaşılan kodun tek çaresi
değiştirmek (Telegram "revoke link", Discord'un süreli/sayılı davetleri aynı ihtiyaç).

🔴 Karıştırılmamalı: **kod sıfırlama içerideki kimseyi atmaz**, yalnız yeni girişleri kapatır.
Yasak belirli kişiyi hedefler. Alternatif değil, tamamlayıcı.

### G4. Davet linki → zor değil, bir alan adı istiyor
Link = davet kodunun URL'ye sarılmışı. Gerekenler:
- **Alan adı** — zaten alınacak (C3 hesap silme sayfası, C4 gizlilik politikası, Play'in
  istediği destek adresi). Aynı alan adı davet linklerini de taşır, ek maliyet yok.
- **Android App Links doğrulaması** (`assetlinks.json`) — yarım günlük yapılandırma.
- Kurulu ise doğrudan gruba, değilse Play'e.

Tek çirkin yer sonuncusu: kurulum sonrası hangi gruba gelindiğini taşımak. Ücretsiz hazır
çözüm **Firebase Dynamic Links kapandı (2025 Ağustos)**; kalan seçenekler ücretli servis
(Branch/AppsFlyer) veya elle çözüm.
Öneri — elle ve basit: link bir web sayfası açsın, sayfada grup adı ve **kod açıkça yazsın**;
uygulama kuruluysa App Link doğrudan içeri alsın, değilse kişi kurulumdan sonra kodu girsin.

### G5. 🔴 Sahibin önerisine karşı görüş: yasak ile davet birbirine bağlanmasın
Sahip iki model önerdi: "yasaklanan yalnız admin davetiyle girebilsin" ya da "girmek için
admin'e onay isteği gitsin".

Karşı görüş: **koşullu yasak, yasak değildir.** "Yasakladım ama davet linkiyle yine
girebiliyor" hem admin'i şaşırtır hem çıkarma/yasaklama ayrımını anlamsızlaştırır — bulanık
bir üçüncü hâl doğar. Discord ve Telegram'da yasaklı kişi geçerli davetle bile giremez;
admin geri istiyorsa **yasağı kaldırır**. Tek düğme, tek anlam.

Onay isteği gerçek ve ayrı bir özellik (Telegram "yeni üyeleri onayla", Facebook grup
üyelik onayı) ama **yasakla ilgisi yok** — herkese açık gruba rastgele girişleri süzmekle
ilgili. Grup ayarında bağımsız anahtar olmalı: *"yeni üyeler onay ister"*. Yasaklı kişi bu
istekte bile bulunamaz.

Üç kavram temiz kalır: **çıkar** (geri gelebilir) · **yasakla** (gelemez, kaldırılana kadar) ·
**onay iste** (kapının ne kadar açık olduğu).

### G5-son. Sahip kararı — 2026-07-28
Sahip karşı görüşü kabul etti: **yasak koşulsuzdur ve yalnız grup yöneticisi koyar/kaldırır.**
Davet linki, onay akışı veya başka hiçbir yol yasağı delmez.

### A3-son. Sahip onayı — 2026-07-28
Okuma doğrulandı: **aynı taraftaki alt ve üst hayvanın dikey arası açılacak** (alttakinin
ismi üsttekinin üstüne binmesin), ayrıca **ateşin kendisi biraz aşağı** inecek.
Sayılar önizleme karesinden seçilecek (`gorsel-is-once-onizleme-sonra-kod`).

### G6. Lansman ayrımı
- **Şart:** şikâyet · yasak + yasak listesi · admin bildirimi (A4). Play'in moderasyon
  beklentisinin grup tarafındaki karşılığı.
- **Sonra olur:** davet linki · onay akışı · masaüstü admin yerleşimi. İlk sürümü bunlar için
  geciktirmeye değmez.

---

## H. Konuşulacak ne kaldı — 2026-07-28 envanteri

### H1. Yalnız sahibin karar verebileceği beş şey

1. **Play kapalı test şartı (C5).** Yeni geliştirici hesaplarında production'dan önce
   12 test kullanıcısı / 14 gün kapalı test istenebiliyor. Hesabın buna tabi olup olmadığı
   Play Console'dan görülür ve **yayın tarihini doğrudan belirler**. Sahip bakmalı.
2. **Yaş beyanı.** Çalışma uygulaması ilkokul/ortaokul yaşına da hitap ediyor. 13 altı beyan
   edilirse Play'in Families politikası devreye girer: veri toplama, reklam ve üçüncü taraf
   SDK kuralları sertleşir; görünen ad, grup içi görünürlük ve liderlik tablosu yeniden
   değerlendirilmek zorunda kalır. **Önerim: 13+ beyan etmek.**
3. **Alan adı.** Satın alınması gereken tek şey. C3 (hesap silme sayfası), C4 (gizlilik +
   şartlar), C6 (e-posta gönderimi için alan doğrulaması) ve G4 (davet linki) hepsi buna bağlı.
   Alınmadan bu dördü başlayamaz.
4. **Para modeli.** Ücretsiz mi, reklam var mı, ileride ücretli özellik olacak mı? Play
   listeleme formunda beyan ediliyor; sonradan değiştirmek listelemeyi güncellemeyi gerektirir.
   Hiç konuşulmadı.
5. **Metinleri kim yazacak.** Tur metinlerini sahip yazacak (A6). SSS içeriği (B2) ve başarım
   açıklamaları (B3) için **önerim: ben taslak yazayım, sahip düzeltsin** — sıfırdan yazmak
   sahibin zamanını en çok yiyen iş.

### H2. Karara bağladıklarım — itiraz gelmezse böyle yapılır

- **B6 sürüm notları:** kullanıcıya giden dosya tamamen kullanıcı dili olur, teknik günlük
  ayrı kalır; araya **sözleşme testi** konur ve kullanıcı metnine `migration`, `WP-`, `RPC`,
  `SQL` gibi kelimeler sızarsa CI kırmızı düşer. Bir daha elle gözetmeye gerek kalmaz.
- **A6 çapasız tur adımı:** ekran tanıtan adımlar ekran ortasına + karartılmış üst şerit
  yerine **o sekmenin alt bar ikonuna** çapalanır. Gerçek bir hedef, sahte şerit yok.
- **B1 kart düzenleme:** tam tur değil, ilk girişte **tek ipucu balonu**. Az müdahale, aynı iş.
- **B8 takvim uçları:** sürüklenebilir uçlar yapılabilir; yapılacak.
- **C12:** mağazada yalnız **TR + EN** beyan edilir.
- **C8 çökme raporlaması:** eklenir. Mağazada körlük pahalı.
- **C9 isim süzgeci:** görünen ad ve grup adı için sunucu tarafı süzgeç eklenir.
- **C14 uygulama içi puanlama istemi:** eklenir, birkaç başarılı oturumdan sonra bir kez.
- **C10 sıralama bütünlüğü:** yayından **sonra**, kötüye kullanım görülmedikçe.
- **G1 masaüstü admin yerleşimi:** yayından sonra.

### H1-son. Sahip cevapları — 2026-07-28
1. **Kapalı test:** 2 hafta sorun değil, takvim kabul.
2. **Yaş:** 13+ beyan edilecek. → Families politikası devre dışı; görünen ad, grup içi
   görünürlük ve liderlik tablosu bugünkü hâliyle kalabilir.
3. **Alan adı:** sahip konuyu bilmiyor, anlatıldı (H4). Satın alma sahibe ait.
4. **Para modeli:** **şimdilik tamamen ücretsiz.** İleride üyelik + reklam düşünülüyor ama
   bu turda kapsam dışı. → Play formunda "reklam yok, uygulama içi satın alma yok" beyan edilir.
5. **Metinler:** SSS ve başarım açıklamalarını **ben yazacağım** (sahip düzeltecek).
   Tur metinleri yine sahibe ait.

### H4. Alan adı — sahibe anlatılan özet
Alan adı site değil, yıllık kiralanan bir **adres**. Dört iş buna bağlı: gizlilik+şartlar
sayfası (C4), hesap silme sayfası (C3), **e-posta gönderimi** (C6), davet linkleri (G4).

**Ücretsiz seçenek kısmen var, ama tam işimize yarayan yerde yok:**
- C3/C4/G4 için ücretsiz altadres (GitHub Pages / Netlify / Vercel + geçerli HTTPS) **yeter**;
  Play kabul eder.
- **C6 için yetmez:** gönderim doğrulaması alan adının DNS kayıtlarına satır eklemeyi
  gerektirir; ücretsiz altadreste DNS sahibi sen değilsin. Gönderim servisleri de paylaşımlı
  ücretsiz altadresleri genelde doğrulamaz.

E-posta lansman ön koşulu olduğu için **bir alan adı alınacak**. Yıllık ~10–15 USD; barındırma
ücretsiz statik hostta kalır, ek gider yok. Sahip ismi alır ve DNS panelini açar; dört sayfayı
ve `assetlinks.json`'ı ben yazarım. Yan fayda: Play listeleme formunun istediği destek adresi.

### H5. 🔴 Play imzalama anahtarı — yeni çıkan, geri dönüşü zor karar
Mevcut kullanıcılarda GitHub'dan kurulmuş, sahibin keystore'uyla imzalı uygulama var.
Play'e ilk yüklemede iki yol var ve **karar o anda veriliyor**:

- Google yeni app signing key üretirse → Play sürümü farklı imzalı olur, mevcut kullanıcıların
  hiçbiri güncelleyemez, **silip yeniden kurmaları gerekir**. Oturum verisi sunucuda olduğu
  için kaybolmaz ama pratikte kullanıcıların çoğu kaybedilir.
- **Mevcut keystore Play'e app signing key olarak yüklenirse** → aynı imza korunur, GitHub'dan
  kurmuş kullanıcılar Play üzerinden sorunsuz güncellenir.

**SAHİP KARARI (2026-07-28) — Google anahtarı üretsin.** İlk öneri (kendi keystore'unu yükle)
geri alındı. Gerekçe:
- Mevcut stable kullanıcıları yalnız birkaç arkadaş; yeniden kurma maliyeti sıfıra yakın.
- Play'den indirmek zaten daha iyi: otomatik güncelleme, "bilinmeyen kaynak" izni yok,
  kullanıcı güveni.
- 🔴 Asıl kazanç: Play App Signing'de imzalama anahtarını **Google saklar**, geliştirici yalnız
  upload key kullanır ve onu kaybederse sıfırlatabilir. Kendi anahtarını kullanan biri
  keystore'u kaybederse uygulamayı **bir daha asla güncelleyemez**. Tek kişilik ekip için bu
  sigorta, yerinde güncelleme kolaylığından değerli.

İki pratik sonuç:
- Arkadaşlar Play'den kurmadan önce **mevcut uygulamayı silmeli** (imza farklı, üstüne
  kurulmaz). Oturum ve XP sunucuda, kaybolmaz; yalnız cihazdaki yerel bayraklar sıfırlanır.
- Bundan sonra **Play = stable, GitHub = yalnız beta**. Beta ayrı paket kimliğiyle
  (`.beta` suffix) kurulduğu için Play sürümüyle yan yana durabilir. Stable'ı iki kanaldan
  dağıtmak kullanıcıyı sürekli imza duvarına tosllatır.

İlgili hatırlatma: release keystore yine de kalıcıdır (beta kanalı onu kullanmaya devam eder),
asla yeniden üretilmez.

### H6. Alan adı — nereden alınacak (2026-07-28 araştırması)
Bilinmesi gereken tek numara: **reklam edilen fiyat ilk yıl, önemli olan yenileme fiyatı.**

- **Porkbun — önerilen.** `.com` kayıt ve yenileme aynı, ~11 USD/yıl, sürpriz yok.
- **Cloudflare Registrar** en ucuzu (~9.77 USD, maliyetine satıyor) **ama sıfırdan kayıt
  yapmıyor**; başka yerden alıp transfer etmek gerekir. Yılda 1–2 USD için uğraşmaya değmez.
- **Namecheap**: ilk yıl ~9.58, yenileme ~13.98 — klasik tuzak.

Uyarılar:
- 🔴 **`.com` alınacak.** Ucuz uzantılar (`.xyz`, `.online`) spam filtrelerinde ve e-posta
  sağlayıcılarında daha şüpheli muamele görür; ana kullanımımız **e-posta göndermek** (C6)
  olduğu için bu doğrudan kayıt postalarını spam'e düşürür.
- `.com.tr` alınmayacak — evrak/şart gerektiriyor.
- **WHOIS gizliliği açılacak** (genelde ücretsiz). Yanında satılan hosting/e-posta paketleri
  alınmayacak, gerekmiyor.

Satın alma sahibe ait. İsim adayları belirlenince müsaitlik kontrolü bana.

### H7. Sıra notu
Sahip: **Play'in istediği foreground service tanıtım videosu sona kalsın.** Sahip şu an başka
özellikler için tarama yapıyor.

### H8. Sıralama kararı — 2026-07-28
Sahip: **"uygulamayı yayınlamadan önce sorunları çözelim."**

Yani A bölümündeki cihaz testi bulguları (A1 ayna-durdurma, A3 kamp ateşi, A4 admin bildirimi,
A6 tur, A8 sayaç biçimi) mağaza yayınından **önce** kapanır. G6'daki "şart / sonra olur"
ayrımı bunun üstüne biner; G6'da "sonra olur" denenler (davet linki, onay akışı, masaüstü
admin yerleşimi) yine yayın sonrasına kalır.

Sahibe ait, bekleyen: **alan adı ismi seçimi** (H6) — sahip düşünüyor, aday belirlenince
müsaitlik kontrolü bana.

---

## Durum — 2026-07-28 sonu

Tartışma kapandı. Bu belgede karara bağlanmamış madde kalmadı; açık olan tek şey sahibin
seçeceği alan adı ismi.

✅ **Planlama başladı (2026-07-28).** Sahip emri: *"bu dediklerin ve bizim
konuştuklarımızı planlayalım, hepsini WP'ler halinde yaz."* Bu belgedeki A/B/C/D/F/G/H
maddeleri ve `docs/RAKIPANALIZI-DEGERLENDIRME.md`'den alınacaklar birlikte
`progress.md` → **PLAN 3 — LANSMAN TURU** altında **WP-379…WP-411** olarak kartlara
bölündü. Artık tek güncel kaynak o plandır; bu belge **karar kaydı** olarak kalır.

**Sahipte duran işler:** alan adını al (Porkbun / `.com` / WHOIS gizli) · Play Console'da
uygulamayı oluştururken Google'ın imzalama anahtarını üretmesine izin ver · foreground service
tanıtım videosu (sona bırakıldı) · tur metinleri.

**Bende duran işler:** SSS taslağı · başarım açıklamaları · dört web sayfası
(gizlilik, şartlar, hesap silme, destek) · `assetlinks.json` · ve A/B/C bölümlerindeki kod işi.

**İyi haber — kodda doğrulandı:**
- `play` flavor zaten var ve uygulama içi GitHub güncelleyicisini kapatıyor
  (`android/app/build.gradle.kts:159`, WP-128). Play "kendi dışında güncelleme" yasağını
  ihlal etmiyoruz.
- **C2 cevaplandı:** foreground service türü zaten `dataSync|specialUse` olarak beyan edilmiş
  (`AndroidManifest.xml:95`), gerekçesi manifest yorumunda yazılı (Android 15'te `dataSync`
  24 saatte 6 saatle sınırlı; 8 saatlik sayaç sözleşmesi `specialUse` gerektiriyor).
  Sahibe kalan yalnız Play'in istediği tanıtım videosu.

**Hedef API kontrolü — yapıldı, sorun yok:** `targetSdk`/`compileSdk` Flutter varsayılanından
geliyor (`android/app/build.gradle.kts:118,133`) ve o varsayılan **36** (Flutter SDK
`FlutterExtension.kt:23,34`). Play'in yeni uygulamalar için istediği alt sınırın üzerinde.

### H3. Hiç konuşulmamış, benim de bilgi toplamam gereken

- **C2 foreground service beyanı:** manifest'te hangi türü beyan ettiğimize bakıp sahibe
  söyleyeceğim; Play'in istediği tanıtım videosunu sahip çekecek.
- **C7 Supabase kapasitesi:** gerçek kullanıcı yüküyle ücretsiz katmanın sınırları.
- **C11 mağaza görselleri:** ikon, öne çıkan görsel, ekran görüntüleri, listeleme metni —
  kimin ürettiği belirsiz. Ayrıca **tablet ekran görüntüsü** isteniyor ama tablet yerleşimi
  parked (A/B dışı, sahip kararıyla ertelendi).
