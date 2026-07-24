# Yeni Özellik Turu — Detaylı Teknik Plan (Aşama 2)

> **Girdi belgesi:** [`docs/YENI-OZELLIK-NOTLARI.md`](YENI-OZELLIK-NOTLARI.md) (konuşma fazı, 9 tur, kapandı).
> **Bu belge:** o kararların kod gerçeğiyle buluşturulmuş hâli — ne, nerede, nasıl, hangi riskle.
> **Sonraki adım:** WP kartları `progress.md` Plan Kuyruğu'na yazılır, sonra worker'lar uygular.
>
> Tarih: **2026-07-24** · Kurallar: `.agents/AGENTS.md` · `docs/KALITE-PROGRAMI.md`
> Kanıt etiketleri: `Kodda doğrulandı` · `Cihazda doğrulanmalı` · `Ürün kararı gerekiyor`

---

## 0. Yönetici özeti

Sekiz başlık konuşuldu. Kod gerçeğiyle karşılaştırınca **iş yükü beklenenden farklı dağılıyor**:

| # | İş | Görünen zorluk | **Gerçek zorluk** | Neden |
|---|---|---|---|---|
| F-01 | Kısayol kartını sil | Küçük | **Küçük** | Kart zaten ölü; 10 satır + l10n temizliği |
| F-02 | Ayarları birleştir | Orta | **Orta** | Yeni ekran değil; iki ekranı tek çatı altına almak + durum özeti |
| F-03 | Şifre linki hatası | Bilinmiyordu | **Küçük (kod) + ops** | Kök neden bulundu; 1 satırlık `redirectTo` + Supabase panel ayarı |
| F-04 | Tema yenilemesi | Büyük | **ÇOK BÜYÜK** | Sadece UI değil: tema verisi bugün **cihazda**, hesaba taşınması migration + repo katmanı demek |
| F-05 | Boyut paneli | Orta | **Küçük-orta** | Panel var, sadece yeri değişecek; ama seçim state'i yukarı taşınmalı |
| F-06 | Windows dağıtımı | Orta | **Kod işi yok** | Tek kod tabanı; iş tamamen Store süreci (Aşama C) |
| F-07 | Mağaza hazırlığı | Büyük | **Büyük ama dokümanlı** | WP-259/260/261 + Play tarafı zaten yazılmış |
| F-08 | Kozmetik/animasyon | Belirsiz | **Belirsiz — araştırma bekliyor** | Sahiple konuşarak yapılacak |

**En kritik tek cümle:** F-04'ün gerçek maliyeti tema *arayüzü* değil, **tema verisinin cihazdan hesaba taşınması**.
Bugün tema `SharedPreferences`'ta, 3 sabit yuvada ve sadece 4 renk tutuyor. İstenen: sınırsız, çok alanlı,
hesapta saklanan tema. Bu bir **veri modeli değişimi + migration + çift repo implementasyonu**dur.

---

## 1. Repo analizi — bugünkü gerçek (`Kodda doğrulandı`)

### 1.1 Proje temeli

| Konu | Durum |
|---|---|
| Çatı | Flutter, tek kod tabanı; Android + Windows aynı ekranları kullanır |
| Platform ayrımı | Yalnız `isDesktopWindow` bayrağı (`core/desktop/desktop_window_io.dart:15`) ile yerleşim dallanması |
| Durum yönetimi | Riverpod 3 (`NotifierProvider`) |
| Yerel depolama | `SharedPreferences` (`core/prefs/app_prefs.dart`) |
| Sunucu | Supabase; **tek yetkilendirme katmanı RLS** |
| Migration zinciri | `supabase/migrations/` → son numara **0070**, **sıradaki 0071** |
| Migration head | production `0065`, staging `0070` |
| l10n | 4 dil: `app_tr.arb`, `app_en.arb`, `app_de.arb`, `app_ar.arb` (+ generated) |
| Test | 132 test dosyası; `flutter analyze` 0 uyarı ve yeşil test commit şartı |
| Sürümler | stable **v45**, beta **beta-v4308** yayında |

### 1.2 Ayarlar ekranı — bugünkü kart sırası

`app/lib/features/profile/settings_screen.dart` (394 satır):

| Sıra | Kart | Hedef | Not |
|---|---|---|---|
| … | Yasal merkez | `LegalCenterScreen` | |
| … | Engellenen kullanıcılar | `BlockedUsersScreen` | |
| ~176 | **Görünüm ve atmosfer temaları** | `AppearanceScreen` | **F-04 buraya** |
| ~192 | Uygulama dili | dropdown | |
| ~240 | Kamp hayvanın | dialog | |
| ~259 | **Bildirim merkezi** | `NotificationCenterScreen` | **F-02 birleşecek** |
| ~279 | **Widget ve alarm izinleri** | `ClockWidgetsScreen` | **F-02 birleşecek** |
| ~293 | **Aylık çalışma raporu** | `SwitchListTile` (satır içi) | **F-02 birleşecek** |
| ~312 | Sürüm ve güncellemeler | `ReleaseNotesScreen` | |
| **~330** | **Uygulama kısayolları (rutinler)** | **YOK** | **F-01 → silinecek** |
| ~341 | Geri bildirim gönder | dialog | |
| ~354 | Yönetim (admin) | `AdminScreen` | yalnız admin |

