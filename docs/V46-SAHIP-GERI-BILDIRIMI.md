# v46 stable — sahip geri bildirimi (2026-07-25)

> Sahibin **ilk** değerlendirmesi. Hepsi tema sihirbazı/tema motoru ve istatistik
> yüzeyinde. Kartlar: **WP-306 … WP-313**. Sıra ve kapsam sahibe ait.
> Bu dosya kaydın kendisidir — kart özetleri `progress.md`'de, ayrıntı burada.

## WP-306 — Tema adı alanında klavye açılıp kapanıyor ✅ ÇÖZÜLDÜ (v47)

**Sahip:** "tema oluşturduktan sonra isim yazma yerine gelince tıklıyorum üstüne
klavye açılıp kapanıyor. telefonu yana çevirince yazabildim ismi."

Dikey ekranda ad alanına odak **anında kaybediliyor**; yatayda çalışıyor.
Yataya çevirince düzelmesi klasik işaret: klavye açılınca `viewInsets` değişiyor,
düzen yeniden kuruluyor ve `TextField` **yeniden yaratılıp** odağı düşürüyor
(state/`GlobalKey` kimliği korunmuyor ya da `resizeToAvoidBottomInset` ile
sihirbaz sayfası yeniden inşa ediliyor). Yatayda klavye oranı küçük olduğu için
tetiklenmiyor.

