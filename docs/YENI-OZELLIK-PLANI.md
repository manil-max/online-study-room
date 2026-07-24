# Yeni Özellik Turu — Detaylı Teknik Plan (Aşama A)

> **Bu belge devredilebilir olacak şekilde yazıldı.** Okuyan kişi bu projeyi hiç görmemiş olabilir;
> her iddia dosya:satır referanslıdır, her karar gerekçelidir, her WP tek başına uygulanabilir.
>
> **Girdi:** [`docs/YENI-OZELLIK-NOTLARI.md`](YENI-OZELLIK-NOTLARI.md) — proje sahibiyle 10 turluk konuşma kaydı (kapandı).
> **Çıktı:** `progress.md` Plan Kuyruğu'ndaki **WP-286…292** kartları.
> **Proje kuralları:** `.agents/AGENTS.md` (çekirdek) · `docs/KALITE-PROGRAMI.md` (kanonik program).
>
> Tarih: **2026-07-24** · Kanıt etiketleri: `Kodda doğrulandı` · `Cihazda doğrulanmalı` · `Ürün kararı gerekiyor`

---

## 0. Yönetici özeti

Aşama A, yedi iş paketinden oluşur. Hiçbiri sunucu şeması değiştirmez, hiçbiri production'a dokunmaz.

| WP | İş | Boyut | Bağımlılık |
|---|---|---|---|
| 286 | Ayarlar: ölü kartı sil + bildirim/izin/rapor birleştir | S | — |
| 287 | Şifre sıfırlama derin bağlantı hatası (**canlı hata**) | S–M | — |
| 288 | Tema modeli genişletmesi + yerel saklama v2 + göç | M | — |
| 289 | Animasyon/"his" araştırma turu ve katalog | S (doküman) | — |
| 290 | "Kendi Temanı Oluştur" sihirbazı + görünüm ekranı | **L** | 288, 289 |
| 291 | Ana sayfa kart boyut paneli → sabit alt panel | M | — |
| 292 | Kozmetik: taç görseli + kamp ateşi | M | 290 + sahiple konuşma |

### 0.1 Kapsam değişiklik günlüğü (bu planın 2. sürümü)

Planın ilk sürümü temayı **hesaba senkronlu ve sınırsız** varsayıyordu. Proje sahibi 10. turda kapsamı daralttı:

| Konu | 1. sürüm | **Geçerli karar (10. tur)** | Etkisi |
|---|---|---|---|
| Tema nerede saklanır | Sunucu (`user_themes` tablosu) | **Cihazda** (`SharedPreferences`) | Migration `0071`, RLS politikası, çift repo implementasyonu ve cihazlar-arası senkron **tamamen düştü** |
| Kaç tema | Sınırsız | **En fazla 3** | Mevcut 3 yuvalı yapı korunur; UUID'ye geçiş gerekmez |
| Düzenleme/silme | Konuşulmadı | **İkisi de olacak** | Yeni gereksinim: slot düzenleme + slot boşaltma |
| Cihazlar arası | Otomatik senkron | **Kullanıcı isterse diğer cihazda elle yeniden oluşturur** | Sahibin ifadesi: "beğenen kişi gider Windows ya da diğer mobil cihazında aynı temayı oluşturur" |

**Sonuç:** F-04'ün riski ve süresi ciddi düştü. Backend işi sıfır; iş tamamen istemci tarafında.

### 0.2 Bu turda kapsam dışı (kalkan)

Kısayol/rutin özelliği · widget saydamlık ayarı · tema paylaşma/kod ile aktarma · tema XP/seviye kilidi ·
temanın ana ekran widget'ına ve bildirim paneline uzanması · güncelleme push bildirimi ·
production backend değişikliği · Play/Microsoft Store işleri (Aşama B ve C).

---

## 1. Repo analizi — bugünkü gerçek

Bu bölümün tamamı `Kodda doğrulandı`.

### 1.1 Proje temeli

