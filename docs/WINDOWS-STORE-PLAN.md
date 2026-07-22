# Odak Kampı — Windows Store Hazırlık ve Test Planı

> Plan tarihi: 2026-07-22 · Karar: Stable dağıtım kanalı **Microsoft Store MSIX**.
>
> Bu planın amacı uygulamayı halka açmadan önce üretim kimliği, güncelleme davranışı,
> masaüstü kalite kanıtı ve Store listeleme paketini güvenle doğrulamaktır.

## Durum tespiti

`Kodda doğrulandı`:

- v43 GitHub release'i Windows MSIX/ZIP içerir; Windows CI analiz, test, Windows release build ve SHA-256 artefaktlarını üretir.
- Uygulama açılışta GitHub release kontrolü yapıp MSIX'i indirerek Windows kurulum yüzeyini açabilir. Bu, kullanıcı tarafından ertelenebilen bir sideload akışıdır; Store güncellemesi değildir.
- Bu bilgisayardaki kurulu `OdakKampi.App` sürümü `1.0.0.0`, `CN=Msix Testing` publisher'lı test paketidir. Üretim Store kimliğine yerinde yükseltme kabul edilmez; test paketini etkilemeden ayrı sandbox/VM'de doğrulama yapılır.
- Store kapak görseli, ekran görüntüsü seti ve Store kimliği henüz yoktur. Windows ikonu 2026-07-11 tarihli varlıktır.

## Kanal sözleşmesi

| Kanal | Amaç | Backend | Güncelleme sahibi |
|---|---|---|---|
| Local QA | Windows Sandbox/VM'de geliştirici doğrulaması | staging test hesabı veya local | Elle, iki paketle kanıt |
| Store Private Audience | Seçili testçi Microsoft hesapları | staging | Microsoft Store |
| Store public stable | Herkes | production | Microsoft Store |
| GitHub Release | Beta/QA/portable | staging (beta) veya yalnız doğrulama | Best-effort; Store stable'a uygulanmaz |

## Canlıya çıkmadan test yolu

1. **Windows Sandbox veya temiz VM:** Ana bilgisayardaki test paketini kaldırmadan, izole Windows 11 ortamında çalışılır. Bu PC Windows 11 Home olduğu için Sandbox uygun değildir; koşum, ayrı VM veya ikinci PC'de [`WINDOWS-VM-QA.md`](WINDOWS-VM-QA.md) ile yapılır.
2. **Staging manifesti:** CI'ın geçici oluşturduğu staging env düzeni kullanılır; gerçek production hesabı/verisiyle test yapılmaz. `env.json` veya secret repoya yazılmaz.
3. **İki sürümlü paket provası:** Aynı yalnız-QA identity/publisher ile `N` ve `N+1` MSIX üretilir. Temiz kurulum → giriş → timer/senkron → `N+1` update → veri korunumu → uninstall senaryosu video/ekran kanıtıyla yürütülür.
4. **Store private pilot:** Partner Center'da Private Audience seçilir; yalnız seçilen Microsoft hesabı e-postaları paketi ve listelemeyi görebilir. Bu paket Store sertifikasyonundan geçer ama halka görünmez.
5. **Public yok:** Private pilot sonrası bile public submission/rollout, WP-262 kanıtları ve o anki somut kullanıcı GO olmadan yapılmaz.

Microsoft'un Private Audience özelliği, listemeyi ve indirmeyi yalnız seçilen hesaplara kısıtlar; package flight daha sonra bu grubun alt kümelerine yeni paket verme imkânı sağlar. Kaynaklar: [Private audience](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/visibility-options) · [Package flights](https://learn.microsoft.com/en-us/windows/apps/publish/package-flights).

## İş paketleri

### WP-259: Windows QA Temeli ve Yerel İki-Sürüm Provası 🧪

