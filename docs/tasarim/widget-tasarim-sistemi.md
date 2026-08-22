# Ana Ekran Widget'ları — Ortak Tasarım Sistemi (WP-750)

> **Bu belge kod değildir, sözleşmedir.** Dokuz widget'ı üç ayrı ajan
> tasarlayacak. Bu belge onların *paylaştığı* şeyi tanımlar: palet, kademe
> bütçesi, sayı biçimi, görsel sözlük, çizim mekanizması. Tek tek widget
> tasarımları buradan **türetilir**, buraya rakip olmaz.
>
> Referans widget (§6) sistemin kanıtıdır. Kendi widget'ını tasarlarken
> önce §7'deki on kuralı, sonra §6'yı oku.

---

## 0. Teşhis — sahip haklı, sebebi ölçüldü

Sahip (2026-08-22): *"Android ana ekran widget'ları sadece yazı."*

Bu bir izlenim değil, ölçülebilir bir olgu:

```
$ grep -c "ImageView" res/layout/odak_*.xml
odak_alarm_widget.xml:0        odak_minimal_timer_widget.xml:0
odak_clock_widget.xml:0        odak_stats_widget.xml:0
odak_countdown_widget.xml:0    odak_task_widget.xml:0
odak_group_goal_widget.xml:0   odak_timer_widget.xml:0
odak_leaderboard_widget.xml:0
```

**Dokuz layout, sıfır `ImageView`.** Tüm görsel yük `TextView`'da. Ekranda
grafik olarak yalnız iki şey var: `widget_progress_arc` (ters U yay, tek
widget'ta) ve `widget_progress_bar` (düz pill, iki widget'ta). Geri kalan her
şey — durum, kimlik, seri, sıra, ilerleme — **kelimeyle** anlatılıyor. Bir
ana ekran widget'ı kelimeyi okutacak kadar uzun bakılan bir yüzey değildir.

İkinci bulgu: **üç ölü kaynak dosyası**.

| Dosya | Durum |
|---|---|
| `res/values/widget_colors.xml` | Tanımladığı 6 simgenin hiçbiri layout/drawable/kotlin'de kullanılmıyor |
| `res/values-night/widget_colors.xml` | aynı |
| `res/values-v31/widget_colors.xml` | aynı — **ve widget yığınındaki TEK Material You referansı burada** |

Doğrulama: `grep -rn "widget_stats_surface\|widget_leaderboard_surface\|
widget_heading\|widget_primary_text\|widget_secondary_text\|@color/widget_accent"
res/layout res/drawable kotlin/` → **sıfır sonuç.**

Yaşayan dil `res/values/widget_design.xml` + `values-night/` (WP-717).
Ölü küme silinmelidir; Material You tartışması (§2.3) böylece kendiliğinden
kapanır, çünkü zaten kullanılmıyor.

Üçüncü bulgu: **kimlik kayması.** Uygulamanın kendi varsayılan teması
`campfire_night` — gece, kömür siyahı, ateş turuncusu
(`app/lib/core/theme/theme_presets.dart:93-111`: `scaffold #07090E`,
`primary #F97316`, `textPrimary #F5EDE4`). Widget'ın gündüz paleti ise
krem bir kart (`widget_design_surface #FFF9F3`). Uygulama gece, widget
gündüz. Aynı ürünün iki parçası gibi durmuyorlar.

### Ne YANLIŞ değil

WP-717/718/719/730 zinciri sağlam bir iskelet bıraktı ve bu belge onu
yıkmıyor, **üstüne kuruyor**:

- İki eksenli boyut sınıfı (genişlik→punto, yükseklik→satır sayısı) —
  `StudyWidgetProviders.kt:113-127`. Doğru model.
- Saf, JVM'de ölçülebilir aritmetik — `WidgetDesign.kt:48-57`. Doğru doktrin.
- Opak zemin gerekçesi — `values/widget_design.xml:17-27`. Doğru karar.
- 48dp dokunma hedefi kuralı ve "sığmıyorsa kökün kendisi hedeftir" çözümü —
  `StudyWidgetProviders.kt:330-360`. Doğru çözüm.

Eksik olan **görsel sözlük**tür. Bu belge onu ekler.

---

## 1. Kademe sözleşmesi — bir widget küçülünce ne düşer

### 1.1 Dört kademe

Hücre→dp formülü Android'in yayımladığı `70n − 30`'dur: 1→40dp, 2→110dp,
3→180dp, 4→250dp, 5→320dp. Kademe adları kamp dünyasından türedi ve üç
ajanın ortak sözlüğüdür.

| Kademe | Ad | Hücre | dp | İç alan (dolgu sonrası) |
|---|---|---|---|---|
| **K1** | **Kor** | 1×1 | 40×40 | ~36×36 (dolgu 2) |
| **K2** | **Kütük** | 2×1 | 110×40 | ~104×36 (dolgu 2) |
| **K3** | **Ocak** | 2×2 | 110×110 | ~102×102 (dolgu 4) |
| **K4** | **Kamp** | 3×2 ve üstü | 180×110+ | ~170×100 (dolgu 5) |

Kademe adı **tasarım sözlüğüdür**; sayısal eşik widget başına ayrı kalır
(`WidgetSizeSpecs`, `StudyWidgetProviders.kt:196-249`) çünkü içerik ayrıdır.
Mevcut koda eşleme:

| Kademe | `WidgetWidthClass` | `WidgetHeightClass` | Ek koşul |
|---|---|---|---|
| K1 | NARROW | SHORT | rapor edilen genişlik < `defaultWidthDp` |
| K2 | NARROW | SHORT | — |
| K3 | NARROW / MEDIUM | MEDIUM | — |
| K4 | MEDIUM / WIDE | MEDIUM / TALL | — |

K1'in ayrı koşulu yeni değil: `timerTimeSp` zaten
`widthDp in 1 until WIDGET_TIMER_DEFAULT_WIDTH_DP` dalını taşıyor
(`StudyWidgetProviders.kt:376-390`). Sistem var olan davranışı **adlandırıyor**,
değiştirmiyor.

