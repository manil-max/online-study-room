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

## Bundan sonrasını hat kendi yapar

Üç değer GitHub'da **repository variables** olarak girilir:

| Değişken | Kaynak |
|---|---|
| `MSIX_STORE_IDENTITY_NAME` | Package/Identity/Name |
| `MSIX_STORE_PUBLISHER` | Package/Identity/Publisher (`CN=…`) |
| `MSIX_STORE_PUBLISHER_DISPLAY_NAME` | Package/Properties/PublisherDisplayName |

Üçü birden dolduğunda `windows-release.yml` **Store modunu** açar:

- `msix:create --store` ile **imzasız** Store paketi üretir,
- paketin kimliğini ve yayıncısını `AppxManifest.xml`'den **okuyarak doğrular**,
- paketi `windows-store-package` **artefaktına** koyar.

Üçü de boşsa hat **bugünkü davranışını aynen sürdürür** (taşınabilir ZIP).
İkisi dolu biri boşsa iş **başlamadan durur** — yarım yapılandırma, Partner
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
