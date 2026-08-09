# Denetim — Tema / görünüm / kişiselleştirme + erişilebilirlik

> **Yöntem:** yalnız kod kanıt sayıldı. `progress.md`, `docs/**` ve kod
> yorumları iddia kabul edildi ve koda karşı ölçüldü. Derleme başlatılmadı,
> test koşturulmadı, hiçbir üretim dosyası değiştirilmedi. Kontrast sayıları
> WCAG 2.1 bağıl parlaklık formülüyle **repo'daki sabit renklerden** hesaplandı
> (aynı formül `app/lib/core/theme/warning_tokens.dart:52` ve
> `app/lib/features/profile/theme_builder/theme_contrast.dart:31`).
>
> **Tarih:** 2026-08-09 · **Kapsam:** `app/lib/core/theme/**`,
> `app/lib/features/profile/appearance_screen.dart`,
> `app/lib/features/profile/theme_builder/**`, `app/lib/features/home/**`,
> `app/lib/features/classroom/widgets/campfire*`, `app/lib/core/widgets/**`,
> `app/lib/features/desktop/**`, `app/lib/features/stats/widgets|charts/**`,
> `app/test/**` golden + a11y testleri.
>
> Bugün (2026-08-09) bu alana dokunanlar `git log --oneline -130 -- <dosya>` ile
> tek tek kontrol edildi: **WP-594** (odak halkası tokeni + masaüstü rozet),
> **WP-604** (seri alevi), **WP-611** (platform sınır şeridi), **WP-541**
> (büyük yazı + aciliyet renkleri). Bunların düzelttikleri bu raporda **yok**.
> Aşağıdakilerin hiçbirine bugün dokunulmadı.

**Özet:** 2 KANAMA · 7 RİSK · 4 TEMİZLİK.

---

## KANAMA

### K1 — `ColorScheme`'de "container" rolleri HİÇ tanımlanmamış; üç ayrı yüzeyde ölçülen kayıp

**Belirti.** Uygulamanın tüm temaları tek fabrikadan çıkıyor
(`AppTheme._buildFromTokens`). O fabrika `ColorScheme`'i elle kuruyor ama
`primaryContainer` / `secondaryContainer` / `tertiaryContainer` /
`errorContainer` (ve karşılıkları) alanlarını **hiç geçmiyor**. Flutter'ın
`ColorScheme` getter'ları bu durumda tam doygunluktaki ana renge düşüyor. Yani
"container" niyetiyle yazılmış her yüzey, aslında markanın en bağıran rengi
oluyor — ve bu rengin ÜSTÜNE çizilen her şey paletle çarpışıyor.

**Kanıt.**
- `app/lib/core/theme/app_theme.dart:331-354` — `ColorScheme(...)` çağrısında
  geçen alanlar: brightness, primary, onPrimary, secondary, onSecondary,
  tertiary, onTertiary, error, onError, surface, onSurface, onSurfaceVariant,
  surfaceContainerLowest, surfaceContainerLow, surfaceContainer,
  surfaceContainerHigh, surfaceContainerHighest, outline, outlineVariant.
  Hiçbir `*Container` (primary/secondary/tertiary/error) rolü yok.
- Flutter SDK (`c9a6c48`, `/c/src/flutter/packages/flutter/lib/src/material/color_scheme.dart`):
  - `:1050` `Color get primaryContainer => _primaryContainer ?? primary;`
  - `:1099` `Color get secondaryContainer => _secondaryContainer ?? secondary;`
  - `:1153` `Color get tertiaryContainer => _tertiaryContainer ?? tertiary;`
  - `:1202` `Color get errorContainer => _errorContainer ?? error;`
- `app/lib/core/theme/app_theme.dart:335,337` — `secondary: colors.accent` ve
  `tertiary: colors.accent`. Yani `secondaryContainer == tertiaryContainer ==
  accent`, `primaryContainer == primary`.

**Ölçülen üç sonuç** (15 hazır temanın sabit renkleriyle,
`app/lib/core/theme/theme_presets.dart:93-513`):