**F-01 kanıtı:** `settings_screen.dart:330-339` — `ListTile`'da `onTap` yok, `subtitle` yok, `trailing` yok.
Kart tıklanabilir görünüyor ama hiçbir şeye bağlı değil. Sahibin gözlemi kodla birebir örtüşüyor.

### 1.3 Tema sistemi — **en kritik bölüm**

Dosyalar:

| Dosya | Satır | Rolü |
|---|---|---|
| `core/theme/theme_tokens.dart` | 429 | **5 katman ThemeExtension**: `AppColors`, `AppTypography`, `AppShapes`, `AppAtmosphere`, `AppMotion` |
| `core/theme/theme_presets.dart` | 534 | Hazır aile/preset tanımları |
| `core/theme/theme_settings.dart` | 185 | **Tercih saklama** (SharedPreferences) + provider |
| `core/theme/app_theme.dart` | — | `ThemeData` üretimi, `AppPalette` |
| `features/profile/appearance_screen.dart` | 309 | Görünüm ekranı: stüdyo girişi + mod + hazır paletler + özel paletler |
| `features/profile/theme_studio_screen.dart` | 616 | WP-55 adım akışı: aile → mood → şekil → önizleme |
| `features/profile/widgets/custom_palette_editor.dart` | 172 | Özel palet dialog'u |

**İyi haber — token katmanı zaten zengin.** İstenen "tek tek seçim" için gereken alanların çoğu var:

```
AppColors     : surface1, surface2, scaffold, primary, onPrimary, accent, onAccent,
                textPrimary, textSecondary, border, success, error, onError   (13 renk)
AppTypography : displayClock, title, body, label + useSerifTitles, useMonospaceClock
AppShapes     : radiusSm/Md/Lg, cardElevation, borderWidth, sharp
AppAtmosphere : gradientStart, gradientEnd, glowColor, glowStrength, blurSigma, glassOpacity
AppMotion     : fast, normal, slow, respectReduceMotion    ← animasyon altyapısı ZATEN VAR
```

**Kötü haber — saklama katmanı istenen şeyi karşılamıyor:**

| Konu | Bugün | İstenen | Fark |
|---|---|---|---|
| Nerede saklanıyor | **SharedPreferences = sadece o cihaz** (`theme_settings.dart:65-69`) | **Hesapta** | Yeni tablo + migration + repo |
| Kaç özel tema | **Tam 3, sabit** (`theme_settings.dart:104` → `while (customPalettes.length < 3)`) | **Sınırsız** | Liste modeli değişecek |
| Özel temada ne var | **4 renk**: primary, onPrimary, accent, onAccent | 13 renk + font + şekil + atmosfer + animasyon | Model 4 alandan ~30 alana çıkıyor |
| Kimlik | **`custom_1/2/3` — index tabanlı** (`theme_settings.dart:35-41`) | Sınırsızda index çöker | UUID'ye geçiş + geriye uyumluluk |
| Renk kaynağı | `family` / `palette` ikiliği (`ThemeColorSource`) | Tek akış | Sadeleştirme + eski seçim göçü |

> ⚠️ **`AppMotion` bir tuzak barındırıyor:** Altyapı var ama içi neredeyse boş — yalnız `fast/normal/slow`
> süreleri. Sahibin istediği "vintage / eskimiş kutu / neon" hissi **süre değil doku+şekil+efekt** demek.
> Yani animasyon işi `AppMotion`'a üç sayı yazmakla bitmez; yeni bir "his/doku" katmanı gerekir.

### 1.4 Şifre sıfırlama — kök neden

| Adım | Kanıt |
|---|---|
| Çağrı | `data/repositories/supabase/supabase_auth_repository.dart:185` → `resetPasswordForEmail(safe)` — **`redirectTo` yok** |
| Sonuç | Supabase, e-posta linkini projenin **Site URL**'ine yönlendirir |
| Site URL | `supabase/config.toml:43` → `http://127.0.0.1:3000` (yerel varsayılan; hosted projede de düzeltilmemiş) |
| Gözlem | Sahip: link **`localhost:3000`** açıyor, tarayıcı "check your internet connection" diyor |
| Uygulama hazır mı | **Evet** — `recovery_screen.dart` (127 satır) + `authRepository.passwordRecoveryEvents` + `auth_gate.dart:39` dinliyor |
| Deep link altyapısı | **Var ama kullanılmıyor**: `AndroidManifest.xml:64` → `<data android:scheme="${authCallbackScheme}" android:host="login-callback" />` |
| Scheme değerleri | `android/app/build.gradle.kts:148-174` → stable `com.manilmax.onlinestudyroom`, beta `…​.beta`, local `…​.local` |
| Dart tarafı | `grep login-callback lib/` → **0 sonuç.** Intent-filter tanımlı, hiç kullanılmıyor |

**Teşhis kesin:** Zincirin tek eksik halkası `redirectTo`. Altyapının geri kalanı yerinde duruyor.

### 1.5 Ana sayfa kart düzeni (F-05)

- `features/home/home_screen.dart` (1103 satır). `HomeScreen` **kendi `Scaffold`'unu** kuruyor —
  hem masaüstü dalı (`:161`) hem mobil dal (`:210`). → `Scaffold.bottomSheet` doğrudan kullanılabilir. ✅