İlk bakılacak: `theme_builder_screen.dart` (sayfa geçişi / önizleme sabitleme —
WP-302'de mobil dal `Column + Expanded(ListView)` olarak değişti) ve ad alanının
yaşadığı adım (`theme_builder_steps.dart`).

**Kök neden (bulundu):** WP-302 sabit önizleme dalı kararını doğrudan
`constraints.maxHeight` ile veriyordu. Klavye gövdeyi küçültünce ölçüt 480 dp
eşiğinin altına düşüyor, düzen `Column` → `ListView`'a atlıyor, ağaç şekli
değiştiği için `TextField` sıfırdan kuruluyor ve odağı düşürüyordu. Yatayda
yükseklik zaten eşiğin altında olduğundan dal değişmiyor — sahibin gözlemi.

**Çözüm:** karar klavyeden bağımsız yükseklikle verilir; klavye açıkken
önizleme gizlenir (Column'un çocuk sayısı sabit kalacak şekilde). Ayrıca aynı
ekranda `StepDots` 8×48 dp ile 360 dp telefonda taşıyordu — dar ekranda eşit
bölüşür oldu. Test: `app/test/features/profile/theme_builder_name_focus_test.dart`.

## WP-307 — 7. adım (His) önceki ayarları siliyor ✅ ÇÖZÜLDÜ (v48)

**Sahip:** "7. kademede feels kısmında bir şeye basınca önceden ayarladıklarımız
gidiyor."

His adımında bir seçeneğe basmak, daha önceki adımlarda yapılan ayarları (renk /
tipografi / köşe vb.) taslaktan düşürüyor. Muhtemel sebep: his ön ayarı
`ThemeDraft`'ı **kısmi güncelleme yerine yeniden kuruyor** (preset uygulanırken
`copyWith` yerine yeni draft üretiliyor).

İlk bakılacak: `theme_feel_catalog.dart`, `feel_overlay.dart`, `theme_draft.dart`.

**Kabul:** his ön ayarı seçmek yalnız his alanlarını değiştirir; 1–6. adımların
çıktısı aynen kalır. Regresyon testi: draft kur → his seç → önceki alanlar eşit.

**Kök neden (bulundu):** `ThemeDraft.withFeel` şekil ve atmosferi **koşulsuz**
hisle hizalıyordu (`shapesForFeel` / `atmosphereForFeel`). Sihirbaz sırası
Biçim → Atmosfer → His olduğu için his seçmek bir önceki iki adımda yapılan
her şeyi siliyordu.

**Çözüm:** taslak artık "kullanıcı bu katmana elle dokundu mu" bilgisini tutar
(`shapesEdited` / `atmosphereEdited`); Biçim ve Atmosfer adımları
`withShapes` / `withAtmosphere` üzerinden yazar. Dokunulmuş katman his
seçiminde korunur, dokunulmamış katmanda his hâlâ makul bir zemin verir.
Kayıtlı temayı düzenlemede iki bayrak da baştan açıktır.

## WP-308 — Okunmayan metin: kullanıcı teması bazı yüzeylerde tutmuyor ✅ ÇÖZÜLDÜ (v48)

**Sahip:** "bazı yazılar bu ayarlarda okunmuyor mesela profil sekmesinde isim
kısmı. koyu renkte siyaha yakın tonda ama görselde metin ve metin 2 de açık
renkler ayarlanmış."

Gönderilen ekran görüntüsünde (kullanıcıdan gelme) Ana Sayfa'da **"Ana Sayfa",
"Bugün özeti", "Sıralama", "Şu an çalışanlar", "Grup hedefi"** başlıkları
zemine gömülü — oysa temada Metin ve İkincil metin **açık sarı/bej** seçilmiş.
Yani bu yüzeyler kullanıcının metin rengini değil, **başka bir rolü** (ör.
`onSurfaceVariant` / `outline` / başlık için türetilmiş bir ton) kullanıyor;
türetme koyu zeminde kontrastı düşürüyor.

Bu bir "kullanıcı yanlış seçti" durumu değil: **ayar var, uygulanmıyor.**
`theme_contrast.dart` bir AA uyarısı üretiyor ama uyarı yüzeyin kendisini
kurtarmıyor.

**Kabul:** özel temada tüm başlık/gövde metinleri seçilen metin renklerinden
türer; AA altına düşen kombinasyon **otomatik düzeltilir** ya da kaydetmeden önce
somut olarak engellenir. En az bir golden: koyu zemin + açık metin.

**Kök neden (bulundu):** `CustomTheme` tipografiyi **tek** kopya saklıyor ve o
kopyaya kaydetme anındaki metin rengi pişiyor (`toCustomTheme()` →
`typographyFor(Brightness.light)`). `main.dart` aynı kopyayı hem açık hem koyu
`ThemeData`'ya veriyor; `_buildFromTokens` ise `color: token.color ?? …`
diyerek pişmiş rengi olduğu gibi kullanıyordu. Sonuç: koyu modda tüm
`textTheme` slotları **açık varyantın koyu metnini** taşıyor — kullanıcı metni
açık seçse bile başlıklar zemine gömülüyor. `colorScheme.onSurface` kullanan
yüzeyler doğru göründüğü için hata "bazı yazılar" gibi görünüyordu.

**Çözüm:** `AppTypography.recolored()` eklendi; `_buildFromTokens` tipografiyi
**her zaman** aktif varyantın `colors.textPrimary` değeriyle tazeliyor.
Test: `app/test/core/custom_theme_text_contrast_test.dart` (iki varyantta da
başlık AA eşiğini geçiyor).

## WP-309 — Renk seçici: hazır renk + spektrum (Samsung Notes deseni) ✅ ÇÖZÜLDÜ (v48)

**Sahip:** "renk seçme için hazır renkler vermek yerine spektrumlu hazır renkler
daha güzel olur… hazır renkler var birde en sağda kine basınca spektrum açılıyor
istediğin rengi seçebiliyorsun." (3. ekran görüntüsü referans)

Tek satır hazır renk yuvarlağı + **en sağda gökkuşağı düğmesi** → tam spektrum
seçici (ton/doygunluk/parlaklık + hex).

**Kabul:** her renk rolünde (Ana renk, Vurgu, Zemin, Yüzey, Metin…) hazır palet
görünür; sağdaki düğme spektrumu açar; seçilen renk canlı önizlemeye anında
yansır.

**Çözüm:** renk yaprağı artık iki modlu. Hazır ızgaranın **son hücresi**
gökkuşağı düğmesi (başlıkta da "Spektrum" bağlantısı var — ızgara uzunsa
kaydırmaya gerek kalmasın). Spektrum modu HSV kaydırıcıları (ton/doygunluk/
parlaklık), kendi zemininde renkli şeritler, canlı örnek ve hex kodu gösterir.
Test: `app/test/features/profile/theme_color_spectrum_test.dart`.

## WP-310 — Font adımında düğmeler yerinde durmuyor ✅ ÇÖZÜLDÜ (v48)

**Sahip:** "font seçme kısmında fontlar seçenek butonları sabit olsun bastıkça
yer değiştiriyor ekran kayıyor vs kafa karışıyor… sürekli her değişiklikte
ekranda butonlar hareket ediyor."

Seçim yapınca liste yeniden ölçülüyor (seçili kart büyüyor / seçilen fontla
etiket genişliği değişiyor) ve düğmeler zıplıyor.

**Kabul:** seçim değişince hiçbir düğme yer değiştirmez, kaydırma konumu sabit
kalır. Test: iki farklı seçim sonrası düğme dikdörtgenleri eşit.

**Kök neden (bulundu):** `ChoiceChip` varsayılan olarak seçilince **onay tiki**
çiziyor (~24 dp genişleme) — `Wrap` satırları yeniden diziliyor ve düğmeler
zıplıyordu. Kenarlık kalınlığını seçime bağlamak da 2 dp kaydırıyor (test bunu
yakaladı).

**Çözüm:** `showCheckmark: false`, kenarlık kalınlığı sabit 1.5 dp; seçim yalnız
renkle anlatılıyor. Test: `theme_builder_typography_step_test.dart` iki ardışık
seçimden sonra tüm çip dikdörtgenlerini karşılaştırıyor.

## WP-311 — Canlı önizleme neyin değiştiğini göstermiyor ✅ ÇÖZÜLDÜ (v48)

**Sahip:** "fontlarda da bazı ayarı değiştiriyoruz neye etki ediyor görünmüyor
canlı önizlemeyi ona göre revize etmek lazım."

Önizleme kartı (Bugün / Sayaç) tipografi ve his değişimlerini yeterince
göstermiyor: başlık/gövde/rakam/etiket hiyerarşisi ve ağırlık farkı görünmüyor.

**Kabul:** önizleme o adımda değişen şeyi **öne çıkarır** — tipografi adımında
başlık + gövde + rakam + küçük etiket bir arada; his adımında efekt gerçekten
görünür.

**Çözüm (yazı adımı):** `ThemePreviewFocus` eklendi. Yazı adımında önizleme iki
mini kart yerine **etiketli örneklik** gösteriyor: "Başlık yazı tipi",
"Gövde yazı tipi", "Sayaç yazı tipi" başlıkları altında gerçek örnekler —
hangi seçicinin neye dokunduğu doğrudan okunuyor. Kalınlık/ölçek/harf aralığı
aynı üç örnekte görünür. His adımı için ayrı odak henüz yok (WP-312 kararına
bağlı).

## WP-312 — Kavramsal sadeleştirme: "kaç kere renk ayarlıyoruz?"

**Sahip:** "tam anlamadım kaç kere renk ayarlıyoruz sistem garip biraz bazı
şeyleri hep ayarlıyoruz bazılarının etkisi neyi değiştiriyor anlamıyoruz."

8 adımlı sihirbazda renk birden çok yerde soruluyor (2. adım rolleri + his
katmanı + koyu/açık varyant) ve hangi ayarın nereye dokunduğu belirsiz.
🔴 **Bu kart sahip kararı ister** — çözüm ya adımları birleştirmek ya her role
"bu neyi değiştirir" tek satır açıklama + önizlemede vurgulamak.

## WP-313 — Grafikte her sütunun altında tarih ✅ ÇÖZÜLDÜ (v48)

**Sahip:** "tarihler 2 günde bir yazılıyor ama ben her sütunun altında olsun
istiyorum." (4. ekran görüntüsü, 14 gün)

**Kök neden bulundu:** [daily_bar_chart.dart:69](../app/lib/features/stats/widgets/daily_bar_chart.dart:69)
`axisLabelStep(days.length, constraints.maxWidth, labelWidth: 26)`. Etiket
**iki satır** (gün numarası + ay adı) olduğu için 26 px genişlik varsayılıyor;
sığmayınca adım 2'ye çıkıyor ve her ikinci gün yazılıyor.

Önerilen çözüm: gün numarası **her sütunda**, ay adı yalnız **ay değiştiğinde**
(ve ilk sütunda). Böylece etiket genişliği ~14 px'e iner, 14 ve çoğu 30 günlük
seride adım 1 olur. 30 günde hâlâ sığmazsa gün numarası döndürülmeden tek satır
kalır.

**Kabul:** 7 ve 14 günde her sütunun altında tarih var; 30 günde okunabilirlik
bozulmuyor. `chart_axis.dart` yardımcı fonksiyonunun testi güncellenir.

**Çözüm:** ay adı yalnız ilk sütunda ve **ay değiştiğinde** yazılır; etiket
genişliği varsayımı 26 → 14 px'e indi, 7/14 günlük seride adım 1 oldu. İkinci
satır her zaman çizilir (gerekmediğinde boş metin) ki taban hizası bozulmasın.
Test: `app/test/features/stats/daily_bar_chart_labels_test.dart`.

---

## Durum (v48)

| Kart | Durum |
| --- | --- |
| WP-306 klavye | ✅ v47 |
| WP-307 his ayarları siliyor | ✅ v48 |
| WP-308 okunmayan metin | ✅ v48 |
| WP-309 spektrum seçici | ✅ v48 |
| WP-310 font düğmeleri zıplıyor | ✅ v48 |
| WP-311 önizleme odağı | ✅ v48 (yazı adımı) |
| WP-312 kavramsal sadeleştirme | 🔴 sahip kararı bekliyor |
| WP-313 grafik tarihleri | ✅ v48 |

**Kalan tek iş WP-312.** Seçenekler:
1. Adım sayısını 8 → 5'e indir (Zemin+Renk, Yazı, Biçim+Atmosfer, His, Özet).
2. Adımları koru, her renk rolüne "bu neyi değiştirir" tek satır açıklama ekle
   ve önizlemede o rolü vurgula (WP-311'in renk adımına genişletilmesi).
3. Karma: rolleri "temel / ileri" diye ikiye ayır, ileri olanlar katlanmış dursun.
