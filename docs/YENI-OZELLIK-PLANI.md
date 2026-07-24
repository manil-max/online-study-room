# Yeni Özellik Turu — Bağlayıcı Uygulama Planı (Aşama A)

> **Sürüm: rev. 3 · 2026-07-24 · Durum: worker'a verilebilir.**
> rev.2 yamalarla üretildiği için eski ve yeni tasarımı bir arada taşıyordu (senior 2. inceleme, P1).
> Bu belge **baştan yazıldı**; her konunun tek bir tanımı var. Çelişen eski metin bırakılmadı.
>
> **Girdi:** [`docs/YENI-OZELLIK-NOTLARI.md`](YENI-OZELLIK-NOTLARI.md) — sahiple 10 turluk konuşma (kapandı).
> **Çıktı:** `progress.md` Plan Kuyruğu · WP-286…295.
> **Kurallar:** `.agents/AGENTS.md` · `docs/KALITE-PROGRAMI.md`.
> **Kanıt etiketleri:** `Kodda doğrulandı` · `Cihazda doğrulanmalı` · `Ürün kararı gerekiyor`.
>
> Bu belge devredilebilir yazıldı: okuyan kişi projeyi hiç görmemiş olabilir.

---

## 0. Yönetici özeti

| WP | İş | Boyut | Bağımlılık |
|---|---|---|---|
| **293** | **Gate 0:** ortam durum modeli + production kapısını yeniden kilitle | M | — · **her şeyden önce** |
| 287 | Şifre sıfırlama: `redirectTo` + OTP (**canlı hata**) | M | 293 |
| 286 | Ayarlar: ölü kartı sil + bölüm ayıklama + izin API'si + birleştirme | M | 293 |
| 291 | Ana sayfa kart boyut paneli → sabit alt panel | M | 293 |
| 289 | His araştırması + **`AppFeel` şema kararı** | S (doküman) | 293 |
| 288 | Tema modeli (light+dark) + saklama v2 + göç | **L** | 289 · **golden baseline** |
| 294 | l10n borcu + audit genişletme + CI kapısı | M | **K-7 (AR/DE ürün kararı)** |
| 290 | "Kendi Temanı Oluştur" sihirbazı | **L** | 288 |
| 292 | Kozmetik: taç görseli | S | 290 |
| 295 | Kozmetik: kamp ateşi | M | sahiple konuşma |

**Aşama A bitişi = WP-286…295'in tamamı** (293/294/295 dahil).

### 0.1 Bu turda kesin kapsam dışı

Kısayol/rutin özelliği · widget saydamlık ayarı · tema paylaşma/kod ile aktarma · tema XP kilidi ·
temanın widget/bildirim paneline uzanması · güncelleme push bildirimi · **production'a yeni migration** ·
Play/Microsoft Store işleri (Aşama B ve C) · genel `dart format` temizliği · dependency güncellemeleri ·
yasal metinlerin mimari olarak dışarı taşınması.

---

## 1. Ortam durum modeli (WP-293'ün temeli)

> ✅ **WP-293 uygulandı (2026-07-24).** Altı gerçek `progress.md` Proje Gerçekleri'ne kanonik olarak yazıldı; production `deploy_enabled` yeniden `false` kilitlendi; guard testleri 51/51 yeşil. Aşağıdaki bölüm bu WP'nin gerekçesi ve durum modelinin referansı olarak kalır.

> **rev.3 düzeltmesi.** rev.2 "dört belge aynı head'i söylesin" diyordu. **Bu yanlıştı** —
> altı ayrı gerçek var ve bunları tek sayıya indirmek operasyon bilgisini yok eder.

`Kodda doğrulandı` + canlı workflow kanıtı:

| # | Gerçek | Değer | Kaynak |
|---|---|---|---|
| 1 | Repo/local migration zinciri | **`0070`** | `supabase/migrations/` son dosya `0070_require_pg_net_for_push_dispatch.sql` |
| 2 | Staging uygulanmış head | **`0070`** | `deploy-contract.json` staging + staging workflow kanıtı |
| 3 | Production **etkin şema** | **`0070`** | Database Gates koşumu başarılı; `0066–0070` manuel uygulandı + post-check |
| 4 | Production **CLI migration history** | **legacy / uzlaştırılmamış** | `docs/recovery/PRODUCTION-BASELINE.md:63` — normal `schema_migrations` geçmişi yok |
| 5 | Deploy contract **hedef/izin** head'i | **`0070`** | `tooling/release/deploy-contract.json` |
| 6 | Stable v45 artefakt manifesti | **`0065`** (tarihsel) | v45 release manifesti; production sonradan `0070`e yükseldi |

**Neden `0066–0070` history'siz uygulandı:** `tooling/supabase/remote.ps1` içinde
`manual-push-0066-0070` adında ayrı, allowlist/hash korumalı bir action var (`remote.ps1:158`).
Production'da normal migration history tablosu bulunmadığı için standart `db push` yolu kullanılamamış.

**Sonuç — WP-293'ün işi bunları tek sayıya indirmek DEĞİL**, altısını da **ayrı ayrı, doğru şekilde
belgelemek**. "Production `0070`" demek yeterli değil; "etkin şema `0070`, CLI history uzlaştırılmamış,
v45 manifesti tarihsel `0065`" demek gerekiyor.

### 1.1 Operasyon borcu — production deploy kapısı ✅ yeniden kilitlendi (WP-293)

`Kodda doğrulandı` — `tooling/release/deploy-contract.json` (WP-293 sonrası):
```json
"production": { "migration_head": "0070", "deploy_enabled": false, "release_enabled": false }
```
`deploy_enabled: true`, tek seferlik sahip-yönlendirmeli `0066–0070` terfisi için açılmıştı
(`8b53290`). Terfi bitti, kapı açık kalmıştı → **WP-293 `false`'a kilitledi**, `guard.tests.ps1` buna çekildi.

`remote.ps1:133` bu bayrağı `apply` / `manual-push-*` / `bootstrap-*` / `reconcile-*` action'larının
ön koşulu olarak okuyor. Yani kapı açık kaldıkça bu yollar teknik olarak çalıştırılabilir durumda.

**P0 değil** — çünkü `remote.ps1:148` production `apply` için ayrıca exact SHA, beklenen head,
project-ref, backup kanıtı ve protected environment onayı istiyor (`Assert-ProductionApproval`).
Ama **tek kullanımlık yetki iş bitince kapanmalıydı.**

> ⚠️ **Kural notu:** `AGENTS.md §2`, contract kapısının "test ve kabul kanıtı olmadan değiştirilmesini"
> ve "workflow'u geçirmek için geçici bypass" yazılmasını yasaklıyor. **Kapıyı SIKILAŞTIRMAK
> (`true → false`) bu yasağın kapsamında değildir** — yasak, kapıyı gevşetmeye yöneliktir.
> Sıkılaştırma serbesttir ve WP-293'ün asıl işidir. Gevşetmek somut GO ister.

---

## 2. Repo analizi — bugünkü gerçek

Bu bölümün tamamı `Kodda doğrulandı` (2026-07-24 tarihli ağaç).

### 2.1 Proje temeli