- `_SizePanel` (`:818`) **`_MatrixGrid`'in içinde**, grid'in altına `Column` çocuğu olarak ekleniyor (`:487`).
- Tüm gövde tek `SingleChildScrollView` içinde (`:87`) → panel sayfayla birlikte kayıyor. **Şikayetin sebebi bu.**
- Seçili kart state'i `_MatrixGridState._selected` (`:300`) — yani **iç state**. Panel dışarı taşınırsa
  bu state'in yukarı çıkması gerekir.
- Panelde bugün **yalnız genişlik/yükseklik `−/+`** var. Saydamlık/hizalama **yok** (sahibin sorusu cevaplandı).

### 1.6 Kozmetik yüzeyler (F-08)

| Konu | Dosya |
|---|---|
| Kamp ateşi sahnesi | `features/classroom/widgets/campfire_scene.dart` |
| Ateş katmanı | `features/classroom/widgets/campfire/layered_campfire_fire.dart` |
| Hayvanlar | `features/classroom/widgets/camp_critter.dart` |
| **Taç** | `core/widgets/crowned_avatar.dart` + `core/widgets/crown_tiers_sheet.dart` |
| Taç kademesi mantığı | `core/stats/achievement_ledger_engine.dart:358` → `crownRankForXp(int xp)` |

> ⚠️ Taç **XP'den türeyen bir göstergedir** ve XP server-authoritative'dir. Görseli değiştirirken
> `crownRankForXp` ve eşik sabitleri (`kCrownXpThresholds`) **kesinlikle değiştirilmez** — yoksa
> kullanıcıların görünen kademesi sessizce kayar.

---

## 2. Kritik bulgular ve riskler

### 🔴 R1 — Tema hesaba taşınırken mevcut kullanıcıların teması kaybolabilir
Bugün tema cihazda. Hesaba taşırken göç (migration) yazılmazsa, güncelleme sonrası herkes varsayılan temaya düşer.
**Önlem:** İlk açılışta yerel `SharedPreferences` temaları okunup hesaba **bir kez** yükleyen idempotent göç;
yerel kayıt silinmez (geri dönüş güvenliği). Göç bayrağı yerelde tutulur.

### 🔴 R2 — `custom_1/2/3` index tabanlı kimlik, sınırsız temada çöker
`theme_settings.dart:35-41` id'yi `custom_` + index diye ayrıştırıyor. Sınırsız temada silme/sıralama olunca
index kayar ve **kullanıcı yanlış temayı görür**.
**Önlem:** Yeni model UUID kullanır; eski `custom_N` id'leri göç sırasında UUID'ye eşlenir ve eşleme tablosu saklanır.

### 🔴 R3 — Aktif tema cihaz başına, tema listesi hesapta (sahip kararı)
Bu bilinçli bir ikilik: **tanım sunucuda, seçim yerelde.** Yanlış uygulanırsa "telefonda seçtiğim tema
bilgisayarımı da değiştirdi" şikayeti gelir.
**Önlem:** Sunucuda **yalnız tema tanımı** tutulur. `active_theme_id` **asla** sunucuya yazılmaz; `SharedPreferences`'ta kalır.
Test: iki cihaz simülasyonunda aktif seçim sızmadığı doğrulanır.

### 🟠 R4 — Font seçimi için projede hiç font yok
`pubspec.yaml:115-124` → `fonts:` bloğu **tamamen yorumda**. `google_fonts` paketi de **yok**.
Bugün "serif/monospace" yalnız sistem ailesi adıyla çözülüyor (`theme_tokens.dart:132-133`).
**Seçenekler:**
- (a) **3-6 font ailesini asset olarak paketle** — çevrimdışı çalışır, boyut ~1-3 MB artar. **Önerilen.**
- (b) `google_fonts` ekle — ilk kullanımda ağdan indirir; çevrimdışıda ve mağaza incelemesinde risk.
**Karar gerekiyor** (bkz. §7 K-1). Lisans: yalnız SIL OFL / Apache-2.0 fontlar paketlenir.

### 🟠 R5 — Erişilebilirlik: kullanıcı okunamaz tema üretebilir
Kullanıcı arka planı ve yazı rengini tek tek seçebilecek → siyah üstüne koyu gri yazı mümkün.
DoD zaten WCAG AA kontrast şartı koyuyor (`AGENTS.md §3`).
**Önlem:** Her renk adımında **canlı kontrast göstergesi**; AA altındaysa uyarı + "otomatik düzelt" önerisi.
Kaydetmeyi engellemeyiz (kullanıcının hakkı), ama **uyarmadan geçirmeyiz**.

### 🟠 R6 — "Sıcak dosya" çakışması
`AGENTS.md §1.4` sıcak dosyaları: `app/pubspec.yaml`, `core/theme/**`, `core/navigation/**`,
`supabase/migrations/**`, l10n/generated, `AndroidManifest.xml`.
Bu turda **F-04 `core/theme/**` + `pubspec.yaml` + `migrations/`** üçüne birden giriyor.
**Önlem:** F-04 kendi içinde **motor → UI** diye ikiye bölünür ve bu ikisi **seri** çalışır.
F-04 sürerken başka WP `core/theme/**`'e giremez.