### 1.2 Kademe bütçesi

| | K1 · Kor | K2 · Kütük | K3 · Ocak | K4 · Kamp |
|---|---|---|---|---|
| En fazla metin öğesi | **1** | **2** (yalnız yatay) | **3** | **5** |
| En fazla grafik | 0 *(veya 1 ikon, metin yerine)* | 0 | 1 | 1 (+ liste satırları) |
| Başlık | yok | yok | yok | yalnız yükseklik ≥ 150dp |
| En küçük punto | 20sp (tek öğe) | 11sp yardımcı / 20sp ana | 11sp | 11sp |
| Dokunma hedefi | **kökün tamamı** | **kökün tamamı** | ayrı 48dp hap | ayrı 48dp hap |
| Yığma yönü | — | **yatay** | dikey | dikey + yatay |

**K2'de dikey yığma yasaktır.** Aritmetik: 36dp iç yükseklikte iki 11sp satır
(2 × ~14dp) + 4dp aralık = 32dp; kalan 4dp payla bu "sığıyor" değil, "henüz
taşmıyor"dur. Bir dil boyu, bir yazı tipi ölçeği, bir OEM değişikliği bunu
kırar. K2 tek satırdır.

### 1.3 Düşme sırası — SABİT

Her widget küçülürken bu sırayla eleme yapar. Sıra değiştirilemez; widget'a
özgü olan yalnız *hangi öğenin hangi kademede sıraya girdiğidir*.

```
1. Başlık (widget adı)          ← ilk düşen
2. Yardımcı etiket ("gün kaldı", "Seri:") → ya ikona dönüşür ya sayıya emilir
3. İkincil satırlar / liste kuyruğu (3. satır, sonra 2. satır)
4. Ayrı dokunma hedefi (hap)   → kökün kendisi hedef olur
5. Grafik (yay / çubuk / ikon)
6. ÇEKİRDEK                     ← asla düşmez
```

**Başlık neden ilk düşer:** kullanıcı o widget'ı kendi eliyle kurdu; hangisi
olduğunu biliyor. Depoda bu karar zaten alınmış ve gerekçelendirilmiş —
`statsTitleVisible` yalnız `TALL`da true döner
(`StudyWidgetProviders.kt:428-437`).

### 1.4 Çekirdek — tasarıma başlamadan önce yazılır

**Her widget'ın tam olarak bir çekirdeği vardır: K1'de tek başına hayatta
kalan bilgi.** Ajan kendi WP'sinde tasarıma başlamadan önce çekirdeği tek
cümleyle yazar. Çekirdek iki türden biridir:

- **Sayı çekirdeği** — en fazla **3 karakter**. (Aritmetik §3.4.)
- **Glif çekirdeği** — 24dp'lik tek vektör ikon; sayı yoksa veya sayı 3
  karaktere sığmıyorsa.

Dokuz widget için önerilen çekirdek (ilgili ajan gerekçeyle değiştirebilir,
ama **değiştirdiğini yazmak zorundadır**):

| Widget | Çekirdek | Tür |
|---|---|---|
| `odak_timer_widget` | geçen süre, dakika | sayı (`47`) |
| `odak_minimal_timer_widget` | geçen süre, dakika | sayı (`47`) |
| `odak_stats_widget` | günlük hedef yüzdesi | sayı (`%72`) |
| `odak_countdown_widget` | kalan gün | sayı (`12`) |
| `odak_group_goal_widget` | grup hedef yüzdesi | sayı (`%72`) |
| `odak_leaderboard_widget` | kullanıcının sırası | sayı (`#3`) |
| `odak_task_widget` | kalan görev sayısı | sayı (`4`) |
| `odak_clock_widget` | saat `HH:MM` — 5 karakter, sığmaz | **glif** (ay+yıldız) |
| `odak_alarm_widget` | sonraki alarm — 5 karakter, sığmaz | **glif** (çan) |

Saat ve alarm için çekirdek gliftir çünkü `08:30` beş karakterdir ve 36dp'ye
okunur biçimde girmez (§3.4). Bu bir kayıp değil, dürüst bir karardır: 1×1
bir saat widget'ı zaten sistem saatinin kopyasıdır; oradaki değer **markadır**,
sayı değil.

### 1.5 Dokunma hedefi

Material asgarisi 48dp. K1 ve K2'de bu, **widget'ın tamamı** demektir ve bu
yeterlidir: launcher gerçek hücreyi ~70–85dp çizer, yani kök zaten 48dp'nin
üstündedir. Ayrı bir hap ancak yükseklik ≥ 110dp olduğunda çizilir.

Bu kural yeni değil; WP-718'de ölçülüp yazılmış:
`odak_timer_widget_info.xml` yorumu + `timerControlsVisible`
(`StudyWidgetProviders.kt:355-360`). Sistem onu **dokuz widget'ın hepsine**
genelleştiriyor.

> 🔴 K1/K2'de ikinci bir tıklanabilir alan **yasaktır**. İki hedef bir
> hücreye sığmaz; sığdırılırsa ikisi de 48dp'nin altına düşer ve kullanıcı
> yanlış olana basar.

---

## 2. Renk sistemi

### 2.1 Karar: tek koyu kimlik

**`values-night/` KALDIRILIR. Widget her sistem temasında koyudur.**

Gerekçe, önem sırasıyla:

1. **Kimlik.** Uygulamanın varsayılan teması `campfire_night`
   (`theme_presets.dart:93`). Ürün gece kampıdır. Açık temada krem bir kart
   çizmek, widget'ı uygulamanın değil launcher'ın parçası yapar.
2. **Kanıt maliyeti.** İki palet, her kontrast iddiasının iki kez
   kanıtlanması demektir. Depo bunun bedelini zaten ödüyor: `values-night/`
   dosyasının başlığı, bir simgenin unutulmasının **hiçbir derleme hatası
   üretmeden** gece modunda yüzeyi okunmaz bıraktığını yazıyor
   (`values-night/widget_design.xml:2-6`). Tek palet bu sınıf hatayı yok eder.