| Konu | Durum |
|---|---|
| Çatı | Flutter; **tek kod tabanı**, Android + Windows aynı ekranlar |
| Platform ayrımı | Yalnız `isDesktopWindow` (`core/desktop/desktop_window_io.dart:15`) |
| Durum yönetimi | Riverpod 3 (`NotifierProvider`) |
| Yerel depolama | `SharedPreferences` (`core/prefs/app_prefs.dart`) |
| Sunucu | Supabase; tek yetkilendirme katmanı **RLS** |
| l10n | 4 katalog: `app_tr/en/de/ar.arb` + generated |
| Test | 132 dosya, 690 test yeşil. **Golden test YOK** (§2.5) |
| Sürüm | stable **v45**, beta **beta-v4308** |
| Git | Tek dal `main`; branch/merge/push yok; WP başına tek ayrık commit; `git add -A` yasak |

Komutlar (hepsi `app/` içinde):
```bash
flutter run   --dart-define-from-file=env.json     # env ZORUNLU, yoksa sessizce InMemory moda düşer
flutter test  --dart-define-from-file=env.json
flutter analyze                                     # --dart-define-from-file KABUL ETMEZ
```

### 2.2 Ayarlar ekranı

`features/profile/settings_screen.dart` (394 satır). Bu turda dokunulacak satırlar:

| Satır | Kart | İşlem |
|---|---|---|
| ~176 | Görünüm ve atmosfer temaları → `AppearanceScreen` | WP-290 |
| ~259 | Bildirim merkezi → `NotificationCenterScreen` | WP-286 birleştir |
| ~279 | Widget ve alarm izinleri → `ClockWidgetsScreen` | WP-286 birleştir |
| ~293 | Aylık çalışma raporu (satır içi `SwitchListTile`) | WP-286 içeri taşı |
| **329-339** | **Uygulama kısayolları (rutinler)** | **WP-286 sil** |

Ölü kart kanıtı (`:330-339`): `ListTile`'da `onTap` yok, `subtitle` yok, `trailing` yok.
⚠️ `device_integration_listener.dart` ve `samsung_modes_service.dart` içindeki "routine/shortcut"
kelimeleri **Samsung Modes & Routines** entegrasyonudur — ilgisiz, **dokunulmaz**.

### 2.3 Tema sistemi

```
main.dart:143-166          ← tema seçimini ThemeData'ya çeviren TEK yer (SICAK DOSYA)
  themeSettingsProvider    ← core/theme/theme_settings.dart:182 (NotifierProvider, auto-dispose DEĞİL)
  AppTheme                 ← core/theme/app_theme.dart
     fromFamily      :172  · aile yolu (karşı parlaklığı TÜRETİR)
     fromPreset      :233  · preset yolu
     dark(palette)   :257  · palet yolu — taban: themePresetById(migratePaletteIdToPreset(palette.id))
     light(palette)  :279  · palet yolu — taban: SABİT 'nordic_snow'
     _buildFromTokens:297  → extensions: :338 · textTheme: :414
  theme_presets.dart       ← ThemePreset:8 · kThemePresets:90 · themePresetById:511
  theme_tokens.dart        ← 5 ThemeExtension katmanı (429 satır)
```

**Token katmanları:** `AppColors` (13 renk, `:7`) · `AppTypography` (`:110`) · `AppShapes` (`:199`) ·
`AppAtmosphere` (`:279`) · `AppMotion` (`:337`). Hepsi `copyWith` + `lerp` taşıyor.

#### 🔴 Bulgu A — açık ve koyu tema FARKLI tabanlardan geliyor

`app_theme.dart:257-295`:
- `dark(palette)` → taban `themePresetById(migratePaletteIdToPreset(palette.id))` — **palet id'sine göre değişir**
- `light(palette)` → taban **sabit `nordic_snow`**

Yani bir özel palet için açık ve koyu tema, birbirinden bağımsız iki token tabanından üretiliyor.
**Sonuç:** "iki varyantı tek preset'ten türet" yaklaşımı kullanıcının gördüğü görüntüyü **değiştirir**.
Göç algoritması bunu hesaba katmak zorunda (§4.5).

#### 🔴 Bulgu B — `fromFamily` karşı modda kullanıcı seçimini eziyor

`app_theme.dart:197-228`: karşı parlaklıkta `ColorScheme.fromSeed` + `AppColors.fromScheme(scheme)`
kullanılıyor. `primary`/`onPrimary`/`accent`/`onAccent` korunuyor ama **`textPrimary`, `textSecondary`,
`border` tohumdan türetiliyor**. Kullanıcı 13 rengi tek tek seçerse, karşı modda bir kısmı sessizce kaybolur.

#### 🔴 Bulgu C — `TextTheme` kapsaması %24

`app_theme.dart:414-418` yalnız 4 slot dolduruyor: `displayLarge`, `titleLarge`, `bodyMedium`, `labelMedium`.

Uygulamanın gerçek kullanımı (`grep textTheme\.\w+`, 375 çağrı):

| Slot | Kullanım | Tema kontrolünde? |
|---|---|---|
| `titleMedium` | 85 | ❌ |
| `bodySmall` | 71 | ❌ |
| `labelSmall` | 58 | ❌ |
| `bodyMedium` | 50 | ✅ |
| `titleSmall` | 35 | ❌ |
| `labelMedium` | 23 | ✅ |
| `titleLarge` | 17 | ✅ |
| `labelLarge` | 17 | ❌ |
| `headlineSmall` | 10 | ❌ |
| `bodyLarge` | 5 | ❌ |
| `displaySmall`+`headlineMedium`+`displayMedium` | 4 | ❌ |

**90 / 375 = %24.** Kullanıcı font seçse bile yüzeylerin **%76'sında hiçbir şey değişmez.**

#### Saklama katmanının sınırları — `theme_settings.dart`

| Konu | Bugün | Kanıt |
|---|---|---|
| Özel tema sayısı | 3, sabit doldurulur | `:104` `while (customPalettes.length < 3)` |
| Özel temada ne var | **4 renk** (primary/onPrimary/accent/onAccent) | `AppPalette` → `app_theme.dart:22-27` |
| Kimlik | `custom_1/2/3`, index tabanlı ayrıştırma | `:35-41` |
| Kaydetme | `saveCustomPalette(int, AppPalette)` → **`void`, `await`siz** | `:127-145` |
| Silme | **YOK** | — |

### 2.4 Şifre sıfırlama — kök neden zinciri