### 🟠 R7 — Büyük program çakışması kuralı
`AGENTS.md §1.2`: **Saat, Tema ve Başarım aynı anda açılmaz.** Bu turda Tema açılıyor →
Saat ve Başarım programları bu tur boyunca kapalı kalır. F-08'in taç işi Başarım'ın *görselidir*,
mantığına dokunmadığı sürece çakışma saymaz; yine de F-04 bittikten sonra yapılır.

### 🟡 R8 — Şifre sıfırlama Windows'ta deep link ile çözülmez
`myapp://login-callback` şeması **Android'de** kayıtlı. Windows MSIX tarafında protokol kaydı yok.
**Sonuç:** Sadece `redirectTo` eklemek Windows kullanıcısını çözmez.
**Önlem (planda):** Windows için ya protokol kaydı eklenir ya da **OTP/kod ile sıfırlama** yolu açılır
(Supabase `verifyOTP`). Kod yolu her platformda çalışır ve daha basittir. Bkz. §7 K-2.

### 🟡 R9 — Supabase panel ayarı = ops işi, kod işi değil
`redirectTo` eklense bile Supabase projesinin **Redirect URL allowlist**'inde o adres yoksa istek reddedilir.
Bu **panelden** yapılır, repodan değil; `supabase/config.toml` yalnız local'i etkiler.
**Sonuç:** F-03'ün bir kod adımı, bir de **sahip tarafından panelde yapılacak** adımı var. İkisi olmadan düzelmez.

### 🟡 R10 — l10n dört dil
Her yeni metin `app_tr.arb`, `app_en.arb`, `app_de.arb`, `app_ar.arb` dosyalarına girer.
Tema sihirbazı çok metin getirecek. Eksik çeviri sessiz hata üretir (ekranda anahtar adı görünür).
**Önlem:** Her WP'nin DoD'sinde "4 dilde anahtar tam" maddesi.

---

## 3. Özellik başına detaylı tasarım

### F-01 — "Uygulama kısayolları (rutinler)" kartını sil

**Yapılacak**
1. `settings_screen.dart:330-339` arasındaki `_SettingsCard` bloğu ve öncesindeki `SizedBox(height: 10)` silinir.
2. `profileUygulamaKisayollariRutinler` anahtarı 4 `.arb` dosyasından ve generated dosyalardan temizlenir.
3. Kullanılmayan `Icons.shortcut_outlined` importu kalmadıysa dokunulmaz (Material tek import).

**Tuzak:** l10n anahtarını silmeden önce `grep` ile başka kullanım olmadığı doğrulanır.
**Kabul:** Ayarlar listesinde kart yok; `flutter analyze` 0; l10n generate sonrası 4 dilde build yeşil.

---

### F-02 — "Bildirimler ve izinler" birleşik ekranı

**Hedef:** Üç ayrı giriş → tek giriş. Ad: **"Bildirimler ve izinler"** (sahip kararı).

**Yeni ekran iskeleti** (`features/notifications/notifications_and_permissions_screen.dart` — yeni dosya):

```
┌ Durum özeti (en üstte, tek satır)          ← YENİ
│  ✓ Her şey hazır        /  ⚠ 2 izin eksik — Düzelt
├ Bölüm 1: Bana ne gelsin
│  (mevcut NotificationCenterScreen içeriği: türler, sessiz saatler,
│   hatırlatıcılar, duyurular, push sağlığı)
├ Bölüm 2: Cihaz izinleri
│  (mevcut ClockWidgetsScreen içeriği: bildirim, tam zamanlı alarm,
│   pil, tam ekran, widget)
└ Bölüm 3: E-posta
   Aylık çalışma raporu  [switch]           ← ayarlardan buraya taşındı
```

**Teknik yaklaşım — yeniden yazma değil, birleştirme.**
`NotificationCenterScreen` 896 satır, `ClockWidgetsScreen` 340 satır. İkisini sıfırdan yazmak
gereksiz risk. Bunun yerine mevcut kart widget'ları (`_TypesCard`, `_QuietHoursCard`, `_RemindersCard`,
`_AnnouncementsCard`, `_PushHealthCard`, `_PermTile`, `_WidgetCard` …) **olduğu gibi yeniden kullanılır**;
yalnız üstlerindeki `Scaffold`/`AppBar` kabuğu tek ekrana indirilir.

**Durum özeti nasıl hesaplanır**
`ClockPermissions.instance.snapshot()` zaten bir `ClockPermissionSnapshot` döndürüyor
(`core/time_engine/clock_permissions.dart`; `clock_widgets_screen.dart:20,42` kullanıyor).
Özet satırı bu snapshot'tan türer — **yeni izin API'si yazılmaz.**

**Sadelik kuralı (sahip):** Mobilde ekran küçük; bölüm başlıkları minimum, gereksiz boşluk yok.

**Edge case'ler:** izin durumu ekran açıkken değişebilir (kullanıcı sistem ayarından döner) →
`WidgetsBindingObserver` ile `resume`'da snapshot yenilenir (mevcut ekranda bu desen zaten var).
Çevrimdışı → push sağlığı kartı hata durumunu zaten ele alıyor.