1. **Kamp hayvanı seçicisinde seçili döşemenin yazısı okunmuyor.**
   `app/lib/features/profile/widgets/camp_animal_picker.dart:90` zemin
   `primaryContainer.withValues(alpha: 0.6)` (= `primary` %60), `:106` yazı
   `textTheme.labelSmall` — **rengi verilmemiş**, yani `textPrimary`.
   15 temanın **9'unda** normal metin için gereken 4.5'in altında:
   ocean_glass 2.54 · retro_terminal 2.59 · material_you 2.83 · deep_amoled 2.87
   · glacier_ice 3.27 · paper_ink 3.69 · coffee_library 3.79 · royal_academy 4.04
   · future_edge 4.10. Ekran: Profil > Ayarlar
   (`app/lib/features/profile/settings_screen.dart:56`).

2. **Masaüstü sol panelin WinUI seçim çubuğu 13/15 temada görünmez.**
   `app/lib/features/desktop/desktop_navigation_pane.dart:287` seçili döşeme
   zemini `scheme.secondaryContainer` (= accent), `:320-329` o zeminin üstüne
   çizilen 3 px'lik seçim göstergesi `color: scheme.primary`. primary/accent
   kontrastı 15 temanın **13'ünde** 3.0'ın altında; `retro_terminal` **1.01**,
   `material_you` **1.01**, `soft_cream` 1.06, deep_amoled 1.15,
   campfire_night 1.19. Aynı çarpışma iki yerde daha:
   `desktop_navigation_pane.dart:517` (`Icons.check`, `scheme.primary`, zemin
   yine `secondaryContainer`) ve
   `app/lib/features/desktop/desktop_page_scaffold.dart:246` + `:255-266`
   (seçili satır zemini `secondaryContainer`, sol accent çubuğu `scheme.primary`).

3. **Seri paleti 8 renk vaat ediyor, 4 veriyor.**
   `app/lib/features/stats/charts/series_palette.dart:12-24` sırasıyla
   primary · tertiary · secondary · error · primaryContainer · tertiaryContainer
   · secondaryContainer · outline döndürüyor. Fallback sonrası: 0≡4 (primary),
   1≡2≡5≡6 (accent). Gerçekte 4 ayrı renk var.

**Etki.** Kök neden tek, belirti üç ayrı katmanda. Kullanıcı temayı değiştirdikçe
hangi yüzeyin kaybolacağı öngörülemez; bu tam olarak WP-358 (uyarı rozeti) ve
WP-594 (odak halkası) ile iki kez ayrı ayrı yamalanan sınıfın **üçüncüsü** — ama
bu sefer token seviyesinde, tek dosyada.

**Öncelik:** KANAMA

---

### K2 — Grup grafiklerinin üye renkleri açık temalarda kayboluyor; yorum tersini iddia ediyor

**Belirti.** Grup istatistiklerinde her üyeye bir renk atanıyor. Renk **sabit
açıklıkta** (HSL lightness 0.62) üretiliyor ve temanın açık/koyu olduğuna hiç
bakmıyor. Açık temada bu renklerin yarısından fazlası beyaz zeminde ayırt
edilemiyor: liderlik çizgisi ve donut dilimi çiziliyor ama görünmüyor.

**Kanıt.**
- `app/lib/features/stats/widgets/member_chart_colors.dart:18-23` —
  `HSLColor.fromAHSL(1, (24 + hueStep * i) % 360, 0.70, 0.62)`. Doygunluk ve
  açıklık sabit; `ColorScheme`/`Brightness` fonksiyona hiç girmiyor.
- Aynı dosya `:13-14` yorumu: *"Yüksek saturation + dengeli lightness koyu/açık
  temada okunur kalır."* — **ölçüm bunu çürütüyor.**
