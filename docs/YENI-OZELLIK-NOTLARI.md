# Yeni Özellik Notları — konuşma kaydı (Aşama 1)

> Bu dosya **düz not defteridir**. Amaç: yeni özellikleri önce konuşmak, konuşulanı kaybetmeden yazmak.
> Burada kesinleşmiş plan, mimari karar, tahmin ya da WP **yoktur**. Sadece proje sahibinin söylediği,
> Claude'un anladığı ve üzerinde anlaşılan şeyler yazılır.
>
> **Akış:** 1) Konuşma (bu dosya) → 2) Plan → 3) WP paketleme → 4) Uygulama.
> Şu an: **Aşama 1 — konuşma**. Plan aşamasına geçilene kadar buraya sadece not eklenir; kod yazılmaz.

- **Başlangıç:** 2026-07-24
- **Son güncelleme:** 2026-07-24 (3. konuşma turu)

---

## 0. Tur özeti — 2026-07-24, 1. konuşma

Proje sahibinin gündeme getirdiği 6 madde. Sırası öncelik sırası değil, konuşma sırasıdır.

| # | Başlık | Tür | Durum |
|---|---|---|---|
| F-01 | Ayarlar: "Uygulama kısayolları (rutinler)" kartını sil | Temizlik | Karar net |
| F-02 | Ayarlar: bildirim/izin/rapor kartlarını tek yerde birleştir | UX düzenleme | Yön net, detay konuşulacak |
| F-03 | Şifremi unuttum → e-postadaki link açılmıyor | **Hata** | Tekrar üretilecek |
| F-04 | Görünüm & atmosfer temaları tamamen yenilenecek | Büyük özellik | Konuşuluyor |
| F-05 | Ana sayfa kart düzenleme: boyut aracı sabit/yüzen olsun | UX düzenleme | Seçenek C seçildi |
| F-06 | Windows sürümünü arkadaşlara dağıtmak (production) | Dağıtım | F-01…F-05 sonrası yapılacak |
| F-07 | Play Store + Microsoft Store hazırlık süreci | Yol haritası | Genel plana dahil edilecek |

---

## F-01 — Ayarlar: "Uygulama kısayolları (rutinler)" kartı silinecek

**Sahibin ifadesi:** "Ayarlar kısmında 'Application shortcuts (routines)' kısmına basınca bir şey olmuyor.
Direkt ayarlardan bunu sil, gereksiz yer kaplıyor."

**Claude'un kodda gördüğü (doğrulama):**
- Kart `app/lib/features/profile/settings_screen.dart` içinde, ~330–339. satırlar.
- `ListTile`'ın **`onTap`'i yok, `subtitle`'ı yok, `trailing` oku yok** → gerçekten ölü bir plasebo satır.
  Yani "bir şey olmuyor" gözlemi kod tarafından birebir doğrulanıyor; bozulan bir şey değil, hiç bağlanmamış.
- Metin anahtarı: `profileUygulamaKisayollariRutinler` (l10n: TR/EN/DE/AR).

**Karar:** Kart ayarlardan tamamen kaldırılacak. Kullanılmayan l10n anahtarı da temizlenir.

**KARAR (3. tur):** Kısayol/rutin özelliği **gelmeyecek**. Kart tamamen silinir, geri dönüş notu tutulmaz.
İlgili l10n anahtarı da temizlenir. (S-01 kapandı.)

---

## F-02 — Ayarlar: bildirim + izin + rapor kartları tek yerde birleşecek

**Sahibin ifadesi:** "Ayarlarda 'notification center' ve 'widget and alarm permission' var, bu ikisini tek bir
yerde birleştir ve biraz daha düzenle; ilk defa kullananlar daha rahat anlasın. Yine ayarlarda 'monthly study
reports' var, bunu da öncekilerle birleştirelim."

**Bugün ayarlarda ayrı ayrı duran üç şey:**
1. **Bildirim merkezi** → `NotificationCenterScreen` (dürtme, hatırlatıcı, duyuru vs.)
2. **Widget ve alarm izinleri** → `ClockWidgetsScreen` (cihaz izinleri)
3. **Aylık çalışma raporu e-postası** → ayarlar listesinde doğrudan duran bir **switch** (opt-in)