3. **Duvar kâğıdı.** Okunabilirlik zaten opaklıktan geliyor (§2.4), sistem
   temasından değil. İkinci palet okunabilirliğe hiçbir şey katmıyor.

**Değişecek test:** `values`/`values-night` ad kümesi karşılaştırması artık
konusuz kalır; yerine "widget paleti tek dosyadır ve `values-night/` altında
`widget_ember_*` simgesi YOKTUR" iddiası konur. Bu, aynı sınıf regresyonu
(bir simgenin bir temada eksik kalması) daha ucuz yakalar.

### 2.2 Palet — altı simge

Renkler `campfire_night` presetinden türedi, koyu zeminde kontrast için
kaldırıldı. **Hepsi opaktır. Alfa yoktur.**

| Simge | Hex | Rol | Kart zeminine kontrast |
|---|---|---|---|
| `widget_ember_night` | `#120E0A` | kart zemini (opak) | — (referans, L=0.0046) |
| `widget_ember_ash` | `#75604D` | **yalnız grafik**: yay izi, ayraç, kenar, halka | **3.24 : 1** ✓ (grafik AA) |
| `widget_ember_flame` | `#FF8A3D` | birincil vurgu: kahraman sayı, dolu yay, eylem hapı | **8.19 : 1** ✓ AAA |
| `widget_ember_glow` | `#FFC46B` | ikincil vurgu: seri alevi, 1. sıra, "bugün" işareti | **12.22 : 1** ✓ AAA |
| `widget_ember_ink` | `#F6EFE6` | ana metin | **16.84 : 1** ✓ AAA |
| `widget_ember_ink_dim` | `#A79483` | yardımcı metin, etiket | **6.59 : 1** ✓ AA |

Oranlar WCAG 2.1 bağıl luminans formülüyle hesaplandı
(`L = 0.2126R + 0.7152G + 0.0722B`, sRGB doğrusallaştırılmış). Bunlar saf
aritmetiktir; `widgetContrastRatio(a, b)` gibi saf bir fonksiyona alınıp JVM
testine bağlanmalıdır — `WidgetDesign.kt:48-57`'deki doktrinin aynısı.

### 2.3 İki sert kural

> **`ash` bir metin rengi DEĞİLDİR ve metin zemini DEĞİLDİR.**
> `#75604D` kart zeminine 3.24:1'dir — grafik için yeterli (WCAG 1.4.11: 3:1),
> metin için değil (1.4.3: 4.5:1). `ash` yalnız çizgi, iz, kenar ve halka
> rengidir.
>
> **`flame` veya `glow` üstündeki metin DAİMA `night`tır.**
> `ink` on `flame` = **2.06 : 1** — başarısız. `night` on `flame` = 8.19:1 ✓,
> `night` on `glow` = 12.22:1 ✓. Mevcut kod bu deseni zaten doğru kullanıyor
> (`odak_timer_widget.xml:41,82`: eylem hapının metni `widget_design_surface`).

Sonucu: 2. ve 3. sıra rozetleri `ash` zeminli olamaz. Doğru biçim —
**1. sıra:** `glow` dolgu + `night` metin. **Diğerleri:** `night` dolgu +
1dp `ash` halka + `ink_dim` metin. Bu, birinciyi gerçekten öne çıkarır.

### 2.4 Duvar kâğıdı — ne iddia ediliyor, ne edilmiyor

**İddia (kanıtlanabilir):** Kart %100 opak olduğu için widget'ın *içindeki*
her kontrast oranı duvar kâğıdından bağımsızdır ve yukarıdaki tabloda
yazandır. Metin okunabilirliği her cihazda, her duvar kâğıdında aynıdır.
Ölçülebilen ve teste bağlanabilen iddia budur.

**İddia EDİLMEYEN:** "Kart her duvar kâğıdından ayrışır." Bu doğru değildir
ve doğruymuş gibi yazılmamalıdır. Aritmetik:

- Kart zemini `night` (L = 0.0046), kenar `ash` (L = 0.1268).
- Duvar kâğıdının o hücredeki luminansı `L_w` ise ayrışma
  `max(C(L_w, night), C(L_w, ash))` kadardır.
- En kötü hâl ikisinin eşitlendiği yerdedir: `L_w ≈ 0.048` (≈ `#3E3E3E`,
  orta gri). Orada **her iki taraf da 1.80 : 1**'dir — kart, orta gri bir
  duvar kâğıdında zayıf ayrışır.

Bunu 3:1'e çıkarmanın tek yolu kenarı `L ≥ 0.442`'ye taşımaktır; yani
her widget'ın çevresine `glow` parlaklığında turuncu bir çerçeve çizmek.
**Reddedildi** — bedeli, kazancından büyük.

**Bu yüzden şu kural:** *kenar hiçbir zaman bilgi taşımaz.* Kenar yalnız
koyu duvar kâğıdında kartı ayıran bir yardımdır. Durum, uyarı, seri, sıra —
hiçbiri kenara kodlanmaz. Önizlemedeki `#3E3E3E` örneği bu en kötü hâli
**göstermek** için oradadır; gizlemek için değil.

### 2.5 Material You: HAYIR

Karar zaten alınmış, gerekçesi `values/widget_design.xml:17-27`'de yazılı:
*"rengi duvar kâğıdı seçer, kontrastı kimse ölçmez."* Bu belge onu
onaylıyor ve son adımı atıyor: `values-v31/widget_colors.xml` **ölü
dosyadır** (§0) ve silinir. Widget yığınında `@android:color/system_*`
referansı kalmaz.

İki savunmayı birden yapmıyoruz: kamp ateşi kimliği sabittir, dinamik renk
yoktur.

### 2.6 Kart yarıçapı kademeye bağlıdır

Mevcut `widget_design_corner` = **22dp** (`values/widget_design.xml:44`).
K1'de kart 40×40dp'dir; 22dp yarıçap köşelerin **tamamını** yer ve kart
karta değil hapa dönüşür.

