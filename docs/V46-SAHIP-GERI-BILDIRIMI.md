# v46 stable — sahip geri bildirimi (2026-07-25)

> Sahibin **ilk** değerlendirmesi. Hepsi tema sihirbazı/tema motoru ve istatistik
> yüzeyinde. Kartlar: **WP-306 … WP-313**. Sıra ve kapsam sahibe ait.
> Bu dosya kaydın kendisidir — kart özetleri `progress.md`'de, ayrıntı burada.

## WP-306 — Tema adı alanında klavye açılıp kapanıyor 🔴

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

**Kabul:** dikey ekranda ada dokun → klavye açık kalıyor, yazılabiliyor;
ekran döndürülünce yazılan ad kaybolmuyor.

## WP-307 — 7. adım (His) önceki ayarları siliyor 🔴

**Sahip:** "7. kademede feels kısmında bir şeye basınca önceden ayarladıklarımız
gidiyor."

His adımında bir seçeneğe basmak, daha önceki adımlarda yapılan ayarları (renk /
tipografi / köşe vb.) taslaktan düşürüyor. Muhtemel sebep: his ön ayarı
`ThemeDraft`'ı **kısmi güncelleme yerine yeniden kuruyor** (preset uygulanırken
`copyWith` yerine yeni draft üretiliyor).

İlk bakılacak: `theme_feel_catalog.dart`, `feel_overlay.dart`, `theme_draft.dart`.

**Kabul:** his ön ayarı seçmek yalnız his alanlarını değiştirir; 1–6. adımların
çıktısı aynen kalır. Regresyon testi: draft kur → his seç → önceki alanlar eşit.

## WP-308 — Okunmayan metin: kullanıcı teması bazı yüzeylerde tutmuyor 🔴

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

## WP-309 — Renk seçici: hazır renk + spektrum (Samsung Notes deseni)

**Sahip:** "renk seçme için hazır renkler vermek yerine spektrumlu hazır renkler
daha güzel olur… hazır renkler var birde en sağda kine basınca spektrum açılıyor
istediğin rengi seçebiliyorsun." (3. ekran görüntüsü referans)

Tek satır hazır renk yuvarlağı + **en sağda gökkuşağı düğmesi** → tam spektrum
seçici (ton/doygunluk/parlaklık + hex).

**Kabul:** her renk rolünde (Ana renk, Vurgu, Zemin, Yüzey, Metin…) hazır palet
görünür; sağdaki düğme spektrumu açar; seçilen renk canlı önizlemeye anında
yansır.

## WP-310 — Font adımında düğmeler yerinde durmuyor

**Sahip:** "font seçme kısmında fontlar seçenek butonları sabit olsun bastıkça
yer değiştiriyor ekran kayıyor vs kafa karışıyor… sürekli her değişiklikte
ekranda butonlar hareket ediyor."

Seçim yapınca liste yeniden ölçülüyor (seçili kart büyüyor / seçilen fontla
etiket genişliği değişiyor) ve düğmeler zıplıyor.

**Kabul:** seçim değişince hiçbir düğme yer değiştirmez, kaydırma konumu sabit
kalır. Test: iki farklı seçim sonrası düğme dikdörtgenleri eşit.

## WP-311 — Canlı önizleme neyin değiştiğini göstermiyor

**Sahip:** "fontlarda da bazı ayarı değiştiriyoruz neye etki ediyor görünmüyor
canlı önizlemeyi ona göre revize etmek lazım."

Önizleme kartı (Bugün / Sayaç) tipografi ve his değişimlerini yeterince
göstermiyor: başlık/gövde/rakam/etiket hiyerarşisi ve ağırlık farkı görünmüyor.

**Kabul:** önizleme o adımda değişen şeyi **öne çıkarır** — tipografi adımında
başlık + gövde + rakam + küçük etiket bir arada; his adımında efekt gerçekten
görünür.

## WP-312 — Kavramsal sadeleştirme: "kaç kere renk ayarlıyoruz?"

**Sahip:** "tam anlamadım kaç kere renk ayarlıyoruz sistem garip biraz bazı
şeyleri hep ayarlıyoruz bazılarının etkisi neyi değiştiriyor anlamıyoruz."

8 adımlı sihirbazda renk birden çok yerde soruluyor (2. adım rolleri + his
katmanı + koyu/açık varyant) ve hangi ayarın nereye dokunduğu belirsiz.
🔴 **Bu kart sahip kararı ister** — çözüm ya adımları birleştirmek ya her role
"bu neyi değiştirir" tek satır açıklama + önizlemede vurgulamak.

## WP-313 — Grafikte her sütunun altında tarih

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

---

## Sıra önerisi

1. **WP-306** (klavye) ve **WP-313** (tarih ekseni) — küçük, net, tek dosyalık.
2. **WP-307** (ayar sıfırlanması) — veri kaybı, en can yakıcı hata.
3. **WP-308** (okunmayan metin) — tema motoruna dokunur, en riskli iş.
4. **WP-310 / WP-311** (font adımı yerleşimi + önizleme).
5. **WP-309** (spektrum seçici) — yeni yüzey.
6. **WP-312** — 🔴 önce sahip kararı.
