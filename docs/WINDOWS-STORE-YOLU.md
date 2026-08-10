# Windows: Microsoft Store yolu (ücretsiz)

> Kısa cevap: **Windows'u yayınlamak için sertifika satın almana gerek yok.**
> Store'a gönderilen paketi Microsoft kendi sertifikasıyla imzalıyor, geliştirici
> kaydı da artık ücretsiz.

## Önceki bilginin düzeltmesi

Daha önce "Windows kod imzalama sertifikası ~yıllık 200-400 $" dendi. O rakam
**Store'un ücreti değildi** — bir sertifika otoritesinden (DigiCert, Sectigo…)
satın alınan **kod imzalama sertifikasının** fiyatıydı ve yalnızca
**Store DIŞI** dağıtım için gerekiyor.

| Yol | Ücret | Kullanıcı kurabilir mi? |
|---|---|---|
| **Microsoft Store** | **0 ₺** — kayıt ücretsiz, paketi Microsoft imzalar | ✅ Evet |
| Taşınabilir ZIP (bugün yapılan) | 0 ₺ | ✅ Evet (kurulum yok, klasörden çalışır) |
| Store dışı MSIX / kendi imzan | Sertifika ücreti | ✅ Evet |
| Store dışı MSIX / imzasız (v62'ye kadarki hâl) | 0 ₺ | ❌ **Hayır** — `0x800B010A` |

## Sahibin yapması gerekenler (bir kez, ~30 dk)

1. <https://developer.microsoft.com/microsoft-store/register> → **Individual
   developer (free)** seç.
2. Microsoft hesabıyla giriş yap.
3. Kimlik doğrulaması: **devlet kimliği/pasaport fotoğrafı + selfie**. (Bu adım
   ücretsiz ama atlanamaz.)
4. Partner Center → **Apps and games → New product → MSIX or PWA app** →
   uygulama adını **rezerve et**: `Odak Kampı` (alınmışsa `Odak Kampı - Focus Camp`).
5. Uygulamanın **Product Identity** sayfasından şu **üç değeri** kopyala:
   - **Package/Identity/Name** → örn. `12345OdakKampi.OdakKampi`
   - **Package/Identity/Publisher** → `CN=` ile başlayan uzun GUID
   - **Package/Properties/PublisherDisplayName** → örn. `Odak Kampı`
6. Bu üçünü bana ver. (Sır değil — pakete zaten gömülüyorlar, gizlemeye gerek yok.)

## Gönderim hazırlık tablosu (WP-605/606 · 2026-08-09)

Sahip "hesap açma dışında her şey hazır olsun" dedi. Durum:

| Gereken | Durum | Not |
|---|---|---|
| Paket üretimi (`msix:create --store`) | ✅ **Uçtan uca denendi** | Yer değiştirme kimliğiyle gerçek paket üretildi, aşağıya bak |
| Paket sürüm şeması `1.0.<patch>.0` | ✅ | Store 4. alanın 0 olmasını ister; WP-568'den beri öyle |
| Paket **imzasız** (Store imzalar) | ✅ **Doğrulandı** | Üretilen pakette `AppxSignature.p7x` yok |
| Dil listesi | ✅ **Düzeltildi (WP-606)** | `tr-tr, en-us`; eskiden yalnız `tr-tr` idi |
| Min/max Windows sürümü | ✅ | `min=10.0.17763` (Win10 1809), `maxTested=10.0.22621` |
| Yetenekler | ✅ | `internetClient`, `runFullTrust` — fazlası yok |
| Gizlilik politikası adresi | ✅ **Yayında** | `…/legal/privacy-tr.html`, sürüm 2026-08-08 |
| Mağaza sayfası metinleri (TR + EN) | ✅ | `docs/store/MICROSOFT-STORE-LISTING.md` |
| **Yüksek çözünürlüklü logo** | ❌ **SAHİPTEN GEREKİYOR** | Aşağıya bak |
| **Ekran görüntüleri** | ❌ **SAHİPTEN GEREKİYOR** | En az 1 tane, 1366×768 veya daha büyük |
| Yaş derecelendirme (IARC) anketi | ⚠️ Sahip dolduracak | Cevap taslağı listeleme belgesinde |
| **Destek e-postası** | ❌ **SAHİPTEN** | Depoda tek bir destek adresi yok |
| **İnceleme test hesabı** | ❌ **SAHİPTEN** | Aşağıya bak — atlanırsa gönderim reddedilir |
| Windows App Certification Kit (WACK) | ⚠️ **Koşulamadı** | Yönetici izni istiyor; sahip yokken UAC onaylanamaz |

### ❌ Logo: 256×256 yetmiyor (ölçüldü)

`msix` paketi Store varlıklarını tek kaynak logodan üretiyor. Kaynağımız
`windows/runner/resources/app_icon.ico` ve içindeki **en büyük görüntü 256×256**.
Üretilen paketten ölçülen gerçek boyutlar:

| Varlık | Üretilen | Durum |
|---|---|---|
| `Square150x150Logo.scale-400` | 600×600 | büyütülmüş |
| `Wide310x150Logo.scale-400` | 1240×600 | büyütülmüş |
| `LargeTile.scale-400` | 1240×1240 | büyütülmüş |
| `SplashScreen.scale-400` | 2480×1200 | **~10× büyütülmüş** |

Yani Başlat menüsündeki büyük kutu ve açılış ekranı **bulanık** çıkar.
**Gereken:** kardeşindeki logodan **en az 1240×1240**, tercihen **2048×2048**
şeffaf arka planlı **PNG**. Dosya gelince `logo_path` ona çevrilir, başka
değişiklik gerekmez. (Logoya ben dokunmuyorum — sahip kararı.)

### ❌ Ekran görüntüleri

Store en az bir ekran görüntüsü ister (1366×768 – 3840×2160). Bunu üretmenin
normal yolu ekranı yakalamak ama **bu makinede çalışmıyor**: GDI, Flutter'ın
DirectComposition yüzeyini göremiyor (WP-602'de iki yöntemle ölçüldü, ikisi de
bomboş beyaz veriyor). Seçenekler:

**Sahip kendi çeker** — uygulamayı açıp `Win+Shift+S` ya da `Win+PrtScn`.
4-6 kare yeter: ana sayfa, sayaç, grup, istatistik, başarımlar, tema stüdyosu.

#### Golden altyapısından üretme DENENDİ ve BIRAKILDI (dürüstçe)

Testten render edip PNG yazan bir üreteç yazıldı ve üç kez denendi. Sonuç:

- İlk kare: bütün yazılar **kutu** çıktı — test ortamında font ailesi yok.
  Temaya `fontFamily: 'Inter'` bağlanınca yazılar düzeldi.
- Ama **ikonlar kutu kalmaya devam etti** ve `boundary.toImage()` çağrısı
  koşumu asıyor: her denemede "did not complete" ile 3-4 dakika sonra düştü.
  Üretilen tek kare de yalnız tema seçme ekranıydı — bir çalışma uygulamasının
  mağaza sayfası için en zayıf ilk izlenim.

Üreteç **silindi**. Gerekçe: bu depoda kural, ölçtüğünü iddia ettiği şeyi
ölçmeyen araç bırakmamak. Yarım çalışan bir üretecin bakımı, sahibin iki
dakikada çekeceği gerçek kareden pahalı.

### ❌ İnceleme test hesabı — atlanırsa doğrudan RET

Uygulama girişsiz açılmıyor. Microsoft'un inceleme ekibi giremezse gönderim
**reddedilir** ve bu en sık ret sebeplerinden biridir. Partner Center'da
"Notes for certification" alanına çalışan bir **e-posta + şifre** girilmeli.

Şifreyi ben oluşturmam ve yazmam. Sahip bir test hesabı açıp bilgileri o alana
kendisi girer. (Aynı gereklilik Google Play kapalı testi için de geçerli.)

### ⚠️ WACK koşulamadı — neden ve ne zaman koşacak

`appcert.exe` bu makinede **kurulu** ama **yönetici izni** istiyor; sahip yokken
UAC onayı verilemez. Ayrıca Store paketi imzasız olduğu için yerel makineye
kurulamaz ve WACK kurulu uygulama üzerinde çalışır — kurmak için sertifika
güven deposunu değiştirmek gerekir, o da yapılmaz.

**Bu bir engel değil:** Microsoft aynı denetimleri gönderim sonrası
sertifikasyonda kendisi koşturuyor. Sahip isterse gönderimden önce yönetici
olarak şunu koşabilir (imzalı yerel paket gerektirir):

```bash
"C:\Program Files (x86)\Windows Kits\10\App Certification Kit\appcert.exe" reset
```

## Bundan sonrasını hat kendi yapar

Dört değer GitHub'da **repository variables** olarak girilir:

| Değişken | Kaynak |
|---|---|
| `MSIX_STORE_IDENTITY_NAME` | Package/Identity/Name |
| `MSIX_STORE_PUBLISHER` | Package/Identity/Publisher (`CN=…`) |
| `MSIX_STORE_PUBLISHER_DISPLAY_NAME` | Package/Properties/PublisherDisplayName |
| `MSIX_STORE_DISPLAY_NAME` | **Rezerve edilmiş uygulama adı** (Product management → Manage app name reservations) |

🔴 Dördüncüsü ilk üçüyle aynı sayfada **yazmaz** ve unutulması kolaydır:
Partner Center, paketin içindeki uygulama adının rezerve edilmiş bir adla
birebir aynı olmasını şart koşar. Eşleşmezse gönderim *"The name found in the
package is not one of your reserved app names"* ile reddedilir — kimlik,
yayıncı ve sürüm doğruyken bile. Ad, uygulamanın kod içinde taşıdığı görünen
addan **ayrı bir veridir**: mağazada `Focus Camp` rezerve edilmişken hat
paketi `Odak Kampı` adıyla üretiyordu (WP-664).

Dördü birden dolduğunda `windows-release.yml` **Store modunu** açar:

- `msix:create --store` ile **imzasız** Store paketi üretir,
- paketin kimliğini ve yayıncısını `AppxManifest.xml`'den **okuyarak doğrular**,
- paketi `windows-store-package` **artefaktına** koyar.

Dördü de boşsa hat **bugünkü davranışını aynen sürdürür** (taşınabilir ZIP).
Biri bile eksikse iş **başlamadan durur** — yarım yapılandırma, Partner
Center'ın reddedeceği bir paketi ancak koşum bittikten sonra fark ettirirdi.

## 🔴 Store paketi indirme bağlantısı olarak yayınlanmaz

Store paketi **imzasızdır** ve bu kasıtlıdır — imzayı Microsoft sertifikasyondan
sonra atar. Böyle bir dosyayı GitHub Release'e koymak v62'ye kadar yapılan
hatanın aynısı olurdu: kullanıcı indirir, **kuramaz**. Bu yüzden Store paketi
Release varlıklarına **hiç girmez**; ayrı artefakttan indirilip Partner Center'a
yüklenir. Bunu `windows_store_mode_wp597_test.dart` sözleşmeye bağlıyor.

## Gönderim

1. Sürüm koşumundan `windows-store-package` artefaktını indir.
2. Partner Center → uygulaman → **Submissions → Packages** → `.msix`'i yükle.
3. Fiyat (**ücretsiz**), yaş derecelendirmesi anketi, gizlilik politikası
   bağlantısı ve mağaza açıklamasını doldur → **Submit**.
4. Sertifikasyon tipik olarak birkaç saat–birkaç gün sürer.

## Ölçülmemiş olan (dürüstçe)

- Store hesabı olmadan bu dal CI'da **hiç koşamaz**; şu an tek koruma yukarıdaki
  metin sözleşmesidir. İlk gerçek koşum ilk gönderimde olacak.
- Paketin **sertifikasyondan geçeceği** garanti değil. Bilinen riskler: gizlilik
  politikası bağlantısı zorunlu, yaş derecelendirmesi anketi zorunlu, uygulama
  açılışta çökerse ret. Üçü de bizde hazır ama Microsoft'un kendi testinden
  geçtiğini ancak gönderince görürüz.
- Sürüm alanı kuralı: Store `1.0.<patch>.0` ister — dördüncü alan **0** olmalı.
  Hat bunu WP-568'den beri zaten böyle üretiyor.

## Kaynaklar

- [Ücretsiz bireysel geliştirici kaydı — Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/publish/whats-new-individual-developer)
- [Şirket kaydında da kayıt ücreti kaldırıldı — Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/publish/whats-new-company-developer)
- [Kod imzalama seçenekleri: Store paketlerini Microsoft imzalar — Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options)
- [MSIX paket gereksinimleri — Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements)

---

# Gönderim otomatiği (WP-669 · 2026-08-10)

Yukarıdaki **Gönderim** başlığındaki elle akış **yedek yol olarak duruyor**;
normal yol artık `.github/workflows/msstore-upload.yml`. Sahibin artefakt indirip
Partner Center'a sürüklemesi gerekmiyor.

## Hangi API — ve neden ötekisi değil

Microsoft'un iki ayrı gönderim API'si var ve **ikisi aynı şeyi yapmıyor**:

| API | Taban adres | Paket türü |
|---|---|---|
| [Store submission API for MSI or EXE app](https://learn.microsoft.com/en-us/windows/apps/publish/store-submission-api) | `https://api.store.microsoft.com` | belge paket türünü `[exe, msi]` diye sınırlıyor — **MSIX yok** |
| [Microsoft Store submission API](https://learn.microsoft.com/en-us/windows/uwp/monetize/create-and-manage-submissions-using-windows-store-services) | `https://manage.devcenter.microsoft.com/v1.0/my/` | **MSIX/appx** — kullandığımız |

Yeni olan API bizim işimizi görmüyor: MSI/EXE tarafında paket Store'a
**yüklenmez**, kendi sunucunda barındırdığın bir URL olarak verilir. Bizim
hattımızın ürettiği imzasız MSIX oraya hiç girmez. Bu yüzden hat
`manage.devcenter.microsoft.com` üzerinden çalışıyor:

- kimlik doğrulama: Azure AD (Microsoft Entra) `client_credentials`,
  `https://login.microsoftonline.com/<tenant>/oauth2/token`,
  `resource=https://manage.devcenter.microsoft.com`,
- jeton **60 dakika** geçerli,
- paket akışı: gönderim oluştur → gövdeyi güncelle → ZIP'i SAS adresine yükle →
  `commit` → durumu yokla.

## Ne otomatikleşti, ne otomatikleşmedi

🔴 **İlk gönderimi sahip elle yapar.** Kullanılan API bunu yapamıyor; belgenin
kendi şartı: *"Before you can create a submission for a given app using this
API, you must first create one submission for the app in Partner Center,
including answering the age ratings questionnaire."* Yani listeleme metni, yaş
derecelendirmesi anketi, fiyat ve ekran görüntüleri **bir kez** elle girilir.

Ondan sonrası otomatiktir: **paket güncellemesi**. Hat her sürümde yeni MSIX'i
yükler, eskisini silinmek üzere işaretler ve "Bu sürümdeki yenilikler" metnini
`app/assets/release_notes.json`den yazar (tek kaynak — Play tarafındaki kuralın
aynısı; alan sınırı
[1500 karakter](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/add-and-edit-store-listing-info)).

## İki kip — `verify` kasıtlı olarak önce

```
# 1) Ölç: kimlik, yayıncı, mağazada yayında olan sürüm, listeleme dilleri
Actions → Microsoft Store Upload → Run workflow → mode: verify

# 2) Gönder: windows-store-package artefaktını üreten koşumun ID'siyle
Actions → Microsoft Store Upload → Run workflow → mode: upload, run_id: <koşum ID>
```

Etiket değil **koşum ID** isteniyor, çünkü Store paketi imzasızdır ve GitHub
Release varlıklarına **hiç girmez** (yukarıdaki 🔴 başlık). Paket yalnız
`windows-store-package` artefaktında bulunur.

Betiğin durduğu yerler (hepsi fail-closed, hepsi `--self-test` ile ölçülüyor):

| Durum | Ne olur |
|---|---|
| Üç secret'tan biri bile eksik | İş **başlamadan** durur; yarım yapılandırma da durdurur |
| Paketin kimliği/yayıncısı mağazadakiyle uyuşmuyor | Durur — gönderim reddedilmeden önce |
| Paket sürümü ilerlemiyor (aynı ya da geri) | Durur |
| Paket sürümünün 4. alanı 0 değil (**beta paketi**) | Durur — beta mağazaya gönderilmez |
| Partner Center'da yarım kalmış bir gönderim var | Durur; üstüne yazmaz (`--allow-delete-pending` ile bilerek silinir) |
| Uygulamanın hiç yayınlanmış gönderimi yok | Durur ve "önce elle bir gönderim yap" der |
| Artefaktta 1'den farklı sayıda `.msix` | Durur; hangisinin gideceğini tahmin etmez |

Build numarası **elle girilmez**, paketin `AppxManifest.xml`indeki sürümden
türetilir (`1.0.<patch>.0` → `<patch>`). Yanlış sürümün notlarını yayınlamanın
yolu elle girilen sayıydı.

## 🔴 Sahibin yapacağı tek şey: üç değeri üretmek

Bu bir kerelik. Partner Center'da, sırayla:

1. ⚙ (sağ üst) → **Account settings** → **Tenants** →
   **Associate Microsoft Entra ID with your Partner Center account**.
   Microsoft Entra dizinin yoksa aynı ekrandan **ücretsiz** yeni bir tane
   oluşturulabiliyor.
2. **Account settings** → **User management** → **Microsoft Entra applications**
   sekmesi → **Add Microsoft Entra application** → **Create Microsoft Entra
   application**.
3. Görünen ad: `Focus Camp CI`. **Reply URL**: sahip olduğun herhangi bir adres
   (ör. deponun adresi) — 256 karakteri aşmasın. → **Next**.
4. **Roles applicable to developer programs** → **Manager** → **Create**.
5. Listede uygulamanın adına tıkla → **Tenant ID** ve **Client ID** oradadır.
6. **Add new key** → çıkan ekrandaki **Key** değerini kopyala.
   🔴 Bu değer **bir daha gösterilmez**; sayfadan çıkmadan al.
7. Üç değeri bana ver. GitHub'a şu adlarla girilecekler:
   `MS_STORE_TENANT_ID` · `MS_STORE_CLIENT_ID` · `MS_STORE_CLIENT_SECRET`.

Not: 1. ve 2. adım için Partner Center'da **Manager** rolüyle ve o Entra
dizininde **global administrator** yetkisiyle giriş yapmış olman gerekiyor.
Anahtarın bir son kullanma tarihi var ve uygulama sayfasında yazıyor; süresi
dolduğunda hat yeşile dönmez, açık bir hatayla durur.

Kaynaklar:
[tenant ilişkilendirme](https://learn.microsoft.com/en-us/windows/apps/publish/partner-center/associate-azure-ad-with-partner-center)
·
[uygulama ve anahtar](https://learn.microsoft.com/en-us/windows/apps/publish/partner-center/manage-azure-ad-applications-in-partner-center)

## Ölçüldü / ölçülemedi (WP-669)

**Ölçüldü** (kimlik bilgisi gerektirmeyen her şey):

- `python tooling/msstore/store_publish.py self-test` → `self-test: gecti`.
  Kapsadıkları: MSIX kimliğinin paketin **içinden** okunması, dört alanlı sürüm
  şeması, kimlik/yayıncı eşleşmesi, sürüm ilerlemesi, beta paketinin
  reddedilmesi, paket planı (eski → `PendingDelete`, yeni → `PendingUpload`),
  1500 karakter sınırı, yanıt-only alanların PUT gövdesine sızmaması, üç
  secret'ın fail-closed okunması (yarım yapılandırma dahil).
- Kapılar **sabote edilerek** sınandı: sürüm karşılaştırması, paket planı, beta
  kapısı ve iş akışının secret kontrolü tek tek bozuldu, dördü de kırmızı düştü,
  dördü de geri alındı (dosya hash'i sabotaj öncesine birebir döndü).
- `.github/workflows/msstore-upload.yml` YAML olarak ayrıştırıldı; WP-666/668
  "gömülü girdi" kapısına göre ihlal sayısı **0**.

**Ölçülemedi** (kimlik bilgisi henüz yok):

- Gerçek API çağrılarının **hiçbiri** koşturulmadı: jeton alma, `GET
  applications`, gönderim oluşturma, SAS'a yükleme, `commit`, durum yoklama.
  Bunların hepsi ilk gerçek koşumda sınanacak.
- Azure Blob'a yükleme başlığı (`x-ms-blob-type: BlockBlob`, tek `Put Blob`
  çağrısı) belgeye göre yazıldı ama **çalıştırılmadı**.
- `PUT` gövdesinden çıkarılan yanıt-only alan listesi (`id`, `status`,
  `statusDetails`, `fileUploadUrl`) belgeden türetildi; API'nin fazladan bir
  alanı reddedip reddetmediği ölçülmedi.
- Store'un gerçekten MSIX'i kabul edip sertifikasyondan geçireceği — bu zaten
  yukarıdaki "Ölçülmemiş olan" başlığında yazıyordu, hâlâ geçerli.

## ⚠️ Yukarıdaki bir adım artık yanlış

Bu belgenin **"Sahibin yapması gerekenler"** bölümünde 4. adım uygulama adını
`Odak Kampı` diye rezerve etmeyi söylüyor. Gerçekte mağazada rezerve edilen ad
**`Focus Camp`** oldu ve hat `MSIX_STORE_DISPLAY_NAME` değişkeninden bu adı
kullanıyor (WP-664). Rezervasyon zaten yapıldığı için o adım geçmişte kaldı;
tarihsel kayıt olarak duruyor.