| Kademe | Yarıçap | Drawable |
|---|---|---|
| K1 | 12dp | `widget_card_bg_tight` |
| K2 | 14dp | `widget_card_bg_tight` |
| K3 / K4 | 20dp | `widget_card_bg` |

Seçim kodda: `setInt(rootId, "setBackgroundResource", resId)` —
`View.setBackgroundResource` `@RemotableViewMethod`'dur. *(Uygulama WP'sinde
cihazda doğrulanacak; doğrulanmazsa geri düşüş, kademeye göre ayrı kök
layout vermektir.)*

---

## 3. Tipografi ve sayı sunumu

### 3.1 Yazı tipi

**`sans-serif-condensed`** (Roboto Condensed) — sayılar ve kahraman metin.
**`sans-serif-medium`** — etiket ve satır metni.

Neden: bugün sayılar `android:textScaleX="0.55"` ile **%45 yatay eziliyor**
(`odak_timer_widget.xml:25`). O bir daraltma değil, deformasyondur; gliflerin
dikey çizgileri kalın, yatay çizgileri ince kalır ve rakam "hastalıklı"
görünür. Roboto Condensed'in kendi ilerleme genişliği ~0.87'dir ve glif
formu **tasarlanarak** dar çizilmiştir.

**Yeni sıkıştırma tabanı: `textScaleX` 0.85'in altına inmez.** Condensed ile
birleşik yatay katsayı ≈ **0.74** olur — bugünkü 0.55'in çok üstünde, yani
gözle görülür bir kalite kazancı, aynı kutuda.

`sans-serif-condensed-light` **yasaktır**: saç inceliğindeki çizgiler duvar
kâğıdı parıltısında kaybolur.

> **Doğrulanacak (uygulama WP'si):** Roboto/Roboto Condensed rakamlarının
> sabit ilerlemeli (tabular) olduğu. Akan bir `Chronometer`'da rakamlar
> orantılı ilerlemeliyse sayı her saniye titrer. Titriyorsa geri düşüş:
> `Chronometer` yerine sabit genişlikli bir `TextView` + `setChronometer`
> yerine push güncelleme.

### 3.2 `autoSizeTextType` KULLANILMAZ

RemoteViews'ta çalışmaz — `TextView`'in auto-size metotları
`@RemotableViewMethod` değildir. Punto **koddaki merdivenden** gelir
(`WidgetTypography`, `StudyWidgetProviders.kt:294-311`). Bu bir eksiklik
değil, avantajdır: merdiven saf bir fonksiyondur ve JVM testinde ölçülür.

### 3.3 En küçük punto: **11sp**

Anlam taşıyan hiçbir metin 11sp'nin altına inmez.

**Tek istisna:** dolu bir şeklin içindeki **≤2 karakterlik rakam** 10sp
olabilir (sıra rozeti). Gerekçe: o rakam layout'un en yüksek yerel
kontrastına sahiptir ve çevresi bir daire tarafından tanımlıdır.

11sp'nin gerekçesi keyfî değil: deponun kendi ölçülmüş merdivenleri zaten
11sp'de dipleniyor (`countdownLabel`, `statsRow`, `statsTitle` → `narrow = 11f`,
`StudyWidgetProviders.kt:303-308`), ve ağaçtaki tek 10sp bir karakterlik
rozettir (`odak_leaderboard_widget.xml:49`). Sistem, ölçümün zaten kanıtladığı
tabanı **kurallaştırıyor** — yani hiçbir widget'ın yeni bir tabana uymak için
küçülmesi gerekmiyor.

### 3.4 Genişlik modeli — tüm kademe aritmetiğinin kaynağı

Deponun modeli (`StudyWidgetProviders.kt:294-301`), sıkıştırma katsayısı
eklenmiş hâliyle:

```
sp_max = (W_dp − 2·dolgu − 8) / (0.60 × k × karakter_sayısı)

  W_dp   : widget genişliği
  8      : emniyet payı (dp)
  0.60   : Roboto'nun ortalama rakam ilerlemesi / punto
  k      : textScaleX × yazıtipi_daralma  →  bu sistemde 0.85 × 0.87 ≈ 0.74
```

**0.60 sabiti düşürülmez.** Condensed'in dar oluşu bütçeye değil **emniyet
payına** yazılır; böylece cihazda ölçülmeden önce hiçbir kutu iyimser
hesaplanmış olmaz.

K1'in "3 karakter" sınırı buradan gelir:

```
K1, 3 karakter:  (40 − 4 − 8) / (0.60 × 0.74 × 3) = 28 / 1.332 = 21sp
K1, 5 karakter:  (40 − 4 − 8) / (0.60 × 0.74 × 5) = 28 / 2.220 = 12.6sp  ✗
```

12.6sp bir kahraman sayı değildir; 11sp tabanının hemen üstünde bir fısıltıdır.
**Bu yüzden K1 çekirdeği en fazla 3 karakterdir** ve `08:30` gösteren bir
saat widget'ının K1'de sayısı olamaz (§1.4).

Not: 21sp hesabı, WP-718'de bağımsız olarak ölçülüp koda yazılmış
`WIDGET_TIMER_ONE_CELL_SP = 20f` sabitiyle (`StudyWidgetProviders.kt:345`)
çakışıyor. Sistem var olan ölçümü **yeniden üretiyor** — uydurmuyor.
Kullanılacak değer 20sp'dir.

### 3.5 Sayı biçimleri — KARAR