| Konu | Durum |
|---|---|
| Çatı | Flutter; **tek kod tabanı**, Android + Windows aynı ekranları kullanır |
| Platform ayrımı | Yalnız `isDesktopWindow` bayrağı (`core/desktop/desktop_window_io.dart:15`, stub: `desktop_window_stub.dart:7`) |
| Durum yönetimi | **Riverpod 3** (`NotifierProvider`) |
| Yerel depolama | `SharedPreferences`; provider `core/prefs/app_prefs.dart` (main'de override edilir, testte `setMockInitialValues`) |
| Sunucu | Supabase; **tek yetkilendirme katmanı RLS** (`AGENTS.md §2`) |
| Migration | `supabase/migrations/`, son numara **0070**; production head `0065`, staging `0070` |
| l10n | 4 dil: `app_tr.arb`, `app_en.arb`, `app_de.arb`, `app_ar.arb` + generated |
| Test | 132 test dosyası. Commit şartı: `flutter analyze` **0 uyarı** + ilgili testler yeşil |
| Sürüm | stable **v45**, beta **beta-v4308** yayında |
| Git disiplini | Tek dal `main`; branch/merge/push yok; her WP tek ayrık commit; `git add -A` **yasak** (`AGENTS.md §1.5`) |

### 1.2 Komut hatırlatmaları (yeni gelen için)

```bash
# Tüm flutter komutları app/ içinde çalışır, repo kökünde DEĞİL.
# run/test/build → env dosyası ZORUNLU, yoksa uygulama sessizce InMemory moda düşer:
flutter run   --dart-define-from-file=env.json
flutter test  --dart-define-from-file=env.json
# analyze --dart-define-from-file bayrağını KABUL ETMEZ, bayraksız çalıştır:
flutter analyze
```

### 1.3 Ayarlar ekranı — bugünkü kart sırası

`app/lib/features/profile/settings_screen.dart` (394 satır):

| Satır | Kart | Hedef | Bu turda |
|---|---|---|---|
| ~150 | Yasal merkez | `LegalCenterScreen` | — |
| ~163 | Engellenen kullanıcılar | `BlockedUsersScreen` | — |
| **~176** | **Görünüm ve atmosfer temaları** | `AppearanceScreen` | **WP-290** |
| ~192 | Uygulama dili | dropdown (5 seçenek) | — |
| ~240 | Kamp hayvanın | dialog | — |
| **~259** | **Bildirim merkezi** | `NotificationCenterScreen` | **WP-286 → birleşecek** |
| **~279** | **Widget ve alarm izinleri** | `ClockWidgetsScreen` | **WP-286 → birleşecek** |
| **~293** | **Aylık çalışma raporu** | satır içi `SwitchListTile` | **WP-286 → içeri taşınacak** |
| ~312 | Sürüm ve güncellemeler | `ReleaseNotesScreen` | — |
| **~330** | **Uygulama kısayolları (rutinler)** | **YOK** | **WP-286 → silinecek** |
| ~341 | Geri bildirim gönder | dialog | — |
| ~354 | Yönetim | `AdminScreen` (yalnız admin) | — |

**Ölü kart kanıtı** — `settings_screen.dart:330-339`:
```dart
_SettingsCard(
  child: ListTile(
    leading: Icon(Icons.shortcut_outlined),
    title: Text(AppLocalizations.of(context).profileUygulamaKisayollariRutinler),
  ),                      // ← onTap YOK, subtitle YOK, trailing YOK
),
```
Tıklanabilir görünüyor, hiçbir şeye bağlı değil. Sahibin "basınca bir şey olmuyor" gözlemi birebir doğru.

### 1.4 Tema sistemi — mimari haritası

```
main.dart:143-166                     ← tema seçimini ThemeData'ya çeviren TEK yer (SICAK DOSYA)
  └─ themeSettingsProvider (core/theme/theme_settings.dart:182)
       ├─ ThemeSettings          : familyId, paletteId, mode, colorSource, customPalettes[3]
       └─ ThemeSettingsNotifier  : SharedPreferences okuma/yazma
  └─ AppTheme (core/theme/app_theme.dart)
       ├─ fromFamily(preset, brightness)      :172   ← aile yolu
       ├─ fromPreset(preset, {dynamicSeed})   :233   ← ★ ÖZEL TEMA BURAYA BAĞLANIR
       ├─ dark(palette) / light(palette)      :257/279  ← palet yolu
       └─ _buildFromTokens(...)               :297   → extensions: [...]  :338
  └─ theme_presets.dart : ThemePreset :8 · kThemePresets :90 · themePresetById :511
  └─ theme_tokens.dart  : 5 ThemeExtension katmanı
```

**Bugünkü karar akışı** (`main.dart:160-166`):
```dart
if (settings.usePaletteColors) {          // palet seçili (hazır veya custom_N)
  lightTheme = AppTheme.light(settings.palette);
  darkTheme  = AppTheme.dark(settings.palette);
} else {                                   // Tema Stüdyosu ailesi seçili
  lightTheme = AppTheme.fromFamily(family, Brightness.light);
  darkTheme  = AppTheme.fromFamily(family, Brightness.dark);
}
```

**Token katmanları** (`core/theme/theme_tokens.dart`, 429 satır) — hepsi `ThemeExtension`, hepsinde `copyWith` + `lerp`:

| Katman | Alanlar | Satır |
|---|---|---|
| `AppColors` | surface1, surface2, scaffold, primary, onPrimary, accent, onAccent, textPrimary, textSecondary, border, success, error, onError — **13 renk** | 7 |
| `AppTypography` | displayClock, title, body, label + `useSerifTitles`, `useMonospaceClock` | 110 |
| `AppShapes` | radiusSm/Md/Lg, cardElevation, borderWidth, sharp + hazır `soft`/`bubble`/`sharpBox` | 199 |
| `AppAtmosphere` | gradientStart, gradientEnd, glowColor, glowStrength, blurSigma, glassOpacity | 279 |
| `AppMotion` | fast, normal, slow, respectReduceMotion + `resolve()` | 337 |

Erişim: `context.appColors`, `context.appTypography`, `context.appShapes`, `context.appAtmosphere`,
`context.appMotion` (`theme_tokens.dart:396-429`) — hepsi güvenli fallback'li.

**★ En önemli mimari bulgu:** `ThemePreset` (`theme_presets.dart:8-31`) tam olarak şunları taşıyor:

```dart
class ThemePreset {
  final String id;
  final Brightness brightness;
  final AppColors colors;
  final AppShapes shapes;
  final AppAtmosphere atmosphere;
  final AppMotion motion;
  final bool serifTitles;
  final bool monospaceClock;
  final bool isDynamic;
}
```

Yani **bir özel tema = kullanıcının yazdığı bir `ThemePreset`**. Yeni bir render yolu icat etmeye gerek yok:
`AppTheme.fromPreset` (`app_theme.dart:233`) zaten var. Özel tema onu besler. Bu, WP-288/290'ın
risk profilini ciddi düşürüyor.

**Saklama katmanının bugünkü sınırları** — `core/theme/theme_settings.dart`:

| Konu | Bugün | Kanıt |
|---|---|---|
| Yer | SharedPreferences (cihaz) | `:65-69` anahtarlar: `theme_family`, `theme_palette`, `theme_mode`, `theme_color_source`, `custom_palettes` |
| Özel tema sayısı | **Tam 3, sabit doldurulur** | `:104` → `while (customPalettes.length < 3)` |
| Özel temada ne var | **4 renk**: primary, onPrimary, accent, onAccent | `AppPalette` → `app_theme.dart:22-27` |
| Kimlik | `custom_1/2/3`, **index tabanlı ayrıştırma** | `:35-41` → `int.tryParse(paletteId.split('_').last)` |
| Kaydetme | `saveCustomPalette(int index, AppPalette)` | `:127-145` |
| **Silme** | **YOK** | dosyada silme metodu yok |
| **Düzenleme** | dolaylı: dialog + aynı index'e kaydet | `appearance_screen.dart:148-162` |
| Renk kaynağı ikiliği | `ThemeColorSource.family` / `.palette` | `:11`, `:45-47` |

**Görünüm/stüdyo ekranları:**

| Dosya | Satır | İçerik |
|---|---|---|
| `features/profile/appearance_screen.dart` | 309 | Stüdyo girişi (`:52-73`) · mod seçici (`:86`) · hazır palet ızgarası (`:116`) · özel palet listesi (`:141`) |
| `features/profile/theme_studio_screen.dart` | 616 | WP-55 adım akışı: aile → mood → şekil hissi → özet; `_LivePreview` (`:482`) sahte dashboard + sayaç |
| `features/profile/widgets/custom_palette_editor.dart` | 172 | 4 renk seçen dialog |

### 1.5 Şifre sıfırlama — kök neden zinciri

| # | Halka | Kanıt | Durum |
|---|---|---|---|
| 1 | UI tetiği | `features/auth/auth_screen.dart:78,210` → `_sendPasswordReset()` | ✅ çalışıyor |
| 2 | Repo çağrısı | `supabase_auth_repository.dart:185` → `resetPasswordForEmail(safe)` | ❌ **`redirectTo` yok** |
| 3 | Supabase davranışı | `redirectTo` yoksa link **Site URL**'e gider | — |
| 4 | Site URL | `supabase/config.toml:43` → `http://127.0.0.1:3000` | ❌ yerel varsayılan |
| 5 | Kullanıcı gözlemi | Link `localhost:3000` açıyor, tarayıcı "check your internet connection" | ❌ doğrulandı (stable) |
| 6 | Deep link altyapısı | `AndroidManifest.xml:64` → `<data android:scheme="${authCallbackScheme}" android:host="login-callback" />` | ✅ **var** |
| 7 | Scheme değerleri | `android/app/build.gradle.kts:148/157/166/174` → stable `com.manilmax.onlinestudyroom`, beta `….beta`, play `com.manilmax.onlinestudyroom`, local `….local` | ✅ var |
| 8 | Dart tarafında kullanım | `grep -rn "login-callback" lib/` → **0 sonuç** | ❌ **hiç kullanılmıyor** |
| 9 | Uygulama içi kurtarma ekranı | `features/auth/recovery_screen.dart` (127 satır) + `auth_repository.passwordRecoveryEvents` + `auth_gate.dart:39` dinliyor | ✅ **hazır** |

**Teşhis:** Zincirin **tek** kopuk halkası #2/#8. Geri kalan her şey yerinde. Intent-filter tanımlanmış
ama Dart tarafı hiç `redirectTo` göndermiyor, dolayısıyla Supabase Site URL'e (localhost) düşüyor.

### 1.6 Ana sayfa kart düzeni (F-05)

`app/lib/features/home/home_screen.dart` (1103 satır):

| Satır | Bulgu |
|---|---|
| `:87` | Tüm gövde tek `SingleChildScrollView` içinde (`controller: _scroll`) |
| `:111` | `_MatrixGrid` — ızgara |
| `:161` | **Masaüstü dalı kendi `Scaffold`'unu kurar** |
| `:210` | **Mobil dal kendi `Scaffold`'unu kurar** → `Scaffold.bottomSheet` doğrudan kullanılabilir ✅ |
| `:300` | `_MatrixGridState._selected` — **seçili kart iç state'te** |
| `:312` | `_effectiveSelected()` — seçim yoksa/silinmişse ilk karta düşer |
| `:473` | `if (!widget.editing) return grid;` — panel yalnız düzenleme modunda |
| `:484-499` | `_SizePanel` grid'in **altına `Column` çocuğu** olarak ekleniyor → **sayfayla kayıyor** |
| `:818` | `_SizePanel` tanımı: yalnız genişlik/yükseklik `−/+` (saydamlık/hizalama **yok**) |
| `:868-877` | `_SizeStepper` — genişlik sınırı `config.w < columns` |

Düzen motoru: `features/home/dashboard_providers.dart` — `setBounds`, `persist`, `compactUp`,
`removeCard` (`:145`, `:295`, `:309`). **Bu WP'de davranışı değişmez, yalnız okunur.**

### 1.7 Kozmetik yüzeyler (F-08)

| Konu | Dosya |
|---|---|
| Kamp ateşi sahnesi | `features/classroom/widgets/campfire_scene.dart` |
| Ateş katmanları | `features/classroom/widgets/campfire/layered_campfire_fire.dart` |
| Hayvanlar | `features/classroom/widgets/camp_critter.dart` (şu an vektör fallback; asset brief: `references/campfire/TASARIMCI_BRIEF.md`) |
| **Taç** | `core/widgets/crowned_avatar.dart` (`:17` `crownRank`, `:182`) · `core/widgets/crown_tiers_sheet.dart` |
| Taç kademesi **mantığı** | `core/stats/achievement_ledger_engine.dart:358` → `crownRankForXp(int xp)`, `kCrownXpThresholds` |
| Çağrı yeri | `core/navigation/home_shell.dart:55-65` |

---

## 2. Mimari kararlar (ADR)

### ADR-1 — Özel tema = kullanıcının yazdığı `ThemePreset`
**Karar:** Yeni bir tema render yolu yazılmaz. `CustomTheme` modeli `ThemePreset`'e **birebir çevrilebilir**
olacak ve `AppTheme.fromPreset` (`app_theme.dart:233`) ile render edilecek.
**Gerekçe:** `ThemePreset` zaten brightness + 4 token katmanı + tipografi bayraklarını taşıyor.
Paralel bir yol açmak, tema uygulanan ~%95 yüzeyde iki farklı davranış riski üretir.
**Sonuç:** `main.dart` karar akışı iki yollu yerine **üç yollu** olur (aşağıda ADR-3).

### ADR-2 — Saklama: cihaz-yerel, şema versiyonlu, 3 sabit yuva
**Karar:** `SharedPreferences`; **yeni anahtar** `custom_themes_v2` (JSON liste, `schemaVersion` alanlı).
Eski `custom_palettes` anahtarı **silinmez, dokunulmaz**.
**Gerekçe:** (a) sahip kararı cihaz-yerel; (b) eski anahtar korunursa sürüm geri alınırsa kullanıcı
paletlerini kaybetmez; (c) `schemaVersion` ileride alan eklenince göç yazılabilmesini sağlar.
**Yuva semantiği:** 3 yuva **sabit index**'lidir (`custom_1/2/3`). Silme **index kaydırmaz**, yuvayı
**boş** duruma alır. Bu, `theme_settings.dart:35-41`'deki index tabanlı çözümlemeyi korur ve
"sildim, başka temam geldi" hatasını baştan imkânsız kılar.

### ADR-3 — `main.dart` üç yollu tema çözümü
```dart
// Öncelik: özel tema > palet > aile.  (Yalnız bu üç yol vardır.)
final custom = settings.activeCustomTheme;        // null olabilir
if (custom != null) {
  lightTheme = AppTheme.fromPreset(custom.toPreset(Brightness.light));
  darkTheme  = AppTheme.fromPreset(custom.toPreset(Brightness.dark));
} else if (settings.usePaletteColors) {
  lightTheme = AppTheme.light(settings.palette);
  darkTheme  = AppTheme.dark(settings.palette);
} else {
  lightTheme = AppTheme.fromFamily(settings.family, Brightness.light);
  darkTheme  = AppTheme.fromFamily(settings.family, Brightness.dark);
}
```
⚠️ `main.dart` **sıcak dosyadır** (`AGENTS.md §1.4`). Bu değişiklik WP-288'de yapılır ve o sırada
başka WP `main.dart`'a girmez.

### ADR-4 — Fontlar uygulamaya paketlenir (K-1 kararı: Claude'a bırakıldı)
**Karar:** `google_fonts` **eklenmez**. 4–5 font ailesi `app/assets/fonts/**` altına paketlenir.
**Gerekçe:**
- `google_fonts` ilk kullanımda **ağdan indirir** → çevrimdışıda tema bozuk görünür; uygulama
  "çalışma odası" ürünü, çevrimdışı kullanım normaldir.
- Mağaza incelemesinde çalışma anında varlık indirme ek beyan/risk üretir.
- Paketlenmiş font deterministiktir → **golden testler kararlı** olur (bu proje golden kullanıyor).

**Somut plan:**
| Rol | Aday | Not |
|---|---|---|
| UI sans (varsayılan) | mevcut sistem fontu | **paketlenmez** — "Sistem" seçeneği kalır |
| Nötr sans | Inter benzeri | Latin + Latin-Ext subset |
| Yumuşak/yuvarlak | Nunito benzeri | "zen/yumuşak" hissi |
| Serif | Lora/Merriweather benzeri | "vintage/kâğıt" hissi |
| Daktilo/vintage | Special Elite benzeri | "eskimiş kutu" hissi |
| Mono (sayaç) | JetBrains/Roboto Mono benzeri | sayaç hizası için tabular |

**Zorunlu kurallar:**
1. Yalnız **SIL OFL veya Apache-2.0** lisanslı font; lisans metni `app/assets/fonts/LICENSES/` altına eklenir.
   Her fontun lisansı WP sırasında **tek tek teyit edilir** — bu listedeki adlar adaydır, kesin değil.
2. **Subset:** yalnız Latin + Latin-Ext (Türkçe `ğ ş ı İ ç ö ü` dahil) + gerekli ağırlıklar. Hedef toplam **≤ 2.5 MB**.
3. **Arapça kritik:** uygulama AR destekliyor (`app_ar.arb`). Paketlenen fontlar Arap alfabesi içermez →
   `fontFamilyFallback` zinciri **zorunlu**, yoksa AR locale'de kutu karakter çıkar.
4. Ölçüt: `flutter build apk --analyze-size` ile artışın ≤ 2.5 MB olduğu kanıtlanır.

### ADR-5 — Windows'ta şifre sıfırlama: e-posta kodu (K-2 kararı)
**Karar:** Deep link yolu Android'de kullanılır. **Windows için ek olarak "e-postadaki kodu gir" yolu** açılır.
**Gerekçe:** `authCallbackScheme` yalnız `AndroidManifest.xml`'de tanımlı; Windows tarafında protokol kaydı yok.
MSIX'e protokol eklenebilir ama (a) yalnız kurulu MSIX'te çalışır, portable ZIP'te çalışmaz,
(b) Store kimliği geldiğinde (Aşama C) yeniden ele alınması gerekir. Kod yolu her platformda,
her dağıtım biçiminde çalışır ve tek ekran ekler.
**Not:** Bu, Android akışını **değiştirmez**; Android'de link tıklanınca eskisi gibi uygulama açılır.

### ADR-6 — F-02 birleştirme: yeniden yazma değil, çatı birleştirme
**Karar:** `NotificationCenterScreen` (896 satır) ve `ClockWidgetsScreen` (340 satır) içindeki kart
widget'ları **olduğu gibi** yeniden kullanılır; yalnız `Scaffold`/`AppBar` kabuğu tek ekrana indirilir.
**Gerekçe:** 1236 satırlık çalışan, cihazda kabul görmüş bildirim/izin kodunu yeniden yazmak,
kazanılan IA iyileştirmesine kıyasla çok yüksek regresyon riski taşır (push sağlığı, sessiz saatler,
hatırlatıcılar, izin snapshot'ı — hepsi cihaz davranışına bağlı).

---

## 3. Özellik başına uygulama tasarımı

### F-01 — Ölü "Uygulama kısayolları (rutinler)" kartını sil → **WP-286**

**Değişecek dosyalar**
| Dosya | Değişiklik |
|---|---|
| `features/profile/settings_screen.dart` | `:329-339` (önündeki `SizedBox(height: 10)` dahil) blok silinir |
| `l10n/app_tr.arb`, `app_en.arb`, `app_de.arb`, `app_ar.arb` | `profileUygulamaKisayollariRutinler` anahtarı silinir |
| generated l10n | `flutter gen-l10n` ile yeniden üretilir |

**Ön kontrol (zorunlu):** `grep -rn "profileUygulamaKisayollariRutinler" app/` → yalnız silinecek yerlerde
geçtiği doğrulanır. `device_integration_listener.dart` ve `samsung_modes_service.dart` içinde
"routine/shortcut" kelimeleri geçiyor ama bunlar **Samsung Modes & Routines entegrasyonu**dur,
bu kartla ilgisi yoktur — **onlara dokunulmaz.**

**Kabul:** Ayarlar listesinde kart yok · 4 dilde anahtar yok · `flutter analyze` 0 · test paketi yeşil.

---

### F-02 — "Bildirimler ve izinler" birleşik ekranı → **WP-286**

**Hedef bilgi mimarisi**
```
Ayarlar  ▸  Bildirimler ve izinler                     ← tek giriş (3 giriş yerine)
   ┌──────────────────────────────────────────┐
   │ ⚠ 2 izin eksik — Düzelt                  │  ← durum özeti (YENİ), tek satır
   ├──────────────────────────────────────────┤
   │ Bana ne gelsin                            │
   │   _TypesCard · _QuietHoursCard            │  ← mevcut widget'lar, aynen
   │   _RemindersCard · _AnnouncementsCard     │
   │   _PushHealthCard                         │
   ├──────────────────────────────────────────┤
   │ Cihaz izinleri                            │
   │   _PermTile ×N · _WidgetCard              │  ← mevcut widget'lar, aynen
   │   _PermissionRevocationGuide              │
   ├──────────────────────────────────────────┤
   │ E-posta                                   │
   │   Aylık çalışma raporu           [switch] │  ← ayarlardan taşındı
   └──────────────────────────────────────────┘
```

**Yeniden kullanılacak mevcut parçalar** (`Kodda doğrulandı`)
- `features/notifications/notification_center_screen.dart`: `_PushHealthCard:71`, `_HealthRow:247`,
  `_SectionCard:279`, `_PermissionCard:314`, `_TypesCard:380`, `_QuietHoursCard:479`,
  `_RemindersCard:546`, `_ReminderTile:608`, `_AnnouncementsCard:658`, `_AnnouncementTile:722`,
  `_ReminderDialog:781`
- `features/clock/clock_widgets_screen.dart`: `_WidgetCard:209`, `_PermTile:233`,
  `_PermissionRevocationGuide:279`, `_PermissionGuideStep:322`
- İzin kaynağı: `core/time_engine/clock_permissions.dart` → `ClockPermissions.instance.snapshot()`
  → `ClockPermissionSnapshot` (kullanım: `clock_widgets_screen.dart:20,42`)

**Durum özeti nasıl hesaplanır**
`ClockPermissionSnapshot` üzerinden eksik izinler sayılır. **Yeni izin API'si yazılmaz.**
Görünüm: hepsi tamsa yeşil tek satır ("Her şey hazır"), eksik varsa sayı + "Düzelt" düğmesi;
düğme eksik olan **ilk** iznin sistem ekranını açar (`requestNotifications` /
`openExactAlarmSettings` / `openBatterySettings` / `openFullScreenSettings` — dördü de mevcut).

**Sadelik kuralı (sahip, 4. tur):** Mobilde ekran küçük. Bölüm başlıkları minimum tutulur,
gereksiz `SizedBox`/başlık yığmadan; gruplar arası **ince ayraç** yeterlidir.

**Edge case'ler**
| Durum | Beklenen |
|---|---|
| Kullanıcı sistem ayarına gidip izin verip dönüyor | `WidgetsBindingObserver.didChangeAppLifecycleState` → `resume`'da snapshot yenilenir (desen `clock_widgets_screen.dart`'ta zaten var) |
| Snapshot hata veriyor | Ekran çökmez; özet "durum okunamadı" der, kartlar çalışır |
| Çevrimdışı | `_PushHealthCard` mevcut hata durumunu korur |
| Aylık rapor yazma hatası | Mevcut `_setMonthlyReportPreference` hata davranışı korunur |
| Admin olmayan kullanıcı | Admin'e özel bir şey bu ekranda yok |

**Kabul (ölçülebilir)**
1. Ayarlarda bildirim/izin/rapor için **tam 1** giriş (öncesi 3).
2. Eksik izin sayısı doğru; "Düzelt" ilgili sistem ekranını açar.
3. Sistem ayarından dönüldüğünde özet **≤ 1 sn** içinde güncellenir.
4. Aylık rapor switch'i yeni yerinde çalışır, `monthlyReportOptIn` sunucuya aynen yazılır.
5. Mevcut bildirim testleri **değiştirilmeden** yeşil kalır (regresyon kanıtı).
6. 4 dilde anahtar tam.

---

### F-03 — Şifre sıfırlama düzeltmesi → **WP-287**

#### (a) Kod: `redirectTo` ekle

**Yeni yardımcı** — `core/config/auth_redirect_config.dart` (yeni dosya):
```dart
/// Şifre sıfırlama / auth callback derin bağlantısı.
/// scheme == applicationId (android/app/build.gradle.kts:148-174 ile birebir),
/// host == 'login-callback' (AndroidManifest.xml:64).
/// Sabit yazılmaz: paket adından türetilir, böylece beta/stable/local karışmaz.
String? authRedirectUrl(String packageName) { … }   // '<packageName>://login-callback'
```
Paket adı kaynağı: `package_info_plus` (projede zaten var — `pubspec.yaml`). Windows'ta bu yol
kullanılmaz → `null` döner (ADR-5).

**Değişecek yerler**
| Dosya | Değişiklik |
|---|---|
| `data/repositories/auth_repository.dart` | Arayüz: `sendPasswordResetEmail` imzası korunur; gerekiyorsa `verifyRecoveryCode` eklenir (ADR-5) |
| `data/repositories/supabase/supabase_auth_repository.dart:185` | `resetPasswordForEmail(safe, redirectTo: authRedirectUrl(...))` |
| `data/repositories/in_memory/in_memory_auth_repository.dart:98` | Arayüz uyumu (**çift implementasyon zorunlu** — `AGENTS.md §2`) |
| `features/auth/**` | ADR-5 kod girişi ekranı (Windows/yedek yol) |

#### (b) Ops: Supabase panel adımı — **sahip yapacak**
Kod tek başına yetmez. Her iki projede (staging **ve** production):
1. Authentication → URL Configuration → **Redirect URLs** listesine eklenir:
   - `com.manilmax.onlinestudyroom://login-callback` (stable/play)
   - `com.manilmax.onlinestudyroom.beta://login-callback` (beta)
2. **Site URL** `localhost:3000` ise gerçek bir değere çekilir.
> `supabase/config.toml:43-44` **yalnız local**'i etkiler; hosted projeyi değiştirmez.
> Bu bir **production auth yapılandırması**dır → WP'de ayrı ops adımı olarak yazılır, runbook'a girer.

#### (c) Güvenlik notu
Redirect allowlist'e **yalnız** uygulama scheme'leri eklenir. Genel joker (`*`) veya
üçüncü taraf domain **eklenmez** → open-redirect riski. Token/kod hiçbir log'a, Sentry
breadcrumb'ına veya kullanıcı yanıtına yazılmaz.

**Edge case'ler**
| Durum | Beklenen |
|---|---|
| Süresi dolmuş link/kod | Anlaşılır Türkçe hata; "yeniden gönder" yolu |
| Link ikinci kez tıklanıyor | Tek kullanımlık; ikinci denemede net hata |
| Uygulama kapalıyken link tıklanıyor | Cold start → `auth_gate.dart:39` recovery event'i yakalar → `RecoveryScreen` |
| Beta linki stable uygulamada | Scheme ayrımı zaten engelliyor (`build.gradle.kts:157`) |
| Kullanıcı e-postayı bilgisayarda açıyor, telefonu yanında | Kod yolu (ADR-5) bunu çözer |
| Windows | Kod yolu |

**Kabul (ölçülebilir)** — `Cihazda doğrulanmalı`
1. Android: şifremi unuttum → e-posta → linke dokun → uygulama açılır → `RecoveryScreen` →
   yeni şifre kaydedilir → **yeni şifreyle giriş başarılı**.
2. Windows: kod ile aynı sonuç.
3. Regresyon testi: `redirectTo` olmadan çağrı yapılırsa test **kırmızı** olur (ölü anahtar koruması).
4. `flutter analyze` 0; auth testleri yeşil.

---

### F-04 — Tema yenilemesi

#### F-04-A · Model + yerel saklama v2 + göç → **WP-288**

**Yeni model** — `core/theme/custom_theme.dart` (yeni dosya):

```dart
/// Kullanıcının oluşturduğu tema. 3 sabit yuvadan biri (custom_1/2/3).
/// ThemePreset'e çevrilebilir (ADR-1) → AppTheme.fromPreset ile render edilir.
@immutable
class CustomTheme {
  static const int schemaVersion = 1;

  final String id;            // 'custom_1' | 'custom_2' | 'custom_3'  (index sabit)
  final String name;          // kullanıcının verdiği ad
  final bool isDefined;       // false → yuva BOŞ (ADR-2 silme semantiği)
  final DateTime updatedAt;   // listeyi "en yeni en üstte" sıralamak için

  final Brightness brightness;
  final AppColors colors;         // 13 renk
  final CustomTypography type;    // aşağıda
  final AppShapes shapes;         // 6 alan
  final AppAtmosphere atmosphere; // 6 alan
  final AppFeel feel;             // WP-289 çıktısı; AppMotion + doku (aşağıda)

  ThemePreset toPreset(Brightness b) { … }
  Map<String, dynamic> toMap();            // schemaVersion dahil
  factory CustomTheme.fromMap(Map<String, dynamic>);  // eksik alan → varsayılan
  factory CustomTheme.emptySlot(int index);
}
```

**`AppTypography` genişletmesi** (`theme_tokens.dart:110`) — bugün yalnız iki bool var
(`useSerifTitles`, `useMonospaceClock`). Gereken:
```
titleFontFamily     String?   // null = sistem
bodyFontFamily      String?
clockFontFamily     String?
titleWeight         FontWeight
bodyWeight          FontWeight
letterSpacing       double
textScale           double    // 0.9 – 1.2 arası kısıtlı
```
⚠️ `AppTypography` bir `ThemeExtension` → **`copyWith` ve `lerp` yeni alanlar için güncellenmeli**,
yoksa tema geçiş animasyonunda alanlar sessizce kaybolur. `lerp`'te bool/String alanlar
`t < 0.5 ? a : b` desenini izler (mevcut desen: `:191-192`).

**`AppFeel` (yeni katman)** — "his/animasyon" için. WP-289 kataloğu bu katmanın alanlarını belirler.
Ön iskelet: `motion` (mevcut `AppMotion`) + `grainStrength` + `edgeIrregularity` + `feelId`.
⚠️ Yeni bir `ThemeExtension` eklenirse `app_theme.dart:338` `extensions:` listesine **eklenmeli**,
aksi halde `context.appFeel` fallback'e düşer ve seçim hiçbir etki yapmaz (**ölü anahtar** — DoD ihlali).

**Saklama** — `theme_settings.dart` değişiklikleri:
| Anahtar | Durum |
|---|---|
| `custom_palettes` (eski) | **Okunur, yazılmaz, silinmez** — geri alma güvenliği (ADR-2) |
| `custom_themes_v2` (yeni) | `List<String>` JSON; 3 eleman (boş yuvalar dahil) |
| `active_custom_theme_id` (yeni) | `custom_1/2/3` veya null |
| `custom_themes_migrated_v1` (yeni) | idempotent göç bayrağı |

**Yeni notifier metotları**
```dart
void saveCustomTheme(int slotIndex, CustomTheme theme);   // düzenleme de bu
void deleteCustomTheme(int slotIndex);                    // → emptySlot, index KAYMAZ
void setActiveCustomTheme(String? id);                    // null → palet/aile yoluna dön
```

**Silme davranışı (kritik detay)**
1. Silinen yuva `isDefined: false` olur; **index kaymaz** (yuva 2 silinince yuva 3 yerinde kalır).
2. Silinen tema **aktifse**: uygulama son bilinen palet/aile seçimine döner
   (`theme_palette` / `theme_family` anahtarları hâlâ duruyor — bu yüzden onlar silinmiyor).
3. Onay dialogu zorunlu (geri alınamaz).

**Göç (eski 4 renkli palet → yeni zengin tema)**
```
1. custom_themes_migrated_v1 == true  → hiçbir şey yapma (idempotent)
2. Eski custom_palettes oku (theme_settings.dart:96-103 mantığı)
3. Varsayılandan farklı olan her paleti aynı index'e taşı:
   primary/onPrimary/accent/onAccent → AppColors'ın karşılık gelen alanları
   Diğer 9 renk + şekil + atmosfer + tipografi → o an seçili preset'ten devralınır
   (böylece kullanıcının gördüğü görüntü değişmez)
4. Eski aktif seçim custom_N ise → active_custom_theme_id = custom_N
5. custom_themes_migrated_v1 = true
```
**Neden "seçili preset'ten devral":** Kullanıcı bugün 4 renk seçmiş, geri kalanı preset'ten geliyor.
Varsayılanlara sıfırlamak, güncelleme sonrası temayı görünür şekilde bozar.

**Edge case'ler**
| Durum | Beklenen |
|---|---|
| `custom_themes_v2` bozuk JSON | O eleman atlanır, boş yuva olur, uygulama çökmez (mevcut `try/catch` deseni: `:99-102`) |
| `schemaVersion` gelecekten (daha yeni sürüm sonrası downgrade) | Bilinmeyen alanlar yok sayılır, eksikler varsayılana düşer |
| 3 yuva dolu, kullanıcı 4.'yü istiyor | UI net söyler: "3 yuva dolu — birini düzenle veya sil" |
| Aktif tema silinmiş | Palet/aile yoluna güvenli dönüş |
| Göç iki kez çalıştırılıyor | Bayrak sayesinde mükerrer olmaz |
| Yeni kurulum (hiç veri yok) | 3 boş yuva, varsayılan tema |

**Test matrisi (WP-288)**
- `custom_theme_test.dart`: `toMap`/`fromMap` round-trip · eksik alan varsayılana düşer ·
  bozuk JSON çökmez · `toPreset` her iki brightness'ta doğru token üretir.
- `theme_settings_migration_test.dart`: göç idempotent · eski 4 renk doğru eşlenir ·
  eski aktif seçim korunur · eski anahtar silinmemiş.
- `theme_settings_slot_test.dart`: silme index kaydırmaz · aktif silinince güvenli dönüş ·
  3'ten fazla eklenemez.
- ⚠️ **Riverpod 3 tuzağı:** auto-dispose provider'lar **dinleyicisiz her `read`'de yeniden build**
  olur; bu, regresyon testini sessizce etkisiz kılar. Testlerde `container.listen(...)` ile
  abonelik açılmalı, yoksa "geçti" diyen test hiçbir şeyi kanıtlamaz.

**Kabul (ölçülebilir)**
1. Göç sonrası kullanıcının **gördüğü tema değişmez** (golden karşılaştırması).
2. Göç idempotent (iki kez çalıştır → aynı sonuç).
3. Silme index kaydırmaz; aktif silinirse uygulama çökmez ve makul temaya döner.
4. 3'ten fazla tema oluşturulamaz; UI nedeni açıkça söyler.
5. Bozuk/eksik veride açılış çökmesi **0**.
6. `flutter analyze` 0; yeni testler + mevcut tema testleri yeşil.

#### F-04-B · "Kendi Temanı Oluştur" sihirbazı → **WP-290**

**Ekran düzeni** (sahip kararı: başlıksız, sade)
```
Görünüm
 ┌────────────────────────────────────┐
 │  ✨  Kendi Temanı Oluştur           │   ← en üstte, büyük giriş kartı
 └────────────────────────────────────┘
   [ Temam 3 ]  ✎ 🗑     ← kullanıcının temaları, EN YENİ EN ÜSTTE (updatedAt desc)
   [ Temam 1 ]  ✎ 🗑
   [ + boş yuva ]        ← 3'ten az doluysa
 ────────────────────────  ← ince ayraç çizgi, BAŞLIK METNİ YOK
   [ hazır tema ] [ hazır tema ] …
   açık / koyu / sistem
```
- Sıralama: `updatedAt` azalan. **Düzenlenen tema en üste çıkar** (updatedAt güncellenir).
- Her tema satırında **düzenle (✎)** ve **sil (🗑)** — sahip 10. turda ikisini de istedi.
- Boş yuva satırı doğrudan sihirbazı açar.

**Sihirbaz adımları** (her adımda canlı önizleme + altta sabit gezinme)
| # | Adım | Kontroller | Token |
|---|---|---|---|
| 1 | Zemin | açık/koyu · arka plan · yüzey 1 · yüzey 2 | `AppColors.scaffold/surface1/surface2` |
| 2 | Renkler | vurgu · üstü metin · ikincil vurgu · üstü metin · kenarlık · başlık metni · gövde metni | `primary/onPrimary/accent/onAccent/border/textPrimary/textSecondary` |
| 3 | Yazılar | başlık fontu · gövde fontu · sayaç fontu · kalınlık · harf aralığı · ölçek | `CustomTypography` |
| 4 | Biçim | köşe (sm/md/lg) · kenarlık kalınlığı · yükseklik/gölge · keskin mod | `AppShapes` |
| 5 | Atmosfer | degrade başı/sonu · parıltı rengi/gücü · bulanıklık · cam | `AppAtmosphere` |
| 6 | His | WP-289 kataloğundan hazır "his" seçenekleri | `AppFeel` |
| 7 | Özet | ad ver · hangi yuvaya · kaydet | — |

**Canlı önizleme:** `theme_studio_screen.dart:482` `_LivePreview` (sahte dashboard kartı + sayaç)
**taşınır ve genişletilir**, sıfırdan yazılmaz. Her adım o adımın etkisini vurgular
(ör. 3. adımda metin ağırlıklı önizleme).

**Kontrast koruması (R5)**
1. ve 2. adımda `textPrimary`/`textSecondary` ile `scaffold`/`surface1` arasındaki kontrast oranı
hesaplanır. WCAG AA (normal metin 4.5:1, büyük metin 3:1) altındaysa:
satır içi uyarı + "en yakın okunur tona çek" tek dokunuş düzeltmesi.
**Kaydetmeyi engellemeyiz** (kullanıcının hakkı) ama **sessiz geçirmeyiz** (DoD erişilebilirlik maddesi).

**Kaldırılacak:** `features/profile/theme_studio_screen.dart` — sahip "yerine geçsin" dedi (9. tur).
Silmeden önce `_LivePreview`, `_StepHeader`, `_Swatch` gibi işe yarar parçalar yeni klasöre taşınır.
`appearance_screen.dart:52-73`'teki stüdyo giriş kartı yeni giriş kartıyla değiştirilir.
`widgets/custom_palette_editor.dart` (4 renkli dialog) sihirbaz gelince **gereksizleşir** → kaldırılır.

**Edge case'ler**
| Durum | Beklenen |
|---|---|
| Hiç tema yok | Sade boş durum daveti (3 boş yuva **gösterilmez** — sahip 4. turda bu fikri düşürdü) |
| Çok uzun tema adı | Kırpma + karakter sınırı (ör. 24) |
| Okunamaz renk seçimi | Uyarı + düzeltme önerisi |
| Sihirbaz yarıda bırakılıyor | Kaydedilmemiş değişiklik uyarısı; tema bozulmaz |
| Açık/koyu geçişi | Her iki brightness için token üretilir (ADR-3) |
| RTL (AR dili) | Yerleşim aynalanır; önizleme de RTL |
| "Hareketi azalt" açık | 6. adım his efektleri durur (`AppMotion.respectReduceMotion` — `:342,362`) |
| Masaüstü geniş pencere | Sol kontrol + sağ sabit önizleme (mevcut stüdyo deseni: `theme_studio_screen.dart:13`) |
| Font yüklenemedi | `fontFamilyFallback` devreye girer, kutu karakter olmaz (ADR-4) |

**Test matrisi (WP-290)**
- Widget: 7 adım ileri/geri gezinme · her adımda önizleme güncellenir · kaydet → yuvaya yazılır ·
  sil → onay dialogu · 3 dolu iken oluştur → engellenir.
- Golden: 3 temsili özel tema × {açık, koyu} = 6 golden · sihirbazın her adımı için 1 golden.
- Erişilebilirlik: AA altı kontrastta uyarı görünür (widget testi) · dokunma hedefleri ≥ 48 dp.
- Regresyon: mevcut hazır palet/aile seçimi bozulmadı (eski tema testleri **değiştirilmeden** yeşil).

**Kabul (ölçülebilir)**
1. Her adımda yapılan değişiklik önizlemede **≤ 1 kare** içinde görünür.
2. Kaydedilen tema uygulamanın **≥ %95 yüzeyinde** token'dan uygulanır (KALITE-PROGRAMI §4.4).
3. AA altı kontrastta uyarı çıkar.
4. Kaydedilen/düzenlenen tema listenin **en üstünde** görünür.
5. Silme onay ister; sonrasında uygulama çökmez.
6. 6 golden + adım golden'ları yeşil.
7. APK boyut artışı **≤ 2.5 MB** (`--analyze-size` kanıtı).
8. 4 dilde anahtar tam; AR'de kutu karakter yok.

#### F-04-C · Animasyon/"his" araştırması → **WP-289**

Sahip: *"oyunlarda ve uygulamalarda çok güzel temalar var, onlardan animasyon/efekt bakıp örnek almak lazım."*
Bu araştırma **WP-290'ın 6. adımı tasarlanmadan önce** tamamlanır ve `AppFeel` alanlarını belirler.

**Çıktı:** `docs/TEMA-HIS-KATALOGU.md` — her "his" ailesi için:
1. Ne hissettiriyor (bir cümle), 2. hangi token'larla ifade edilir, 3. Flutter'da nasıl yapılır,
4. performans maliyeti (blur/gölge/shader riski), 5. "hareketi azalt" davranışı,
6. koyu/açık modda farkı.

**Ham liste (budanacak):** modern-minimal · vintage/retro gren · eskimiş karton kutu · neon/cyber ·
kâğıt-defter · zen/yumuşak · cam (glassmorphism) · düz (flat).

⚠️ **Telif:** Yalnız **fikir ve teknik desen** alınır. Başka uygulamanın asset'i, ikonu, tam renk
paleti veya birebir görsel kimliği kopyalanmaz.

---

### F-05 — Kart boyut paneli → sabit alt panel (Seçenek C) → **WP-291**

**Bugünkü sorun** (`Kodda doğrulandı`): `_SizePanel`, `_MatrixGrid`'in `Column`'unda grid'in altına
ekleniyor (`home_screen.dart:484-499`) ve tüm gövde tek `SingleChildScrollView` içinde (`:87`).
Kart aşağıdaysa panel de aşağıda kalıyor.

**Hedef:** Panel ekranın altına **yapışık**. Kapalıyken ince şerit (yalnız boyut), yukarı çekilince genişler.

**Uygulama adımları**
1. **Seçim state'ini yukarı taşı.** `_MatrixGridState._selected` (`:300`) → `HomeScreen` state'ine
   veya düzenleme moduna özel bir `ValueNotifier<DashboardCardType?>`'a. `_MatrixGrid` seçimi
   bildirir (`onSelect`), alt panel dinler. `_effectiveSelected()` (`:312`) mantığı **aynen korunur**.
2. **Paneli `Scaffold.bottomSheet`'e bağla.** `HomeScreen` her iki dalda kendi `Scaffold`'una
   sahip (`:161` masaüstü, `:210` mobil) → doğrudan mümkün. Yalnız `_editing == true` iken.
3. **İki kademeli yükseklik.** Kapalı ~72 dp (tutamak + boyut `−/+`), açık: kart adı + boyut +
   diğer eylemler. `DraggableScrollableSheet` veya `AnimatedContainer` + sürükleme.
4. **Grid altına boşluk ekle** — panel yüksekliği kadar; yoksa son kart panelin altında kalır.
5. **Masaüstü varyantı:** geniş pencerede panel tüm genişliği kaplamaz; dar/köşeye hizalı durur.
6. `_editing` kapanınca panel kaldırılır ve alt boşluk sıfırlanır.

**Kapsam dışı:** Saydamlık ayarı **eklenmeyecek** (sahip 3. turda kararlaştırdı — panelde bugün de yok).

**Edge case'ler**
| Durum | Beklenen |
|---|---|
| `layout.isEmpty` | Panel görünmez (`_EmptyDashboard` yolu — `:85`) |
| Seçili kart siliniyor | `_effectiveSelected()` ilk karta düşer, panel boş kalmaz |
| Klavye açılıyor | `viewInsets` ile panel yukarı itilir, çakışmaz |
| Sürükle-bırak sırasında | Panel görünür kalır ama sürüklemeyi engellemez (`_DragTargetCell` mantığı korunur) |
| Çok küçük ekran (≤ 600 dp yükseklik) | Kapalı panel yine ≤ 80 dp; açık panel ekranın ≤ %40'ı |
| Masaüstü çok geniş pencere | Panel içeriği `maxContentWidth` ile sınırlı (`:97` deseni) |
| Maksimum sütun sınırı | Genişlik `config.w < columns` sınırına saygı (`:873`). ⚠️ Izgara sütun üst sınırı (`kMaxGridColumns`) aşılırsa `analyze` temiz geçse de **runtime assert** çöker — sınır değiştirilmez |

**Kabul (ölçülebilir)**
1. Düzenleme modunda sayfa en alta kaydırılsa bile panel **ekranda kalır**.
2. Kapalı panel yüksekliği **≤ 80 dp**; açık panel ekranın **≤ %40**'ı.
3. Boyut değişince kart **≤ 1 kare** içinde yeni boyutu alır (mevcut davranış korunur).
4. Panel yüzünden **erişilemez kart kalmaz** (alt boşluk widget testi).
5. Dokunma hedefleri **≥ 48 dp**.
6. Sürükle-bırak, yukarı toplama (`compactUp`), sıfırlama ve kart silme davranışları **değişmez**
   (mevcut ana sayfa testleri değiştirilmeden yeşil).

---

### F-06 / F-07 — Dağıtım ve mağazalar (Aşama B ve C — bu turun kapsamı dışında)

**F-06'da kod işi yoktur.** Tek kod tabanı olduğu için WP-286…292 Windows'a otomatik gelir.
Yalnız `isDesktopWindow` dallanmaları ayrıca gözden geçirilir (WP-290 ve WP-291 kartlarında yazılı).

**Aşama B — Play Store.** Kaynak: `docs/PLAY-STORE-HAZIRLIK-TARAMASI.md`,
`docs/play-store/PLAY-RELEASE-GATE.md`. Kritik bağımlılık: **uygulama içi hesap silme (WP-276)** —
Play bunu şart koşuyor. Ayrıca gizlilik politikası, destek adresi, Veri güvenliği formu,
listeleme görselleri, `play` flavor'ının sideload'suz doğrulanması
(`core/config/distribution_channel.dart:83-88` — `play` ve `local` flavor'da sideload **mutlak kapalı**).

**Aşama C — Microsoft Store.** Kaynak: `docs/WINDOWS-STORE-PLAN.md` (WP-259 yerel QA · WP-260 Store
kimliği · WP-261 marka/listeleme · WP-262 private pilot). Bugünkü engel: paket `CN=Msix Testing`
test publisher'ı ile imzalı; kalıcı Store identity alınmadan yayın olmaz.

**Bilgi — güncelleme akışı** (`Kodda doğrulandı`, sahip sordu): Push bildirimi **yok**.
Uygulama açılışta `auth_gate.dart` → `maybeShowUpdateDialog` → GitHub Releases kontrolü →
uygulama içi pencere → indir → **SHA-256 doğrula** → kurulum ekranı
(`updater_service.dart:51-125`, `updater_dialog.dart:104-151`). Windows'ta indirilen paket
**yalnız MSIX**'tir (`updater_service.dart:124-125`) → portable ZIP kullanan kullanıcıda güncelleme
ikinci bir kopya kurar. Store'a geçiş bu sorunu tamamen ortadan kaldırır.

---

### F-08 — Kozmetik tur → **WP-292**

1. **Kamp ateşi animasyonları** — `campfire_scene.dart`, `campfire/layered_campfire_fire.dart`,
   `camp_critter.dart`. **Sahip şartı: birlikte konuşularak yapılacak** → iş sırası gelince ayrı
   konuşma turu açılır, kararlar `YENI-OZELLIK-NOTLARI.md`'ye eklenir, sonra kodlanır.
   Bağlam: hayvanlar şu an vektör fallback; tasarımcı asset'i bekliyor
   (`references/campfire/TASARIMCI_BRIEF.md`).
2. **Taç görseli** — `core/widgets/crowned_avatar.dart`.
   🔴 **`core/stats/achievement_ledger_engine.dart:358` `crownRankForXp` ve `kCrownXpThresholds`
   DEĞİŞTİRİLMEZ.** Taç XP'den türeyen bir göstergedir ve XP server-authoritative'dir
   (`AGENTS.md §2`). Eşiğe dokunmak kullanıcıların görünen kademesini sessizce kaydırır.
   Yalnız **çizim katmanı** yenilenir.
3. **Sahibin sonra göstereceği animasyon noktaları** — yeri geldiğinde işaret edilecek.

---

## 4. Risk kaydı

| # | Risk | Etki | Önlem | Sahip WP |
|---|---|---|---|---|
| R1 | Göç yazılmazsa kullanıcıların mevcut özel paletleri kaybolur | Yüksek | İdempotent göç + eski anahtarı silmeme (ADR-2) | 288 |
| R2 | Silme index kaydırırsa kullanıcı yanlış temayı görür | Yüksek | Silme = yuvayı boşalt, index sabit (ADR-2) | 288 |
| R3 | Yeni `ThemeExtension` `extensions:` listesine eklenmezse seçim hiçbir şey yapmaz (**ölü anahtar**) | Yüksek | `app_theme.dart:338` güncellenir + "seçim gerçekten etki üretiyor" testi | 288/290 |
| R4 | `AppTypography.copyWith`/`lerp` yeni alanları taşımazsa tema geçişinde alanlar kaybolur | Orta | İkisi de güncellenir; lerp round-trip testi | 288 |
| R5 | Kullanıcı okunamaz tema üretir | Orta | Canlı AA kontrast uyarısı + düzeltme önerisi | 290 |
| R6 | Font paketleme APK'yı şişirir / lisans ihlali | Orta | Subset + ≤ 2.5 MB kanıtı + yalnız OFL/Apache-2.0 + lisans dosyaları (ADR-4) | 290 |
| R7 | AR locale'de paketlenmiş font Arapça içermez → kutu karakter | Orta | `fontFamilyFallback` zinciri zorunlu + AR golden | 290 |
| R8 | Windows'ta deep link yok → şifre sıfırlama çözülmemiş kalır | Orta | E-posta kodu yolu (ADR-5) | 287 |
| R9 | Supabase panel adımı atlanırsa kod düzeltmesi kullanıcıya ulaşmaz | Yüksek | Ops runbook + WP kabulünde panel adımı şart | 287 |
| R10 | Sıcak dosya çakışması (`core/theme/**`, `main.dart`, `pubspec.yaml`, l10n) | Yüksek | 288 ve 290 **seri**; çakışma matrisi §5 | plan |
| R11 | Bildirim/izin ekranı yeniden yazılırsa cihazda kanıtlanmış davranış bozulur | Yüksek | Çatı birleştirme, widget'lar aynen (ADR-6) + mevcut testler değiştirilmeden yeşil | 286 |
| R12 | Taç görseli değişirken kademe eşiği kayar | Yüksek | `crownRankForXp` dokunulmaz + aynı XP → aynı kademe regresyon testi | 292 |
| R13 | Riverpod 3 auto-dispose: dinleyicisiz provider her `read`'de yeniden build olur → regresyon testi sessizce etkisiz kalır | Orta | Testlerde `container.listen(...)` ile abonelik açılır | 288/290 |
| R14 | Panel yüzünden son kart erişilemez kalır | Orta | Grid altına panel yüksekliği kadar boşluk + widget testi | 291 |

---

## 5. WP dökümü, sıra ve çakışma matrisi

> Son WP numarası `progress.md` "Proje Gerçekleri"nden okunur. Bu turun WP'leri **286–292**.

### 5.1 Önerilen sıra

```
1) WP-286   Ayarlar IA          — küçük, bağımsız, hemen görünür kazanım
2) WP-287   Şifre sıfırlama     — CANLI HATA, kullanıcıyı bugün etkiliyor
3) WP-291   Boyut paneli        — bağımsız, sahibi her gün rahatsız eden UX sorunu
4) WP-288   Tema modeli/saklama — core/theme + main.dart; tek başına çalışır
5) WP-289   His araştırması     — doküman; 288 sürerken paralel gidebilir
6) WP-290   Tema sihirbazı      — 288 kabul + 289 katalog şart
7) WP-292   Kozmetik            — 290 sonrası + sahiple kamp ateşi konuşması
```

### 5.2 Çakışma matrisi

| WP | Ana SAHİP yüzey | Sıcak dosya | Kimle çakışır |
|---|---|---|---|
| 286 | `features/profile/settings_screen.dart`, `features/notifications/**`, `features/clock/clock_widgets_screen.dart` | l10n | 290 (yalnız l10n) → **l10n'de seri** |
| 287 | `data/repositories/**auth**`, `core/config/**`, `features/auth/**` | — | yok |
| 288 | `core/theme/custom_theme.dart` (yeni), `core/theme/theme_settings.dart`, `core/theme/theme_tokens.dart`, `main.dart` | `core/theme/**`, `main.dart` | **290 ile seri** |
| 289 | yalnız `docs/**` | — | yok (kod yazmaz) |
| 290 | `features/profile/**`, `core/theme/theme_tokens.dart`, `pubspec.yaml`, `assets/fonts/**` | `core/theme/**`, `pubspec.yaml`, l10n | **288 ile seri**, 286 ile l10n'de seri |
| 291 | `features/home/home_screen.dart` (+ `features/home/widgets/**`) | — | yok |
| 292 | `core/widgets/crowned_avatar.dart`, `features/classroom/widgets/campfire*` | — | yok |

> ✅ **WP-286 / 287 / 291 paralel çalışabilir** — ortak SAHİP dosyası yok.
> (Not: 286 l10n'e girer; 290 da girer → bu ikisi l10n'de aynı anda olmamalı, ama 290 zaten sonra.)
> ⚠️ **WP-288 ve WP-290 asla aynı anda açılmaz** — ikisi de `core/theme/**`.
> ⚠️ **WP-290 `pubspec.yaml`'a girer** — o sırada başka WP pubspec'e dokunmaz.
> ⚠️ **Tema programı açıkken Saat ve Başarım programları açılmaz** (`AGENTS.md §1.2`).
> ✅ Plan yazıldığında `progress.md` Aktif Çalışma Kaydı'nda **tüm lane'ler boşta** → başlangıç temiz.

### 5.3 Her WP'de zorunlu DoD (`AGENTS.md §3`)

- [ ] Kabul kriterleri yazılı ve tek tek doğrulandı (ölçülebilir; "profesyonel olsun" kabul değil)
- [ ] **Ölü anahtar yok** — her kontrol gerçek etki üretiyor
- [ ] `flutter analyze` **0 uyarı** (bayraksız çalıştır) · ilgili `flutter test` yeşil
- [ ] Yeni mantık birim/entegrasyon testiyle örtülü · görsel değişiklik **golden** ile
- [ ] Boş / hata / çevrimdışı durumları ele alındı
- [ ] RLS/güvenlik değerlendirmesi yapıldı; sır istemcide yok
- [ ] Migration + geri alma (bu turda yalnız gerekirse — Aşama A'da şema değişikliği **yok**)
- [ ] Erişilebilirlik: WCAG AA kontrast, 48 dp dokunma, açık/koyu
- [ ] **4 dilde l10n anahtarı tam** (`tr`, `en`, `de`, `ar`)
- [ ] Tek ayrık commit, **yalnız kendi SAHİP yolları** (`git add -A` yasak)

---

## 6. Aşama A bitiş tanımı

Aşama A "bitti" denebilmesi için:
1. WP-286…292 hepsi en az **"Otomatik test geçti"** seviyesinde,
2. bir beta (`beta-v44xx`) yayımlanmış ve **gerçek cihazda sahip tarafından kabul edilmiş**,
3. şifre sıfırlama uçtan uca cihazda doğrulanmış (**Supabase panel adımı dahil**),
4. tema göçü gerçek bir hesapta doğrulanmış (güncelleme sonrası kullanıcının teması bozulmadı),
5. stable sürüm normal release kapısından geçmiş (`AGENTS.md §3` release kalite kapısı:
   kritik bug 0 · testler yeşil · Android release build · **gerçek Samsung cihaz** · beta soak ≥ 3 gün · rollback hazır).

---

## 7. Açık kararlar

| # | Konu | Durum |
|---|---|---|
| K-1 | Font kaynağı | ✅ **Karar verildi (ADR-4):** fontlar paketlenir, `google_fonts` kullanılmaz. Sahip "font kısmını halledersin" dedi. |
| K-2 | Windows'ta şifre sıfırlama | ✅ **Karar verildi (ADR-5):** Android deep link + her platformda çalışan e-posta kodu yolu. |
| K-3 | Hangi "his" seçenekleri girecek | ⏳ **WP-289 çıktısı** — katalog hazır olunca sahiple birlikte kısa listeden seçilir. |
| K-4 | Supabase panel adımı | ⏳ **Sahip yapacak** — WP-287 kodu hazır olunca staging + production panelinde Redirect URL + Site URL. Claude panele erişemez. |
| K-5 | Kamp ateşi tasarımı | ⏳ **Sahiple konuşma** — WP-292 öncesi ayrı tur. |

---

## 8. Kanıt durumu

- §1 Repo analizi: **`Kodda doğrulandı`** — her satır dosya:satır referanslı, 2026-07-24 tarihli ağaç.
- §2 ADR'ler: karar + gerekçe; uygulama sırasında worker detayı netleştirir, kararı değiştirmez.
- §3 Tasarımlar: öneri düzeyinde; kabul kriterleri bağlayıcı.
- §4 Risk kaydı: her risk bir WP'ye atanmış.
- Cihaz davranışı gerektiren kabuller: **`Cihazda doğrulanmalı`**.
- WP-289 kataloğu: **henüz üretilmedi**.