**Kabul (ölçülebilir):**
- Ayarlar listesinde bildirim/izin/rapor için **tek** giriş kalır (3 → 1).
- Eksik izin varken özet satırı eksik sayısını doğru gösterir; "Düzelt"e basınca ilgili sistem ekranı açılır.
- Sistem ayarından izin verilip dönüldüğünde özet ≤ 1 sn içinde güncellenir.
- Aylık rapor switch'i yeni yerinde çalışır; `monthlyReportOptIn` sunucuya yazılır (davranış değişmez).

---

### F-03 — Şifre sıfırlama linki düzeltmesi

**İki parça var; ikisi de şart.**

**(a) Kod tarafı**
```
supabase_auth_repository.dart:185
  await _client.auth.resetPasswordForEmail(safe);
→ await _client.auth.resetPasswordForEmail(safe, redirectTo: <ortama uygun adres>);
```
Adres nasıl türetilir: scheme = applicationId (build.gradle.kts ile birebir) →
stable `com.manilmax.onlinestudyroom://login-callback`, beta `…​.beta://login-callback`,
local `…​.local://login-callback`. Sabit yazılmaz; `package_info_plus` ile çalışma anında paket adından
üretilir veya `DistributionConfig` yanına bir `AuthRedirectConfig` eklenir.
`in_memory` repo da aynı arayüzü korur (`AGENTS.md §2` çift implementasyon kuralı).

**(b) Ops tarafı — sahip yapacak (`Ürün kararı gerekiyor` / panel erişimi)**
Supabase panelinde **her iki proje için** (staging + production):
- Redirect URL allowlist'ine yukarıdaki scheme'ler eklenir.
- Site URL `localhost:3000` ise gerçek bir değere çekilir.
> Bu **production auth yapılandırması**dır. Kod tarafı bu adım olmadan da güvenle merge edilir ama
> **kullanıcı için düzelmiş olmaz.**

**(c) Windows açığı (R8)**
Deep link Android'e özgü. Windows'ta iki seçenekten biri seçilecek (§7 K-2):
- **Seçenek 1 — OTP/kod:** Kullanıcı e-postadaki 6 haneli kodu uygulamaya girer. Her platformda çalışır,
  deep link gerekmez, en sağlamı. Ek UI: küçük bir "kodu gir" ekranı.
- **Seçenek 2 — Windows protokol kaydı:** MSIX manifestine protokol eklenir. Yalnız kurulu MSIX'te çalışır,
  portable ZIP'te çalışmaz.

**Edge case'ler:** süresi dolmuş link · link ikinci kez tıklanması · uygulama kapalıyken tıklanması ·
farklı flavor'ın (beta/stable) linkini yanlış uygulamanın açması → scheme ayrımı bunu zaten çözüyor.

**Kabul:** Gerçek cihazda: şifremi unuttum → e-posta → linke dokun → uygulama açılır → `RecoveryScreen`
gelir → yeni şifre kaydedilir → yeni şifreyle giriş yapılır. `Cihazda doğrulanmalı`.

---

### F-04 — Tema sistemi yenilemesi (**en büyük iş, ikiye bölünüyor**)

#### F-04-A · Veri modeli ve hesap senkronu (motor)

**Yeni tablo** — `supabase/migrations/0071_user_custom_themes.sql`:

```
public.user_themes
  id           uuid primary key default gen_random_uuid()
  user_id      uuid not null references auth.users(id) on delete cascade
  name         text not null                      -- kullanıcının verdiği ad
  payload      jsonb not null                     -- tema tanımı (versiyonlu)
  schema_version int not null default 1
  created_at   timestamptz not null default now()
  updated_at   timestamptz not null default now()
```
- **RLS:** `user_id = auth.uid()` — select/insert/update/delete hepsinde. Başkasının teması görünmez.
- **Sınır:** Sınırsız denildi; yine de **kötüye kullanım koruması** olarak satır başına `payload` boyut
  kısıtı (ör. ≤ 16 KB) ve kullanıcı başına makul üst sınır (ör. 200) konur — bu kullanıcıya "sınır" gibi
  hissettirmez ama veri tabanını korur.
- **Geri alma:** `drop table public.user_themes;` (migration başlığında zorunlu rollback bloğu ile).

**Neden `jsonb`?** Tema alanları (renkler, font, şekil, atmosfer, hareket) zamanla değişecek.
Her alan için kolon açmak her yeni özellikte migration demek. `schema_version` + `jsonb` ileriye dönük
esneklik verir; okuma tarafında bilinmeyen alan yok sayılır, eksik alan varsayılana düşer.

**Dart tarafı**
- `core/theme/custom_theme.dart` (yeni): `CustomTheme` modeli — `id`, `name`, ve 5 katmanın serileştirilmiş hâli.
  `fromMap`/`toMap` + `schemaVersion` + eksik alanda güvenli varsayılan.
- `data/repositories/custom_theme_repository.dart` (abstract) + `supabase/` + `in_memory/` implementasyonları
  (**AGENTS.md §2: ikisi de zorunlu**).
- `theme_settings.dart` genişletilir: liste artık `List<CustomTheme>`, kaynak sunucu; `activeThemeId`
  **yerelde kalır** (R3).