| Ne | Biçim | Örnek | Gerekçe |
|---|---|---|---|
| **Akan sayaç** | `H:MM:SS`, bir saatin altında `MM:SS` | `1:23:45` / `23:45` | `Chronometer`'ın kendi biçimi; canlı sayaçta saniye beklenir |
| **Birikmiş süre** | `2sa 45dk` (tr) / `2h 45m` (en) | `2sa 45dk` | 8 karakter, K2'ye sığar; birim harfi var, **saatle karışmaz** |
| **Bir saatin altı** | yalnız dakika | `45dk` / `45m` | `0sa 45dk` asla yazılmaz |
| **K1 süre** | yalnız dakika, birimsiz | `47` | 3 karakter sınırı (§3.4) |
| **Yüzde** | tam sayı, tr'de önek | `%72` (tr) / `72%` (en) | Türkçe tipografi kuralı |
| **Sıra** | `#` öneki | `#3` | Sıra eki (`3.`, `3rd`) l10n kâbusudur |
| **Gün** | tam sayı + ayrı küçük etiket | `12` + `gün kaldı` | Mevcut geri sayım deseni |

**`2:45` biçimi reddedildi.** Aynı ana ekranda bir saat widget'ı var; iki nokta
üst üste orada saat demek. Aynı sözlükte iki anlam taşıyamaz.

Bu, bugünkü Dart biçimlendiricisinin değişmesini gerektirir:
`study_providers.dart:3113-3122` şu an `l10n.commonHourCount` /
`commonMinuteCount` ile uzun sözcük biçimi üretiyor ("2 saat 45 dakika"
sınıfı). Widget için ayrı, kısa bir biçimlendirici gerekir.

---

## 4. Görsel sözlük — dokuz widget'ın paylaştığı parçalar

**Her parça vektör/şekil drawable'dır. Bitmap YOKTUR.** Gerekçe §5.

| # | Parça | Yol | Durum |
|---|---|---|---|
| 1 | **Ters U yay** (kahraman gösterge) | `widget_progress_arc` + `ProgressBar` | **VAR** — korunur |
| 2 | **Düz pill çubuk** (satır içi ilerleme) | `widget_progress_bar` + `ProgressBar` | **VAR** — korunur |
| 3 | **Kart zemini** | `widget_card_bg` (20dp) + `widget_card_bg_tight` (12dp) | biri var, biri **yeni** |
| 4 | **Eylem hapı** (48dp) | `widget_action_bg` — `flame` dolgu, `night` metin | **VAR** — palet güncellenir |
| 5 | **Chip** (ders, etiket) | `widget_chip_bg` — `night` dolgu + 1dp `ash` halka | **VAR** — palet güncellenir |
| 6 | **Sıra rozeti** | `widget_rank_first_bg` (`glow`) / `widget_rank_other_bg` (`night`+`ash` halka) | **VAR** — palet güncellenir (§2.3) |
| 7 | **Seri alevi** | `widget_flame_off/on/peak` — üç ayrı vektör | **YENİ** |
| 8 | **Ayraç** | `widget_divider` — 1dp `ash` şekil | **YENİ** |
| 9 | **İkon ailesi** | `widget_ic_*` — dokuz vektör, 24dp ızgara, 2dp çizgi | **YENİ** |

### 4.1 Tam halka YOK — tek gösterge geometrisi ters U yaydır