**Anlaşılan hedef:** Üçü tek bir üst başlık altında toplanacak; içeride mantıklı gruplara ayrılacak.
İlk kez açan biri "hangisi neydi" diye düşünmeyecek.

**Claude'un ilk taslağı (tartışmaya açık):**
Tek giriş: **"Bildirimler ve izinler"**. İçeride 3 bölüm:
- *Bana ne gelsin* — dürtme, hatırlatıcı, duyuru, grup bildirimleri (uygulama içi tercihler)
- *Cihaz izinleri* — bildirim izni, alarm/tam zamanlı alarm, widget, pil optimizasyonu; her satırda
  **"şu an kapalı/açık" durumu** + tek dokunuşla düzeltme
- *E-posta* — aylık çalışma raporu opt-in

**Açık sorular:**
- (S-02) Üst başlığın adı: "Bildirimler ve izinler" mi, "Bildirim merkezi" mi, başka bir şey mi?
- (S-03) İlk kullanıcı için: en üstte tek satırlık bir **durum özeti** ("2 izin eksik — düzelt") ister misin?
- (S-04) Aylık rapor switch'i ayarlar ana listesinden tamamen çıkıp içeri mi girsin (evet gibi anlaşıldı, teyit)?

---

## F-03 — HATA: Şifremi unuttum akışında link açılmıyor

**Sahibin ifadesi:** "Şifremi unuttuma bastım, mail geldi, tıkladım ama site açılmadı. Tekrar tekrar
denedim ama o kısımda sorun var."

**Not:** Bu bir yeni özellik değil, **canlı hata**. Diğer maddelerden ayrı tutulacak ve muhtemelen önce çözülecek.

**Sahibin ek bilgisi (2. tur):**
- Sayfa hiç yüklenmiyor. Tarayıcı hata sayfası çıkıyor; "Details"a basınca
  **"check your internet connection"** diyor. Ama internet çalışıyor.
- **stable** sürümde denendi.

**Claude'un kodda bulduğu güçlü aday kök neden (henüz kanıtlanmadı, ama semptomla birebir örtüşüyor):**
- `app/lib/data/repositories/supabase/supabase_auth_repository.dart:185` →
  `await _client.auth.resetPasswordForEmail(safe);`
  **`redirectTo` parametresi verilmiyor.**
- `redirectTo` verilmeyince Supabase, e-postadaki linki projenin **Site URL** ayarına yönlendirir.
- `supabase/config.toml:43` → `site_url = "http://127.0.0.1:3000"` (yerel geliştirme varsayılanı).
  Hosted production projesinde de Site URL hâlâ `localhost`/`127.0.0.1` ise, e-postadaki link telefonun
  kendi 3000 portuna gider; orada bir şey olmadığı için tarayıcı **bağlantı hatası** verir ve Chrome bunu
  "check your internet connection" diye gösterir. → Semptom birebir bu.
- Uygulama tarafı zaten deep link'e hazır görünüyor: `authRepository.passwordRecoveryEvents` stream'i +
  `features/auth/recovery_screen.dart` var, `auth_gate.dart` bunu dinliyor. Yani eksik olan **link hedefi**.

**KÖK NEDEN DOĞRULANDI (3. tur):** Sahip maildeki linkin **`localhost:3000`** açtığını teyit etti.
Yani yukarıdaki tahmin doğru: `redirectTo` verilmediği için link, Supabase projesinin Site URL'ine
(`localhost:3000`) gidiyor; telefonda o adreste bir şey olmadığı için tarayıcı bağlantı hatası veriyor.
**Bu artık teşhis edilmiş bir hatadır, araştırma gerektirmez — doğrudan düzeltme WP'sine gider.**

**Çözüm yönü (planlanınca kesinleşecek):**
`resetPasswordForEmail`'e ortam başına doğru `redirectTo` vermek (uygulama deep link'i veya gerçek bir web
sayfası) + Supabase panelinde Site URL ve Redirect allowlist'i düzeltmek + Android intent-filter'ı doğrulamak.
**Not:** Supabase panel ayarı production'ı etkiler → ayrı GO kuralına tabi.