**Göç (R1/R2) — idempotent, tek yönlü, veri kaybı yok**
1. Uygulama açılışında yerel `custom_palettes` okunur (`theme_settings.dart:96`).
2. Varsayılandan farklı olan her palet, `user_themes`'e UUID ile bir kez yüklenir.
3. Yerelde `themes_migrated_v1 = true` bayrağı yazılır; yerel kayıtlar **silinmez**.
4. Eski `custom_N` → yeni UUID eşlemesi yerelde saklanır ki aktif seçim bozulmasın.

**Kabul (ölçülebilir):**
- Aynı hesapla iki cihazda giriş → tema **listesi** ikisinde de aynı; **aktif seçim** birbirini etkilemez.
- Göç iki kez çalıştırılırsa mükerrer tema oluşmaz (idempotent).
- Başka kullanıcının `user_themes` satırı RLS ile okunamaz (abuse testi).
- Çevrimdışı: sunucuya ulaşılamazsa uygulama son bilinen tema ile açılır, çökmez.

#### F-04-B · "Kendi Temanı Oluştur" sihirbazı (UI)

**Ekran düzeni (sahip kararı, başlıksız/sade):**
```
┌ [ Kendi Temanı Oluştur ]        ← en üstte büyük giriş kartı
│  senin temaların (en yeni en üstte)
│  ────────────────────────       ← ince ayraç çizgi, BAŞLIK METNİ YOK
│  hazır temalar
```

**Sihirbaz adımları** (her adımda **canlı önizleme**, altta sabit "geri / ileri"):

| Adım | İçerik | Token karşılığı |
|---|---|---|
| 1. Zemin | açık/koyu, arka plan (`scaffold`), yüzey 1-2 | `AppColors.scaffold/surface1/surface2` |
| 2. Renkler | vurgu, ikincil vurgu, üstü metin renkleri, kenarlık | `primary/onPrimary/accent/onAccent/border` |
| 3. Yazılar | başlık fontu, gövde fontu, sayaç fontu, kalınlık, harf aralığı, ölçek | `AppTypography` (genişletilecek) |
| 4. Biçim | köşe yuvarlaklığı, kenarlık kalınlığı, yükseklik/gölge, keskinlik | `AppShapes` |
| 5. Atmosfer | degrade, parıltı gücü, bulanıklık, cam etkisi | `AppAtmosphere` |
| 6. His/animasyon | hazır "his" seçenekleri (araştırma çıktısı) | `AppMotion` + **yeni doku katmanı** |
| 7. Özet | ad ver, kaydet | — |

**Canlı önizleme:** `theme_studio_screen.dart:482` içinde `_LivePreview` (sahte dashboard + sayaç) zaten var.
Sıfırdan yazılmaz, **genişletilir** — her adımda o adımın etkisini vurgulayan bir önizleme gösterilir.

**Kontrast koruması (R5):** 1. ve 2. adımda metin/zemin kontrastı hesaplanır; AA altındaysa satır içi uyarı
ve tek dokunuşla düzeltme önerilir.

**Silinecek:** `theme_studio_screen.dart` (WP-55 akışı) — sahip "yerine geçsin" dedi. Silmeden önce
`_LivePreview` ve işe yarar parçalar yeni ekrana taşınır.

**Kabul (ölçülebilir):**
- Her adımda yapılan değişiklik önizlemede **≤ 1 kare** içinde görünür.
- Kaydedilen tema uygulamanın **≥ %95 yüzeyinde** token'dan uygulanır (KALITE-PROGRAMI §4.4 kriteri).
- Kontrast AA altındaki seçimde uyarı görünür.
- Yeni tema kaydedilince listenin **en üstünde** çıkar.
- Golden testler: 3 temsili özel tema × açık/koyu.

#### F-04-C · Animasyon/"his" araştırması — **plan girdisi, henüz yapılmadı**

Sahip: *"oyunlarda ve uygulamalarda çok güzel temalar var, onlardan animasyon/efekt bakıp örnek almak lazım."*
Karar: bu araştırma **F-04-B'nin 6. adımı yazılmadan önce** yapılacak.

**Ham fikir listesi (araştırma sonrası budanacak/değişecek):**
modern-minimal · vintage/retro gren · eskimiş karton kutu · neon/cyber · kâğıt-defter ·
zen/yumuşak · cam (glassmorphism) · düz (flat).
**Erişilebilirlik şartı:** sistem "hareketi azalt" ayarına saygı + uygulama içinden kapatma
(`AppMotion.respectReduceMotion` zaten bu iş için var).

---

### F-05 — Kart boyut paneli → sabit alt panel (Seçenek C)

**Hedef:** Panel sayfayla kaymaz; altta sabit ince şerit, yukarı çekilince genişler.

**Teknik yaklaşım**
1. `_SizePanel` `_MatrixGrid`'in `Column`'undan çıkarılır (`home_screen.dart:484-499`).
2. `HomeScreen`'in kendi `Scaffold`'una `bottomSheet:` olarak bağlanır — **yalnız `_editing == true` iken**.
3. Seçili kart state'i (`_MatrixGridState._selected`, `:300`) yukarı taşınır: `HomeScreen` state'ine ya da
   düzenleme moduna özel küçük bir `ValueNotifier`'a. Grid seçimi bildirir, alt panel dinler.