`ProgressBar`'ın seviye mekanizması `<clip>`tir ve clip **doğrusaldır**;
360° bir süpürme yapamaz. Alternatifler ve neden elendikleri
(`widget_progress_arc.xml`'de zaten yazılı): 21 dosyalık `LevelListDrawable`
= bakım yükü; `Canvas`→`Bitmap` = §5.

**Karar: dokuz widget'ın hepsi aynı ters U yayı kullanır.** Bu, sistemin en
güçlü birleştiricisidir — dokuz widget yan yana durduğunda onları tek ürün
yapan şey aynı gösterge biçimidir. Ayrıca sahibin kendi isteğidir; alıntı
`widget_arc_track_shape.xml:5-6`'da korunuyor.

Yayı sürerken **`WidgetDesign.arcPercent`** kullanılır, `barPercent` değil.
Düz çubukta tersi. Yanlış eşleşme sessizdir (`WidgetDesign.kt:81-86`).

### 4.2 Seri alevi — üç dosya, `setImageViewResource`

| Durum | Dosya | Renk |
|---|---|---|
| Seri yok / bugün kırık | `widget_flame_off` | `ash` |
| Seri sürüyor | `widget_flame_on` | `flame` |
| Rekor / bugün tamam | `widget_flame_peak` | `glow` |

Boyutlar: 12dp (K2 satır içi), 16dp (K3), 20dp (K4).

**Neden üç dosya, tek dosya + renk filtresi değil:** seçim böylece saf bir
fonksiyon olur (`flameResFor(streak, goalMet) → Int`) ve JVM testinde
ölçülür. `setColorFilter` yolu hem kırılgandır hem test edilemez —
`WidgetDesign.kt:48-57`'deki gerekçenin aynısı.

### 4.3 İkon ailesi — 24dp ızgara, 2dp çizgi, tek renk, çizgisel

Her widget'ın bir ikonu vardır ve o ikon aynı zamanda **K1 glif çekirdeğidir**
(gerekirse) ve **K4 başlık satırının işaretidir**.

| Widget | İkon | Not |
|---|---|---|
| sayaç / minimal sayaç | ocak (üç kütük + alev) | ürünün ana simgesi |
| istatistik | yükselen çubuklar | |
| geri sayım | kum saati | |
| görev | onaylı kutu | |
| grup hedefi | çadır | |
| sıralama | kupa | |
| saat | ay + yıldız | K1 çekirdeği |
| alarm | çan | K1 çekirdeği |

Kurallar: dolu değil **çizgisel**; tek renk (`ink_dim` pasif, `flame` aktif);
24dp viewport, 2dp `strokeWidth`, yuvarlak uçlar (yayla aynı dil —
`strokeLineCap="round"`, `widget_arc_track_shape.xml:18`); optik ağırlık
merkezde, 2dp iç boşluk.

**Yasak:** emoji. Emoji cihaz yazı tipine bağlıdır, OEM'e göre değişir,
rengi paletten bağımsızdır ve tema değişince kaybolabilir — deponun kırmızı
rozet dersinin aynısı (`values/widget_design.xml:19-22`).

### 4.4 Ayraç — `View` değil `ImageView`

RemoteViews'ın izin verdiği görünüm listesinde **düz `View` yoktur**.
Ayraç için tek doğru yol:

```xml
<ImageView
    android:layout_width="match_parent"
    android:layout_height="1dp"
    android:background="@drawable/widget_divider"
    android:contentDescription="@null" />
```

Ayraç yalnız K4'te ve yalnız **liste ile başlık arasında** çizilir. Liste
satırları arasına ayraç konmaz — orada ayrımı boşluk yapar.

---

## 5. Bitmap yasağı — sayıyla

Soru: "kahraman göstergeyi Kotlin'de `Canvas` ile çizip
`setImageViewBitmap` versek?" Cevap: **hayır**, ve gerekçe aritmetiktir.

RemoteViews Binder işlemiyle launcher prosesine geçer; bütçe ~1 MB
mertebesindedir ve o bütçe işlemdeki **her şeyle** paylaşılır.
`ARGB_8888` = piksel başına 4 bayt.

| Kademe | dp | yoğunluk 3.0 | yoğunluk 3.5 |
|---|---|---|---|
| K3 (2×2) | 110×110 | 435 KB | **593 KB** |
| K4 (3×2) | 180×110 | 713 KB | **970 KB** |
| K4 geniş (4×2) | 250×110 | **990 KB** | **1.29 MB** ✗ |

4×2'lik tek bir kahraman bitmap, yoğunluk 3.5'te bütçeyi tek başına aşar —
`TransactionTooLargeException`, yani widget **çöker**. Yoğunluk 3.0'da bile
bütçenin tamamına oturur, geriye hiçbir şey kalmaz.

Bu da saf aritmetiktir: `widgetBitmapBytes(wDp, hDp, density)` fonksiyonuna
alınıp "4×2 @ 3.5 bütçeyi aşar" iddiası JVM testine bağlanmalıdır.

**Sonuç: bitmap hiçbir widget'ta, hiçbir kademede kullanılmaz.** Yukarıdaki
dokuz parçanın tamamı vektör/şekille çizilebiliyor — zaten bu yüzden öyle
seçildiler.

---

## 6. Referans widget — Odak Sayacı, dört kademe

`odak_timer_widget`. En çok kullanılan ve en zor olan: canlı akan bir sayı,
bir dokunma hedefi ve bir ilerleme, hepsi 40×40dp'ye kadar inecek.

**Çekirdek:** geçen süre, dakika cinsinden.
**Başlık:** hiçbir kademede yok — bu bir saat nesnesidir, sayının kendisi
kimliktir.
**Durum (çalışıyor/duruyor):** ikinci bir öğeyle değil, **sayının rengiyle**.
Çalışıyor → `flame`. Duruyor → `ink_dim`. Bu desen depoda zaten seçilmiş ve
gerekçelendirilmiş (`odak_minimal_timer_widget.xml:16-18`).

### K1 · Kor — 40×40dp

```
┌────────┐   dolgu 2dp · yarıçap 12dp
│        │
│   47   │   ← 20sp condensed, flame (çalışıyor) / ink_dim (duruyor)
│        │      biçim: dakika, birimsiz. <1dk → "<1". >99dk → "2sa"
└────────┘   kökün tamamı Başlat/Durdur
```

**Kalan:** 1 öğe — sayı.
**Düşen:** başlık · ders adı · Başlat/Durdur hapı · yay · saniye · birim
etiketi · ikon.
**Dikey bütçe:** 40 − 2·2 = 36dp; 20sp satır ≈ 26dp ✓
**Yatay bütçe:** (40 − 4 − 8) / (0.60 × 0.74 × 3) = 21sp → 20sp kullanılır ✓

### K2 · Kütük — 110×40dp

```
┌──────────────────────────┐   dolgu 2dp · yarıçap 14dp
│        1:23:45           │   ← 26sp condensed, flame / ink_dim
└──────────────────────────┘   kökün tamamı Başlat/Durdur
```

**Kalan:** 1 öğe — sayı. K1'e göre kazanılan **bilgi**, boyut değil:
saat ve saniye görünür (`H:MM:SS`).
**Düşen:** başlık · ders adı · hap · yay · ikon.
**Yatay bütçe:** (110 − 4 − 8) / (0.60 × 0.74 × 8) = 27.6sp → **26sp** ✓
**Dikey bütçe:** 36dp; 26sp satır ≈ 34dp ✓ (K2'nin dikey yığmaya niye
kapalı olduğu buradan görünüyor — tek satır kutuyu zaten dolduruyor.)

> Bugünkü hâl 28sp @ `textScaleX 0.55`. Yeni hâl 26sp @ efektif 0.74.
> 2sp daha kısa, ama glif **%35 daha az ezilmiş**. Sahibin gördüğü
> "hastalıklı rakam" burada düzeliyor.

### K3 · Ocak — 110×110dp

```
┌────────────────────────┐   dolgu 4dp · yarıçap 20dp
│    ╭──────────────╮    │
│   ╱                ╲   │   ← ters U yay, 102×48dp
│  │    1:23:45       │  │      iz: ash · dolu: flame
│  │                  │  │      yüzde = GÜNLÜK HEDEF (arcPercent)
│                        │   ← sayı 24sp, yayın ağzında
│  ┌──────────────────┐  │
│  │     Başlat       │  │   ← 48dp hap, flame dolgu, night metin
│  └──────────────────┘  │
└────────────────────────┘
```

**Kalan:** 2 metin öğesi (sayı, hap etiketi) + 1 grafik (yay).
**Düşen:** başlık · ders adı · yüzde rakamı (yay tek başına taşır).
**Dikey bütçe:** 4·2 + 48 (yay bloğu) + 4 (aralık) + 48 (hap) = **108 ≤ 110** ✓
**Yatay bütçe:** (110 − 8 − 8) / (0.60 × 0.74 × 8) = 25.2sp → **24sp** ✓
**Ders adı neden yok:** genişlik 110dp = NARROW. Mevcut kural
`timerSubjectVisible` ders hapını genişlik ≥ MEDIUM (150dp) şartına bağlıyor
(`StudyWidgetProviders.kt:365-371`). Sistem o kuralı **değiştirmiyor**.

### K4 · Kamp — 180×110dp

```
┌──────────────────────────────────────┐   dolgu 5dp · yarıçap 20dp
│   ╭──────────────────────────────╮   │
│  ╱                                ╲  │   ← yay 170×46dp (yassılaşır,
│ │        1:23:45           %72     │ │      çizgi kalınlığı sabit)
│ │                          ────    │ │   ← sayı 30sp · yüzde 11sp glow,
│                                      │      yayın sağ boşluğunda
│  ┌────────────┐  ┌────────────────┐  │
│  │ Matematik  │  │    Durdur      │  │   ← chip 48dp + hap 48dp
│  └────────────┘  └────────────────┘  │
└──────────────────────────────────────┘
```

**Kalan:** 4 metin öğesi (sayı, yüzde, ders, hap) + 1 grafik (yay).
**Düşen:** yalnız başlık.
**Dikey bütçe:** 5·2 + 46 + 4 + 48 = **108 ≤ 110** ✓
**Yatay bütçe:** (180 − 10 − 8) / (0.60 × 0.74 × 8) = 45.6sp → dikey bütçe
bağlar: 46dp blokta 30sp satır ≈ 39dp ✓ → **30sp**
**Yüzde nereye:** yayın kendi negatif alanına — yay sağ bacağında kıvrıldığı
için sağ-alt köşe boştur. `FrameLayout`, üç çocuk: yay (ProgressBar), sayı
(merkez), yüzde (`bottom|end`).

### K4-uzun · 180×180dp ve üstü

Yükseklik ≥ 150dp olduğunda **başlık satırı** açılır: 16dp ocak ikonu +
"Odak" (13sp `ink_dim`) + 1dp `ash` ayraç. Bundan büyüğü sayacın işine
yaramaz; `maxResizeHeight` 180dp'de kalır (bugünkü değer,
`odak_timer_widget_info.xml`).