---

## F-04 — "Görünüm ve atmosfer temaları" tamamen yenilenecek

**Sahibin ifadesi (özet):**
- Bu bölüm **tamamen yenilenecek**.
- **Altta hazır temalar** olacak (şu anki hâli sadece renk seçimi gibi duruyor).
- **En üstte "create your own" gibi bir seçenek** olacak — adını sahip tam bulamadı, Claude önerecek.
- Bu bölümde her şey **tek tek, aşama aşama** seçilecek:
  - **Renk:** tek paket hâlinde değil — arka plan, yazı rengi, yazı arkası/yüzey rengi vs. ayrı ayrı.
    Her aşamada **canlı önizleme** olacak.
  - **Yazılar:** yazı tipi (font), yazı kalınlığı… "bu tür şeyleri zenginleştir".
  - **Animasyonlar:** modern, vintage, "kutular eskimiş gibi" vb. Genel tema uygulamalarında ne varsa
    araştırılıp uygulamanın **havasını değiştirecek** şeyler konacak.
  - **Keskinlik:** şu anki idare eder ama biraz daha seçenek eklenebilir.
  - Gerisi Claude'un hayal gücüne bırakıldı.
- En altta bunlardan **mix edilmiş birkaç hazır tema** olacak.

**Claude'un kodda gördüğü mevcut durum (sıfırdan başlanmıyor, üstüne inşa edilecek):**
- `features/profile/appearance_screen.dart` — atmosfer temaları + palet + açık/koyu/sistem (309 satır)
- `features/profile/theme_studio_screen.dart` — WP-55 "Katmanlı Tema Stüdyosu": aile → mood → şekil hissi →
  önizleme özeti, canlı önizlemeli 4 adım (616 satır). **Yani adım adım akışın iskeleti zaten var**,
  ama seçimler paket hâlinde (aile/mood), tek tek değil.
- `core/theme/theme_tokens.dart` — tema zaten 4 katmana ayrılmış durumda:
  - `AppColors`: surface1, surface2, scaffold, primary, accent, textPrimary, textSecondary, border, success, error…
  - `AppTypography`: displayClock, title, body, label + `useSerifTitles`, `useMonospaceClock`
  - `AppShapes`: radiusSm/Md/Lg, cardElevation, borderWidth, `sharp`
  - `AppAtmosphere`: gradientStart, gradientEnd, glowColor, glowStrength, blurSigma
- `core/theme/theme_presets.dart` — hazır preset'ler (534 satır)

  → **Önemli:** İstenen "tek tek seçim" için gereken alanların çoğu token katmanında zaten var.
  Asıl eksik: bu alanları kullanıcıya tek tek açan arayüz + kaydetme/paylaşma.

**İsim önerileri ("create your own" için):**
| Öneri | TR | EN |
|---|---|---|
| A | **Kendi temanı yarat** | Create your own |
| B | **Tema atölyesi** | Theme Workshop |
| C | **Tema stüdyosu** (mevcut ad, WP-55) | Theme Studio |
| D | **Sıfırdan tasarla** | Design from scratch |
| E | **Özel tema oluştur** | Custom theme |

**SEÇİLEN AD (sahip kararı, 2. tur): "Kendi Temanı Oluştur"** — EN karşılığı "Create your own theme".
Ayarlar/görünüm ekranının **en üstünde** büyük giriş kartı olarak duracak.

**Claude'un adım taslağı (tartışmaya açık, sıra değişebilir):**
1. **Zemin** — açık/koyu/sistem + arka plan rengi (düz / degrade / dokulu)
2. **Renkler** — tek tek: arka plan, kart/yüzey, vurgu (primary), ikincil vurgu (accent), yazı rengi
   (başlık/gövde ayrı), kenarlık. Her seçimde canlı önizleme.
3. **Yazılar** — font ailesi, başlık fontu ayrı, sayaç fontu ayrı (mono/serif), kalınlık, harf aralığı,
   satır yüksekliği, yazı boyu ölçeği
