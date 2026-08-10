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
