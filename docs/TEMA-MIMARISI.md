# Tema Stüdyosu & Görünüm Motoru Mimarisi (Faz 0)

> Bu doküman, uygulamanın statik 2-3 renkten kurtulup, tam kapsamlı bir görünüm motoruna (Theme Engine) geçişinin teknik altyapısını ve 12 hazır temanın tasarım detaylarını içerir.

## 1. Mimari Yaklaşım (Flutter ThemeExtension)

Uygulamanın her köşesinde rastgele kullanılan `Colors.grey`, `Colors.blue` gibi sabit renkler tamamen silinecek. Bunun yerine Flutter'ın **ThemeExtension** yapısı kullanılarak 5 katmanlı bir sistem kurulacak:

1. **Renk Katmanı (`AppColors`):** `surface1` (kartlar), `surface2` (modallar), `primary`, `accent`, `textPrimary`, `textSecondary`, `border`, `success`, `error`.
2. **Tipografi Katmanı (`AppTypography`):** Saat/kronometre için dev ekran fontları (örn: monospace), normal başlık ve gövde fontları.
3. **Şekil ve Derinlik (`AppShapes` & `AppShadows`):** Kartların köşe radyusları (keskin vs yumuşak), gölge yoğunluğu, cam efekti (glassmorphism) bulanıklık değerleri.
4. **Atmosfer Katmanı (`AppAtmosphere`):** Arka plan degrade (gradient) açıları, kamp ateşi ışıması (glow), parçacık efektleri.
5. **Animasyon Katmanı (`AppMotion`):** Geçiş süreleri, yay (spring) efektleri. (Rahatsız olanlar için Reduce Motion desteği).

Bu token'lar Supabase'de JSON formatında `user_preferences` tablosuna kaydedilecek. Kullanıcı cihaz değiştirdiğinde teması aynen yüklenecek.

---

## 2. Hazır 12 Sanat Yönü (Theme Presets)