4. **Biçim/keskinlik** — köşe yuvarlaklığı, kenarlık kalınlığı, gölge/yükseklik, boşluk yoğunluğu
5. **Atmosfer** — degrade, parıltı (glow) gücü, bulanıklık (blur), doku/gren
6. **Animasyon/his** — geçiş hızı ve karakteri (aşağıya bak)
7. **Özet + isim ver + kaydet**

**ARAŞTIRMA GÖREVİ (sahip kararı, 3. tur):** "Kutular eskimiş gibi" ve genel animasyon/efekt seti için
sahip net bir tarif vermek yerine **araştırma istedi**: "oyunlarda ve uygulamalarda çok güzel temalar var,
onlardan animasyon/efekt vs. bakıp örnek almak lazım."
→ Plan aşamasından **önce** ayrı bir görsel referans/araştırma turu yapılacak; bulunanlar buraya ekran
görüntüsü/isim listesi olarak düşülecek, sonra hangilerinin uygulanacağı seçilecek. (S-13 araştırmaya döndü.)

**Animasyon/"his" fikirleri (ham liste, araştırma sonrası budanacak):**
- *Modern / minimal* — hızlı, yumuşak fade+slide, az hareket
- *Vintage / retro* — hafif grenli doku, sararmış kâğıt tonu, yazı makinesi tarzı yazı belirmesi
- *Eskimiş kutular* — kenarları hafif düzensiz, kâğıt/karton dokusu, gölgesi sert
- *Neon / cyber* — glow yüksek, koyu zemin, keskin köşe, titreşen vurgu
- *Kâğıt / defter* — çizgili zemin, mürekkep hissi, sayfa çevirme geçişi
- *Yumuşak / sakin (zen)* — yavaş geçiş, düşük kontrast, yuvarlak köşe, nefes alan boşluk
- *Cam (glassmorphism)* — bulanık şeffaf yüzey, ince parlak kenarlık
- *Bezelsiz düz (flat)* — gölgesiz, kenarlıkla ayrılan yüzeyler
- **Erişilebilirlik notu:** "hareketi azalt" sistem ayarına saygı + uygulama içi kapatma şart.

**KARARLAR (2. tur — sahip cevapladı):**
- **İsim:** **"Kendi Temanı Oluştur"**. (S-01 kapandı.)
- **Adet:** **Birkaç özel tema kaydedilebilecek** — tek slot değil, isimli birden fazla. (S-08 kapandı.)
- **Senkron:** Özel temalar **hesaba kaydedilecek**, yani tüm cihazlarda listede görünür.
  **Ama hangi temanın aktif olduğu cihaz başına serbest** — kullanıcı telefonda A temasını,
  Windows'ta B temasını seçebilir. (S-09 kapandı.)
  → *Teknik sonuç: tema tanımı sunucuda ortak, "aktif tema seçimi" cihaz yerel.*
- **Kapsam:** **Şimdilik yalnız uygulama içi.** Ana ekran widget'ı ve bildirim paneli bu turda
  kapsam dışı. (S-14 kapandı.)

**KARARLAR (3. tur):**
- **Sınır yok** — kullanıcı istediği kadar özel tema oluşturabilir. (S-18 kapandı.)
- **Ekran düzeni:** en üstte **"Kendi Temanı Oluştur"** girişi, onun **altında hazır temalar** listesi.
  Yeni oluşturulan tema aynı listeye eklenir.
- **DÜZELTME (4. tur):** 3. turdaki "üste geçmesin" ifadesi **yanlış yazılmış**. Sahibin gerçek isteği:
  **yeni oluşturulan tema listenin en üstüne geçsin.** En son yapılan en üstte durur. (S-19 kapandı.)
- **Başlık kullanılmayacak — sadeleştirme kuralı (4. tur):** Mobilde ekran küçük olduğu için
  "Benim temalarım" / "Hazır temalar" gibi **metin başlıkları konmayacak**; iki grup arasında
  **ince/minik bir ayraç çizgi** olacak. Daha sade, daha az dikey yer.
  → *Bu, bu turun genel kuralı sayılır: yeni tema ekranında gereksiz başlık/boşluk yaratılmayacak.*
