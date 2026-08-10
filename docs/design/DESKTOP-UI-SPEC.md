# Masaüstü Arayüz Tasarım Speci (WP-670)

> **Durum:** karar belgesi. Uygulayan ajanlar buradaki **sayıları** birebir kullanır.
> **Kapsam:** yalnız düzen/yoğunluk. **İşlev değişmez** — bkz. §7.
> **Tetikleyen:** sahip v64 Windows sürümünü reddetti: *"dikey mobil uygulama için
> tasarlanan arayüzler yatay pc ekranında çok kötü duruyor, tamamen mobilin
> penceresi gibi olmuş, hiç beğenmedim, baştan tasarla."*

---

## 0. Kök neden — düzen değil, **ölçek**

Sahip "mobilin penceresi gibi olmuş" derken tam olarak doğru şeyi tarif etti.
Ekranların düzeni ikincil kusur. Birincil kusur şu dosyada:

`app/lib/features/desktop/desktop_proportional_scale.dart`

```dart
const double kDesktopReferenceWidth = 1100;   // referans genişlik
maxScale = 1.5;                               // üst sınır
```

`DesktopHomeShell` bütün gövdeyi bu ölçeğe sarar (`desktop_home_shell.dart:119`)
ve içeriye **sahte bir MediaQuery** verir (`desktop_proportional_scale.dart:80`).
Sonuç, gerçek pencere genişliği ne olursa olsun uygulamanın **gördüğü** genişlik:

| gerçek pencere | ölçek | uygulamanın gördüğü mantıksal genişlik |
|---:|---:|---:|
| 1100 | 1.000 | 1100 |
| 1280 | 1.164 | 1100 |
| 1440 | 1.309 | 1100 |
| 1600 | 1.455 | 1100 |
| 1920 | 1.500 | 1280 |
| **2000** | **1.500** | **1333** |
| 2560 | 1.500 | 1707 |

İki sonuç çıkar ve ikisi de sahibin şikâyetinin birebir karşılığıdır:

1. **1100–1650 px arası hiçbir kırılım noktası tetiklenmez.** Uygulama her zaman
   1100 mantıksal px görür. 1440'lık `maxContentWidth` bu bantta **ölü koddur**:
   içerik zaten 1100'e sıkışmıştır, 1440'a hiç ulaşamaz.
2. **1650 px üstünde arayüz büyütülür, yeniden düzenlenmez.** 15 px'lik gövde
   yazısı ekranda 22.5 px olarak boyanır. Bu, tanımı gereği "mobil pencerenin
   büyütülmüşü"dür.

`desktop_home_shell.dart:122`'deki yorum bunu zaten itiraf ediyor:

> `// Ölçek içi MediaQuery = tasarım boyutu → pane her zaman expanded.`

**KARAR 0 (diğer her şeyden önce gelir):** `DesktopHomeShell` gövdesindeki
`DesktopProportionalScale` sarmalayıcısı **kaldırılır**. Aşağıdaki hiçbir kırılım
noktası, hiçbir sütun kuralı bu sarmalayıcı dururken çalışmaz — önce bu, sonra
gerisi.

*Güvenli mi?* Evet. Compact Focus kipi (`Ctrl+Shift+M`, 360×220 pencere) bu
sarmalayıcıyı kullanmaz: `main.dart:273` `CompactFocusView`'ü `desktopChrome`
seviyesinde, yani `DesktopHomeShell`'in **üstünde** takas eder. Ölçeği kaldırmak
compact kipi bozmaz.

---

## 1. Kırılım noktaları

### 1.1 Bugünkü ladder ve neden yetmedi

`app/lib/core/desktop/desktop_layout.dart`:

```dart
static const double compact = 640;
static const double expanded = 1008;
static const double maxContentWidth = 1440;
```

640 ve 1008 **doğru** — WinUI'nin kendi Small / Medium / Large sınırları bunlar
(Small <640, Medium 641–1007, Large 1008+). Yetmemesinin üç sebebi var:

1. **WinUI ladder'ı 1008'de biter.** Microsoft'un tablosunda 1024×640 laptop ile
   1920×1080 masaüstü **aynı kovada**. 2560 px'lik bir monitör için ayrı bir
   talimat yok. Bizim sahibimizin şikâyeti tam olarak o kovanın içinde.