Kullanıcılara ilk etapta sunulacak, her biri tamamen farklı bir "uygulama hissi" veren hazır sanat yönleri (İlk 5'inin detayları belirlendi, diğerleri tasarlanacak):

### 1. Campfire Night (Odak Kampı Klasiği)
- **Konsept:** Gece ormanda yanan ateşin etrafı.
- **Zemin:** Çok koyu lacivert/siyah (Gece gökyüzü).
- **Vurgu:** Sıcak turuncu, amber ve kor kırmızı (Ateş ışığı).
- **Atmosfer:** Ekranda hafif bir turuncu "glow" (ışıma) ve yüksek kontrastlı kalın fontlar.

### 2. Deep AMOLED (Maksimum Pil Tasarrufu)
- **Konsept:** Sıfır ışık, tam odaklanma.
- **Zemin:** Saf Siyah (`#000000`). Tüm pikseller kapalı.
- **Vurgu:** Tercihe göre Neon Yeşil, Elektrik Mavisi veya Matrix Yeşili.
- **Atmosfer:** Gölgeler veya blur yok, tamamen düz (flat) ve keskin köşeli hatlar. İnce fontlar.

### 3. Nordic Snow (Ferah ve Aydınlık)
- **Konsept:** İskandinav minimalizmi, karlı bir sabah.
- **Zemin:** Temiz beyaz ve çok açık buz grisi.
- **Vurgu:** Soğuk mavi ve nane yeşili.
- **Atmosfer:** Yumuşak gölgeler, bolca beyaz alan (margin), çok yuvarlak hatlı kartlar (iOS tarzı).

### 4. Ocean Glass (Cam ve Su)
- **Konsept:** Denizaltı derinliği ve modern arayüz (Glassmorphism).
- **Zemin:** Koyu okyanus mavisi (`#0A192F`).
- **Vurgu:** Su yeşili, camgöbeği (Cyan).
- **Atmosfer:** Kartların arka planı yarı saydam ve bulanık (Blur). Uygulama katman katman camdan yapılmış gibi hissettirir.

### 5. Coffee Library (Sıcak ve Loş)
- **Konsept:** Eski bir kütüphanede veya kahvecide çalışmak.
- **Zemin:** Koyu sepya, ahşap kahvesi ve krem.
- **Vurgu:** Bordo, koyu altın sarısı.
- **Atmosfer:** Sarımtırak, göz yormayan, okuma modunu (Night Shift/True Tone) andıran kağıt/ahşap dokusu. Serif font destekli.

### 6. Retro Terminal (Odaklanmış Kodlayıcı)
- **Konsept:** Eski bilgisayar ekranları, hacker hissiyatı (Matrix).
- **Zemin:** Zift Siyahı (`#0C0C0C`).
- **Vurgu:** Fosforlu Terminal Yeşili (`#00FF41`).
- **Atmosfer:** Klasik monospace (daktilo) fontları. Sıfır köşe radyusu (tamamen köşeli keskin kartlar), gölge yerine düz yeşil ince çerçeveler (borders).

### 7. Neon Focus (Cyberpunk & Synthwave)
- **Konsept:** 80'ler retro-fütürizm, neon ışıklar.
- **Zemin:** Çok koyu mor ve lacivert (`#0D0221`).
- **Vurgu:** Sıcak pembe (`#FF007F`) ve parlak camgöbeği (`#00F0FF`).
- **Atmosfer:** Butonların ve sayaçların etrafında yoğun neon "glow" (ışıma) efektleri. Gradient (degrade) geçişli arka planlar.

### 8. Forest Study (Doğa ve Dinginlik)
- **Konsept:** Orman içinde huzurlu bir kabin.
- **Zemin:** Koyu çam yeşili (`#122315`) ve yosun tonları.
- **Vurgu:** Ahşap kahvesi (`#8B5A2B`) ve yumuşak sarı (güneş ışığı).
- **Atmosfer:** Çok yumuşak, göz yormayan pastel tonlar. Köşeleri yuvarlatılmış yaprak formuna yakın kart tasarımları. 

### 9. Paper & Ink (E-Okuyucu Minimalizmi)
- **Konsept:** Kindle veya gerçek bir kitap sayfası. En saf okuma/odaklanma deneyimi.
- **Zemin:** Kirli beyaz / krem kağıt rengi (`#F4F4F0`). (Koyu modda: Koyu kurşuni gri)
- **Vurgu:** Mürekkep siyahı (`#1C1C1C`) ve soluk kırmızı.
- **Atmosfer:** Sıfır gölge (tamamen flat). Çizgili defter andıran ince ayırıcı çizgiler. Şık Serif fontlar (Times, Merriweather) ile yüksek okunabilirlik.

### 10. Pastel Day (Bahar ve Neşe)
- **Konsept:** Notion'ın estetik çalışma şablonları veya sevimli (kawaii) tasarım dili.
- **Zemin:** Çok uçuk lavanta (`#E6E6FA`) veya pamuk şekeri tonları.
- **Vurgu:** Nane yeşili (`#98FF98`) ve bebek pembesi.
- **Atmosfer:** Çok yumuşak gölgeler, devasa yuvarlak köşeler (bubble), neşeli ve modern kalın tipografi.

### 11. Royal Academy (Prestijli ve Klasik)
- **Konsept:** Oxford veya Harvard kütüphanesi hissiyatı, premium görünüm.
- **Zemin:** Gece mavisi (`#001427`).
- **Vurgu:** Altın varak rengi (`#D4AF37`).
- **Atmosfer:** Şık serif başlıklar, ince altın rengi çerçeveler, lüks ve ağırbaşlı bir ciddiyet. Başarımlar ve rozetler bu temada gerçek madalya gibi durur.

### 12. Dynamic Material You (Sistem Odaklı)
- **Konsept:** Kullanıcının telefonuna tam uyum. (Android 12+ Monet Motoru)
- **Zemin & Vurgu:** Android cihazın mevcut duvar kağıdından işletim sistemi tarafından otomatik çekilen palet.
- **Atmosfer:** Google'ın Material 3 standartları. Standart yuvarlaklık ve dinamik renk eşleşmesi.

---

## 3. Katmanlı Tema Editörü (Kişiselleştirme UX)

Kullanıcı hazır temayı beğenmezse veya değiştirmek isterse 30 farklı renk koduyla uğraşmayacak. Basit bir huni akışıyla (Katmanlı UX) temayı düzenleyecek:

1. **Temel Seçim:** "Hangi atmosferi istiyorsun?" (12 hazır temadan birini seç)
2. **Mood Değişimi:** (Açık Mod / Koyu Mod / AMOLED Mod)
3. **Vurgu Rengi:** (Butonlar ve ilerleme çubukları için tek bir renk paleti seçimi)
4. **Şekil Karakteri:** (Kartlar nasıl olsun? -> Keskin / Hafif Yuvarlak / Tam Oval)
5. **Gelişmiş Stüdyo (PRO):** Yalnızca detaylara inmek isteyenler için tek tek hex kodu değiştirme ekranı (Renkler, Blur seviyesi, Font kalınlığı).
6. **Canlı Önizleme:** Seçimler yapılırken ekranın üst yarısında "Örnek Dashboard", "Örnek Timer" anlık olarak renk değiştirir. Devam etmeden test edilir.
