# iOS yol haritası — Mac olmadan App Store'a (WP-905)

Bu belge **sahip** içindir. Mac gerekmez: uygulama GitHub'daki bir macOS
sunucusunda derlenir, imzalanır ve App Store Connect'e yüklenir
(`.github/workflows/ios-release.yml`). Senin işin yalnız **tarayıcıda** yapılan
Apple / Firebase / Google adımları. Her adımın sonunda Claude'a ne göndereceğin
yazılı.

Sabit değerler (kopyala-yapıştır):

| Alan | Değer |
|---|---|
| Bundle ID | `com.manilmax.focuscamp` |
| Uygulama adı (App Store) | `Focus Camp: Odak ve Çalışma` |
| SKU | `focuscamp-ios` |
| Birincil dil | Türkçe |
| Gizlilik politikası | `https://manil-max.github.io/online-study-room/legal/privacy-tr.html` |

> **Güvenlik:** Aşağıdaki `.p8` dosyaları ve anahtarlar **şifre gibidir**.
> GitHub issue'ya, herkese açık sohbete, e-posta listesine, ekran görüntüsüne
> koyma. Yalnız Claude ile olan bu özel oturuma yapıştır; Claude onları
> GitHub'da **şifreli secret** olarak saklar ve dosyayı hiçbir yere yazmaz.

---

## Kim ne yapar

| Adım | Sen (tarayıcı) | Claude (komut satırı) |
|---|---|---|
| a | Apple Developer Programına katıl | — |
| b | Team ID'yi bul ve gönder | `APPLE_TEAM_ID` değişkenini ayarlar |
| c | App Store Connect API anahtarı oluştur, gönder | `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_P8` secret'larını ayarlar |
| d | App ID kaydet (Push + Apple ile giriş) | — |
| e | APNs anahtarı → Firebase; Firebase'e iOS uygulaması ekle, iki değeri gönder | `FIREBASE_IOS_API_KEY`, `FIREBASE_IOS_APP_ID` değişkenlerini ayarlar |
| f | Google Cloud'da iOS OAuth istemcisi oluştur, kimliği gönder | `GOOGLE_IOS_CLIENT_ID` değişkenini ayarlar, Supabase'e ekler, Apple sağlayıcısını açar |
| g | App Store Connect'te uygulama kaydı aç | — |
| h | iPhone'a TestFlight kur, test et | TestFlight derlemesini tetikler |
| i | Mağaza sayfasını doldur, incelemeye gönder | Metinleri ve kareleri hazırladı, demo hesabı açar |

Claude'un ayarlayacağı adların tam listesi: `APPLE_TEAM_ID`,
`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
`APP_STORE_CONNECT_API_KEY_P8`, `GOOGLE_IOS_CLIENT_ID`, `FIREBASE_IOS_API_KEY`,
`FIREBASE_IOS_APP_ID`.

---

## a) Apple Developer Programına katıl

1. Kendi Apple ID'nle (iPhone'da kullandığın hesap olabilir) **iki adımlı
   doğrulamanın açık** olduğundan emin ol: iPhone → Ayarlar → adın → Giriş ve
   Güvenlik → İki Faktörlü Kimlik Doğrulama **Açık**.
2. En kolayı iPhone'dan: **Apple Developer** uygulamasını App Store'dan indir →
   **Hesap** → **Şimdi Kaydol**. (Tarayıcıdan: `https://developer.apple.com/programs/enroll/`)
3. Tür: **Bireysel / Individual** (şirket değil).
4. Ad-soyad **kimliğindeki yasal adınla** aynı olmalı. App Store'da "satıcı"
   olarak bu ad görünür (ör. `Muhlis Anıl Özkan`).
5. Ücret yıllık **99 USD**'dir; ekranda gösterilen tutarı (TL karşılığı ve
   vergiler) ödemeden önce **kendin kontrol et**.
6. Onay genelde 24–48 saat sürer. "Welcome to the Apple Developer Program"
   e-postası gelince devam et.

## b) Team ID'yi bul → Claude'a gönder

1. `https://developer.apple.com/account` → sol menü **Membership details**
   (Üyelik).
2. **Team ID** satırındaki 10 karakterlik değeri (ör. `A1B2C3D4E5`) kopyala.
3. Claude'a: *"Team ID: A1B2C3D4E5"* yaz. (Gizli değildir.)

## c) App Store Connect API anahtarı → Claude'a gönder

Bu anahtar, GitHub'daki sunucunun senin yerine imzalayıp yükleyebilmesi için.

1. `https://appstoreconnect.apple.com` → **Users and Access** (Kullanıcılar ve
   Erişim) → üstte **Integrations** (Entegrasyonlar) → **App Store Connect API**.