- **Program/Faz:** Windows Store ürünleştirme · Faz 1
- **Durum:** [ ] Bekliyor
- **Problem:** Mevcut CI artefakt üretir; ancak temiz Windows'ta kurulum, update ve kaldırma için doldurulmuş kanıt yoktur. Ana bilgisayarda eski test paketini bozmak güvenli değildir.
- **Kapsam dışı:** Store hesabı açma, public Store yayınlama, üretim backend/migration değişikliği.
- **SAHİP dosyalar (yaz):** `scripts/windows_fast_smoke.ps1`, `scripts/windows_local_dev.ps1`, `docs/QA-WINDOWS.md`, `scripts/windows_smoke_screenshot.ps1`, Windows odaklı test/kanıt dosyaları, `docs/WINDOWS-STORE-PLAN.md`, `progress.md`.
- **DOKUNMA:** `app/pubspec.yaml`, `app/lib/features/updater/**`, `.github/workflows/windows-release.yml`, production secrets/migration'lar.
- **Adımlar:** 10 saniyelik yerel smoke aracıyla her geliştirme turunda görünür pencere + yeni screenshot kanıtı al; Sandbox/VM prosedürünü ve redacted kanıt şablonunu ekle; staging manifestiyle iki artan build üret; W-01…W-06, W-10…W-22'yi temiz VM'de çalıştır; ekran ölçekleri, klavye, uyku/uyanma ve aynı test hesabıyla Android+Windows senkronunu kanıtla.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Local + staging test hesabı; public/production deploy yok.
- **RLS/Güvenlik:** Secret, token ve gerçek kullanıcı verisi ekran kaydına/kanıta girmez; test paketi production endpoint'e bağlanmaz.
- **Kabul:** İki MSIX arasında update sonrası oturum, yerel tercih ve giriş korunur; uninstall sonrası paket görünmez; 1366×768/%100, 1080p/%125, 1440p/%150 koşumlarında overflow 0; P0/P1 0.
- **Tuzaklar:** Ana PC'deki `CN=Msix Testing` paketini kaldırmak; ZIP'i update kanıtı saymak; production hesabını test etmek.
- **Model önerisi:** 🟣 Pro.

### WP-260: Store Kimliği, Paketleme ve Kanal Ayrımı 🏪

- **Program/Faz:** Windows Store ürünleştirme · Faz 2
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-259 yerel QA geçer; Partner Center hesabı/uygulama adı kullanıcı tarafından açılır.
- **Problem:** Test publisher'lı MSIX, Store kimliği ve Store-managed update için geçerli değildir. Stable Store paketinde GitHub sideload updater'ı kalmamalıdır.
- **Kapsam dışı:** Public submission/rollout, yeni ürün özelliği, App Installer/direct-download kanalı.
- **SAHİP dosyalar (yaz):** `app/pubspec.yaml`, `app/lib/core/config/distribution_channel.dart`, `app/lib/features/updater/**`, `.github/workflows/windows-release.yml`, yeni Store packaging/test dosyaları, `docs/WINDOWS-RELEASE-GATE.md`, `docs/QA-WINDOWS.md`, `progress.md`.
- **DOKUNMA:** Android flavor/manifestleri, Supabase migration'ları, uygulama feature kodu.
- **Adımlar:** Partner Center'dan verilen kalıcı package identity/publisher'ı al; Store MSIX config ve CI doğrulamasını buna bağla; Store build'inde GitHub API/download/installer yolunun erişilemediğini test et; beta GitHub ve Store artefaktlarını ayrı ad/manifest/versiyonla üret; Store upload paketi ve provenance manifestini hazırla.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Yerel/CI package validation; Store public yok. Private Audience'a yükleme WP-262'dir.
- **RLS/Güvenlik:** Store/Partner Center erişim tokenı yalnız secret store'da; PFX alınmaz ve repoya yazılmaz; stable Store paketi production backend dışına bağlanamaz.
- **Kabul:** Store build'inde sideload updater network çağrısı 0; package identity/publisher Partner Center değeriyle birebir; stable/beta backend uyuşmazlığı fail-closed; CI artefaktı sürüm, SHA, commit, backend ve migration head taşır.
- **Tuzaklar:** Test publisher'ını Store'a taşımak; aynı identity ile GitHub test paketi ve Store paketini karıştırmak; Store package'te updater UI'ını yalnız gizlemek.
- **Model önerisi:** 🔴 Opus.

### WP-261: Windows Marka, Kapak ve Store Listeleme Paketi 🎨

