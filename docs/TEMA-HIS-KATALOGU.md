# Tema "His" Kataloğu ve `AppFeel` Şema Kararı (WP-289)

> **Amaç:** "Kendi Temanı Oluştur" sihirbazının 6. adımı (his/animasyon) için
> uygulama/oyun temalarında yaygın "his" ailelerini derlemek ve bunları mevcut
> token sistemine bağlamak. **Çıktının asıl işi WP-288'i açmaktır:** `AppFeel`
> katmanının **alan listesi** burada kesinleşir; 288 bunu birebir uygular.
>
> **Telif sınırı:** Yalnız **fikir ve teknik desen** alınmıştır. Hiçbir başka
> uygulamanın asset'i, ikonu, birebir renk paleti veya görsel kimliği kopyalanmaz.
>
> **K-3 (hangi hisler ürüne girecek) hâlâ ürün kararıdır** — aşağıdaki kısa liste
> sahiple birlikte budanır. Bu belge şemayı ve seçenek havuzunu sağlar.
>
> Tarih: 2026-07-24 · Girdi: Yeni Özellik Turu Aşama A planı §4.4 (git geçmişinde)

---

## 0. Mevcut token altyapısı (neyi zaten ifade edebiliyoruz)

`Kodda doğrulandı` — `app/lib/core/theme/theme_tokens.dart`:

| Katman | İlgili alanlar | His üretiminde rolü |
|---|---|---|
| `AppColors` | scaffold, surface1/2, primary, accent, textPrimary/Secondary, border | Sıcaklık/kontrast/ton |
| `AppShapes` | radiusSm/Md/Lg, cardElevation, borderWidth, `sharp` | Yuvarlaklık ↔ keskinlik, gölge derinliği |
| `AppAtmosphere` | gradientStart/End, glowColor, glowStrength, blurSigma, glassOpacity | Degrade, parıltı, cam, bulanıklık |
| `AppMotion` | fast/normal/slow, `respectReduceMotion`, `resolve()` | Geçiş hızı/karakteri |

**Sonuç:** Hislerin çoğu renk+şekil+atmosfer+hareket bileşimidir ve **mevcut token'larla
büyük ölçüde ifade edilebilir.** Eksik olan iki şey vardır ve `AppFeel` bunları ekler:
1. **Doku/gren** (kâğıt, karton, film greni) — hiçbir token bunu taşımıyor.
2. **Kenar düzensizliği** ("eskimiş kutu" hissi) — `AppShapes` yalnız düzgün yarıçap taşıyor.

---

## 1. His aileleri (havuz — budanacak)

Her aile: **ne hissettirir · token karşılığı · Flutter'da nasıl · maliyet · reduce-motion · koyu/açık farkı.**

### H-01 · Modern / Minimal
- **His:** Sakin, temiz, "az ama öz". Varsayılan/güvenli seçim.
- **Token:** orta yuvarlaklık (`radiusMd 16`), düşük/sıfır elevation, düz yüzey, `glowStrength 0`, `blurSigma 0`, hızlı-yumuşak geçiş (`AppMotion.snappy`).
- **Flutter:** mevcut düz kartlar; `AnimatedContainer` + `Curves.easeOut`. Ek maliyet yok.
- **Maliyet:** yok. **Reduce-motion:** geçiş süresi 0'a iner, görünüm bozulmaz. **Koyu/açık:** nötr.

