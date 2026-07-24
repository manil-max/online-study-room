# progress.md — Canlı Durum

> Son güncelleme: **2026-07-24** · Saat dilimi: **Europe/Istanbul**
>
> Bu dosya yalnız aktif iş, açık kabul ve ürün kararlarını taşır. Tamamlanmış WP'lerin ayrıntısı git geçmişi, [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md) ve kanonik raporlardadır; burada tekrar edilmez.

## Proje Gerçekleri

- **Stable/production:** v45 yayında. Production migration head `0065`; staging `0070`. Yeni production migration, Edge deploy veya stable tag/release yalnız ayrı, somut kullanıcı GO ile yapılır.
- **Beta/staging:** beta-v4308 staging `0070` üzerinde yayında. Proje sahibi 2026-07-24'te stable+beta yayınını ve bildirim/sayaç davranışını cihazda test etti; genel sorun yok, bekleyen cihaz kabulleri kapatıldı.
- **Release ilkesi:** Android beta/stable artefaktı Android işi başarılı olunca yayımlanır. Windows bağımsız sürer ve başarılı olursa aynı release'e eklenir; Windows hatası Android güncellemesini geri çekmez.
- **Yönetim varsayılanı:** Production `deploy_enabled/release_enabled` kapalıdır. Stable yalnız protected `production` Environment, exact SHA/head/project-ref GO ve reviewer kanıtıyla ilerler.
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md` ve `docs/KALITE-PROGRAMI.md` geçerlidir. Tek çalışma dalı `main`; her WP ayrı commit; production varsayılmaz.
- **Son WP:** **292** (286–292 planlandı, uygulanmadı) · Sıradaki boş numara: **293**.
- **Aktif tur:** Yeni Özellik Turu **Aşama A** — plan hazır, uygulama bekliyor. Kanonik plan: [`docs/YENI-OZELLIK-PLANI.md`](docs/YENI-OZELLIK-PLANI.md).

## ⚡ Aktif Çalışma Kaydı

### Gemini Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Claude Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-285 kod/test tamam; beta-v4308 P7 cihaz kabulü bekler. Timer state motoru, migration, backend ve production değişmedi.

### Codex-2 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Grok Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

## Öncelik ve Yürütme Sırası

| Öncelik | İş | Durum | Kalan gerçek iş |
|---|---|---|---|
| 0 | Production backend değişikliği | 🔴 Kapalı | Yeni migration/Edge deploy/secret yalnız backup+dry-run ve somut GO ile; v45 mevcut head `0065` ile çalışır |
| 1 | WP-287 şifre sıfırlama hatası | [ ] Bekliyor | **Canlı hata** — kod + Supabase panel adımı |
| 2 | WP-286 ayarlar IA · WP-291 boyut paneli | [ ] Bekliyor | Bağımsız, paralel gidebilir |
| 3 | WP-288 → 289 → 290 tema zinciri | [ ] Bekliyor | Seri; `core/theme/**` sıcak dosya |
| 4 | WP-292 kozmetik | [ ] Bekliyor | WP-290 sonrası + sahiple konuşma |
| Sonra | WP-276/277 ops kabulü | [ ] Bekliyor | Sentetik staging ops kanıtı; WP-276 Play Store için de gerekli |
| Karar | WP-278/279 | [?] Ürün/ops kararı | Açık sahip ve kapsam kararı olmadan başlanmaz |

## Yeni Özellik Turu — Aşama A (Plan Kuyruğu)

Konuşma fazı kapandı (9 tur). Kanonik belgeler:
- Konuşma kaydı: [`docs/YENI-OZELLIK-NOTLARI.md`](docs/YENI-OZELLIK-NOTLARI.md)
- **Detaylı teknik plan: [`docs/YENI-OZELLIK-PLANI.md`](docs/YENI-OZELLIK-PLANI.md)** ← WP'lerin gerekçesi, repo analizi, riskler burada

Sıra: **Aşama A (kod) → Aşama B (Play Store) → Aşama C (Microsoft Store).** Aşama B/C'nin WP'leri Aşama A kabulünden sonra açılır.

Önerilen yürütme sırası: **286 → 287 → 291 → 288 → 289 → 290 → 292** (286/287/291 paralel gidebilir).

> ✅ Çakışma: 286, 287, 291 ortak SAHİP dosyası paylaşmaz — paralel çalışabilir.
> ⚠️ Çakışma: **288 ve 290 seri olmalı** — ikisi de `app/lib/core/theme/**` (sıcak dosya). 290 ayrıca `app/pubspec.yaml`'a girer.
> ⚠️ Tema programı açıkken **Saat ve Başarım programları açılmaz** (`.agents/AGENTS.md §1.2`).

### WP-286: Ayarlar bilgi mimarisi — ölü kartı sil, bildirim/izin/rapor birleştir 🧹
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (plan §3 F-01 + F-02)
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** "Uygulama kısayolları (rutinler)" kartı hiçbir şeye bağlı değil (`settings_screen.dart:330-339` — `onTap` yok); ayrıca bildirim tercihleri, cihaz izinleri ve aylık rapor ayarlarda üç ayrı yerde duruyor, ilk kullanan anlamıyor.
- **Kapsam dışı:** Yeni bildirim türü, yeni izin API'si, push altyapısı değişikliği, tema.
- **SAHİP dosyalar (yaz):** `app/lib/features/profile/settings_screen.dart`, `app/lib/features/notifications/**` (yeni birleşik ekran dosyası dahil), `app/lib/features/clock/clock_widgets_screen.dart`, `app/lib/l10n/app_*.arb`, ilgili testler.
- **DOKUNMA:** `app/lib/core/theme/**`, `app/lib/core/navigation/**`, `app/pubspec.yaml`, `supabase/**`.
- **Adımlar:**
  - [ ] Kısayol kartını ve `profileUygulamaKisayollariRutinler` anahtarını 4 dilden sil (önce `grep` ile başka kullanım yok doğrula).
  - [ ] Tek ekran: **"Bildirimler ve izinler"** — mevcut kart widget'ları yeniden kullanılır, yalnız kabuk birleşir.
  - [ ] En üste **durum özeti** satırı: `ClockPermissions.instance.snapshot()` üstünden eksik izin sayısı + "Düzelt".
  - [ ] Aylık rapor switch'i ayarlar listesinden bu ekrana taşınır.
  - [ ] Ayarlar listesinde 3 giriş → 1 giriş.
- **Veri/Migration etkisi:** Yok.
- **Ortam/Deploy:** Local. Production dokunuşu yok.
- **RLS/Güvenlik:** Yok (yalnız istemci IA). `monthlyReportOptIn` yazma davranışı **değişmez**.
- **Edge-case'ler:** Kullanıcı sistem ayarından izin verip dönerse özet `resume`'da yenilenir · izin snapshot'ı hata verirse ekran çökmez · çevrimdışıda push sağlığı kartı mevcut hata durumunu korur.
- **Kabul (ölçülebilir):** Ayarlarda bildirim/izin/rapor için tek giriş · eksik izin sayısı doğru · "Düzelt" ilgili sistem ekranını açar · izin verilip dönüldüğünde özet ≤ 1 sn güncellenir · 4 dilde anahtar tam · `flutter analyze` 0.
- **Tuzaklar:** 896 satırlık bildirim ekranını sıfırdan yazmaya kalkmak (gereksiz risk — birleştir, yeniden yazma) · l10n anahtarını generated dosyadan temizlemeyi unutmak.
- **Model önerisi:** 🔵 Sonnet

### WP-287: Şifre sıfırlama derin bağlantı düzeltmesi 🔑
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (plan §3 F-03) · **canlı hata**
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** `supabase_auth_repository.dart:185` `resetPasswordForEmail`'i **`redirectTo` olmadan** çağırıyor. Supabase linki Site URL'e (`localhost:3000`) yönlendiriyor; kullanıcı "check your internet connection" hatası alıyor ve şifresini sıfırlayamıyor. Sahip stable'da doğruladı.
- **Kapsam dışı:** Yeni auth yöntemi, OAuth, e-posta şablonu tasarımı, hesap silme.
- **SAHİP dosyalar (yaz):** `app/lib/data/repositories/supabase/supabase_auth_repository.dart`, `app/lib/data/repositories/in_memory/in_memory_auth_repository.dart`, `app/lib/data/repositories/auth_repository.dart`, `app/lib/core/config/**` (redirect çözümleyici), `app/lib/features/auth/**`, ilgili testler, `docs/` runbook.
- **DOKUNMA:** `AndroidManifest.xml` (intent-filter **zaten var**, `:64`), `supabase/migrations/**`, tema.
- **Adımlar:**
  - [ ] Ortama göre `redirectTo` çözümleyici: scheme = applicationId (`build.gradle.kts:148-174` ile birebir), host `login-callback`. Sabit yazma.
  - [ ] `resetPasswordForEmail(safe, redirectTo: …)`; in_memory implementasyonu arayüzle uyumlu kalsın.
  - [ ] **ADR-5:** Android deep link + **her platformda çalışan e-posta kodu yolu** (Windows'ta protokol kaydı yok, portable ZIP'te de çalışması gerekiyor). Android akışı değişmez.
  - [ ] Ops runbook: staging + production Supabase panelinde Redirect URL allowlist ve Site URL adımları yazılır (**sahip uygulayacak**).
  - [ ] Kırmızı-yeşil test: `redirectTo` olmadan çağrıyı yakalayan regresyon testi.
- **Veri/Migration etkisi:** Yok. **Supabase panel yapılandırması var** (kod dışı).
- **Ortam/Deploy:** Kod local; panel adımı staging **ve** production auth ayarı → sahip yapar.
- **RLS/Güvenlik:** Redirect allowlist dışına açık yönlendirme bırakılmaz (open-redirect riski); yalnız uygulama scheme'leri eklenir. Token/secret loglanmaz.
- **Edge-case'ler:** Süresi dolmuş link · link iki kez tıklanması · uygulama kapalıyken tıklama · beta linkinin stable uygulamayı açması (scheme ayrımı çözüyor) · Windows'ta deep link yok (K-2).
- **Kabul (ölçülebilir):** Gerçek cihazda şifremi unuttum → e-posta → link → uygulama açılır → `RecoveryScreen` → yeni şifre → yeni şifreyle giriş başarılı. `Cihazda doğrulanmalı`.
- **Tuzaklar:** Scheme'i sabit yazıp beta/stable'ı karıştırmak · yalnız kodu düzeltip panel adımını atlamak (kullanıcı için düzelmez) · `config.toml`'u değiştirip hosted projeyi düzelttiğini sanmak.
- **Model önerisi:** 🟣 Pro

### WP-288: Tema modeli genişletmesi, yerel saklama v2 ve göç 🗄️
- **Program/Faz:** Yeni Özellik Turu · Aşama A · Tema programı · (plan §3 F-04-A, ADR-1/2/3)
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** Özel tema bugün yalnız **4 renk** tutuyor (`AppPalette` — `app_theme.dart:22-27`) ve **silme yok**. Sahip: 3 yuva, her yuvada tam tema (renk+yazı+biçim+atmosfer+his), **düzenleme ve silme**. Saklama **cihazda kalacak** (10. tur kararı — sunucu senkronu iptal).
- **Kapsam dışı:** Sihirbaz UI (WP-290), sunucu tablosu/migration/RLS (**iptal edildi**), cihazlar arası senkron, tema paylaşma, XP ile kilitleme, widget/bildirim teması.
- **SAHİP dosyalar (yaz):** `app/lib/core/theme/custom_theme.dart` (yeni), `app/lib/core/theme/theme_settings.dart`, `app/lib/core/theme/theme_tokens.dart`, `app/lib/core/theme/app_theme.dart` (`extensions:` listesi), `app/lib/main.dart` (tema karar akışı), ilgili testler.
- **DOKUNMA:** `app/lib/features/profile/**` (UI WP-290'ın), `app/pubspec.yaml` (font WP-290'ın), `supabase/**` (bu WP'nin sunucu işi YOK), `AndroidManifest.xml`.
- **Adımlar:**
  - [ ] `CustomTheme` modeli: `id` (custom_1/2/3 — **index sabit**), `name`, `isDefined`, `updatedAt`, `brightness` + 5 katman. `toMap`/`fromMap` + `schemaVersion` + eksik alanda güvenli varsayılan.
  - [ ] `toPreset(Brightness)` → **ADR-1:** özel tema `AppTheme.fromPreset` (`app_theme.dart:233`) ile render edilir; yeni render yolu yazılmaz.
  - [ ] `AppTypography` genişlet: font aileleri (başlık/gövde/sayaç), ağırlıklar, harf aralığı, ölçek. **`copyWith` ve `lerp` mutlaka güncellenir** (R4).
  - [ ] `AppFeel` katmanı iskeleti + **`app_theme.dart:338` `extensions:` listesine ekle** (R3 — eklenmezse seçim ölü anahtar olur).
  - [ ] Saklama: yeni anahtar `custom_themes_v2`, `active_custom_theme_id`, `custom_themes_migrated_v1`. Eski `custom_palettes` **okunur, silinmez, yazılmaz**.
  - [ ] `saveCustomTheme(slot, theme)` · `deleteCustomTheme(slot)` (**index kaydırmaz**, yuvayı boşaltır) · `setActiveCustomTheme(id?)`.
  - [ ] `main.dart:160-166` üç yollu olur: **özel tema > palet > aile** (ADR-3).
  - [ ] **Göç:** eski 4 renk aynı index'e taşınır; kalan alanlar **o an seçili preset'ten devralınır** (kullanıcının gördüğü görüntü değişmesin). İdempotent, bayraklı.
- **Veri/Migration etkisi:** **Yok** — sunucu şeması değişmiyor. Yalnız yerel `SharedPreferences` şeması v2. Geri alma: yeni anahtarlar silinir, eski `custom_palettes` yerinde olduğu için kullanıcı eski durumuna döner.
- **Ortam/Deploy:** Local. Production/staging dokunuşu **yok**.
- **RLS/Güvenlik:** Yok (sunucuya veri gitmiyor). Sır/token yok.
- **Edge-case'ler:** Bozuk JSON (o yuva boş olur, çökmez) · gelecekten `schemaVersion` · 3 yuva dolu · aktif tema silinmiş (palet/aile yoluna güvenli dönüş) · yeni kurulum (3 boş yuva) · göç iki kez çalışıyor.
- **Kabul (ölçülebilir):** Göç sonrası kullanıcının gördüğü tema **değişmez** (golden) · göç idempotent · silme index kaydırmaz · aktif silinince çökme 0 · 3'ten fazla tema oluşturulamaz · bozuk veride açılış çökmesi 0 · her yeni token seçimi **gerçek etki üretir** (ölü anahtar yok) · `flutter analyze` 0, testler yeşil.
- **Tuzaklar:** `extensions:` listesine yeni katmanı eklememek (R3) · `copyWith`/`lerp`'i güncellememek (R4) · göç yazmadan modeli değiştirmek (R1) · silmede index kaydırmak (R2) · **Riverpod 3:** dinleyicisiz provider her `read`'de yeniden build olur → testte `container.listen(...)` açılmazsa regresyon testi sessizce etkisiz kalır (R13) · `main.dart` sıcak dosya, aynı anda başka WP girmemeli.
- **Model önerisi:** 🔴 Opus

### WP-289: Animasyon/his araştırma turu ve katalog 🔍
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (plan §3 F-04-C)
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** Sahip tema "hissi" için oyun/uygulama örneklerinden ilham istedi ama hangi efektlerin gireceği belirsiz. WP-290'ın 6. adımı bu katalog olmadan tasarlanamaz.
- **Kapsam dışı:** Kod yazma, asset üretme, tema motoru.
- **SAHİP dosyalar (yaz):** `docs/TEMA-HIS-KATALOGU.md` (yeni), `docs/YENI-OZELLIK-PLANI.md` §3 F-04-C güncellemesi.
- **DOKUNMA:** Tüm kod dosyaları (bu WP kod yazmaz).
- **Adımlar:**
  - [ ] Yaygın tema/kişiselleştirme uygulamalarında ve oyunlarda kullanılan "his" ailelerini derle.
  - [ ] Her aile için: hangi token'larla ifade edilir (renk/şekil/atmosfer/hareket), Flutter'da maliyeti ne, performans riski ne.
  - [ ] Erişilebilirlik: "hareketi azalt" ile nasıl davranır.
  - [ ] Sahibe **kısa liste** sun; K-3 kararı birlikte verilir.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Yok. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Düşük donanımlı cihazda kare düşmesi · blur/gölge maliyeti · koyu/açık modda aynı efektin farklı görünmesi.
- **Kabul (ölçülebilir):** Katalogda her his ailesi için token karşılığı + maliyet notu + erişilebilirlik notu var; sahip kısa listeden seçim yapabildi.
- **Tuzaklar:** Telif korumalı görsel/asset kopyalamak — **yalnız fikir/teknik desen alınır**, varlık kopyalanmaz.
- **Model önerisi:** 🔵 Sonnet

### WP-290: "Kendi Temanı Oluştur" sihirbazı ve görünüm ekranı yeniden düzeni 🎨
- **Program/Faz:** Yeni Özellik Turu · Aşama A · Tema programı · (plan §3 F-04-B)
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-288 kabul + WP-289 kataloğu
- **Problem:** Görünüm ekranı bugün "renk seçimi" gibi duruyor; kullanıcı arka plan/yazı/font/şekil/atmosferi tek tek seçemiyor. Sahip adım adım, canlı önizlemeli bir oluşturucu istiyor. Ayrıca **3 yuva için düzenleme ve silme** UI'ı gerekiyor (10. tur).
- **Kapsam dışı:** Tema paylaşma/kod ile aktarma, XP ile kilit, widget/bildirim teması, yeni ekonomi kuralı, sunucu senkronu (iptal).
- **SAHİP dosyalar (yaz):** `app/lib/features/profile/appearance_screen.dart`, `app/lib/features/profile/theme_studio_screen.dart` (**kaldırılacak**), yeni sihirbaz dosyaları `app/lib/features/profile/theme_builder/**`, `app/lib/core/theme/theme_tokens.dart` (tipografi/his genişletmesi), `app/pubspec.yaml` (font asset'leri), `app/assets/fonts/**`, `app/lib/l10n/app_*.arb`, golden + widget testleri.
- **DOKUNMA:** `supabase/migrations/**`, `app/lib/core/navigation/**`, bildirim/timer kodu.
- **Adımlar:**
  - [ ] Ekran düzeni: en üstte **"Kendi Temanı Oluştur"** girişi → kullanıcının temaları (**en yeni en üstte**, `updatedAt` desc) → **ince ayraç çizgi (başlık metni yok)** → hazır temalar.
  - [ ] Her tema satırında **düzenle (✎)** ve **sil (🗑)**; silme **onay dialogu** ister. 3 yuva doluysa "oluştur" yerine net mesaj.
  - [ ] 7 adımlı sihirbaz: zemin → renkler → yazılar → biçim → atmosfer → his → özet/ad ver.
  - [ ] Her adımda **canlı önizleme** (mevcut `_LivePreview` — `theme_studio_screen.dart:482` — taşınıp genişletilir, sıfırdan yazılmaz).
  - [ ] Kontrast koruması: AA altı seçimde uyarı + tek dokunuşla düzeltme (kaydetmeyi engelleme).
  - [ ] **ADR-4:** fontlar `app/assets/fonts/**` altına paketlenir (`google_fonts` **kullanılmaz**). Yalnız SIL OFL / Apache-2.0; lisans metinleri `assets/fonts/LICENSES/`. Subset: Latin + Latin-Ext (Türkçe dahil). **`fontFamilyFallback` zorunlu** — AR locale'de kutu karakter olmasın (R7).
  - [ ] Eski `ThemeStudioScreen` **kaldırılır**; işe yarar parçalar taşınır. `custom_palette_editor.dart` gereksizleşir → kaldırılır. Eski `family`/`palette` seçimleri kırılmaz.
- **Veri/Migration etkisi:** Yok (model ve saklama WP-288'de). Yeni alan eklenirse `schemaVersion` korunur.
- **Ortam/Deploy:** Local. Sunucu/production dokunuşu yok.
- **RLS/Güvenlik:** Sunucuya veri gitmiyor. **Font asset lisansları tek tek doğrulanır.**
- **Edge-case'ler:** Hiç tema yokken sade boş durum daveti (3 boş yuva **gösterilmez** — 4. turda düşürüldü) · çok uzun tema adı (≤ 24 karakter) · okunamaz renk seçimi · sihirbaz yarıda bırakılıyor (kaydedilmemiş değişiklik uyarısı) · açık/koyu geçişi · masaüstünde sol kontrol + sağ sabit önizleme · RTL (AR) · "hareketi azalt" açıkken his efektleri durur · font yüklenemedi (fallback).
- **Kabul (ölçülebilir):** Her adımda değişiklik önizlemede ≤ 1 kare içinde görünür · kaydedilen tema uygulamanın ≥ %95 yüzeyinde token'dan uygulanır · AA altı kontrastta uyarı çıkar · kaydedilen/düzenlenen tema listenin en üstünde · silme onay ister ve sonrası çökme 0 · 3 temsili tema × açık/koyu = 6 golden yeşil · **APK boyut artışı ≤ 2.5 MB** (`--analyze-size` kanıtı) · 4 dilde anahtar tam, AR'de kutu karakter yok.
- **Tuzaklar:** Sihirbazı ekran başlıklarıyla şişirmek (sahip **sade** istedi) · `pubspec.yaml` ve `core/theme/**` sıcak dosya — aynı anda başka WP girmemeli · font paket boyutunu kontrolsüz büyütmek · AR fallback zincirini atlamak · eski kullanıcının seçili temasını bozmak.
- **Model önerisi:** 🔴 Opus

### WP-291: Ana sayfa kart boyut paneli → sabit alt panel 📐
- **Program/Faz:** Yeni Özellik Turu · Aşama A · (plan §3 F-05)
- **Ajan:** — · **Durum:** [ ] Bekliyor
- **Problem:** `_SizePanel` (`home_screen.dart:818`) grid'in altına akış içinde çiziliyor (`:487`) ve tüm gövde tek `SingleChildScrollView` içinde (`:87`). Kart aşağıdaysa panel ekrandan çıkıyor; kullanıcı sürekli aşağı yukarı kaydırmak zorunda kalıyor.
- **Kapsam dışı:** Saydamlık ayarı (**eklenmeyecek**), yeni kart türü, ızgara motoru değişikliği, tema.
- **SAHİP dosyalar (yaz):** `app/lib/features/home/home_screen.dart`, gerekiyorsa `app/lib/features/home/widgets/**` yeni panel dosyası, ilgili widget testleri.
- **DOKUNMA:** `app/lib/features/home/dashboard_providers.dart` (düzen motoru — okunur, davranışı değiştirilmez), tema, navigation.
- **Adımlar:**
  - [ ] Seçili kart state'i (`_MatrixGridState._selected`, `:300`) yukarı taşınır; grid bildirir, panel dinler.
  - [ ] `_SizePanel` `Scaffold.bottomSheet`'e bağlanır — **yalnız `_editing == true` iken** (HomeScreen kendi Scaffold'una sahip: `:161` ve `:210`).
  - [ ] Kapalı ~72 dp ince şerit (boyut), yukarı çekilince genişleyen panel (Seçenek C).
  - [ ] Grid altına panel yüksekliği kadar boşluk — son kart panelin altında kalmasın.
  - [ ] Masaüstünde dar/köşeye hizalı varyant.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local.
- **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Düzen boş → panel yok · seçili kart silinir → `_effectiveSelected()` (`:312`) ilk karta düşer · klavye açık (`viewInsets`) · düzenleme modundan çıkış · çok küçük ekran · masaüstü geniş pencere.
- **Kabul (ölçülebilir):** Düzenleme modunda sayfa en alta kaydırılsa bile panel ekranda kalır · kapalı yükseklik ≤ 80 dp, açık ≤ ekranın %40'ı · boyut değişince kart ≤ 1 kare içinde güncellenir · panel yüzünden erişilemez kart kalmaz · dokunma hedefleri ≥ 48 dp.
- **Tuzaklar:** Seçim state'ini yukarı taşırken sürükle-bırak davranışını bozmak · panel yüzünden son kartın kapanması · `_editing` kapanınca panelin ekranda kalması.
- **Model önerisi:** 🟣 Pro

### WP-292: Kozmetik tur — taç görseli ve kamp ateşi animasyonları ✨
- **Program/Faz:** Yeni Özellik Turu · Aşama A (son) · (plan §3 F-08)
- **Ajan:** — · **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-290 kabul + **sahiple ayrı konuşma turu**
- **Problem:** Profil fotoğrafı üstündeki taç sahibe göre kötü duruyor; kamp ateşi animasyonları yenilenecek. Sahip kamp ateşi tasarımını **birlikte konuşarak** yapmak istiyor.
- **Kapsam dışı:** XP/kademe mantığı, başarım motoru, tema motoru, yeni ekonomi kuralı.
- **SAHİP dosyalar (yaz):** `app/lib/core/widgets/crowned_avatar.dart`, `app/lib/features/classroom/widgets/campfire_scene.dart`, `app/lib/features/classroom/widgets/campfire/**`, `app/lib/features/classroom/widgets/camp_critter.dart`, ilgili golden testler.
- **DOKUNMA:** `app/lib/core/stats/achievement_ledger_engine.dart` (**`crownRankForXp` ve `kCrownXpThresholds` DEĞİŞTİRİLMEZ**), sunucu tarafı, tema motoru.
- **Adımlar:**
  - [ ] Kamp ateşi için sahiple konuşma turu → kararlar `docs/YENI-OZELLIK-NOTLARI.md`'ye eklenir.
  - [ ] Taç çizim katmanı yenilenir; kademe→görsel eşlemesi **birebir korunur**.
  - [ ] Golden testler güncellenir; performans (kare düşmesi) kontrol edilir.
- **Veri/Migration etkisi:** Yok. **Ortam/Deploy:** Local. **RLS/Güvenlik:** Yok.
- **Edge-case'ler:** Taçsız kullanıcı (rank null/boş) · en yüksek kademe · küçük avatar boyutları · "hareketi azalt" açık · düşük donanım.
- **Kabul (ölçülebilir):** Aynı XP → aynı kademe (regresyon testi yeşil) · taçsız durumda düz avatar · golden yeşil · animasyon "hareketi azalt" açıkken durur.
- **Tuzaklar:** Görsel değişiklik sırasında kademe eşiğini kaydırmak (kullanıcıların tacı sessizce değişir) · ağır efektle kare düşürmek.
- **Model önerisi:** 🟣 Pro

## Bekleyen Uygulanabilir WP'ler

### WP-276 — Hesap silme staging ops ve kabul kanıtı
- **Durum:** [ ] Bekliyor · **Bağımlılık:** Kurtarma release güveni; production için ayrıca somut GO.
- **Amaç:** Sentetik staging hesapta request/cancel/purge, 14 günlük grace simülasyonu, yetkisiz çağrı, retry/terminal hata ve rollback runbook'unu kanıtlamak.
- **Sınır:** Gerçek kullanıcı hesabı, production purge, yeni feature/migration kapsam dışıdır.
- **Sahip yollar:** `docs/qa/ACCOUNT-DELETION-STAGING.md`, `docs/play-store/PLAY-RELEASE-GATE.md`, redacted staging kanıtı ve yalnız gerekli testler.

### WP-277 — Başarım, görev ve grup ilerlemesi kabul matrisi
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-271 cihaz/release güveni; WP-276 ile paralel backend ops yok.
- **Amaç:** Beş süre kaynağında istatistik/XP/başarım/grup sonucunu, pending reward/claim'i, iki cihazı ve İstanbul gün sınırını sentetik staging kanıtıyla sınıflandırmak.
- **Sınır:** Yeni ekonomi kuralı, migration/backfill ve production claim kapsam dışıdır; bulunmuş hata ayrı WP olur.

### WP-278 — AR/DE dil desteği ve RTL ürün kararı
- **Durum:** [?] Kullanıcı üründe AR/DE olup olmayacağını ve çeviri sahibini belirlemeli.
- **Karar sonrası:** Evetse insan çevirisi/RTL cihaz QA için ayrı WP'ler; hayırsa EN/TR sınırı ve kullanıcıya görünen dil seçenekleri dürüstçe güncellenir.

### WP-279 — Aylık rapor canlı ops kararı
- **Durum:** [?] DNS domaini, sender, sağlayıcı, maliyet limiti ve opt-in sahibi kararı yok.
- **Sınır:** Karar olmadan secret, cron, staging/production e-posta gönderimi yapılmaz.

## Kapanan / Tekilleştirilen Kayıtlar

| Kayıt | Canlı durum |
|---|---|
| WP-269–275, 280–285 | **Kapandı (2026-07-24).** Kod/test kanıtı + proje sahibinin v45 stable ve beta-v4308 üzerindeki cihaz testi; bekleyen cihaz kabulü kalmadı |
| WP-271 | Staging gerçek push/retry ve timer action davranışı sahip testinde sorunsuz; ölçümlü matris kaydı istenirse yeni WP açılır |
| WP-225, 226, 258 | Tarihsel tamamlanmış işler; ayrıntı arşiv+git'te |
| WP-266/267/268 | Eski ayrıntılar arşivde; açık push/timer kabulü WP-271 ve QA matrisinde |

## Worker'a Verilecek Kısa Komutlar

Yeni özellik turu (önerilen sıra):
- `worker'ı oku ve WP-286'yı yap` — ayarlar temizliği + birleştirme
- `worker'ı oku ve WP-287'yi yap` — şifre sıfırlama hatası (canlı)
- `worker'ı oku ve WP-291'i yap` — boyut paneli alta sabitlensin
- `worker'ı oku ve WP-288'i yap` — tema motoru (288 bitmeden 290 başlamaz)
- `worker'ı oku ve WP-289'u yap` — animasyon araştırması
- `worker'ı oku ve WP-290'ı yap` — tema sihirbazı
- `worker'ı oku ve WP-292'yi yap` — kozmetik (önce sahiple kamp ateşi konuşması)

Önceki tur:
- `worker'ı oku ve WP-276'yı yap` · `worker'ı oku ve WP-277'yi yap`
- WP-278/279 için önce ürün/ops kararı alınır.

> Her worker önce Aktif Çalışma Kaydı'nı okur, kendi lane'ini claim eder ve SAHİP yolları çakışıyorsa başlamaz. Production/stable hiçbir WP'nin örtük parçası değildir.