### Kademe boyunca ne oldu — özet

| | K1 | K2 | K3 | K4 |
|---|---|---|---|---|
| Süre | `47` (dk) | `1:23:45` | `1:23:45` | `1:23:45` |
| Punto | 20sp | 26sp | 24sp | 30sp |
| Yay | — | — | ✓ | ✓ |
| Yüzde rakamı | — | — | — | ✓ |
| Başlat/Durdur | kök | kök | 48dp hap | 48dp hap |
| Ders adı | — | — | — | ✓ |
| Başlık | — | — | — | ≥150dp'de |

K3'ün K2'den küçük punto taşıması **kasıtlıdır**: K3'te sayı yayın ağzına
girer, yani yatay bütçeyi yayla paylaşır. Büyüyen şey punto değil,
**bilgi**dir (yay + ayrı dokunma hedefi).

---

## 7. Değişmez kurallar — üç tasarım ajanı için

> Bu on madde tartışmaya kapalıdır. Bir maddeyi ihlal etmek gerekiyorsa
> **önce lidere sorulur**; sessizce ihlal edilmez.

1. **Çekirdek.** Her widget'ın tam olarak bir çekirdeği vardır ve K1'de tek
   başına kalır. Tasarıma başlamadan önce çekirdek tek cümleyle yazılır.
   Sayı çekirdeği en fazla 3 karakterdir; sığmıyorsa çekirdek gliftir.

2. **Düşme sırası sabittir:** başlık → yardımcı etiket → ikincil satırlar →
   ayrı dokunma hedefi → grafik. Çekirdek asla düşmez. Sıra değişmez;
   yalnız hangi öğenin hangi kademede sıraya girdiği widget'a özgüdür.

3. **Palet altı simgedir; yeni renk üretilmez.** `ash` yalnız grafiktir —
   metin rengi olmaz, metin zemini olmaz. `flame`/`glow` üstündeki metin
   **daima** `night`tır.

4. **Zemin opaktır; hiçbir yerde alfa yoktur.** Duvar kâğıdı iddiası yalnız
   kart *içi* kontrastlar içindir. Kenar hiçbir zaman bilgi taşımaz.

5. **Kademe bütçesi:** K1 ≤1 metin öğesi · K2 ≤2 (yalnız yatay) ·
   K3 ≤3 + 1 grafik · K4 ≤5 + 1 grafik. K1/K2'de ikinci tıklanabilir alan
   yasaktır; kökün kendisi hedeftir.

6. **Punto tabanı 11sp** (istisna: dolu şekil içinde ≤2 karakterlik rakam,
   10sp). `autoSizeTextType` kullanılmaz — punto koddaki saf merdivenden
   gelir. `textScaleX` 0.85'in altına inmez; daraltma
   `sans-serif-condensed` ile yapılır.

7. **Sayı biçimleri:** akan sayaç `H:MM:SS` · birikmiş süre `2sa 45dk` /
   `2h 45m` · bir saatin altı `45dk` · yüzde `%72` (tr) / `72%` (en) ·
   sıra `#3`. **`2:45` yasaktır** (saatle karışır).

8. **Gösterge geometrisi ikidir ve ikisi de drawable'dır:** ters U yay
   (`arcPercent`) ve düz pill (`barPercent`). Tam halka yok, yeni geometri
   yok. **Bitmap hiçbir yerde yok** — 4×2 kartın ARGB_8888 bitmap'i
   yoğunluk 3.5'te ~1.29 MB, RemoteViews işlemini düşürür.

9. **RemoteViews izin listesi.** Düz `View` desteklenmez → ayraç 1dp
   `ImageView`dır. ConstraintLayout yok, özel View yok, Compose/Glance yok.
   Kullanılabilir: FrameLayout · LinearLayout · RelativeLayout · GridLayout ·
   TextView · ImageView · ProgressBar · Button · ImageButton · AnalogClock ·
   Chronometer · ListView · GridView · StackView · ViewFlipper · ViewStub.