### H-02 · Yumuşak / Zen
- **His:** Nefes alan, yavaş, düşük kontrast; odaklanma/dinginlik.
- **Token:** büyük yuvarlaklık (`radiusLg 24+`), yumuşak gölge, düşük kontrast renkler, yavaş geçiş (`slow`), hafif degrade.
- **Flutter:** yumuşak `BoxShadow`, geniş boşluk. Ölçülü.
- **Maliyet:** gölge orta (blur'lu gölge GPU). **Reduce-motion:** yavaş geçişler durur. **Koyu:** kontrastı AA altına düşürmemeye dikkat (kontrast koruması devrede).

### H-03 · Neon / Cyber
- **His:** Enerjik, koyu zemin + parlak vurgu, "gece modu / oyun".
- **Token:** koyu `scaffold`, yüksek `glowStrength`, keskin köşe (`sharp` veya küçük radius), doygun `accent`, `glowColor = accent`.
- **Flutter:** glow için dıştan `BoxShadow(color, blurRadius, spreadRadius)` veya `ImageFiltered`. Titreşim isteğe bağlı (reduce-motion'da kapalı).
- **Maliyet:** **yüksek** — çok sayıda glow'lu öğe GPU'yu yorar; glow'u yalnız vurgu öğelerinde kullan. **Reduce-motion:** titreşim durur, statik glow kalır. **Açık modda:** glow zayıf görünür → bu his koyu-öncelikli.

### H-04 · Vintage / Retro (film greni)
- **His:** Sıcak, nostaljik, hafif "eski fotoğraf".
- **Token:** sıcak ton (amber/sepia kayması), orta yuvarlaklık, **gren dokusu** (`AppFeel.grainStrength`).
- **Flutter:** gren = tekrarlı yarı-saydam noise texture (küçük asset) veya `CustomPainter` ile prosedürel nokta deseni; `BlendMode.overlay`. Statik (animasyonsuz) tutmak ucuz.
- **Maliyet:** statik grende düşük; animasyonlu grende orta. **Reduce-motion:** gren statikleşir. **Koyu/açık:** grenin opaklığı moda göre ayarlanmalı.

### H-05 · Eskimiş Karton / Kutu
- **His:** Sahibin tarifi — "kutular eskimiş gibi", yıpranmış kenar + karton dokusu.
- **Token:** karton dokusu (`grainStrength` + doku türü), **kenar düzensizliği** (`AppFeel.edgeIrregularity`), mat yüzey, sert-ish gölge.
- **Flutter:** kenar düzensizliği = `ShapeBorder` özelleştirmesi (hafif düzensiz path) veya köşe maskesi; doku = overlay texture. **Bu ailenin `edgeIrregularity` alanına ihtiyacı var** (yeni).
- **Maliyet:** özel `ShapeBorder` orta; her karta uygulanınca dikkat. **Reduce-motion:** statik zaten. **Koyu/açık:** karton tonu iki modda ayrı.

### H-06 · Kâğıt / Defter
- **His:** Çalışma/not defteri; çizgili zemin, mürekkep hissi.
- **Token:** açık kâğıt zemini, ince çizgi deseni (doku), serif başlık (`AppTypography`), düşük elevation.
- **Flutter:** çizgi deseni `CustomPainter` (ucuz, statik). Sayfa-çevirme geçişi opsiyonel (reduce-motion'da kapalı).
- **Maliyet:** desen düşük. **Reduce-motion:** çevirme animasyonu kapanır. **Koyu:** "gece defteri" varyantı gerekir.

### H-07 · Cam (Glassmorphism)
- **His:** Modern, katmanlı, bulanık şeffaf yüzey.
- **Token:** `glassOpacity > 0`, `blurSigma > 0`, ince parlak kenarlık, degradeli zemin.
- **Flutter:** `BackdropFilter(ImageFilter.blur)` — **pahalı**, iç içe kullanımdan kaçın.
- **Maliyet:** **yüksek** (backdrop blur her karede yeniden). Düşük donanımda kare düşer → sınırlı kullan. **Reduce-motion:** blur statik kalır (hareket değil). **Koyu/açık:** ikisinde de çalışır, zemin degradesi şart.

### H-08 · Düz / Flat
- **His:** Gölgesiz, kenarlıkla ayrılan yüzeyler; en hafif.
- **Token:** `cardElevation 0`, `borderWidth 1`, net kenarlık, düz renk.
- **Flutter:** mevcut. Maliyet yok. **Reduce-motion:** etkilenmez. **Koyu/açık:** nötr.

---

## 2. Performans ve erişilebilirlik özeti

| His | GPU maliyeti | Düşük donanım riski | Reduce-motion davranışı |
|---|---|---|---|
| Modern, Flat | Yok | Yok | Geçiş 0'a iner |
| Zen, Kâğıt, Vintage(statik) | Düşük | Düşük | Animasyon durur, doku/gölge kalır |
| Eskimiş Karton | Orta | Orta (özel ShapeBorder) | Statik |
| Neon | Yüksek (glow) | Orta-Yüksek | Titreşim durur |
| Cam | Yüksek (backdrop blur) | Yüksek | Blur statik kalır |

🔴 **Kural:** `AppMotion.respectReduceMotion` zaten var ve `resolve()` ile süreleri 0'a
indiriyor. `AppFeel` de sistem "hareketi azalt" ayarına saygı duyar; **hareket** kapanır ama
statik doku/gölge kalır (bunlar hareket değildir). Ağır efektler (Neon glow, Cam blur) düşük
donanımda kare düşürebilir → sihirbazda seçilebilir ama varsayılan **Modern**tir.

---

## 3. 🔴 `AppFeel` şema kararı (WP-288 bunu birebir uygular)

Yeni `ThemeExtension` katmanı. `copyWith` + `lerp` + `app_theme.dart:338` `extensions:`
listesine eklenmesi zorunludur (yoksa ölü anahtar — plan R3).

```dart
@immutable
class AppFeel extends ThemeExtension<AppFeel> {
  const AppFeel({
    required this.feelId,          // 'modern' | 'zen' | 'neon' | 'vintage' |
                                   // 'carton' | 'paper' | 'glass' | 'flat'
    required this.grainStrength,   // 0.0–1.0  doku/gren yoğunluğu (0 = yok)
    required this.grainKind,       // 'none' | 'film' | 'paper' | 'carton'
    required this.edgeIrregularity,// 0.0–1.0  kenar yıpranması (0 = düzgün)
    required this.motion,          // mevcut AppMotion (hız/karakter + reduceMotion)
  });

  final String feelId;
  final double grainStrength;
  final String grainKind;
  final double edgeIrregularity;
  final AppMotion motion;

  static const AppFeel modern = AppFeel(
    feelId: 'modern', grainStrength: 0, grainKind: 'none',
    edgeIrregularity: 0, motion: AppMotion.snappy,
  );

  // copyWith: tüm alanlar
  // lerp: double alanlar lerpDouble; String/AppFeel alanlar t<0.5 ? a : b;
  //       motion → AppMotion.lerp
}
```

**Neden bu dört alan yeterli (fazlası değil):**
- `feelId` — sihirbazda seçilen aileyi taşır; render/preset eşlemesi için.
- `grainStrength` + `grainKind` — H-04/05/06'nın doku ihtiyacını karşılar; renk/şekil zaten
  `AppColors`/`AppShapes`'te olduğu için burada **tekrar edilmez.**
- `edgeIrregularity` — yalnız H-05'in ("eskimiş kutu") ihtiyacı; başka hiçbir token karşılamıyor.
- `motion` — mevcut `AppMotion`'ı sarar; ayrı bir hareket katmanı icat edilmez.

**`AppFeel`'in KAPSAMADIĞI (bilerek):** renk (→ `AppColors`), yuvarlaklık/gölge (→ `AppShapes`),
degrade/glow/blur/cam (→ `AppAtmosphere`), tipografi (→ `AppTypography`). His bir **bileşim
kimliğidir**; his seçimi bu dört katmanı birlikte ayarlar ama onları tekrar tutmaz.

**Render tarafı (WP-290 6. adım):** her `feelId` için grain overlay + edge shaper uygulayan
bir `FeelDecoration` sarmalayıcısı; `grainStrength 0 && edgeIrregularity 0` iken hiçbir ek
katman çizilmez (Modern/Flat sıfır maliyet).

---

## 4. Sihirbaza önerilen kısa liste (K-3 — sahip budayacak)

Claude önerisi (varsayılan + 4 belirgin karakter, ağır ikisi opsiyonel):
1. **Modern** (varsayılan, sıfır maliyet)
2. **Zen / Yumuşak** (odak ürünüyle uyumlu)
3. **Kâğıt / Defter** (çalışma teması, ucuz)
4. **Vintage** (sıcak, statik gren)
5. **Eskimiş Karton** (sahibin özel istediği his)
6. *(opsiyonel, "gelişmiş" etiketiyle)* **Neon**, **Cam** — ağır; düşük donanım uyarısıyla.

> Sahip bu listeden çıkarma/ekleme yapabilir. Şema (bölüm 3) listeden **bağımsızdır**:
> hangi hisler seçilirse seçilsin `AppFeel` alanları aynı kalır, yalnız hazır `feelId`
> değerleri değişir. Bu yüzden **WP-288 bu karar beklenmeden başlayabilir.**

---

## 5. WP-288'e devir

- `AppFeel` şeması (§3) kesin — 288 bunu uygular.
- Hazır `feelId` havuzu (§1/§4) — 290'ın sihirbazı bunları sunar; final liste K-3.
- Render deseni (grain overlay + edge shaper) — 290'ın 6. adımı.
- Performans bütçesi: ağır hisler (Neon/Cam) için düşük donanımda p95 ≤ 16.7 ms hedefi 290'da ölçülür.