- Ölçüm (6°'lik adımlarla 60 ton, WCAG metin-dışı eşiği 3.0):
  - `nordic_snow` yüzeyi `#FFFFFF` (`theme_presets.dart:149`): 60 tonun **33'ü**
    3.0'ın altında, en kötü **1.38** (sarı-yeşil bölge).
  - `paper_ink` `#FAFAF6`: 35/60 altında, en kötü 1.32.
  - `pastel_day` `#FAFAFF`: 35/60 altında, en kötü 1.32.
  - `soft_cream` `#FFFCF8`: 34/60 altında, en kötü 1.35.
- Çizim yerleri: `app/lib/features/stats/widgets/leaderboard_rank_chart.dart:93`
  (çizgi rengi) ve `:117` (legend kutusu);
  `app/lib/features/stats/widgets/class_stats_view.dart:377` (donut dilimi);
  üretim: `class_stats_view.dart:100`.

**Etki.** 4 hazır açık tema + her temanın açık modu + kullanıcının kurduğu her
açık özel tema. 5 kişilik bir grupta tonlar 24°/96°/168°/240°/312° düşüyor;
96° (sarı-yeşil) beyaz zeminde ~1.5 kontrast veriyor — o üyenin çizgisi
**yok gibi**. Kullanıcı grafiği yanlış okuyor, hata mesajı yok.

**Öncelik:** KANAMA

---

## RİSK

### R1 — Liderlik/donut grafiklerinde ayrım YALNIZ renge dayanıyor

**Belirti.** Liderlik geçmişi çizgi grafiğinde üyeler yalnız renkle ayrılıyor:
desen (dash), işaret (marker), etiket yok. Legend de renk kutusu + isim; kutunun
kendisi yine yalnız renk. Renk körü kullanıcı için grafik okunamaz.

**Kanıt.**
- `app/lib/features/stats/widgets/leaderboard_rank_chart.dart:88-97` —
  `LineChartBarData(color: memberColors[m.id]!, ...)`. `dashArray` yok;
  `barWidth` yalnız `currentUserId` için farklı (3.5 / 2), diğer tüm üyeler eşit.
- `:113-120` — legend kutusu 10×3 px düz renk.
- `app/lib/features/stats/widgets/class_stats_view.dart:371-378` — donut
  dilimlerinin tek ayrımı `memberColors[...]`.
- Bu iş için yazılmış yardımcı **var ama üretimde çağıran yok**:
  `app/lib/features/stats/charts/series_palette.dart:26` `patternLabel` ve `:29`
  `labeled` — `grep -rn "patternLabel\|\.labeled(" app/lib` yalnız kendi
  dosyasını buluyor.

**Etki.** WP-157'de "yalnız renge dayanma" kuralı yazılmış (`series_palette.dart:4`),
sonra hiç uygulanmamış.

**Öncelik:** RİSK

---

### R2 — "Material You" teması dinamik değil; `dynamicSeed` yolunun tek çağıranı yok

**Belirti.** Kullanıcı "Material You" temasını seçiyor; kod sistem/duvar kâğıdı
renginden tohum almayı destekliyor ama uygulama o tohumu **hiç geçmiyor**. Sonuç
sabit mavi bir tema.

**Kanıt.**
- `app/lib/core/theme/theme_presets.dart:428` — `isDynamic: true`.
- `app/lib/core/theme/app_theme.dart:177-195` ve `:233-245` — dinamik dal
  `dynamicSeed` parametresine bağlı.
- `app/lib/main.dart:239-240` — `AppTheme.fromFamily(family, Brightness.light)`
  / `.dark)`; `dynamicSeed` **verilmiyor**. `grep -rn "dynamicSeed" app/lib app/test`
  → yalnız `app_theme.dart` içindeki tanım/kullanım satırları (6 satır), başka
  hiçbir çağıran yok.
- `app/pubspec.yaml` içinde `dynamic_color` benzeri bir paket yok; tohumu
  üretecek platform kanalı da yok.
- Belge iddia ediyor: `docs/TEMA-MIMARISI.md:92` — *"Standart yuvarlaklık ve
  dinamik renk eşleşmesi."*

**Etki.** Reklamı yapılan bir kişiselleştirme özelliği ölü. `app_theme.dart`
içindeki iki dinamik dal (yaklaşık 30 satır) hiç çalışmıyor.

**Öncelik:** RİSK

---

### R3 — Hazır tema seçmek, kullanıcının "Sistem" (otomatik koyu/açık) tercihini SESSİZCE siliyor

**Belirti.** Görünüm ekranında mod seçici (Koyu/Açık/Sistem) hazır tema
ızgarasının **üstünde** duruyor. Kullanıcı "Sistem"i seçip sonra bir tema
seçiyor; tema seçimi modu ezip diske yazıyor. Kullanıcıya hiçbir şey söylenmiyor
ve tercih geri gelmiyor — cihaz gece moduna geçtiğinde uygulama artık takip
etmiyor.

**Kanıt.**
- `app/lib/features/profile/appearance_screen.dart:161-183` — `SegmentedButton`
  → `notifier.setMode(...)`.
- `app/lib/features/profile/appearance_screen.dart:209-214` — kart dokunuşu
  `notifier.setFamily(preset.id)`.
- `app/lib/core/theme/theme_settings.dart:362-377` — `setFamily` içinde
  `mode = preset.brightness == dark ? ThemeMode.dark : ThemeMode.light;`
  ardından `prefs.setString(_kMode, mode.name)`. `ThemeMode.system` korunmuyor.
- Karşılaştırma: `setActiveCustomTheme` (`:323-340`) modu **değiştirmiyor**;
  yani aynı ekranda iki tema kaynağı iki farklı davranış gösteriyor.

**Öncelik:** RİSK

---

### R4 — Görünüm ekranındaki hazır tema ızgarası büyük yazıda taşıyor (hesaplandı, cihazda ölçülmedi)

**Belirti.** Hazır temalar sabit en/boy oranlı bir `GridView` içinde. Hücre
yüksekliği yazı ölçeğinden bağımsız; içindeki metin ölçeklenince sığmıyor.

**Kanıt.**
- `app/lib/features/profile/appearance_screen.dart:194-199` —
  `SliverGridDelegateWithFixedCrossAxisCount(childAspectRatio: desktop ? 2.15 : 1.75)`.
- `:342-343` iç dolgu `EdgeInsets.symmetric(horizontal: 12, vertical: 8)` (16 px),
  `:408-410` önizleme `SizedBox(height: 38)` — **sabit, ölçeklenmiyor**,
  `:361` `SizedBox(height: 6)`, `:365-374` `bodyMedium` metin.
- `bodyMedium` = `typography.body` (`app/lib/core/theme/app_theme.dart:397`) →
  `fontSize 15, height 1.35` (`app/lib/core/theme/theme_tokens.dart:148-153`).
- Hesap (360×720 telefon, `desktopGridColumns` < 720 → 2 sütun,
  `app/lib/features/desktop/desktop_surface.dart:185-187`): ızgara genişliği
  360−32 = 328, hücre genişliği (328−10)/2 = 159, hücre yüksekliği 159/1.75 = **90.9**.
  İçerik ölçek 1.0'da 16+38+6+20.3 = 80.3 (sığıyor); ölçek 2.0'da
  16+38+6+40.5 = **100.5** → ~10 px taşma.
- 320 px genişlikte hücre yüksekliği 79.4; ölçek 1.0'da içerik 80.3 → **sınırda**.
- Mevcut kapı bunu ölçmüyor: `app/test/features/appearance_screen_test.dart:165`
  360×800'de ama **varsayılan yazı ölçeğinde** koşuyor;
  `app/test/features/appearance_screen_golden_test.dart:44-47` yalnız 38 px'lik
  önizleme parçasını 1200×800 masaüstünde fotoğraflıyor — kart yerleşimini
  görmüyor. WP-541 büyük-yazı matrisi (`app/test/features/large_text_reachability_wp541_test.dart:211-341`)
  bu ekranı kapsamıyor.

**Not.** Bu bulgu aritmetiktir; cihazda/testte doğrulanmadı. 320 px + ölçek 1.0
kenar durumunda emin değilim, ölçek 2.0 durumunda taşma payı belirgin.

**Öncelik:** RİSK

---

### R5 — Ekran okuyucu "hangi tema seçili" bilgisini hiç almıyor

**Belirti.** Görünüm ekranında seçili tema görsel olarak üç işaretle belli:
kenarlık rengi, kalın yazı, `check_circle` ikonu. Üçü de ekran okuyucuya
gitmiyor: seçim durumu semantik ağaca yazılmıyor, ikonun etiketi yok.

**Kanıt.**
- `app/lib/features/profile/appearance_screen.dart:339-390` — `_PresetCard`
  `InkWell` ile kuruluyor; `Semantics(button:, selected:)` yok. Seçim yalnız
  `:344-355` kenarlık/dolgu rengi, `:367-371` `fontWeight`, `:376-383`
  `Icon(Icons.check_circle)` — ikonun `semanticLabel`'ı yok.
- `:266-272` — `_CustomThemeTile` `ListTile`'a `selected:` parametresi
  **geçmiyor** (parametre var, `:262-264` yalnız kenarlık için kullanılıyor).
  `:276-277` yine etiketsiz `check_circle`.
- Karşı örnek (doğru yapılmış): `app/lib/features/stats/widgets/draggable_date_range_picker.dart:275-278`
  `Semantics(button: true, selected: selected, label: ...)`.

**Etki.** Kör kullanıcı temaları gezebiliyor ama hangisinin aktif olduğunu
öğrenemiyor; seçim yaptıktan sonra geri bildirim de yok.

**Öncelik:** RİSK

---

### R6 — Dokunma hedefi 48 dp altında iki yer

**Belirti.** İki etkileşimli öğe parmakla güvenilir biçimde vurulamayacak
kadar küçük.

**Kanıt.**
- `app/lib/features/home/home_screen.dart:879-893` — kart düzenleme kipindeki
  "Kaldır" düğmesi: `padding: EdgeInsets.zero`,
  `constraints: BoxConstraints(minWidth: 28, minHeight: 28)`, ikon 17 px.
  Aynı dosyada doğrusu yapılmış: `:1155-1157` yeniden boyutlandırma tutamacı
  `SizedBox(width: 48, height: 48)` (yorumu da `:1142-1144`'te açıkça
  "min. parmak hedefi 48"). Yani kural biliniyor, bu düğmede uygulanmamış.
- `app/lib/features/stats/widgets/study_heatmap.dart:52` — `const cell = 13.0`;
  `:88-100` her hücre bir `Tooltip` + `Container(13×13)`. Dosya başlığı `:25`
  *"Her hücre dokunulabilir (tarih + süre)"* diyor; 13 dp hedefte bu iddia
  pratikte tutmaz. (Tooltip semantiği en azından etiket veriyor — tümüyle
  sessiz değil.)

**Öncelik:** RİSK

---

### R7 — Masaüstünde uygulama, kullanıcının sistem yazı boyutunu 0.65×'e kadar küçültüyor

**Belirti.** Windows kabuğu tüm arayüzü pencere genişliğine göre tek bir
`FittedBox` ile ölçekliyor. Bu ölçek, kullanıcının işletim sisteminde seçtiği
büyük yazı ayarının üstüne **çarpım** olarak biniyor: dar pencerede yazı,
kullanıcının istediğinden %35 küçük çiziliyor.

**Kanıt.**
- `app/lib/features/desktop/desktop_proportional_scale.dart:16-25` —
  `raw = viewport.width / 1100`, `clamp(0.65, 1.5)`.
- `:73-82` — `FittedBox(fit: BoxFit.fill)` + `MediaQuery(size: logical)`;
  `textScaler` **dokunulmadan** aktarılıyor, yani sistem ölçeği bu 0.65 ile
  çarpılıyor.
- Kullanım: `app/lib/features/desktop/desktop_home_shell.dart:119`.
- Uygulamada `textScaler`'ı okuyan/telafi eden tek satır yok:
  `grep -rn "TextScaler\|textScaler:" app/lib` → **0 sonuç**
  (tek `textScalerOf` kullanımı `app/lib/features/classroom/widgets/class_detail_screen.dart:1047`,
  o da genişlik kısıtı için).

**Etki.** 1100 px'in altındaki her pencerede (yaygın kullanım) az görenler için
yazı, sistemde ayarladıklarından küçük çıkıyor. Tasarım kararı olarak yazılmış
(`:5-9` yorumu) ama erişilebilirlik maliyeti hiçbir yerde ele alınmamış.

**Öncelik:** RİSK

---

## TEMİZLİK

### T1 — `StackedBarChart` + `SeriesPalette` üretimde hiç çizilmiyor

`app/lib/features/stats/charts/stacked_bar_chart.dart:7` sınıfının tek çağıranı
`app/test/features/stats/chart_primitives_test.dart:39`; `SeriesPalette`'in tek
çağıranı da o ölü grafiğin `:21` satırı. Ayrıca `StackedBarChart.seriesNames`
(`:12`) yapıcıda alınıyor, `build` içinde **hiç okunmuyor**. İlgili test
(`chart_primitives_test.dart:69-76`) yalnız "boş değil" diyor, yani renk
çakışmasını (K1/3) ölçmüyor.

### T2 — Token motorunun kolay-erişim katmanı büyük ölçüde ölü

`app/lib/core/theme/theme_tokens.dart:482-501` — `context.appShapes`,
`context.appAtmosphere`, `context.appMotion`, `context.appFeel` uzantılarının
`app/lib/` içinde **sıfır** çağıranı var (`appColors` 1, `appTypography` 2, ikisi
de yalnız `theme_builder/theme_preview.dart`). Token'lar UI'a `ThemeData` üzerinden
(cardTheme/textTheme/colorScheme + `FeelOverlay`, `main.dart:279`) ulaştığı için
davranış doğru — ama API katmanı gereksiz.

### T3 — `AppMotion.resolve` ve `respectReduceMotion` hiç çağrılmıyor

`app/lib/core/theme/theme_tokens.dart:354,374-377`. "Hareketi azalt" desteği
tema katmanında değil, üç yerde elle yapılıyor:
`app/lib/core/widgets/avatar_aura.dart:93-95`,
`app/lib/features/classroom/widgets/campfire_scene.dart:343-345,365-367`,
`app/lib/features/profile/widgets/reward_toast.dart:90-94`. Yani davranış var,
token yolu ölü. Yeni bir animasyon eklendiğinde "unutulur" riski buradan geliyor.

### T4 — `AppColors.success` hiçbir yüzeyde çizilmiyor

`app/lib/core/theme/theme_tokens.dart:19,49` (`success: const Color(0xFF22C55E)`
sabiti) ve `theme_presets.dart:70`. `grep -rn "\.success" app/lib` → yalnız
serileştirme (`custom_theme.dart:112`) ve kopyalama (`theme_draft.dart:461`).
Her tema onu taşıyor, hiçbir widget okumuyor. Not: okunsaydı zaten sabit yeşil
olacaktı, yani K1'in aynı sınıfından bir tuzak.

---

## Kontrol ettim, SAĞLAM çıktı

- **WP-358 uyarı token'ı gerçekten zeminden türetiliyor ve gerçekten kullanılıyor.**
  `app/lib/core/theme/warning_tokens.dart:64-113` saf + deterministik;
  çağıranlar `core/navigation/profile_tab_badge.dart:71`,
  `features/classroom/widgets/timer_mode_controls.dart:113`,
  `features/profile/widgets/primary_group_entry.dart:19`,
  `features/profile/widgets/primary_group_selector_card.dart:227`. Ölü token değil.
- **WP-594 odak halkası** (`core/theme/focus_ring_tokens.dart:38-47`) akromatik
  uçlardan seçiyor, `desktop_navigation_pane.dart:178`'de zemin **açıkça**
  geçiliyor ve seçili döşemede doğru zemin (`secondaryContainer`) veriliyor
  (`:399-401`, `:529-531`). Bu kol sağlam — K1/2'deki sorun halka değil,
  onun yanındaki seçim çubuğu.
- **Görev aciliyet renkleri** (`core/tasks/task_deadline.dart:87-159`) iki
  zemine birden karşı kontrast düzeltiyor **ve** renkten bağımsız bir a11y
  anahtarı üretiyor (`taskUrgencyKind`, `:162-173`) — anahtarın gerçek çağıranı
  var: `features/clock/tasks_screen.dart:397` ve
  `features/home/widgets/tasks_card.dart:253`.
- **WP-308 tipografi tazeleme** gerçek: `app_theme.dart:330`
  `rawTypography.recolored(colors.textPrimary)` her `ThemeData` kurulumunda
  koşuyor, `theme_tokens.dart:170-175` dört slotu da yeniden renklendiriyor.
- **Tema sihirbazının AA koruması ölü değil:**
  `theme_builder/theme_builder_steps.dart:167-173` uyarı üretiyor,
  `:203-215` tek dokunuşla düzeltme bağlı (`fixForegroundForAa`,
  `theme_contrast.dart:50-72`).
- **Kamp ateşi PNG seti eksik değil:** `app/assets/campfire/` 10 PNG + `2.0x/`
  diskte duruyor, `app/pubspec.yaml:107-108` ile paketleniyor. Sahne kendi sabit
  paletiyle çiziliyor (`camp_critter.dart`, `campfire_scene.dart`), üstündeki
  metinler beyaz + siyah gölge (`campfire_scene.dart:857-875`) — tema
  değiştiğinde okunabilirlik bozulmuyor.
- **Kamp ateşi durum ayrımı renge dayanmıyor:** `campfire_scene.dart:918-926`
  nokta rengi + `:979` metin etiketi birlikte.
- **Başarım/taç kademeleri renge dayanmıyor:** `core/stats/progression_visuals.dart:33-49`
  ve `:114-130` metin etiketleri üretiyor, `profile/widgets/achievement_showcase.dart`
  (`:722, :840, :1051, :1466, :1547, :1772`) ve `gamification_card.dart:184`
  bunları gerçekten çiziyor.
- **`lib/` içinde tema paletinden kopuk `Colors.red/green/orange…` kalmamış:**
  `grep` tek isabet veriyor (`stats/widgets/class_stats_view.dart:377`
  `?? Colors.grey` fallback'i) ve o da yalnız eşleşmeyen id için.
- **Golden kapısı gerçek:** `.github/workflows/ci.yml:254-279` ayrı bir Windows
  işi `flutter test --tags=golden` koşuyor; `scripts/test_all.py:299-301` de
  aynı kapıyı taşıyor. (Yalnız `release.yml:129` ve `stable-candidate.yml:107`
  goldenları hariç tutuyor — yayın kapısı goldenları görmüyor; bu bir gözlem,
  bulgu olarak yazacak kadar emin değilim çünkü `windows-release.yml:154`
  koşuyor.)
- **`textScaler`'ı kısan/kilitleyen kod yok:** `grep -rn "TextScaler"` → 0.
  Yani büyük yazı ayarı hiçbir yerde bilerek bastırılmıyor (R7 ayrı bir
  mekanizma: kabuk ölçeği).
- **`AppColors` "container" olmayan rolleri tutarlı:** container zemin/yazı
  çiftleri (`primaryContainer`/`onPrimaryContainer` vb.) kullanan yerler —
  `core/widgets/user_avatar.dart:31+38`,
  `classroom/widgets/class_chat_card.dart:287-291`,
  `desktop_navigation_pane.dart:292-297`,
  `clock/platform_limit_banner.dart:29-34`,
  `admin/widgets/moderation_queue_card.dart:154-156` — **eşleşmiş çift**
  kullandıkları için K1'den okunabilirlik kaybı almıyorlar; yalnız beklenenden
  daha doygun görünüyorlar.