10. **Kademeye göre çizim tek mekanizmadan gelir:**
    `onAppWidgetOptionsChanged` + `OPTION_APPWIDGET_MIN_*` → saf
    `widgetSizeClass`. `RemoteViews(Map<SizeF, RemoteViews>)`
    **kullanılmaz** (§8). `onAppWidgetOptionsChanged` gövdesi boştur —
    geçersiz kılınmazsa ekranda hiçbir şey değişmez.

---

## 8. Mekanizma kararı — `RemoteViews(Map<SizeF, …>)` neden yok

**minSdk = 24.** Doğrulama: `app/android/app/build.gradle.kts:132` →
`minSdk = flutter.minSdkVersion`; birleştirilmiş manifest'te çözülmüş hâli
`android:minSdkVersion="24"` (Flutter 3.44.2 — `.github/workflows/ci.yml:165`).

`RemoteViews(Map<SizeF, RemoteViews>)` **API 31**'dir. minSdk 24'te tek
başına kullanılamaz; kullanılırsa API 24–30 için ikinci bir yol şart olur.

**Karar: `SizeF` haritası kullanılmaz. Tek mekanizma, var olan
`onAppWidgetOptionsChanged` + saf `widgetSizeClass` yoludur.**

Gerekçe:

1. **İki mekanizma iki gerçek demektir.** `SizeF` haritası eklenirse
   Android 12+ launcher haritadan, eskiler options'tan seçer. İki yol
   ayrışırsa hata **yalnız bir cihaz sınıfında** görünür — bu depoda tam
   olarak bu sınıf hataların bedeli ödendi (bkz. `WidgetSizeClassWp699Test`
   ve WP-699'da altı sağlayıcıda bulunan `onAppWidgetOptionsChanged` kusuru).
2. **Ölçülebilirlik.** `widgetSizeClass` saf bir fonksiyondur ve JVM
   biriminde ölçülür. `SizeF` haritası bir `RemoteViews` kurucusudur;
   `android.*` saplamaları çağrılamadığı için bu depoda **hiç test
   edilemez** — `WidgetDesign.kt:48-57`'de yazılı kısıt.
3. **Kazanç küçük.** Haritanın tek somut avantajı, yeniden boyutlandırmada
   sağlayıcıya gitmeden layout değiştirmesidir. Mevcut yol da
   `onAppWidgetOptionsChanged` ile aynı sonuca varıyor ve kullanıcı bir
   widget'ı ömründe birkaç kez boyutlandırır.

**Yani "geri düşüş yolu" bu sistemde birincil yoldur.** Kademe adları (K1–K4)
o yolun *sözlüğüdür*; kod sözleşmesi değişmez.

---

## 9. Uygulama WP'lerine devredilenler

Bu WP'de kod yazılmadı. Aşağıdakiler uygulama WP'lerinin işidir ve
**cihazda doğrulanmadan yeşil sayılmaz**:

| # | İş | Not |
|---|---|---|
| 1 | Ölü kaynakların silinmesi | `values/`, `values-night/`, `values-v31/widget_colors.xml` (§0) |
| 2 | `widget_ember_*` paletinin girilmesi + `values-night/` kaldırılması | §2.1–2.2 |
| 3 | `widgetContrastRatio` saf fonksiyonu + JVM testi | §2.2 oranları donar |
| 4 | `widgetBitmapBytes` saf fonksiyonu + JVM testi | §5, "4×2 @ 3.5 bütçeyi aşar" |
| 5 | Dokuz `widget_ic_*` + üç `widget_flame_*` + `widget_divider` + `widget_card_bg_tight` | §4 |
| 6 | Kısa süre biçimlendiricisi (`2sa 45dk`) | `study_providers.dart:3113` ayrı kalır |
| 7 | `sans-serif-condensed` geçişi, `textScaleX` 0.55 → 0.85 | §3.1 |
| 8 | Kademeye göre kart yarıçapı | §2.6, `setBackgroundResource` cihazda doğrulanacak |
| 9 | Rakam ilerlemesinin tabular olduğunun doğrulanması | §3.1 |
| 10 | `odak_alarm_widget_info.xml`'e boyut sözleşmesi | Tek widget ki `targetCell*`, `minResize*`, `maxResize*` **hiç yok**; sağlayıcısının `WidgetSizeSpecs` girdisi de yok |

**10. madde ayrıca bir kusurdur, tasarım işi değil:** alarm widget'ı
kademe sisteminin tamamen dışında. Sekiz widget'ın hepsinde
`onAppWidgetOptionsChanged` geçersiz kılınmışken alarmda yok, yani
kullanıcı onu boyutlandırdığında **ekranda hiçbir şey değişmiyor.**

---

## Kaynaklar (bu belge nereden okundu)

| Konu | Dosya |
|---|---|
| Paylaşılan görsel dil (kod) | `app/android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/WidgetDesign.kt` |
| Boyut sınıfı, punto merdiveni, 48dp kuralı | `.../widgets/StudyWidgetProviders.kt:113-500` |
| Dokuz layout | `app/android/app/src/main/res/layout/odak_*.xml` |
| Boyut sözleşmeleri | `app/android/app/src/main/res/xml/odak_*_info.xml` |
| Mevcut 12 drawable | `app/android/app/src/main/res/drawable/widget_*.xml` |
| Mevcut palet + opaklık gerekçesi | `app/android/app/src/main/res/values{,-night}/widget_design.xml` |
| Ölü palet (silinecek) | `app/android/app/src/main/res/values{,-night,-v31}/widget_colors.xml` |
| Uygulamanın kendi paleti | `app/lib/core/theme/theme_presets.dart:93-111` |
| Süre biçimlendirici | `app/lib/data/providers/study_providers.dart:3113-3122` |
| minSdk | `app/android/app/build.gradle.kts:132` + birleştirilmiş manifest (`24`) |
| Kamp ateşi görsel dünyası | `references/campfire/TASARIMCI_BRIEF.md` |