2. **1440 bir kırılım noktası değil, bir tavan.** `navigationMode()` onu hiç
   okumaz; yalnız `DesktopDensity.of()` ve `home_screen` kullanır. Yani 1008 ile
   sonsuz arasında düzen kararı veren **tek bir eşik bile yok**.
3. §0'daki ölçek yüzünden 1008 eşiği bile gerçek pencereye göre değil, sahte
   1100'e göre değerlendiriliyordu.

### 1.2 Yeni ladder

640 ve 1008 **korunur** (WinUI ile hizalı, kodda var, testli). Üstüne Material 3'ün
masaüstü için sonradan eklediği iki basamak **eklenir** — M3 bu iki sınıfı tam da
"masaüstü ve bağlı ekranları daha iyi hedeflemek" için ekledi:

| ad | genişlik (px) | kaynak | pane / sütun |
|---|---|---|---|
| `minimal` | < 640 | WinUI Small | 1 sütun, rail gizli |
| `compact` | 640 – 1007 | WinUI Medium | 1 sütun + daraltılmış rail (52) |
| `expanded` | 1008 – 1199 | WinUI Large · M3 Expanded (840–1199) | 2 sütun + açık rail (248) |
| `large` | 1200 – 1599 | M3 Large | 2 pane (master + detay) |
| `xlarge` | ≥ 1600 | M3 Extra-Large | 3 pane / 4+ sütun |

M3'ün gerekçesi doğrudan alınabilir: *bir `large` pencere iki pane, bir
`extra-large` pencere üç pane taşıyabilir.*

`DesktopNavigationMode` enum'ına `large` ve `xlarge` **eklenir**; mevcut üç değer
ve onların eşikleri **değişmez** (geriye dönük kırılma yok).

Bütün ölçüler 4'ün katıdır — WinUI kuralı: *"UI öğelerinin boyut, kenar boşluğu ve
konumları her zaman 4 epx'in katı olmalı"*, çünkü 4 sayısı %125/%150/%175 ölçek
platolarında tam sayıya düşer.

---

## 2. İçerik genişliği kuralı

### 2.1 Ölçü (measure) türetimi — bütün genişlik sayılarının kaynağı

Uygulamanın gövde yazısı **15 px**'tir (`theme_tokens.dart:148-153`,
`AppTypography.body` → `textTheme.bodyMedium`). Uydurma değil, kodda okundu.

Karakter genişliği: orantılı yazı tiplerinde `1ch ≈ 0.5em` (70ch ≈ 35–40em
gözlemi). Yani:

```
1 karakter ≈ 0.5 × 15 px = 7.5 px
```

İki otorite, iki sayı:

| ölçüt | karakter | × 7.5 px | 4'ün katına yuvarlanmış |
|---|---:|---:|---:|
| Bringhurst ideal ölçü | 66 | 495 | **496** |
| Bringhurst üst sınır | 75 | 562.5 | 564 |
| **WCAG 2.1 SC 1.4.8 tavanı** | **80** | **600** | **600** |

WCAG 1.4.8 lafzı: *"Width is no more than 80 characters or glyphs (40 if CJK)."*

**Bu tablodaki 600 px, belgedeki bütün metin-öncelikli genişlik sınırlarının tek
kaynağıdır.**

### 2.2 Etiket–değer satırı üst sınırı — sahibin 1 numaralı şikâyeti

Sahibin gördüğü: *"Daily streak" solda, değeri (`0`) ~1900 px ötede sağda.*

Kaynağı `app/lib/features/profile/widgets/profile_stats_panel.dart:195-226`:

```dart
return Row(
  children: [
    Expanded(child: Column(... Text(label) ...)),   // 🔴 tüm genişliği yer
    const SizedBox(width: 12),
    Text(value ?? '—', ...),                        // en sağ kenara itilir
  ],
);
```

`Expanded` sınırsızdır. Satır ne kadar genişse etiket ile değer arasındaki mesafe
o kadar açılır. 2000 px'lik pencerede (mantıksal 1333, ×1.5 boyanır) bu mesafe
fiziksel ~1500 px'e çıkar.