- **Program/Faz:** Windows Store ürünleştirme · Faz 2 (WP-260 ile paralel olabilir)
- **Durum:** [ ] Bekliyor
- **Problem:** Mevcut ikon eski; Store için kapak/hero, ekran görüntüsü, Türkçe açıklama ve destek/gizlilik yüzeyleri hazır değil.
- **Kapsam dışı:** Uygulama işlevi, tema motoru, Store'a public yayın.
- **SAHİP dosyalar (yaz):** yeni `app/assets/branding/windows/**`, `app/windows/runner/resources/app_icon.ico`, Store listing asset/brief dosyaları, `docs/WINDOWS-STORE-PLAN.md`, ilgili görsel golden dosyaları, `progress.md`.
- **DOKUNMA:** `app/lib/core/theme/**`, navigation, `app/pubspec.yaml`, CI/packaging dosyaları.
- **Adımlar:** Odak Kampı görsel yönünü onayla; Windows/Store ikon seti ve hero tasarla; 4–6 gerçek Windows ekran görüntüsünü (Ana Sayfa, Saat/Compact Focus, Gruplar, İstatistik, Profil) üret; TR ana açıklama/EN kısa açıklama, destek ve gizlilik bağlantılarını Store formuna hazırla; 100–200% DPI'da ikon ve screenshot QA yap.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Yerel render/golden; Store public yok.
- **RLS/Güvenlik:** Ekran görüntülerinde gerçek e-posta, access token, özel grup içeriği veya kullanıcı verisi bulunmaz.
- **Kabul:** Her required Store görseli doğru ölçüde; Start menü/Settings/Store'da yeni ikon tutarlı; 4–6 screenshot'ta kişisel veri 0, overflow 0; ürün sahibi tasarım kabulü alınır.
- **Tuzaklar:** Rastgele görseli app icon yapmak; eski test build ekranını Store screenshot'ı saymak; yalnız 1× DPI kontrolü.
- **Model önerisi:** 🟣 Pro + görsel üretim.

### WP-262: Private Audience Pilot ve Public Store GO Kapısı 🚦

- **Program/Faz:** Windows Store ürünleştirme · Faz 3
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-259, WP-260, WP-261 ürün kabulü.
- **Problem:** Public Store yayını öncesi gerçek Store imza/kurulum/güncelleme davranışını güvenli bir kitlede kanıtlamak gerekir.
- **Kapsam dışı:** Yeni feature, production DB/migration, kullanıcı GO olmadan public listing veya rollout.
- **SAHİP dosyalar (yaz):** `docs/QA-WINDOWS.md`, Store submission/provenance kanıtları, `docs/WINDOWS-RELEASE-GATE.md`, `progress.md`.
- **DOKUNMA:** Uygulama feature kodu, `supabase/**`, Store kimliği (WP-260 kabulünden sonra sabittir).
- **Adımlar:** Partner Center'da Private Audience grubu oluştur; seçili hesaplara Store build gönder; install/update/Store auto-update/cold start/telemetry-off senaryolarını test et; pilot P0/P1=0 ise public listing materyalini son kez kontrol et; kullanıcıya public GO paketi sun.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Store Private Audience; public Store yalnız açık kullanıcı GO sonrası.
- **RLS/Güvenlik:** Pilot yalnız test hesapları ve staging backend ile; secret/production veri yok; public submission yetkisi kullanıcıda kalır.
- **Kabul:** Seçili test hesapları dışında listeleme/indirme 0; iki Store build arasında update ve veri korunumu kanıtlı; 72 saat pilotta P0/P1=0; public paket için kimlik, sürüm, Store metadata, gizlilik ve QA kanıtları eksiksiz.
- **Tuzaklar:** "Unlisted"ı private sanmak; private pilotu production verisiyle yapmak; pilotu public GO kabul etmek.
- **Model önerisi:** 🔴 Opus.

## Public yayından önce karar listesi

1. Partner Center hesabı: bireysel mi, şirket mi? Store'da gösterilecek publisher adı buna göre kalıcıdır.
2. Store adı: `Odak Kampı` uygunluğu ve rezervasyonu.
3. Pilot testçileri: Microsoft hesabıyla giriş yapan 2–5 kişi.
4. Public GO: WP-262 sonunda ayrı, somut karar. Bu plan tek başına yayın yetkisi değildir.