- **"3 boş yuva" fikri düştü** — sınırsız tema olduğu için sabit yuva göstermek yanıltıcı olur.
  Hiç tema yokken sade bir "oluştur" daveti yeter. (S-20 kapandı.)
- **Mevcut WP-55 Tema Stüdyosu ekranı: yeni akış onun YERİNE geçecek.** İki ayrı tema ekranı olmayacak.
  (S-12 kapandı.)

**Sonuçta ekran düzeni:**
1. En üstte **"Kendi Temanı Oluştur"** girişi
2. Kullanıcının kendi temaları — **en yeni en üstte**
3. **İnce ayraç çizgi** (başlık metni yok)
4. Hazır temalar

**Açık sorular:**
- (S-10) Tema **paylaşma/kod ile içe aktarma** olsun mu (arkadaşına tema gönderme)? İleriye mi bırakalım?
- (S-11) Ödül/kilit bağı olacak mı — bazı temalar XP/seviye ile mi açılsın, hepsi serbest mi?

---

## F-05 — Ana ekran widget'ı düzenlerken boyut aracı sabit dursun

**Sahibin ifadesi:** "Ana ekran widget'ı düzenlerken widget boyutunu ayarlama tool'u en altta kalıyor ve
sürekli yukarı aşağı inip çıkmak gerekiyor. Aklımda bir şey var, teknik olarak nasıl tarif ediyorlar
bilmiyorum: mesela yüzen bir baloncuk gibi altta dursa; ben ekranda yukarı aşağı hareket etsem de o sabit
olarak aşağıda dursun. En üstteki `+` tuşu, okey tuşu, yukarı al tuşu hep orada duruyor ya — bu da onun gibi,
altta sabit dursa, sürekli aşağı yukarı kaydırmak zorunda kalmasak güzel olur."

**Claude'un anladığı (sahibin isteği: yanlışsa düzeltilecek):**
Boyut aracı şu an sayfanın **akışın içinde**, en altta duruyor; içerik uzun olduğu için ekrandan çıkıyor.
İstenen: araç **sayfayla birlikte kaymasın**, ekranın altına **yapışık/sabit** kalsın — tıpkı üstteki
`+` / onay / yukarı-al düğme çubuğunun hep görünür kalması gibi. Kullanıcı listeyi kaydırırken bile
boyutu anında değiştirip sonucu yukarıda canlı görebilsin.

Teknik adı (sahibin sorduğu): buna genelde **"sabit alt araç çubuğu" (sticky / persistent bottom bar)**
denir. "Yüzen baloncuk" tarifi ise **FAB (floating action button)** veya **kalıcı alt panel
(persistent bottom sheet)** kavramına denk gelir.

**Üç seçenek (sahip seçecek):**
- **A — Sabit alt çubuk (sticky bottom bar):** Ekranın altına yapışık ince bir şerit; içinde boyut
  kaydırıcısı/ölçü seçenekleri. Hep görünür. En basit ve en tahmin edilebilir.
  *Eksi:* ekranın altından sabit bir yer yer (küçük telefonlarda alan daralır).
- **B — Yüzen baloncuk (FAB):** Altta küçük bir yuvarlak düğme durur; basınca boyut kontrolleri açılır,
  tekrar basınca kapanır. Sahibin "baloncuk" tarifine en yakın olan bu.
  *Eksi:* boyutu değiştirmek için önce bir dokunuş gerekiyor.
- **C — Çekilebilir alt panel (persistent bottom sheet):** Altta hep duran, kapalıyken ince (sadece
  kaydırıcı görünür), yukarı çekilince tüm boyut/hizalama seçenekleri açılan panel. **Claude'un önerisi:**
  A'nın "hep elimin altında" avantajını B'nin "yer kaplamama" avantajıyla birleştiriyor.