**Neden bu bir okunabilirlik hatası, estetik tercih değil:** satır uzunluğu
sınırının fizyolojik dayanağı, gözün 6–9 karakterlik sıçramalarla (saccade)
ilerleyip **satır başına doğru geri dönmesi**dir; dönüş mesafesi büyüdükçe okuyucu
satırı kaybeder, yeniden okur ya da bırakır. Etiketten değere göz atlaması aynı
mekanizmadır — aynı tavan geçerlidir.

> **KURAL 2.2 — Etiket–değer satırı**
> Bir etiketin sol kenarı ile değerinin sağ kenarı arasındaki mesafe:
> - **Sert tavan: 600 px** (80 karakter, WCAG 1.4.8)
> - **Hedef: 496 px** (66 karakter, Bringhurst ideali) — yan yana 3+ satırın
>   yığıldığı panellerde (Profil "İstatistik" kartı gibi) bu değer kullanılır.
>
> Satırın kabı bundan genişse satır **kabı doldurmaz**; 496 px'te bırakılır ve
> sola hizalanır. `Expanded` ile sınırsız yayılma yasaktır.

### 2.3 İçerik türüne göre genişlik tavanı

| içerik türü | maks. genişlik | türetme |
|---|---:|---|
| Düz metin / prose (Hakkında, Yasal, SSS) | **600** | 80ch × 7.5 px (§2.1, WCAG 1.4.8) |
| Etiket–değer satırı | **600** sert / **496** hedef | §2.2 |
| Form / ayar satırı (etiket + kontrol) | **760** | 600 (etiket ölçü tavanı) + 160 (Switch/Dropdown kontrol alanı). Bu sayı `DesktopSurface.readingWidth` olarak **zaten kodda ve testli** — korunur. |
| Tek sayılık istatistik döşemesi | **320** (min 200) | İçerik = 32 ikon + 12 boşluk + en uzun etiket ("Günlük ortalama", 15 karakter × 7.5 ≈ 113) + 2×16 iç boşluk ≈ **189 px**. 320, %69 pay bırakır. Ötesi boşluktur. |
| Grafik kartı | **720** (min 360) | 30 günlük dağılım = 30 × 16 px (12 bar + 4 boşluk, 4'ün katı) = **480 px** taban; 720'de gün başına 24 px düşer. Ötesinde barlar yalnız şişer. |
| Izgara / pano toplamı | **1440** | mevcut `maxContentWidth`; 1440 = 3 × 480 sütun, `large`'da 2 + `xlarge`'da 3 pane'e tam bölünür |
| Görsel sahne (kamp ateşi) | **sınırsız** | sabit en-boy oranlı sahne; genişledikçe bozulmaz (§3, A4) |

**🔴 Mevcut koddaki hata:** `DesktopSurface.readingWidth = 760`
(`desktop_surface.dart:22`) hem form hem prose için kullanılıyor.
760 / 7.5 = **101 karakter** — WCAG 1.4.8'in 80 karakter tavanını aşar.
Form için doğru, **prose için yanlış**. Prose çağrı yerleri 600'e iner.

---

## 3. Sayfa arketipleri

Bu uygulamanın bütün ekranları dört arketipe iner.

### A1 — Yoğun liste (master–detay)

Çok satırlı, satırı seçilebilir, seçilince detayı olan ekranlar.

| ölçü | değer | gerekçe |
|---|---:|---|
| master sütun genişliği | **280** | `DesktopMasterDetail.masterWidth` varsayılanı; kodda ve testli |
| detay sütunu | kalan, **maks. 760** | §2.3 form genişliği |
| aralarındaki boşluk | **16** | `DesktopMasterDetail.spacing` varsayılanı |
| master satırı min yüksekliği | **40** | `DesktopDensity.commandHeight` (≥1008) |
| iki pane'e geçiş eşiği | **1200** (`large`) | M3: `large` pencere iki pane taşır |
| < 1200'de | yalnız detay (mevcut `DesktopMasterDetail` davranışı) | |

### A2 — Pano / ızgara

Birbirinden bağımsız kart/döşemelerin akışı. Bu uygulamanın **çoğunluk**
arketipidir ve sahibin şikâyetlerinin 1, 2, 3'ü buraya düşer.

| genişlik bandı | istatistik döşemesi (maks 320) | grafik kartı (maks 720) |
|---|---:|---:|
| `compact` 640–1007 | 2 sütun | 1 sütun |
| `expanded` 1008–1199 | **4 sütun** | 1 sütun |
| `large` 1200–1599 | 4 sütun | **2 sütun** |
| `xlarge` ≥ 1600 | **6 sütun** | 2 sütun (kart 720'de sabitlenir) |

- Izgara oluğu (gutter): **24 px** — WinUI: *640 px üstü pencerelerde 24 epx oluk*.
- Toplam ızgara genişliği **1440**'ta durur; artan yer sola/sağa eşit boşluk olur.
- Kart yüksekliği içeriğe göre; **sabit yükseklik verilmez**. Aynı satırdaki
  kartlar `IntrinsicHeight` ile değil, `CrossAxisAlignment.stretch` ile eşitlenir.

**🔴 Mevcut koddaki hata:**
`app/lib/features/stats/widgets/personal_stats_view.dart:216-256` dört özet
kartını **elle 2×2** diziyor — iki ayrı `Row(Expanded, Expanded)`. Sütun sayısı
genişliğe bağlı değil, **sabit 2**. Sahibin 3 numaralı şikâyeti ("her biri 800 px
genişliğinde, içinde tek bir sayı") birebir budur. Bu blok `desktopGridColumns()`
tabanlı akıcı bir ızgaraya çevrilir ve döşeme 320'de tavanlanır.

### A3 — Tek nesne / okuma

Baştan sona okunan ya da tek bir nesneyi düzenleyen ekranlar.

| ölçü | değer | gerekçe |
|---|---:|---|
| prose sütunu | **600** | §2.3 |
| form sütunu | **760** | §2.3 |
| hizalama | üstte, **yatayda ortalı** | mevcut `DesktopReadingBody` davranışı |
| bölüm arası boşluk | **12** | WinUI: *içerik alanları arası 12 epx* |

**Uyarı:** A3 tek başına "iki yanı boş" hissini üretir. Bu yüzden A3 **yalnız
gerçekten tek nesneli** ekranlarda kullanılır (Hakkında, Yasal, Geri bildirim
formu). Profil gibi **birden çok bağımsız blok** taşıyan ekranlar A3 değil A2'dir
— bkz. §5.

### A4 — Görsel sahne

Sabit en-boy oranlı, genişledikçe **daha iyi** görünen tek bir çizim.

| ölçü | değer | gerekçe |
|---|---:|---|
| sahne genişliği | pencereyi doldurur (tavan yok) | sahibin kendi ifadesiyle "bu İYİ örnek" |
| sahne yüksekliği | **275** | `kCampfireSceneHeight`, `campfire_layout.dart:18` |
| sahnenin altındaki bloklar | A2 kurallarına döner | |

Sahne geometrisi (`kCampfireGroundYFactor` vb.) **hiç ellenmez**.

---

## 4. Yoğunluk — masaüstü ile mobilin sayısal farkı

Ölçek kaldırıldıktan (§0) sonra masaüstü **gerçek** px görür. Fark yazı
küçültmekle değil, **boşluk daraltmakla** kurulur.

| ölçü | mobil | masaüstü | gerekçe |
|---|---:|---:|---|
| gövde yazı boyutu | 15 | **15 (değişmez)** | Ölçek kalkınca 15 px zaten gerçek 15 px olur. Küçültmek okunabilirliği düşürür; masaüstü yoğunluğu boşluktan gelir. |
| etkileşim hedefi min yüksekliği | **48** | **32** | Mobil: Material dokunma hedefi 48 dp. Masaüstü: WinUI standart kontrol yüksekliği 32 epx (imleç hedefi dokunma hedefinden küçüktür). |
| mutlak taban (asla altına inilmez) | 48 | **24** | WCAG 2.2 SC 2.5.8 (AA): işaretçi hedefi en az 24×24 CSS px |
| birincil eylem düğmesi | 48 | **40** | Mevcut `DesktopDensity.commandHeight` (≥1008); WCAG 2.5.5 (AAA) 44'ün altında ama 2.5.8 tabanının çok üstünde |
| liste satırı min yüksekliği | 56 | **40** | `DesktopDensity.commandHeight` |
| kartlar arası boşluk | 16 | **12** | WinUI: *içerik alanları arası 12 epx* |
| sayfa kenar boşluğu | 16 | **24** (≥1440) / **20** (1008–1439) / **12** (<1008) | Mevcut `DesktopDensity.pagePadding` — değişmez |
| ızgara oluğu | 12 | **24** | WinUI: <640 px için 12 epx, üstü için 24 epx oluk |
| ikon boyutu | 24 | **20** | Mevcut `DesktopPageScaffold` başlık ikonu zaten 20 |
| liste öğesi ikonu | 24 | **32** | WinUI: *çok satırlı listelerde 32 epx ikon* |
| kart köşe yarıçapı | 12–16 | **8** (≥1440) / **6** / **4** | Mevcut `DesktopDensity.panelRadius`; düşük yarıçap mobil "yumuşak kart" dilinden ayrılır |
| etiket ↔ kontrol boşluğu | 8 | **12** | WinUI: *kontrol ile etiket arası 12 epx* |
| düğmeler arası boşluk | 8 | **8** | WinUI: *düğmeler arası 8 epx* |

**İmleç hedefleri (mobilde karşılığı yok, masaüstünde zorunlu):**

- Tıklanabilir her satırda `hoverColor` — mevcut `DesktopSectionList` deseni
  (`onSurface` %6 alfa).
- Görünür `focusColor` — mevcut desen (`primary` %12 alfa).
- Yalnız-ikon her düğmede `Tooltip` + klavye kısayolu metni
  (mevcut `_PaneFooter` deseni: `"Ayarlar (Ctrl+,)"`).

---

## 5. Ekran karar tablosu

| ekran | dosya | arketip | `expanded` (1008+) | `large` (1200+) | `xlarge` (1600+) |
|---|---|---|---|---|---|
| **home dashboard** | `features/home/home_screen.dart` | **A2** | kullanıcı seçimli sütun (mevcut) | aynı | aynı |
| **stats** | `features/stats/stats_screen.dart` + `widgets/personal_stats_view.dart` | **A2** | 4 özet döşemesi yan yana; grafik 1 sütun | grafikler **2 sütun** | döşeme 6 sütun |
| **profile** | `features/profile/profile_screen.dart` | **A2** | **2 sütun**: sol = kimlik + XP + rütbe şeridi (maks 496); sağ = İstatistik paneli + başarım vitrini | aynı | 3 sütun |
| **achievements** | `features/profile/widgets/achievement_showcase.dart` | **A2** | taç/XP şeridi tam genişlik (cap 1440); rozet ızgarası 4 sütun | rozet 5 sütun | rozet 6 sütun |
| **groups / campfire** | `features/classroom/widgets/class_detail_screen.dart` | **A4 + A2** | sahne tam genişlik; altı 1 sütun | altı **2 sütun** (sol: hedef + sayaç, sağ: sohbet + üyeler) | aynı, sohbet 720'de tavanlanır |
| **settings** | `features/profile/settings_screen.dart` | **A1** | tek sütun 760 (mevcut) | **master–detay**: 280 kategori + 760 detay | aynı |
| **session history** | `features/profile/session_history_screen.dart` | **A1** | tek sütun 760 | **master–detay**: 320 gün listesi + 760 oturum detayı | aynı |
| about / legal / SSS | `features/profile/about_screen.dart`, `legal_center_screen.dart` | **A3** | prose **600** (bugün 760 → düşer) | aynı | aynı |
| clock / saat | `features/clock/` | **A4** | saat merkezde, sınır yok | aynı | aynı |

### 5.1 Sahibin dört şikâyetinin nereye bağlandığı

| # | şikâyet | kök neden (dosya:satır) | çözüm |
|---|---|---|---|
| 1 | Başarım yolculuğu: taç ortada, "Stats" satırları tüm genişliğe yayılıyor | `profile_stats_panel.dart:195-226` — `Expanded` sınırsız | KURAL 2.2 (496 px) |
| 2 | Profil: tek sütun ortada, iki yan boş | `profile_screen.dart:106-107` — `DesktopReadingBody(maxWidth: 760)` | A3 → **A2**, ≥1008'de 2 sütun |
| 3 | İstatistik: 4 kart 2×2, her biri 800 px, içinde tek sayı | `personal_stats_view.dart:216-256` — elle sabit 2×2 `Row` | A2 akıcı ızgara + döşeme tavanı 320 |
| 4 | Gruplar: sahne iyi, altındaki "Group goal" tek sütun | `class_detail_screen.dart` | A4 + A2, ≥1200'de 2 sütun |

**1 ve 3 birbirinin zıddı, 2 de üçüncü bir tür:** birinde içerik **sınırsız
yayılıyor** (A2 tavanı yok), ötekinde **sabit sütun sayısı** genişliği kullanmıyor,
üçüncüsünde **fazla dar** bir okuma sütunu iki yanı boş bırakıyor. Üçü de aynı
cümlenin sonucudur: *ekranlar mobil için yazıldı, masaüstünde yalnız büyütüldü.*

---

## 6. `DesktopPageScaffold` kararı — **BAĞLA, ATMA**

`app/lib/features/desktop/desktop_page_scaffold.dart`, 471 satır, 8 public API.

**Ölçüm (doğrulandı):** `lib/` içinde bu 8 API'nin **hiçbirinin tek bir çağrı yeri
yok**. `grep` ilk bakışta `desktop_home_shell.dart`, `desktop_surface.dart` ve
`profile_screen.dart`'ı gösteriyor — üçü de **yanlış pozitif**: eşleşen şey
`desktop_surface.dart`'taki ayrı bir fonksiyon olan `showDesktopPanel`. Dosyayı
hayatta tutan tek şey kendi testi (`app/test/features/desktop_page_scaffold_test.dart`).

### Karar

| API | karar | gerekçe |
|---|---|---|
| `DesktopDensity` | **koru, bağla** | Fluent sayıları doğru (radius 4/6/8, padding 12/20/24, commandHeight 36/40). §4 tablosunun kaynağı zaten bu. |
| `DesktopMasterDetail` | **koru, bağla** | A1'in tam karşılığı. `breakpoint` varsayılanı 1008 → **1200**'e alınır (§3 A1). |
| `DesktopSectionList` | **koru, bağla** | Settings master sütunu. WP-627 kontrast düzeltmesi zaten uygulanmış (`accentOn`). |
| `DesktopPanel` | **koru, bağla** | A2 kart yüzeyi. |
| `DesktopContextPanel` | **koru, bağla** | A2 ikincil kolon. |
| `DesktopResponsiveColumns` | **koru, DEĞİŞTİR** | `breakpoint = 1080` sihirli sayısı ladder'da yok → **1200** (`large`) yapılır. |
| `DesktopContent` | **DEĞİŞTİR** | `maxWidth` varsayılanı tek bir 1440. §2.3 üç ayrı tavan istiyor (600 / 760 / 1440). Varsayılan kaldırılır, çağrı yeri **açıkça** vermek zorunda bırakılır. |
| `DesktopPageScaffold` (başlık şeridi) | **koru, DİKKATLİ bağla** | Fluent başlık şeridi doğru. **Ama kendi `Scaffold`'unu kurar** — `StatsScreen` gibi zaten `Scaffold` + `AppBar` + `TabBar` taşıyan ekranlara olduğu gibi takılamaz. O ekranlar için gövde-only bir varyant gerekir. |

**Neden atılmıyor:** kod yanlış değil, **bağlanmamış**. Sayıları Fluent'e uygun,
teması WP-627 ile düzeltilmiş, testi var. Atıp yeniden yazmak aynı riski
(*"yazıldı, bağlanmadı"*) baştan üretir.

**Neden tek başına yetmez:** §0'daki ölçek dururken bu 8 widget'ı bağlamak
**hiçbir şeyi değiştirmez** — `DesktopMasterDetail(breakpoint: 1200)` bile,
uygulama 1100 mantıksal px gördüğü için asla iki pane'e geçmez. **Sıra
zorunludur: önce §0, sonra §6.**

### 🔴 Yalanlanan belge

`git show 0bd23f4` (WP-53) commit gövdesi şunu iddia ediyor:

> *"DesktopDensity, master-detail, section list ve context panel; ≥1008 Ana
> Sayfa/Saat/Gruplar/İstatistik/Profil bağlamsal düzen. Mobil branch korundu.
> Desktop test 7 PASS"*

**Beş sekmenin hiçbiri bu widget'ları kullanmıyor.** "7 PASS" gerçek ama
yanıltıcı: test dosyası widget'ları **izole** kuruyor
(`home: DesktopPageScaffold(...)`, `child: DesktopMasterDetail(...)`), hiçbir
gerçek ekranı monte etmiyor. Kablo yokluğunu görecek tek bir iddia yok.

Bu, hafızadaki *"bitmiş backend + bağlanmamış UI"* ve *"WP kart iddiaları
doğrulanmalı"* derslerinin bir örneği daha: **yeşil test, bağlanmamış özelliği
kurtarmaz.**

---

## 7. Ne YAPILMAYACAK

Sahip: *"işlev aynı kalsın, tasarım değişsin."*

- ❌ Özellik eklenmez, silinmez, gizlenmez. Masaüstünde görünen her veri
  masaüstünde görünmeye devam eder.
- ❌ Navigasyon değişmez: beş sekme, aynı sıra, aynı `Ctrl+1..5` kısayolları,
  aynı rozet davranışı (WP-594).
- ❌ Veri kaynağı, provider, RPC, sorgu **hiç ellenmez**. Bu spec `build()`
  ağacının şeklini değiştirir, veriyi değil.
- ❌ Mobil dal değişmez. Her kural `isDesktopWindow` / genişlik eşiği arkasında
  durur. Mobil ağaç bugünkü çıktısını birebir korur.
- ❌ Kamp ateşi sahne geometrisi (`campfire_layout.dart` sabitleri) ellenmez.
- ❌ Renk, tema, kontrast token'ları ellenmez — WP-627/uyarı rozeti dersleri
  yürürlükte.
- ❌ Yazı boyutu küçültülmez (§4).
- ❌ `CompactFocusView` (Ctrl+Shift+M) ellenmez.

---

## 8. Sınanabilir iddialar

Uygulayan ajan her maddeyi **önce kırmızı** bir testle bağlar (kanıt = kırmızı test):

1. `desktopProportionalScale(viewport: Size(2000, 1200))` → **1.0** döner
   (bugün 1.5). Ölçek artık büyütmez.
2. 2000×1200 pencerede `DesktopHomeShell` monte edilir; içerideki bir
   `Builder`'ın gördüğü `MediaQuery.sizeOf(context).width` ≈ **2000**
   (bugün 1333).
3. `ProfileStatsPanel` 1600 px genişlikte monte edilir; `profile-stat-active-days`
   anahtarlı `Text`'in global sol kenarı ile etiketin sol kenarı arasındaki
   mesafe **≤ 496 px**.
4. `PersonalStatsView` 1200 px'te monte edilir; dört `_StatCard`'ın hepsi **aynı**
   `dy`'de (tek satır, 2×2 değil) ve her birinin genişliği **≤ 320 px**.
5. `ProfileScreen` 1200 px'te monte edilir; iki üst düzey sütun **yan yana**
   (İstatistik paneli ile kimlik bloğunun `dx` aralıkları çakışmıyor).
6. `SettingsScreen` 1280 px'te monte edilir; `DesktopSectionList` **bulunur**
   ve genişliği 280 px'tir.
7. Prose ekranı (`AboutScreen`) 1600 px'te monte edilir; metin sütunu
   **≤ 600 px**.
8. Bütün masaüstü genişlik sabitleri 4'ün katıdır (WinUI kuralı) — sözleşme testi.
9. **Mobil regresyon kapısı:** 390×844'te her ekranın widget ağacı, bu WP
   öncesindeki altın çıktıyla aynı kalır.

---

## KAYNAKLAR

- Microsoft Learn — Screen sizes and breakpoints for responsive design (Small <640 / Medium 641–1007 / Large 1008+; 4 epx katı kuralı, ölçek platoları)
  https://learn.microsoft.com/en-us/windows/apps/design/layout/screen-sizes-and-breakpoints-for-responsive-design
- Microsoft Learn — Content layout and spacing (8/12/16 epx boşluk, 32 epx liste ikonu, etiket↔kontrol 12 epx)
  https://learn.microsoft.com/en-us/windows/apps/design/basics/content-basics
- Fluent 2 Design System — Layout (12 sütun ızgara; <640 px için 12 epx, üstü için 24 epx oluk)
  https://fluent2.microsoft.design/layout
- Material Design 3 — Breakpoints / window size classes (Compact 0–599, Medium 600–839, Expanded 840–1199, **Large 1200–1599, Extra-Large 1600+**)
  https://m3.material.io/foundations/layout/breakpoints/overview
- Android Developers — Use window size classes (large/extra-large'ın masaüstü ve bağlı ekranlar için eklendiği; large = 2 pane, extra-large = 3 pane)
  https://developer.android.com/develop/ui/views/layout/use-window-size-classes
- W3C — Understanding WCAG SC 1.4.8 Visual Presentation (*"Width is no more than 80 characters or glyphs (40 if CJK)"*)
  https://www.w3.org/WAI/WCAG21/Understanding/visual-presentation.html
- WCAG 2.2 SC 2.5.8 Target Size (Minimum), AA — işaretçi hedefi ≥ 24×24 CSS px; 2.5.5 (AAA) ≥ 44×44
  https://wcag22aa.org/new-criteria/target-size/
- Google Fonts Knowledge — Understanding measure / line length (satır uzunluğunun saccade + satır-başına-dönüş gerekçesi)
  https://fonts.google.com/knowledge/using_type/understanding_measure_line_length
- UXPin — Optimal Line Length for Readability (Bringhurst 45–75, ideal 66; acemi okur ~45, deneyimli ~80 CPL)
  https://www.uxpin.com/studio/blog/optimal-line-length-for-readability/
- Eric Meyer — What is the CSS `ch` Unit? (`ch` ile ortalama karakter genişliği ilişkisi)
  https://meyerweb.com/eric/thoughts/2018/06/28/what-is-the-css-ch-unit/
- swyx — Line Lengths (*"70ch is something like 35–40em"* → 1ch ≈ 0.5em)
  https://www.swyx.io/line-lengths

### Depo içi ölçüm kaynakları

- `app/lib/core/theme/theme_tokens.dart:148` — gövde yazısı **15 px** (ölçü türetiminin girdisi)
- `app/lib/features/desktop/desktop_proportional_scale.dart:10,20` — referans 1100, maxScale 1.5
- `app/lib/features/desktop/desktop_home_shell.dart:119` — ölçeğin uygulandığı yer
- `app/lib/core/desktop/desktop_layout.dart:8-10` — 640 / 1008 / 1440
- `app/lib/features/desktop/desktop_surface.dart:22` — `readingWidth = 760`
- `app/lib/features/profile/widgets/profile_stats_panel.dart:195-226` — sınırsız `Expanded`
- `app/lib/features/stats/widgets/personal_stats_view.dart:216-256` — sabit 2×2
- `app/lib/features/classroom/widgets/campfire_layout.dart:18` — sahne yüksekliği 275
- `app/lib/main.dart:273` — `CompactFocusView` takas noktası (ölçeğin üstünde)

---

## GEREKÇE YOK

Bu belgedeki **hiçbir sayı gerekçesiz değildir.** Her genişlik ya §2.1 ölçü
türetiminden, ya bir WinUI/M3/WCAG kaynağından, ya da kodda okunan mevcut bir
sabitten gelir.

Gerekçesi en zayıf iki sayı, açıkça işaretlenir:

- **Grafik kartı tavanı 720 px** — 30 × 16 px = 480 px tabanından türetildi, ama
  "gün başına 24 px yeterlidir" yargısı bir kaynağa değil, taban değerinin 1.5
  katına dayanıyor. *Cihazda sahip onayıyla ayarlanabilir.*
- **İstatistik döşemesi tavanı 320 px** — 189 px ölçülen içerikten türetildi;
  %69'luk pay bir kaynağa değil, en uzun yerelleştirilmiş etiketin ("Günlük
  ortalama") büyümesine bırakılan marja dayanıyor. *Almanca/Fransızca eklenirse
  yeniden ölçülmeli.*