4. Kapalı yükseklik ~72 dp (boyut kaydırıcısı), açık yükseklikte kart adı + `−/+` + diğer eylemler.
5. `_editing` kapanınca panel kaldırılır; grid'in altına **panel yüksekliği kadar boşluk** eklenir ki
   son kart panelin altında kalmasın.

**Kapsam dışı:** saydamlık ayarı **eklenmeyecek** (sahip kararı).

**Edge case'ler:** düzen boş (`layout.isEmpty`) → panel görünmez · seçili kart silinirse
`_effectiveSelected()` (`:312`) zaten ilk karta düşüyor, korunur · masaüstünde geniş ekranda panel
gereksiz yer kaplamamalı → masaüstünde daha dar/köşeye hizalı varyant · klavye açıkken panel ile
çakışma (`viewInsets`).

**Kabul (ölçülebilir):**
- Düzenleme modunda sayfa en alta kadar kaydırılsa bile panel ekranda kalır (kaybolmaz).
- Panel kapalıyken yüksekliği ≤ 80 dp; açıkken ekranın ≤ %40'ı.
- Boyut değişince kart ≤ 1 kare içinde yeni boyutu alır (mevcut davranış korunur).
- Panel yüzünden hiçbir kart erişilemez hâle gelmez (alt boşluk testi).
- Dokunma hedefleri ≥ 48 dp (DoD).

---

### F-06 / F-07 — Dağıtım ve mağazalar (Aşama B ve C)

**F-06 kod işi yoktur.** Tek kod tabanı olduğu için F-01…F-05 Windows'a otomatik gelir.
Windows dağıtımı, sahip kararıyla **Microsoft Store** üzerinden yapılacak → F-07'nin C ayağı.