**C'nin uzun anlatımı (sahip "anlamadım" dedi — 2. turda görselle de gösterildi):**
C aslında **A'nın büyüyebilen hâli**. Normalde ekranın altında A gibi ince bir şerit durur; içinde sadece
boyut kaydırıcısı vardır ve sayfayı kaydırsan da yerinden kıpırdamaz. Farkı şu: şeridin üstünde küçük bir
**tutamak** (kısa çizgi) olur; parmağınla onu **yukarı çekersen** panel büyür ve içinden hizalama, saydamlık,
tema gibi diğer widget ayarları da çıkar. Aşağı itersen tekrar ince şeride döner.
Yani: **kapalı = A** (sadece boyut, az yer), **açık = tam ayar paneli**. Telefonlarda müzik çalarların alttaki
mini çubuğu gibi — küçükken tek satır, yukarı çekince tam ekran kontrol.

**KAPSAM NETLEŞTİ (3. tur — Claude kodda buldu):**
Bu, **Android ana ekran widget'ı değil**; uygulamanın **kendi ana sayfasındaki kart düzeni**.
İlgili kod: `app/lib/features/home/home_screen.dart:815` → `_SizePanel`.
Panel, **seçili kartın hemen altına akış içinde** çiziliyor. Kart sayfanın aşağısındaysa panel de aşağıda
kalıyor → sahip sürekli aşağı yukarı kaydırmak zorunda kalıyor. Şikayet birebir bu.

**KARARLAR (3. tur):**
- **Seçenek C** (çekilebilir alt panel) seçildi. *Sahip notu: "eğer zor olmaz diyorsan C olsun".*
  → Claude'un teknik değerlendirmesi: **zor değil**. Flutter'da hazır mekanizması var
  (`Scaffold.bottomSheet` / `DraggableScrollableSheet`); mevcut `_SizePanel` içeriği neredeyse aynen taşınır,
  değişen şey nereye yerleştirildiği. Riskli/geniş bir iş değil.
- **Saydamlık ayarı YOK ve eklenmeyecek.** Sahip sordu, Claude koda baktı: `_SizePanel` içinde yalnızca
  genişlik/yükseklik `−/+` düğmeleri var; saydamlık hiç yok. Claude'un mockup'ında örnek olsun diye
  görünmüştü, gerçekte yok. **O kadar detaya gerek yok** kararı verildi. (S-16 kapandı: panelde sadece boyut.)

**WINDOWS SORUSU KAPANDI (5. tur):** Sahip Windows'u da kullanıyor ama seyrek; boyut panelini orada
denememiş. **Claude kodda baktı: ayrı Windows kodu yok.** `home_screen.dart` tek dosya, hem telefon hem
Windows onu kullanıyor; sadece `isDesktopWindow` ile birkaç yerde kenar boşluğu/yerleşim dallanıyor
(`home_screen.dart:91` ve `:160`). Yani `_SizePanel` sorunu **her iki platformda da aynı koddan geliyor**
ve düzeltme ikisini birden düzeltir. Ayrıca yapılacak bir Windows işi yok. (S-17 kapandı.)

---

---

## F-06 — Windows sürümünü arkadaşlara test için dağıtmak

**Sahibin ifadesi (5. tur):** "Windows ve mobil kısmında tamamen farklı kodları mı var, birinde olan
diğerinde olmuyor mu? Önce bu dediklerimi Windows'a da kod olarak uygulayıp sonrasında oranın dağıtım
işini yapmak istiyorum, onu da arkadaşlarıma atmam lazım test için."

**Cevap 1 — tek kod tabanı:** Ayrı Windows kodu **yok**. Proje Flutter; ekranların tamamı ortak.
Yalnız `isDesktopWindow` bayrağıyla yer yer yerleşim farkı var (kenar boşluğu, gezinme paneli,
`features/desktop/**` kabuk dosyaları). Yani **F-01…F-05'in hepsi Windows'a da otomatik gelir**;
"Windows'a ayrıca uygulamak" diye ek bir iş yok. İstisna: bir şey `isDesktopWindow` dalında farklı
çiziliyorsa orada ayrıca bakılır (tema ekranı ve boyut paneli bu gruba giriyor, ikisi de zaten kapsamda).