2. İlk kez giriyorsan **Request Access** / erişim iste, şartları kabul et.
3. **Team Keys** sekmesi → **+** (Generate API Key).
   - Name: `github-actions`
   - Access (rol): **Admin**.
     > Neden Admin: imza sertifikasını bulutta otomatik oluşturma ("cloud
     > managed distribution certificate") App Manager rolüne izin vermiyor;
     > App Manager ile ilk yükleme "Cloud signing permission error" ile
     > düşer. Anahtar yalnız bu iş akışında kullanılır.
4. **Download API Key** → `AuthKey_XXXXXXXXXX.p8` dosyası iner. **Yalnız bir kez
   indirilebilir**; kaybolursa anahtarı iptal edip yenisini oluşturman gerekir.
5. Aynı sayfada:
   - **Issuer ID** (sayfanın üstünde, `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` biçiminde)
   - Anahtarın satırındaki **Key ID** (10 karakter)
6. Claude'a bu özel oturumda gönder:
   - *Key ID:* …
   - *Issuer ID:* …
   - `.p8` dosyasını Not Defteri ile aç, `-----BEGIN PRIVATE KEY-----` ile
     `-----END PRIVATE KEY-----` dahil **tamamını** yapıştır.
7. Claude secret'ları ayarladıktan sonra `.p8` dosyasını güvenli bir yerde
   (ör. parola yöneticisi) sakla ya da sil; bilgisayarda açıkta bırakma.

## d) App ID kaydet (Push + Apple ile giriş)

Otomatik imza bunu kendisi de açabilir, ama elle kaydetmek yetenekleri kesinleştirir.

1. `https://developer.apple.com/account/resources/identifiers/list` →
   **Identifiers** → **+**.
2. **App IDs** → Continue → **App** → Continue.
3. Description: `Focus Camp` · Bundle ID: **Explicit** →
   `com.manilmax.focuscamp`
4. Capabilities listesinde işaretle:
   - **Push Notifications**
   - **Sign In with Apple** (yanındaki "Configure" varsayılan kalsın: *Enable as a primary App ID*)
5. Continue → **Register**.

## e) Bildirimler: APNs anahtarı → Firebase, Firebase iOS uygulaması

**e1. APNs anahtarı oluştur**
1. `https://developer.apple.com/account/resources/authkeys/list` → **Keys** → **+**.
2. Key Name: `Focus Camp APNs` · **Apple Push Notifications service (APNs)** işaretle
   (ortam sorulursa **Sandbox & Production**) → Continue → Register.
3. **Download** → `AuthKey_YYYYYYYYYY.p8` (yine yalnız bir kez iner). Key ID'yi not al.
   Bu dosya Claude'a **gitmez**, doğrudan Firebase'e yüklenir.

**e2. Firebase'e iOS uygulaması ekle**
1. `https://console.firebase.google.com` → **odak-kampi** projesi.
2. Proje özeti → **Uygulama ekle** → **iOS** simgesi.
3. Apple paket kimliği: `com.manilmax.focuscamp` · Takma ad: `Focus Camp iOS`
   · App Store kimliği şimdilik boş → **Uygulamayı kaydet**.
4. **GoogleService-Info.plist'i indir**. Bu dosyayı Not Defteri ile aç ve şu iki
   değeri Claude'a gönder (dosyanın tamamı gerekmez, projeye de konmayacak):
   - `API_KEY` satırının altındaki değer (`AIza…`)
   - `GOOGLE_APP_ID` satırının altındaki değer (`1:422149816131:ios:…`)
5. Kalan sihirbaz adımlarını (SDK ekleme, kod) **atla** → Konsola devam et.

**e3. APNs anahtarını Firebase'e yükle**
1. Firebase → ⚙ **Proje ayarları** → **Cloud Messaging** sekmesi.
2. **Apple uygulaması yapılandırması** → `com.manilmax.focuscamp` → **APNs Kimlik Doğrulama Anahtarı** → **Yükle**.
3. e1'deki `.p8` dosyasını seç, **Key ID** ve **Team ID**'yi (b adımı) gir → Yükle.

## f) Google ile giriş: iOS OAuth istemcisi

1. `https://console.cloud.google.com/apis/credentials` → üstte proje olarak
   Android Google girişinde kullanılan projeyi seç (web istemcisi
   `1094303444274-…` olan proje).
2. **+ Kimlik bilgisi oluştur** → **OAuth istemci kimliği**.
3. Uygulama türü: **iOS** · Ad: `Focus Camp iOS` · Paket kimliği:
   `com.manilmax.focuscamp` · (App Store kimliği / Takım kimliği isteğe bağlı;
   varsa Team ID'yi yaz) → **Oluştur**.
4. Çıkan **İstemci kimliği**ni (`…apps.googleusercontent.com`) Claude'a gönder.
   (Gizli değildir.)
5. Supabase'e ekleme işini **Claude yapar** (`supabase-auth-config.yml`,
   `google_ios_client=add`); sen Supabase paneline girmezsin. Aynı iş
   akışıyla Claude Supabase'de **Apple ile giriş** sağlayıcısını da açar
   (`apple_provider=enable`, Client ID `com.manilmax.focuscamp`; yerli iOS
   girişinde gizli anahtar gerekmez).

## g) App Store Connect'te uygulamayı oluştur

1. `https://appstoreconnect.apple.com` → **Apps / Uygulamalar** → **+** → **New App / Yeni Uygulama**.
2. Alanlar:
   - Platforms: **iOS**
   - Name: `Focus Camp: Odak ve Çalışma` (alınmışsa `Focus Camp - Odak Kampı`)
   - Primary Language: **Turkish**
   - Bundle ID: listeden `com.manilmax.focuscamp` (d adımında kaydettiğin)
   - SKU: `focuscamp-ios`
   - User Access: **Full Access**
3. **Create**. Claude'a *"App Store Connect'te uygulama açıldı"* de.

## h) TestFlight ile iPhone'da dene

1. Claude b, c, e, f değerlerini ayarlayıp TestFlight derlemesini tetikler.
   Derleme ~30–45 dk, Apple'ın işlemesi 5–30 dk sürer.
2. App Store Connect → uygulama → **TestFlight** sekmesi.
   - Derlemenin yanında "Missing Compliance" görürsen: **Manage** → *None of
     the algorithms mentioned above* / standart şifreleme → kaydet.
     (Derleme zaten `ITSAppUsesNonExemptEncryption=false` taşır; genelde çıkmaz.)
3. **Internal Testing** → **+** → grup adı `Sahip` → kendini (Apple ID
   e-postanı) ekle → derlemeyi gruba ekle.
4. iPhone'a **TestFlight** uygulamasını App Store'dan kur → davet e-postasındaki
   bağlantıyı aç ya da TestFlight'ta aynı Apple ID ile gir → **Yükle**.
5. Test listesi (her maddeyi dene, sorun olanı ekran görüntüsüyle Claude'a yaz):
   - [ ] Uygulama açılıyor, ikon ve ad doğru.
   - [ ] E-posta + şifre ile kayıt ve giriş.
   - [ ] **Apple ile giriş** (Face ID/şifre ile onay, geri dönünce oturum açık).
   - [ ] **Google ile giriş**.
   - [ ] Sayacı başlat → uygulamayı kapat → 2 dk sonra aç: süre doğru işlemiş.
   - [ ] Bildirim izni sorusu çıkıyor; "İzin ver" sonrası hatırlatma bildirimi geliyor.
   - [ ] Gruba davet koduyla katıl, kamp ateşinde kendini ve diğerlerini gör.
   - [ ] İstatistikler ve rozetler açılıyor, taşma/kesik yazı yok.
   - [ ] Tema değiştir, koyu mod.
   - [ ] Uçak modunda sayaç çalışıyor, bağlantı gelince eşitleniyor.
   - [ ] Ayarlar → hesap silme akışı görünüyor (silmeyi gerçekten yapma).

## i) Mağaza sayfası ve incelemeye gönderme

1. App Store Connect → uygulama → **App Store** sekmesi → **1.0 Prepare for Submission**.
2. Metinler: [`docs/APP-STORE-METINLERI.md`](APP-STORE-METINLERI.md) dosyasından
   Türkçe alanları yapıştır; sağ üstten **English (U.S.)** dilini ekleyip
   İngilizce alanları yapıştır.
3. Ekran görüntüleri: **iPhone 6.9"** bölümüne
   [`docs/app-store-kareleri/`](app-store-kareleri/) içindeki 5 kareyi
   01→05 sırasıyla sürükle (1320x2868). 6.5" bölümü boş kalabilir; Apple 6.9"
   karelerini küçültür. iPad istenirse: uygulama yalnız iPhone ise bu bölüm
   çıkmaz; çıkarsa Claude'a söyle.
4. **Build** bölümü → **+** → TestFlight'ta denediğin derlemeyi seç.
5. **App Information**: kategori Birincil **Education / Eğitim**, İkincil
   **Productivity / Verimlilik**; Content Rights: *"Does your app contain,
   show, or access third-party content?"* → **No**.
6. **Age Rating**: APP-STORE-METINLERI.md'deki cevaplar.
7. **App Privacy** (Gizlilik): APP-STORE-METINLERI.md'deki tablo; Privacy
   Policy URL'sini gir → **Publish**.
8. **Pricing and Availability**: Ücretsiz, tüm ülkeler (ya da istediğin ülkeler).
9. **App Review Information**: demo hesabı (Claude oluşturup sana
   verecek), iletişim adı/telefon/e-posta, **Notes** alanına
   APP-STORE-METINLERI.md'deki inceleme notu.
10. Sağ üst **Add for Review** → **Submit for Review**. İnceleme genelde 1–3 gün.
    Ret gelirse mesajın tamamını Claude'a yapıştır.