**Aşama B — Play Store**
Mevcut doküman: `docs/PLAY-STORE-HAZIRLIK-TARAMASI.md`, `docs/play-store/PLAY-RELEASE-GATE.md`.
Yapılacaklar: Play Console hesabı (sahip) · uygulama içi hesap silme (**WP-276 buraya bağlanıyor,
Play zorunlu kılıyor**) · gizlilik politikası + destek adresi · Veri güvenliği formu · listeleme görselleri ·
`play` flavor'ının sideload updater'sız doğrulanması (altyapı `distribution_channel.dart`'ta hazır) ·
kapalı test → açık test → yayın.

**Aşama C — Microsoft Store**
Mevcut doküman: `docs/WINDOWS-STORE-PLAN.md` (WP-259 yerel QA · WP-260 Store kimliği · WP-261 marka/listeleme ·
WP-262 private pilot). Bugünkü engel: paket `CN=Msix Testing` test publisher'ı ile imzalı; kalıcı Store
identity alınmadan yayın olmaz.

**Not:** Bu iki aşama bu belgede **yol haritası düzeyinde** kalır; WP kartları Aşama A bittikten sonra,
o günün gerçeğine göre açılır (erken açılan mağaza WP'si bayatlar).

---

### F-08 — Kozmetik tur (Aşama A'nın sonunda)

1. **Kamp ateşi animasyonları** — `campfire_scene.dart`, `layered_campfire_fire.dart`, `camp_critter.dart`.
   **Sahip şartı: birlikte konuşularak yapılacak.** Tek başına tasarlanmayacak → iş sırası gelince
   ayrı bir konuşma turu açılır, sonra kodlanır.
   *Bağlam:* hayvanlar şu an vektör fallback; tasarımcı asset'i beklemede (`references/campfire/TASARIMCI_BRIEF.md`).
2. **Taç görseli** — `core/widgets/crowned_avatar.dart`. ⚠️ `crownRankForXp` ve `kCrownXpThresholds`
   **değiştirilmez**; yalnız çizim katmanı yenilenir.
3. **Sahibin sonra göstereceği animasyon noktaları** — yeri geldiğinde işaret edilecek.

---

## 4. İş paketi dökümü

> Son WP numarası `progress.md` → **285**. Bu turun WP'leri **286**'dan başlar.

| WP | Ad | Bağımlılık | Sıcak dosya | Model |
|---|---|---|---|---|
| **286** | Ayarlar bilgi mimarisi: kısayol kartını sil + "Bildirimler ve izinler" birleştirmesi (F-01 + F-02) | — | l10n | 🔵 Sonnet |
| **287** | Şifre sıfırlama derin bağlantı düzeltmesi (F-03 kod) + ops runbook | — | — | 🟣 Pro |
| **288** | Tema veri modeli, `0071` migration, hesap senkronu ve göç (F-04-A) | — | `migrations/`, `core/theme/**` | 🔴 Opus |
| **289** | Animasyon/his araştırma turu ve katalog (F-04-C) | — | — | 🔵 Sonnet |
| **290** | "Kendi Temanı Oluştur" sihirbazı + görünüm ekranı yeniden düzeni (F-04-B) | 288, 289 | `core/theme/**`, `pubspec.yaml` (font), l10n | 🔴 Opus |
| **291** | Ana sayfa boyut paneli → sabit alt panel (F-05) | — | — | 🟣 Pro |
| **292** | Kozmetik tur: taç görseli + kamp ateşi (F-08) | 290 + **sahiple konuşma** | — | 🟣 Pro |

### Önerilen sıra ve gerekçe

```
1. WP-286  ← küçük, görünür kazanım, hiçbir şeye bağımlı değil
2. WP-287  ← canlı hata; kullanıcıyı bugün etkiliyor, kod tarafı küçük
3. WP-291  ← bağımsız, sahibi her gün rahatsız eden UX sorunu
4. WP-288  ← tema motoru (migration + senkron) — tek başına, kimse core/theme'e girmez
5. WP-289  ← araştırma (288 sürerken paralel gidebilir, kod dosyasına dokunmaz)
6. WP-290  ← tema sihirbazı (288 + 289 kabul edilmeden başlamaz)
7. WP-292  ← kozmetik, en son
```

### Çakışma matrisi

- ✅ **WP-286 / 287 / 291 birbirinden bağımsız** — ortak SAHİP dosyası yok, paralel çalışabilir.
  (286 l10n'e, 287 auth repo'ya, 291 home_screen'e girer.)
- ⚠️ **WP-288 ve WP-290 seri olmalı** — ikisi de `core/theme/**` (sıcak dosya). Aynı anda açılmaz.
- ⚠️ **WP-290 `pubspec.yaml`'a girer** (font asset'leri) — o sırada başka WP pubspec'e dokunamaz.
- ✅ **WP-289 hiçbir kod dosyasına yazmaz** (yalnız doküman) — herkesle paralel gidebilir.
- ⚠️ **Tema programı açıkken Saat ve Başarım programları kapalı** (`AGENTS.md §1.2`).
- ✅ Şu an tüm lane'ler boşta (`progress.md` Aktif Çalışma Kaydı) → başlangıç için çakışma yok.

### Her WP'de zorunlu (DoD — `AGENTS.md §3`)

`flutter analyze` 0 uyarı · ilgili testler yeşil · yeni mantık birim/entegrasyon testiyle örtülü ·
görsel değişiklik golden ile · boş/hata/çevrimdışı ele alındı · RLS/güvenlik değerlendirmesi ·
migration + geri alma · erişilebilirlik (WCAG AA kontrast, 48 dp dokunma, açık/koyu) ·
**4 dilde l10n anahtarı tam** · tek ayrık commit, yalnız kendi SAHİP yolları.

---

## 5. Ne yapılmayacak (kapsam kalkanı)

- Kısayol/rutin özelliği **gelmeyecek** — kart siliniyor, geri dönüş planı yok.
- Widget **saydamlık** ayarı eklenmeyecek.
- Tema **paylaşma / kod ile içe aktarma** bu turda yok.
- Tema **XP/seviye ile kilitleme** bu turda yok (sonra).
- Tema kapsamı **ana ekran widget'ı ve bildirim panelini içermiyor** — yalnız uygulama içi.
- Güncelleme için **push bildirimi** yapılmayacak.
- Aşama A sürerken **production backend değişikliği yok** (`0071` yalnız local + staging'e gider;
  production terfi ayrı GO ister — `AGENTS.md §2`).

---

## 6. Aşama A'nın bitiş tanımı

Aşama A **bitti** denebilmesi için:
1. WP-286…292 hepsi "Otomatik test geçti" seviyesinde,
2. bir beta sürümü (`beta-v44xx`) yayımlanmış ve **gerçek cihazda** sahip tarafından kabul edilmiş,
3. şifre sıfırlama akışı uçtan uca cihazda doğrulanmış (Supabase panel adımı dahil),
4. tema göçü gerçek bir hesapta iki cihazda doğrulanmış,
5. sonrasında stable sürüm — normal release kapısından (`AGENTS.md §3` release kalite kapısı).

---

## 7. Açık kararlar (`Ürün kararı gerekiyor`)

| # | Karar | Seçenekler | Claude önerisi |
|---|---|---|---|
| **K-1** | Font kaynağı | (a) 3-6 fontu asset olarak paketle (b) `google_fonts` ile ağdan indir | **(a)** — çevrimdışı çalışır, mağaza incelemesinde sürprizi olmaz; boyut artışı kabul edilebilir |
| **K-2** | Windows'ta şifre sıfırlama | (a) e-postadaki 6 haneli kod (b) Windows protokol kaydı | **(a)** — her platformda çalışır, portable ZIP'te de çalışır, daha az kırılgan |
| **K-3** | Hangi "his" seçenekleri girecek | WP-289 araştırma çıktısından seçilecek | Araştırma sonrası birlikte seçilir |
| **K-4** | Supabase panel adımı (F-03 ops) | Sahip staging + production panelinde Redirect URL ekleyecek | Kod hazır olunca yapılır; Claude panele erişemez |

---

## 8. Bu planın kanıt durumu

- §1 Repo analizi: **`Kodda doğrulandı`** — her satır dosya:satır referansıyla.
- §3 Tasarımlar: **öneri**; uygulama sırasında worker detayları netleştirir.
- §4 WP dökümü: `progress.md` Plan Kuyruğu'na yazılacak; numaralar 285'ten devam.
- Cihaz davranışı gerektiren her kabul: **`Cihazda doğrulanmalı`**.
- F-04-C animasyon kataloğu: **henüz yapılmadı** — WP-289'un çıktısı.