**Cevap 2 — dağıtım altyapısı zaten var (kodda doğrulandı):**
- `.github/workflows/windows-release.yml` her sürümde **hem `.msix` hem `.zip`** üretip release'e ekliyor
  (`windows-release.yml:82-87`).
- **MSIX**: kurulum paketi, ama şu an `CN=Msix Testing` test publisher'ı ile imzalı → arkadaşların
  kurabilmesi için sertifika güvenmesi/geliştirici modu gerekir. Sürtünmeli.
- **ZIP**: release klasörünün portable hâli → indir, çıkart, `.exe`'ye çift tıkla. Kurulum yok,
  sertifika yok. **Arkadaş testi için en kolay yol bu.**
- Ayrıntılı Store planı: [`docs/WINDOWS-STORE-PLAN.md`](WINDOWS-STORE-PLAN.md) (WP-259/260/261 —
  Store kimliği, private audience vb. bunlar bu turun konusu değil).

**Sıralama kararı (sahip):** Önce F-01…F-05 kodlanacak, **sonra** Windows dağıtımı yapılacak.

**KARAR (6. tur):** Arkadaşlar **production** backend'e bağlanacak. Yani bu bir "sentetik test" değil,
gerçek kullanım olacak; açtıkları hesaplar gerçek hesaptır. (S-23 kapandı.)
*Claude notu: bu bilinçli bir karar; staging önerilmişti, sahip production dedi. Sonuç olarak arkadaşların
verisi gerçek veridir — test amaçlı çöp veri üretmemeleri iyi olur, ama teknik engel yoktur.*

### Güncelleme nasıl gidiyor? (sahibin sorusu, 6. tur — Claude kodda doğruladı)

**Kısa cevap: push bildirimi GELMİYOR. Uygulamayı açtıklarında ekranda bir güncelleme penceresi çıkıyor.**