| # | Halka | Durum |
|---|---|---|
| 1 | `auth_screen.dart:78,210` tetikler | ✅ |
| 2 | `supabase_auth_repository.dart:185` → `resetPasswordForEmail(safe)` | ❌ **`redirectTo` yok** |
| 3 | `redirectTo` yoksa link Site URL'e gider | — |
| 4 | `supabase/config.toml:43` → `http://127.0.0.1:3000` (yalnız local'i etkiler) | ❌ |
| 5 | Kullanıcı gözlemi: link `localhost:3000` açıyor | ❌ stable'da doğrulandı |
| 6 | `AndroidManifest.xml:64` intent-filter | ✅ **var** |
| 7 | Scheme'ler: `build.gradle.kts:148/157/166/174` | ✅ var |
| 8 | Dart tarafında kullanım: `grep login-callback lib/` | ❌ **0 sonuç** |
| 9 | `recovery_screen.dart` + `passwordRecoveryEvents` + `auth_gate.dart:39` | ✅ **hazır** |

Tek kopuk halka: **#2/#8**.

### 2.5 🔴 Bulgu D — projede golden test YOK

`grep -rn "matchesGoldenFile\|golden" app/test` → **0 sonuç**.
`app/test/core/theme_engine_test.dart` yalnız yapısal assertion kullanıyor.

> rev.2'de "mevcut golden'lar bu WP'nin güvenlik ağıdır" yazmıştım. **Bu ifade yanlıştı.**
> Güvenlik ağı yok; **WP-288 önce onu kurmak zorunda.**

### 2.6 🔴 Bulgu E — izin okuma fail-open (üç ayrı yoldan)

`core/time_engine/clock_permissions.dart`:
```dart
Future<ClockPermissionSnapshot> snapshot() async {
  if (!_android) return ClockPermissionSnapshot.ok;   // ← desteklenmeyen platform = "ok"
  try { ... } catch (_) {}                            // ← native hata yutuluyor
  return ClockPermissionSnapshot.ok;                  // ← hata da "ok"
}
```
Ek olarak: `ClockPermissionSnapshot.fromMap` eksik native alanları **`true`** sayıyor;
`requestNotifications` Android implementasyonu `null` dönerse **`true`** sayıyor.

**Üç ayrı fail-open yolu var.** Native kanalın bozuk olduğu cihazda uygulama "her şey hazır" der,
bildirim hiç gelmez — sessiz hata. Bu **mevcut bir ürün hatasıdır**, yalnız plan sorunu değil.

### 2.7 Ana sayfa kart düzeni

`features/home/home_screen.dart` (1103 satır):

| Satır | Bulgu |
|---|---|
| `:87` | Tüm gövde tek `SingleChildScrollView` |
| `:161` / `:210` | Masaüstü ve mobil dallar **kendi `Scaffold`'unu kurar** → `bottomSheet` mümkün ✅ |
| `:300` | `_MatrixGridState._selected` — seçili kart **iç state'te** |
| `:312` | `_effectiveSelected()` — seçim yoksa ilk karta düşer |
| `:484-499` | `_SizePanel` grid'in **altına** ekleniyor → sayfayla kayıyor (**şikayetin sebebi**) |
| `:818` | `_SizePanel` — yalnız genişlik/yükseklik; saydamlık/hizalama yok |
| **`:938-939`** | **`_StepButton` 40×40 dp** — DoD 48 dp minimumunun altında |

### 2.8 l10n denetimi — mevcut kapsam

`scripts/l10n_audit.py` (`Kodda doğrulandı`):
- `:23-24` yalnız **`app_en.arb` ve `app_tr.arb`** yüklüyor → **DE/AR denetlenmiyor**.
- Görünür **Türkçe** literal yakalıyor → sabit **İngilizce** kullanıcı metnini yakalamıyor.
- `:26,108` `l10n_android_audit.py`'ı **subprocess ile zaten çağırıyor** → "native audit ayrı" ifadesi yanıltıcıydı.
- UTF-8'de çalıştırıldığında **38 bulgu ile kırmızı**.
- Windows `cp1254` altında `UnicodeEncodeError` ile çöküyor (Ubuntu CI için bloklayıcı değil;
  Windows runner'a bağlanacaksa şart).

Örnek bulgular: `account_settings_screen.dart:257,264,272,318,347,482,484,493` ·
`app_push_notification_service.dart:325,326,331` · `task_deadline.dart:152,153` ·
`achievement_reward_provider.dart:50,68`.

### 2.9 Kozmetik yüzeyler

| Konu | Dosya |
|---|---|
| Kamp ateşi | `features/classroom/widgets/campfire_scene.dart`, `campfire/layered_campfire_fire.dart`, `camp_critter.dart` |
| Taç | `core/widgets/crowned_avatar.dart`, `core/widgets/crown_tiers_sheet.dart` |
| Taç **mantığı** | `core/stats/achievement_ledger_engine.dart:358` `crownRankForXp`, `kCrownXpThresholds` |

---

## 3. Mimari kararlar (ADR) — final

### ADR-1 — Özel tema: iki renk varyantı + `fromCustomTokens`
`CustomTheme` **`lightColors` ve `darkColors`** taşır (ikisi de tam `AppColors`). Tipografi, şekil,
atmosfer ve his tek kopya. Kullanıcı bir varyantı kurar; diğeri `core/theme/brightness_derivation.dart`
içindeki **saf fonksiyonla** türetilir ve sihirbazda **düzenlenebilir sunulur**.

Render: **`AppTheme.fromCustomTokens({colors, typography, shapes, atmosphere, feel, brightness})`** —
mevcut `_buildFromTokens:297` üzerine ince sarmalayıcı.

**`fromPreset` kullanılmaz.** Gerekçe: `ThemePreset` tipografiyi iki bool ile taşıyor; font ailesi,
ağırlık, harf aralığı ve ölçek sözleşmesini taşıyamaz. Genişletmek `kThemePresets:90` listesini de kırar.

**Tek renk seti neden yetmez:** Bulgu B (§2.3) — karşı modda kullanıcının metin/kenarlık seçimi eziliyor.

### ADR-2 — Saklama: cihaz-yerel, 3 sabit yuva, şema versiyonlu
`SharedPreferences`. Yeni anahtarlar: `custom_themes_v2`, `active_custom_theme_id`,
`custom_themes_migrated_v1`. Eski `custom_palettes` **okunur, silinmez, yazılmaz** (geri alma güvenliği).

**Yuva semantiği:** 3 yuva **sabit index** (`custom_1/2/3`). Silme **index kaydırmaz**, yuvayı
`isDefined: false` yapar. Bu, `theme_settings.dart:35-41`'deki index ayrıştırmasını korur ve
"sildim, başka temam geldi" hatasını imkânsız kılar.

Sunucu senkronu **yok** (sahip kararı, 10. tur): migration, RLS politikası, repo katmanı ve
cihazlar-arası senkron kapsam dışıdır.

### ADR-3 — `main.dart` üç yollu tema çözümü
```dart
// Öncelik: özel tema > palet > aile.
final custom = settings.activeCustomTheme;
if (custom != null) {
  lightTheme = AppTheme.fromCustomTokens(custom, Brightness.light);  // custom.lightColors
  darkTheme  = AppTheme.fromCustomTokens(custom, Brightness.dark);   // custom.darkColors
} else if (settings.usePaletteColors) {
  lightTheme = AppTheme.light(settings.palette);
  darkTheme  = AppTheme.dark(settings.palette);
} else {
  lightTheme = AppTheme.fromFamily(settings.family, Brightness.light);
  darkTheme  = AppTheme.fromFamily(settings.family, Brightness.dark);
}
```
Palet ve aile yolları **hiç değişmez**. ⚠️ `main.dart` sıcak dosya.

### ADR-4 — Fontlar paketlenir, `google_fonts` kullanılmaz
**Gerekçe:** (a) `google_fonts` ilk kullanımda ağdan indirir → çevrimdışı çalışma odası uygulamasında
tema bozuk görünür; (b) mağaza incelemesinde çalışma anında varlık indirme ek beyan üretir;
(c) paketlenmiş font deterministiktir → golden testler kararlı olur.

**Kurallar:** yalnız **SIL OFL / Apache-2.0**; lisans metinleri `app/assets/fonts/LICENSES/`;
subset **Latin + Latin-Ext** (Türkçe `ğ ş ı İ ç ö ü`); hedef artış **≤ 2.5 MB**.
🔴 **`fontFamilyFallback` zorunlu** — paketlenen fontlar Arap alfabesi içermez, AR locale'de kutu
karakter çıkar (K-7'de AR kalırsa).

Roller: UI sans (**sistem**, paketlenmez) · nötr sans · yumuşak/yuvarlak · serif · daktilo/vintage · mono (sayaç).
Font adları WP sırasında lisansıyla birlikte **tek tek teyit edilir**; bu listede ad sabitlenmez.

### ADR-5 — Şifre sıfırlama: Android deep link + her platformda OTP
Android'de link tıklanınca uygulama açılır (mevcut altyapı). **Ek olarak** her platformda çalışan
**e-posta kodu (OTP)** yolu açılır: Windows'ta protokol kaydı yok ve portable ZIP'te de çalışması gerekiyor.

**OTP tek başına istemci işi değil:** recovery e-posta şablonuna **`{{ .Token }}`** eklenmeli
(yoksa kullanıcıya kod hiç gitmez) + istemcide `verifyOTP(type: recovery)`.

🔴 **Production Auth paneli ayrı kapıdır** (rev.3 düzeltmesi): WP-287 **istemci + staging** kabulünü
kapsar. **Production template/URL değişikliği ayrı ops/release kapısında ve somut GO ile** yapılır —
"Aşama A production'a dokunmaz" ilkesiyle tutarlı olması için.

### ADR-6 — F-02: characterization testi → public bileşen ayıklama → birleştirme
`_TypesCard`, `_PushHealthCard`, `_QuietHoursCard`, `_RemindersCard`, `_AnnouncementsCard`,
`_PermTile`, `_WidgetCard`, `_PermissionRevocationGuide` hepsi **`_` önekli = library-private**.
**Başka dosyadan import edilemezler.** Bu yüzden "aynen yeniden kullan" mümkün değil.

**Üç adım:** (1) mevcut davranışı sabitleyen characterization testleri → (2) `_` önekli kartları
public `sections/` dosyalarına taşı (davranış değişmez, yalnız görünürlük+konum) → (3) birleşik ekran
bunları dizer. **Sınır:** birleşik ekran tek parça 1000+ satır olmaz; bölüm dosyaları ayrı kalır.

**Neden yeniden yazılmıyor:** 1236 satırlık, cihazda kabul görmüş bildirim/izin kodu — push sağlığı,
sessiz saatler, hatırlatıcılar, izin snapshot'ı, hepsi cihaz davranışına bağlı.

### ADR-7 — Kayıt işlemleri `Future<ThemeSaveResult>`, `void` değil
`saveCustomTheme` / `deleteCustomTheme` / `setActiveCustomTheme` sonuç döner; UI hatayı gösterir.
**Gerekçe:** bugünkü `saveCustomPalette` (`theme_settings.dart:127-145`) `setStringList`'i **`await`
etmeden** çağırıp `void` dönüyor → hata durumunda kullanıcı "kaydedildi" görür, 7 adımlık emeği kaybolur.

### ADR-8 — Bilinmeyen ileri şema: uygulama, ham JSON'u koru
> rev.2'deki hem gerekçe hem davranış düzeltildi.

**Davranış:** Okunan kaydın `schemaVersion`'ı uygulamanınkinden **büyükse**:
- **zorunlu alanlar anlaşılamıyorsa tema UYGULANMAZ**, son uyumlu temaya dönülür;
- anlaşılıyorsa uygulanabilir ama **salt-okunur**;
- her durumda **ham JSON aynen korunur**, üzerine yazılmaz.

**Gerekçe (rev.3 düzeltmesi):** rev.2 "beta ve stable aynı veriyi sırayla okur" diyordu — **yanlıştı**;
ayrı `applicationId` ayrı Android sandbox demektir (`AGENTS.md §4.1`). **Gerçek gerekçe: aynı kanal
içinde sürüm düşürme / rollback.** Kullanıcı yeni sürümde tema oluşturur, sonra eski APK'ya döner;
eski sürüm tanımadığı alanları silerse kullanıcı geri yükseldiğinde teması bozulmuş olur.

### ADR-9 — `TextTheme` sözleşmesinin tamamı token'dan üretilir
`buildTextTheme(AppTypography, AppColors)` saf fonksiyonu **Material `TextTheme` sözleşmesinin
tamamını** doldurur — yalnız bugün kullanılan 13 slotu değil. Gerekçe: bugün kullanılmayan bir slot
yarın kullanıldığında sessizce tema dışında kalmasın.

---

## 4. WP tasarımları

### 4.1 WP-293 · Gate 0: ortam durum modeli + production kapısını yeniden kilitle

**İki işi var:**

**(a) Durum modelini belgele — tek sayıya indirme.** §1'deki altı gerçek ayrı ayrı yazılır.
Kanıt olarak **mevcut başarılı GitHub koşumları tüketilir**; yeni remote işlem yapılmaz.
⚠️ `remote.ps1`'de **`list` action'ı yoktur** (`:4` — geçerli set: `inspect-prerequisites`,
`inspect-push-runtime`, `bootstrap-prerequisites`, `reconcile-prepare`, `reconcile-apply`,
`preflight`, `dry-run`, `apply`, `manual-push-0066-0070`). Ayrıca production'da history tablosu
olmadığı için `migration list` manuel uygulanan `0066–0070`'i zaten kanıtlayamaz.

**(b) Production deploy kapısını yeniden kilitle.** `deploy-contract.json` production
`deploy_enabled: true → false`; `tooling/supabase/guard.tests.ps1:32` beklentisi buna çekilir
(`release_enabled` zaten `false`, öyle kalır). Sıkılaştırma yönü serbesttir (§1.1 kural notu).

**Uzlaştırılacak canlı belgeler:** `progress.md` · `docs/KALITE-PROGRAMI.md` (v43/WP-269–274 HOLD
kaydı bayat) · `project.md` · `backlog.md` (`:12-15` hâlâ v43/`0065`/`0068` diyor) ·
`tooling/README.md` (`:54-55` hâlâ `0065` diyor) · bu plan.
🔴 **Tarihsel belgeler yeniden yazılmaz:** `CHANGELOG.md`, olay raporları ve v45 release manifesti
o günkü gerçeği taşır; tarihsel kayıt olarak korunur.

**Ayrıca:** `progress.md:34` Codex lane notu "WP-285 beta-v4308 P7 cihaz kabulü bekler" diyor;
aynı dosyanın üstü kabullerin kapandığını söylüyor → çelişki giderilir.

**Kabul:** Altı gerçek ayrı ayrı belgelenmiş · production `deploy_enabled: false` · guard testleri
yeşil · altı canlı belge uzlaşmış · tarihsel belgeler değişmemiş · **hiçbir yeni remote işlem
tetiklenmemiş** · `git diff` yalnız doküman + contract + guard testi.

**Tuzaklar:** Altı gerçeği tek sayıya indirmek (operasyon bilgisi kaybı) · kapıyı gevşetme yönünde
değiştirmek · `remote.ps1 list` çağırmaya çalışmak · tarihsel CHANGELOG'u "düzeltmek" ·
doğrulamadan varsayım yazmak.

---

### 4.2 WP-286 · Ayarlar: ölü kart + bölüm ayıklama + izin API'si + birleştirme

**(a) Ölü kartı sil.** `settings_screen.dart:329-339` + `profileUygulamaKisayollariRutinler`
anahtarı 4 katalogdan. Ön kontrol: `grep` ile başka kullanım yok. Samsung Modes & Routines'e dokunma.

**(b) Characterization testleri** (ADR-6 adım 1).

**(c) Public bileşen ayıklama** (ADR-6 adım 2) → `features/notifications/sections/`.

**(d) İzin API'sini üç durumlu yap.** 🔴 **`clock_permissions.dart` SAHİP listesine dahildir**
(rev.3 düzeltmesi — rev.2'de eksikti, worker dosyayı değiştiremezdi).

Yeni sözleşme, §2.6'daki **üç fail-open yolunun hepsini** kapsar:
```
Okuma durumu : available | unsupported | unknown
İzinler      : her biri ayrı değer (bildirim, tam alarm, pil, tam ekran)
Eksik/bozuk native map  → unknown   (asla otomatik true)
requestNotifications null → başarısız/unknown  (asla true)
```
Mevcut çağıranlar (`clock_widgets_screen.dart:42`) geriye uyumlu kalır.

**(e) Birleşik ekran** "Bildirimler ve izinler":
```
⚠ 2 izin eksik — Düzelt          ← durum özeti; unknown'da "hazır" DEMEZ
Bana ne gelsin                    ← türler, sessiz saatler, hatırlatıcılar, duyurular, push sağlığı
Cihaz izinleri                    ← izin satırları, widget, iptal rehberi
E-posta                           ← aylık çalışma raporu (ayarlardan taşındı)
```
Sahip kuralı: mobilde ekran küçük — başlık ve boşluk minimum.

**Kabul:** Ayarlarda 3 giriş → **1** · characterization testleri ayıklama öncesi/sonrası **aynı
sonuç** · eksik izin sayısı doğru · "Düzelt" sistem ekranını açar · sistem ayarından dönüşte özet
≤ 1 sn · **`unknown`'da "hazır" denmiyor** · `unsupported`'ta sahte yeşil yok · bu WP'nin yüzeyinde
yeni sabit metin yok · `flutter analyze` 0.

**Tuzaklar:** `_` önekli widget'ı import etmeye çalışmak (**derlenmez**) · 1236 satırı yeniden yazmak ·
characterization testi olmadan refactor · yalnız `catch → ok` yolunu düzeltip `fromMap`/`requestNotifications`
fail-open'larını atlamak · birleşik ekranı tek dev dosya yapmak.

---

### 4.3 WP-287 · Şifre sıfırlama

**(a) `redirectTo`.** `core/config/auth_redirect_config.dart` (yeni): scheme = applicationId
(`build.gradle.kts:148-174` ile birebir), host `login-callback`. **Sabit yazılmaz** — paket adından
türetilir (`package_info_plus` mevcut). Windows'ta `null` döner (ADR-5).
`supabase_auth_repository.dart:185` bunu geçer; `in_memory` implementasyonu arayüz uyumunu korur.

**(b) OTP yolu.** `verifyOTP(type: recovery)` + kod giriş ekranı + **yeniden gönder ve hız sınırı**
(art arda istekte bekleme süresi söylenir).

**(c) 🔒 Kullanıcı varlığını açığa vurmama.** E-posta kayıtlı olsun olmasın **aynı nötr mesaj**
(user-enumeration koruması). Mevcut `sendPasswordResetEmail` için de test edilir.

**(d) Ops — ikiye ayrıldı (rev.3):**
- **Bu WP'de:** *staging* panelinde Redirect URL + Site URL + recovery şablonuna `{{ .Token }}`.
- **Ayrı ops/release kapısında, somut GO ile:** *production* panelinde aynı üç adım.
  Runbook bu WP'de yazılır, uygulaması ayrı kapıya bırakılır.

**Güvenlik:** Allowlist'e **yalnız uygulama scheme'leri** — joker/üçüncü taraf domain yok
(open-redirect). Token/kod hiçbir log'a, Sentry breadcrumb'ına veya kullanıcı yanıtına yazılmaz.

**Kabul:** (1) Android: e-posta → link → uygulama → `RecoveryScreen` → yeni şifreyle giriş başarılı.
(2) Windows: kod ile aynı sonuç. (3) Kayıtsız e-postada da aynı nötr mesaj. (4) `redirectTo`'suz
çağrıda regresyon testi **kırmızı**. (5) Production panel adımı **yapılmadı**, runbook'ta bekliyor.
`Cihazda doğrulanmalı` (staging).

---

### 4.4 WP-289 · His araştırması + `AppFeel` şema kararı

**WP-288'den önce** — `AppFeel`'in **alanlarını** bu katalog belirler (rev.2'de sıra ters çevrildi).

Çıktı `docs/TEMA-HIS-KATALOGU.md`: her his ailesi için (1) ne hissettirir, (2) hangi token'larla ifade
edilir, (3) Flutter'da nasıl yapılır, (4) performans maliyeti (blur/gölge/shader), (5) "hareketi azalt"
davranışı, (6) koyu/açık farkı. **+ `AppFeel` alan listesi önerisi** — 288 bunu birebir uygular.

Ham liste (budanacak): modern-minimal · vintage gren · eskimiş karton · neon/cyber · kâğıt-defter ·
zen · cam · düz.

⚠️ **Telif:** yalnız fikir ve teknik desen. Başka uygulamanın asset'i, ikonu veya birebir görsel
kimliği kopyalanmaz.

---

### 4.5 WP-288 · Tema modeli + saklama v2 + göç

**Sıra kritik: önce golden baseline, sonra motor değişikliği.**

**(a) 🔴 Golden baseline kur.** Projede golden test **yok** (§2.5). Global `TextTheme` değişikliğine
başlamadan önce temsilî hazır tema/palet kombinasyonları için golden baseline oluşturulur.
Bu, (b) ve (c)'nin tek güvenlik ağıdır.

**(b) `TextTheme` sözleşmesinin tamamı** (ADR-9). Bugün %24 kapsama (§2.3 Bulgu C).

**(c) Model.** `CustomTheme`: `id` (custom_1/2/3, index sabit), `name`, `isDefined`, `updatedAt`,
**`lightColors` + `darkColors`**, ortak tipografi/şekil/atmosfer/his, `schemaVersion`.
`brightness_derivation.dart` saf fonksiyonu karşı varyantı üretir.

**(d) `AppTypography` genişletmesi:** font aileleri (başlık/gövde/sayaç), ağırlıklar, harf aralığı,
ölçek. ⚠️ **`copyWith` ve `lerp` mutlaka güncellenir** — yoksa tema geçişinde alanlar kaybolur.

**(e) `AppFeel`** (289'un şeması) + ⚠️ **`app_theme.dart:338` `extensions:` listesine eklenir** —
eklenmezse `context.appFeel` fallback'e düşer ve seçim hiçbir etki yapmaz (**ölü anahtar**, DoD ihlali).

**(f) Saklama** (ADR-2) + **kayıt `Future<Result>`** (ADR-7) + **ileri şema koruması** (ADR-8).

**(g) 🔴 Göç — etkin ThemeData'dan snapshot** (rev.3 düzeltmesi):

rev.2 "kalan alanları seçili preset'ten devral" diyordu. **Yanlıştı** — §2.3 Bulgu A: açık tema
sabit `nordic_snow` tabanından, koyu tema palet id'sine göre değişen tabandan geliyor. Tek preset'ten
türetmek görünümü değiştirir.

**Doğru algoritma:**
```
1. custom_themes_migrated_v1 == true → çık (idempotent)
2. Her dolu eski yuva için:
     lightColors ← AppTheme.light(oldPalette) ile üretilen ThemeData'nın ETKİN AppColors extension'ı
     darkColors  ← AppTheme.dark(oldPalette)  ile üretilen ThemeData'nın ETKİN AppColors extension'ı
     shapes / atmosphere / typography ← aynı etkin ThemeData'lardan
3. Eski aktif seçim custom_N ise → active_custom_theme_id = custom_N
4. custom_themes_migrated_v1 = true
```
Böylece **açık, koyu ve sistem modunda gerçek görünüm korunur.**

**(h) `main.dart` üç yollu** (ADR-3).

**Kabul:** Göç sonrası görünüm **değişmez** — açık, koyu **ve sistem** modu **ayrı ayrı** golden ile
doğrulanır · göç idempotent · `TextTheme` sözleşmesi tam · "font değişti → başlık+gövde+etiket gerçekten
değişti" regresyon testi · silme index kaydırmaz · aktif silinince çökme 0 · 3'ten fazla tema yok ·
bozuk veride açılış çökmesi 0 · ileri şema ham JSON'u koruyor · kayıt hatası UI'da görünür ·
her token seçimi gerçek etki üretiyor · `flutter analyze` 0.

**Tuzaklar:** Golden baseline kurmadan `TextTheme`'e dokunmak · göçü tek preset'ten türetmek ·
tek renk seti ile açık/koyu üretmek · `extensions:` listesine `AppFeel`'i eklememek ·
`copyWith`/`lerp`'i güncellememek · kaydı `await`siz bırakmak · ileri şemayı yeniden yazmak ·
`main.dart` sıcak dosyasına başka WP ile aynı anda girmek.

> ℹ️ **rev.2'deki Riverpod uyarısı kaldırıldı.** `themeSettingsProvider` (`theme_settings.dart:182`)
> **auto-dispose değildir**; `theme_settings_test.dart` dinleyicisiz `read → mutate → read` yapıyor ve
> state korunuyor. `container.listen` bu provider için **gerekli değil**. (Auto-dispose bir provider
> *eklenirse* uyarı yeniden geçerli olur.)

---

### 4.6 WP-290 · "Kendi Temanı Oluştur" sihirbazı

**Ekran düzeni** (sahip kararı: başlıksız, sade):
```
✨ Kendi Temanı Oluştur          ← en üstte büyük giriş
   [ Temam 3 ]  ✎ 🗑             ← en yeni en üstte (updatedAt desc)
   [ Temam 1 ]  ✎ 🗑
   [ + boş yuva ]
──────────────────                ← ince ayraç, BAŞLIK METNİ YOK
   hazır temalar · açık/koyu/sistem
```

**Adımlar:** 1 zemin → 2 renkler → 3 yazılar → 4 biçim → 5 atmosfer → 6 his → **6b karşı mod**
(türetilen varyant düzenlenebilir gösterilir) → 7 özet/ad ver.

Her adımda **canlı önizleme**: mevcut `_LivePreview` (`theme_studio_screen.dart:482`) taşınıp
genişletilir, sıfırdan yazılmaz.

**Kontrast koruması:** 1. ve 2. adımda WCAG AA hesaplanır (normal 4.5:1, büyük 3:1); altındaysa
satır içi uyarı + tek dokunuş düzeltme. **Kaydetme engellenmez, sessiz de geçilmez.**

**Fontlar:** ADR-4.

**Kaldırılacak:** `theme_studio_screen.dart` (sahip "yerine geçsin" dedi) ve
`widgets/custom_palette_editor.dart` (sihirbaz gelince gereksiz). İşe yarar parçalar önce taşınır.

**Kabul:** Adım değişikliği önizlemede ≤ 1 kare · kaydedilen tema `TextTheme` dahil tüm token
yüzeylerinde uygulanır · AA altı kontrastta uyarı · kaydedilen/düzenlenen tema en üstte · silme onay
ister · 3 temsili tema × {açık, koyu} golden yeşil · **APK boyut artışı ≤ 2.5 MB** · 4 dilde anahtar
tam (K-7'ye göre) · AR kalırsa kutu karakter yok.

**Boyut ölçümü (rev.3 düzeltmesi):**
```bash
flutter build apk --release --flavor stable --target-platform android-arm64 --dart-define-from-file=env.json --analyze-size
```
Karşılaştırma **aynı flavor + aynı ABI + aynı baseline** ile yapılır.

---

### 4.7 WP-291 · Boyut paneli → sabit alt panel

1. Seçim state'i (`_MatrixGridState._selected`, `:300`) yukarı taşınır; grid bildirir, panel dinler.
   `_effectiveSelected()` (`:312`) mantığı korunur.
2. Panel `Scaffold.bottomSheet`'e bağlanır, **yalnız `_editing == true` iken** (her iki dal kendi
   `Scaffold`'una sahip: `:161`, `:210`).
3. Kapalı ~72 dp ince şerit; yukarı çekilince genişler.
4. Grid altına panel yüksekliği kadar boşluk.
5. Masaüstünde dar/köşeye hizalı varyant.
6. 🔴 **`_StepButton` 40×40 → ≥ 48×48 dp** (`home_screen.dart:938-939`). rev.2 kabul kriterinde
   48 dp yazıyordu ama adımlarda yoktu; mevcut kod zaten altında.

**Kapsam dışı:** saydamlık ayarı.

**Kabul:** Sayfa en alta kaydırılsa bile panel ekranda kalır · kapalı ≤ 80 dp, açık ≤ ekranın %40'ı ·
boyut değişince kart ≤ 1 kare · erişilemez kart kalmaz · **tüm dokunma hedefleri ≥ 48 dp** ·
sürükle-bırak, `compactUp`, sıfırlama, kart silme davranışları değişmez.

⚠️ Izgara sütun üst sınırı (`kMaxGridColumns`) değiştirilmez — aşımda `analyze` temiz geçse de
runtime assert çöker.

---

### 4.8 WP-294 · l10n borcu + audit genişletme + CI kapısı

🔴 **Bağımlılık: K-7 (AR/DE ürün kararı) önce kapanmalı.** `progress.md:310` (WP-278) AR/DE'nin
üründe kalıp kalmayacağını hâlâ açık bırakıyor; plan ise dört dili zorunlu sayıyor. Bu bir
**yönetişim çelişkisidir** ve audit kapsamını doğrudan belirler.

**Audit genişletmesi** (§2.8 bulgularına göre):
- `app_de.arb` ve `app_ar.arb` **kataloglara eklenir** (bugün yalnız EN/TR — `:23-24`), placeholder eşliği dahil.
- Sabit **İngilizce** kullanıcı metni de yakalanır (bugün yalnız Türkçe literal).
- Native Android audit **zaten çağrılıyor** (`:26,108`) — bu doğru belgelenir.
- UTF-8 çıktı hatası düzeltilir (Ubuntu CI için bloklayıcı değil; **Windows runner'a bağlanacaksa şart**).
- CI kapısı: yeni sabit metin **reddedilir**, kırmızı-yeşil ispatıyla.

**Borç ayıklama:** görünen metinler kataloglara taşınır. Yasal metin mimarisi **not edilir, çözülmez**.

**Kabul:** Audit dört katalog + sabit EN/TR + native yüzeyleri kapsıyor · UTF-8'de çökmüyor ·
CI kapısı yeni sabit metni reddediyor (ispatlı) · görünen sabit metin sayısı ölçülüp düşürüldü ·
K-7 kararına uygun dil seti.

---

### 4.9 WP-292 · Taç görseli · ve WP-295 · Kamp ateşi

**WP-292 (taç):** `crowned_avatar.dart` + `crown_tiers_sheet.dart` çizim katmanı yenilenir.
🔴 **`achievement_ledger_engine.dart:358` `crownRankForXp` ve `kCrownXpThresholds` DEĞİŞTİRİLMEZ** —
taç XP'den türer, XP server-authoritative'dir. Eşiğe dokunmak kullanıcıların kademesini sessizce kaydırır.
**Kabul:** aynı XP → aynı kademe (regresyon testi) · taçsızda düz avatar · golden yeşil.

**WP-295 (kamp ateşi):** **Önce sahiple konuşma turu**, kararlar notlara yazılır, sonra kod.
Hayvanlar şu an vektör fallback (`references/campfire/TASARIMCI_BRIEF.md`).

**Her ikisinde performans bütçesi (rev.3 — ölçülebilir):**
- Orta seviye Android cihazda ilgili ekranda **p95 kare süresi ≤ 16.7 ms**;
- animasyon boyunca **jank kare oranı ≤ %1**;
- "hareketi azalt" açıkken animasyon durur.
Ölçüm: `flutter run --profile` + timeline. "Kare düşmesi ölçüldü" gibi sayısız ifade kabul değildir.

---

## 5. Risk kaydı

| # | Risk | Etki | Önlem | WP |
|---|---|---|---|---|
| R1 | Göç yazılmazsa mevcut paletler kaybolur | Yüksek | İdempotent göç, eski anahtar silinmez | 288 |
| R2 | Silme index kaydırırsa yanlış tema görünür | Yüksek | Yuva boşaltma, index sabit (ADR-2) | 288 |
| R3 | Yeni `ThemeExtension` `extensions:`e eklenmezse seçim **ölü anahtar** | Yüksek | `app_theme.dart:338` + "gerçek etki" testi | 288 |
| R4 | `copyWith`/`lerp` yeni alanları taşımazsa geçişte kaybolur | Orta | İkisi de güncellenir + round-trip testi | 288 |
| R5 | Kullanıcı okunamaz tema üretir | Orta | Canlı AA uyarısı + düzeltme | 290 |
| R6 | Font paketleme APK'yı şişirir / lisans ihlali | Orta | Subset + ≤ 2.5 MB (aynı flavor/ABI) + OFL/Apache | 290 |
| R7 | AR'de paketlenmiş font Arapça içermez → kutu karakter | Orta | `fontFamilyFallback` + AR golden (K-7'ye bağlı) | 290 |
| R8 | Windows'ta deep link yok | Orta | OTP yolu (ADR-5) | 287 |
| R9 | Panel adımı atlanırsa kod düzeltmesi kullanıcıya ulaşmaz | Yüksek | Runbook + staging kabulü; production ayrı kapı | 287 |
| R10 | Sıcak dosya çakışması (`core/theme/**`, `main.dart`, `pubspec.yaml`, l10n) | Yüksek | Dalga modeli §6 | plan |
| R11 | Bildirim/izin ekranı yeniden yazılırsa cihaz davranışı bozulur | Yüksek | Characterization → ayıklama (ADR-6) | 286 |
| R12 | Taç görseli değişirken kademe eşiği kayar | Yüksek | `crownRankForXp` dokunulmaz + regresyon | 292 |
| R13 | **Golden yok** → global `TextTheme` değişikliği görünümü sessizce bozabilir | **Yüksek** | Önce golden baseline, sonra motor (§4.5a) | 288 |
| R14 | Panel yüzünden son kart erişilemez kalır | Orta | Alt boşluk + widget testi | 291 |
| R15 | Altı ortam gerçeği tek sayıya indirilirse operasyon bilgisi kaybolur | Yüksek | Durum modeli §1, tek sayı yok | 293 |
| R16 | Tek renk seti → kullanıcının metin/kenarlık seçimi karşı modda ezilir | Yüksek | İki varyant + türetme (ADR-1) | 288 |
| R17 | `TextTheme` %24 kapsama → font seçimi yüzeylerin %76'sında etkisiz | Yüksek | Sözleşmenin tamamı (ADR-9) | 288 |
| R18 | `_` önekli widget import edilemez | Orta | Public ayıklama (ADR-6) | 286 |
| R19 | İzin okuma **üç ayrı yoldan** fail-open | Yüksek | `available/unsupported/unknown` + `fromMap` + `requestNotifications` | 286 |
| R20 | Şablona `{{ .Token }}` eklenmezse OTP hiç çalışmaz | Yüksek | Ops adımı, kabul kriterine bağlı | 287 |
| R21 | Kayıt `void`+`await`siz → tema sessizce kaybolur | Orta | `Future<Result>` (ADR-7) | 288 |
| R22 | Sürüm düşürmede eski sürüm yeni şemayı silerek yazar | Orta | Ham JSON korunur (ADR-8) | 288 |
| R23 | Audit yalnız EN/TR → DE/AR sahte güven | Orta | Dört katalog + EN literal (§4.8) | 294 |
| R24 | **Production `deploy_enabled` açık kaldı** | Yüksek | Yeniden kilitle + guard testi (§1.1) | 293 |
| R25 | AR/DE ürün kararı açıkken dört dil zorunlu sayılıyor | Orta | **K-7 önce kapanır** | 294 |
| R26 | Aşama A "production'a dokunmaz" derken WP-287 prod panelini değiştiriyor | Orta | Production panel ayrı ops/release kapısı (ADR-5) | 287 |

---

## 6. Dalga modeli ve çakışma matrisi

```
GATE 0   WP-293  Ortam modeli + kapı kilidi        ← tek başına, her şeyden önce
DALGA 1  WP-287  Şifre sıfırlama  ‖  WP-286  Ayarlar IA + izin API'si
DALGA 2  WP-291  Boyut paneli     ‖  WP-289  His araştırması + AppFeel şeması
DALGA 3  WP-288  Tema modeli (golden baseline dahil)  ‖  WP-294  l10n (K-7 kapanmışsa)
DALGA 4  WP-290  Tema sihirbazı                    ← tek başına
DALGA 5  WP-292  Taç              ‖  WP-295  Kamp ateşi (sahip kararı sonrası)
─────────────────────────────────────────────────────────────────
RELEASE  DB replay + RLS · analyze · tam test · 4 dil audit · env'li APK+Windows build
         · gerçek cihaz matrisi · beta soak ≥ 3 gün · rollback hazır
```

| WP | Ana SAHİP yüzey | Sıcak dosya | Çakışma |
|---|---|---|---|
| 293 | `progress.md`, `KALITE-PROGRAMI.md`, `project.md`, `backlog.md`, `tooling/README.md`, `deploy-contract.json`, `guard.tests.ps1` | `progress.md` | hepsiyle → **tek başına** |
| 286 | `settings_screen.dart`, `features/notifications/**`, `clock_widgets_screen.dart`, **`core/time_engine/clock_permissions.dart`** | l10n | 294 ile l10n'de |
| 287 | `data/repositories/**auth**`, `core/config/**`, `features/auth/**` | — | yok |
| 289 | yalnız `docs/**` | — | yok |
| 288 | `core/theme/**`, `main.dart`, golden baseline testleri | `core/theme/**`, `main.dart` | **290 ile seri** |
| 290 | `features/profile/**`, `core/theme/theme_tokens.dart`, `pubspec.yaml`, `assets/fonts/**` | `core/theme/**`, `pubspec.yaml`, l10n | **288 ile seri**, 294 ile l10n'de |
| 291 | `features/home/home_screen.dart` (+ `widgets/**`) | — | yok |
| 292 | `core/widgets/crowned_avatar.dart`, `crown_tiers_sheet.dart` | — | yok |
| 294 | uygulama geneli l10n, `scripts/l10n_audit.py`, CI workflow | l10n | **286 ve 290 ile** |
| 295 | `features/classroom/widgets/campfire*`, `camp_critter.dart` | — | yok |

⚠️ Tema programı açıkken **Saat ve Başarım programları açılmaz** (`AGENTS.md §1.2`).
✅ Şu an tüm lane'ler boşta.

### DoD (her WP) — `AGENTS.md §3`
Kabul kriterleri yazılı ve ölçülebilir · **ölü anahtar yok** · `flutter analyze` 0 · ilgili testler yeşil ·
yeni mantık test kapsamında · görsel değişiklik golden ile (**baseline WP-288'de kurulur**) ·
boş/hata/çevrimdışı ele alındı · RLS/güvenlik değerlendirmesi · erişilebilirlik (AA kontrast, **48 dp**,
açık/koyu) · **bu WP'nin yüzeyinde yeni sabit metin yok, yeni anahtarlar tam** (genel borç WP-294'ün) ·
tek ayrık commit, yalnız kendi SAHİP yolları.

---

## 7. Açık kararlar

| # | Konu | Durum |
|---|---|---|
| K-1 | Font kaynağı | ✅ ADR-4: paketlenir, `google_fonts` yok |
| K-2 | Windows şifre sıfırlama | ✅ ADR-5: deep link + OTP |
| K-3 | Hangi "his" seçenekleri | ⏳ WP-289 çıktısı |
| K-4 | Staging Auth paneli | ⏳ Sahip — WP-287 kodu hazır olunca |
| K-5 | Kamp ateşi tasarımı | ⏳ Sahiple konuşma — WP-295 öncesi |
| **K-6** | Production Auth paneli (Redirect/Site URL/`{{ .Token }}`) | ⏳ **Ayrı ops/release kapısı + somut GO** |
| **K-7** | 🔴 **AR/DE üründe kalacak mı** (WP-278) | ⏳ **WP-294 ve font/RTL işi başlamadan kapanmalı.** Kalırsa audit dört katalog + RTL QA; kalmazsa dil seçenekleri ve plan EN/TR'ye **dürüstçe daraltılır** |

---

## 8. Aşama A bitiş tanımı

1. **WP-286…295'in tamamı** (293/294/295 dahil) en az "Otomatik test geçti",
2. bir beta yayımlanmış ve **gerçek cihazda sahip tarafından kabul edilmiş**
   — tag adı release anında `AGENTS.md §4.1` kodlamasından (`patch*100 + sıra`) türetilir; plana sabit tag yazılmaz,
3. şifre sıfırlama **staging'de** uçtan uca doğrulanmış; production panel adımı ayrı kapıda,
4. tema göçü gerçek bir hesapta **açık, koyu ve sistem** modunda doğrulanmış,
5. stable release kapısı: DB replay + RLS · analyze · tam test · 4 dil audit · env'li APK ve Windows
   build · **gerçek Samsung cihaz** · beta soak ≥ 3 gün · rollback hazır.

**DB testi kapsamı:** `pnpm db:test` yalnız istemci kodu değiştiren WP'lerde (286/288/290/291/292/295)
her WP başında bloklayıcı **değildir**; **stable release öncesinde, migration/backend WP'sinde ve
release SHA'sında yeşil olmak zorundadır.**

---

## 9. Revizyon günlüğü

### rev.3 — senior 2. incelemesi sonrası (bu sürüm)

| Bulgu | Doğrulama | Yapılan |
|---|---|---|
| rev.2 kendi içinde çelişiyor | ✅ 8 ayrı yerde eski+yeni tasarım bir arada | **Belge baştan yazıldı**; eski metin bırakılmadı |
| WP-293 yanlış modellenmiş | ✅ Altı ayrı gerçek var; tek sayı bilgi kaybı | §1 durum modeli; "dört belge aynı head" kaldırıldı |
| Production `deploy_enabled` açık kaldı | ✅ contract `true`, `remote.ps1:133` bunu okuyor | WP-293'e **yeniden kilitleme** + guard testi eklendi |
| `remote.ps1 list` yok | ✅ `:4` action seti — `list` yok | Adım düzeltildi; mevcut GitHub kanıtları tüketilecek |
| Göç görsel kimliği korumuyor | ✅ `light()` sabit `nordic_snow`, `dark()` palet id'sine göre değişen taban (`:257-295`) | Göç **etkin ThemeData snapshot'ına** bağlandı |
| **Golden test yok** | ✅ `grep matchesGoldenFile app/test` → 0 | rev.2'deki "mevcut golden'lar güvenlik ağı" **yanlıştı**; WP-288'e baseline kurma adımı eklendi (R13) |
| WP-286 SAHİP listesi eksik | ✅ `clock_permissions.dart` yoktu | Listeye eklendi |
| Fail-open üç yoldan | ✅ `catch→ok` + `fromMap` eksik alan `true` + `requestNotifications` null `true` | Üçü de kapsama alındı |
| l10n audit yalnız EN/TR | ✅ `:23-24`; native audit `:26,108` **zaten çağrılıyor** | WP-294 genişletildi; "native ayrı" ifadesi düzeltildi |
| AR/DE ürün kararı açık | ✅ `progress.md:310` WP-278 | **K-7** eklendi, WP-294'ün ön koşulu (R25) |
| WP-287 production paneline dokunuyor | ✅ "Aşama A production'a dokunmaz" ile çelişiyor | Staging bu WP'de, **production ayrı kapı** (ADR-5, K-6, R26) |
| **Riverpod R13 yanlıştı** | ✅ `themeSettingsProvider` auto-dispose **değil**; `theme_settings_test.dart` listenersız çalışıyor | Uyarı **kaldırıldı**, dar bir nota indirildi |
| **ADR-8 gerekçesi yanlıştı** | ✅ Ayrı `applicationId` = ayrı sandbox | Gerekçe **sürüm düşürme/rollback** oldu; davranış "ham JSON'u koru" olarak güçlendirildi |
| `--analyze-size` eksik bayrak | ✅ | Tam komut + aynı flavor/ABI kuralı |
| `_StepButton` 40×40 | ✅ `home_screen.dart:938-939` | 48 dp adım olarak yazıldı |
| Performans bütçesi sayısız | ✅ | p95 ≤ 16.7 ms, jank ≤ %1 |
| Aşama bitişi 293–295'i dışlıyor | ✅ | §8 düzeltildi |
| `backlog.md` / `tooling/README.md` bayat | ✅ `backlog.md:12-15`, `tooling/README.md:54-55` | WP-293 kapsamına eklendi |
| `progress.md:34` lane notu çelişkili | ✅ | WP-293 kapsamına eklendi |

**Kabul edilen, bilinçli olarak ayrı WP'ye bırakılan:** `dart format` ~78 dosya · dependency
güncellemeleri · genel analyze/test CI kapısı · 1000–1700 satırlık dosyaların genel refactor'ü ·
yasal metin mimarisi. Özellik WP'lerine karıştırılmaz.

### rev.2 — senior 1. incelemesi sonrası
Beş P1 bulgu (deployment çelişkisi, tema light/dark, OTP şablonu, private widget, l10n) plana işlendi;
WP-293/294/295 eklendi, 289↔288 sırası düzeltildi, ADR-1 ve ADR-6 yeniden yazıldı.
**Eksiği:** yamalama yöntemiyle yapıldığı için eski metinler temizlenmedi → rev.3'ün ana işi bu oldu.

### rev.1 — ilk plan
Sahip kapsamı 10. turda daralttı (tema cihazda, 3 yuva) → sunucu senkronu, migration `0071` ve RLS düştü.