Akış (`features/updater/updater_service.dart` + `updater_dialog.dart` + `auth_gate.dart`):
1. Kullanıcı uygulamayı açar → `auth_gate.dart` `maybeShowUpdateDialog` çağırır.
2. Uygulama GitHub Releases'e bakar, kendi sürümünden yenisi var mı diye kontrol eder.
3. Varsa **uygulama içi güncelleme penceresi** açılır (ertelenebilir).
4. İndirir, **SHA-256 doğrular** (bozuk/eksik dosya kurulmaz), sonra dosyayı açar:
   - Android → APK kurulum ekranı (`app-release.apk` / beta'da `app-beta-release.apk`)
   - Windows → **MSIX** kurulum ekranı (`odak-kampi-windows-stable.msix` / `...-beta.msix`)
     `updater_service.dart:124-125`

**ÖNEMLİ TUZAK (Claude'un fark ettiği, sahibin bilmesi gereken):**
Güncelleyici Windows'ta **yalnız MSIX** indiriyor. Yani arkadaşlar **ZIP portable** sürümü kullanırsa:
- Uygulama yine "güncelleme var" der ve MSIX indirir,
- ama MSIX kurulunca **portable klasörün yanına ayrı bir kurulu uygulama** gelir → iki kopya, kafa karışıklığı.
→ **Sonuç: "kolay kurulum" (ZIP) ile "çalışan otomatik güncelleme" (MSIX) aynı anda olmuyor.**

| | ZIP portable | MSIX kurulum |
|---|---|---|
| Kurulum kolaylığı | Çok kolay — çıkart, çalıştır | Sertifikaya güvenmek gerekir (test publisher) |
| Uygulama içi güncelleme | **Düzgün çalışmaz** (yanına ikinci kopya kurar) | Çalışır — üstüne günceller |
| Arkadaşa anlatma yükü | Yok | Bir kerelik "sertifikaya güven" adımı |

**Claude'un önerisi:** Arkadaşlar production'da gerçek kullanıcı olacaksa ve sürekli güncelleme
alacaklarsa → **MSIX** doğru seçim; sertifika adımı bir kerelik. ZIP'i yalnız "bir bakıp kapatacak"
kişiye ver. Kalıcı çözüm zaten Microsoft Store (aşağıda F-07) — Store kurulumunda sertifika derdi de,
elle güncelleme derdi de biter.

**Açık sorular:**
- (S-21) Yukarıdaki tabloya göre: **MSIX** (güncelleme çalışsın) mı, **ZIP** (kurulum kolay olsun) mu?
- (S-22) Dağıtım kanalı: mevcut **GitHub Release** linki mi yeter, yoksa dosyayı doğrudan mı göndereceksin?
- (S-24) Güncelleme çıktığında arkadaşlara **push bildirimi** gitsin ister misin? Şu an yok; uygulamayı
  açınca görüyorlar. İstenirse ayrı bir özellik olur (duyuru/push altyapısı zaten var).

---

## F-07 — Play Store ve Microsoft Store hazırlık süreci

**Sahibin ifadesi (6. tur):** "Genel planlama kısmına Play Store ve Microsoft Store'a hazırlık sürecini
de ekle, oradan da dağıtım yapsak güzel olur gibi."

**Durum:** Bu iki mağaza için repoda **zaten hazırlık dokümanı var**, sıfırdan başlanmıyor:
- Microsoft Store → [`docs/WINDOWS-STORE-PLAN.md`](WINDOWS-STORE-PLAN.md)
  (WP-259 yerel QA, WP-260 Store kimliği/paketleme, WP-261 marka/listeleme, WP-262 private pilot)
- Play Store → [`docs/PLAY-STORE-HAZIRLIK-TARAMASI.md`](PLAY-STORE-HAZIRLIK-TARAMASI.md) ve
  `docs/play-store/PLAY-RELEASE-GATE.md`

**Bu turda yapılacak:** Bu iki süreci **genel yol haritasına dahil etmek** — yani F-01…F-06'dan sonra
gelen resmî bir faz olarak yazmak, dağınık doküman hâlinde bırakmamak.

**Bilinen büyük engeller (bunlar konuşulacak, bugün karar yok):**
- **Para/hesap:** Play Console tek seferlik ücret, Microsoft Partner Center hesabı — ikisi de sahip
  tarafından açılır, Claude açamaz.
- **Kimlik:** Microsoft Store'da mevcut test publisher (`CN=Msix Testing`) geçersiz; kalıcı Store
  identity alınmalı (WP-260).
- **Görsel paket:** Her iki mağaza da ikon, ekran görüntüleri, açıklama metni istiyor (WP-261).
- **Yasal:** Gizlilik politikası + destek adresi + veri güvenliği formu (Play tarafında zorunlu).
- **Hesap silme:** Play, uygulama içi hesap silme yolu şart koşuyor → WP-276 buraya bağlanıyor.

**Açık sorular:**
- (S-25) Hangisi önce — **Play Store** mu, **Microsoft Store** mu? (Claude: kullanıcıların çoğu Android
  ise Play önce; Windows zaten GitHub'dan dağıtılabiliyor.)
- (S-26) Mağaza hesapları (ücret dahil) ne zaman açılacak? Bu, planın başlayabileceği tarihi belirler.
- (S-27) Uygulama mağazada **ücretsiz** mi olacak? Reklam/satın alma düşünülüyor mu? (Bu, mağaza
  formlarını ve gizlilik beyanını doğrudan değiştirir.)

## 6. Açık soru listesi (toplu)

Yukarıdaki S-01…S-17. Sıradaki konuşma turunda bunlar tek tek kapatılacak.

## 7. Kapsam dışı olduğu konuşulanlar

- **Kısayol/rutin özelliği** — hiç gelmeyecek (F-01).
- **Widget saydamlık ayarı** — gereksiz detay, eklenmeyecek (F-05).
- **Tema kapsamının ana ekran widget'ı ve bildirim paneline uzanması** — bu turda kapsam dışı (F-04).

## 8. Karar verilenler

- Akış: önce konuşma → sonra plan → sonra WP → sonra uygulama.
- Aşama 1'de kod yazılmaz, WP açılmaz, tahmin/efor verilmez.
- F-03 (şifre sıfırlama linki) bir **hata**dır, özellik değil; ayrı ele alınır.
