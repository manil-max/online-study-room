# Kamp Ateşi R2 — Görsel Yön, PNG Seti ve Asset Sözleşmesi (WP-61)

> **Durum:** Asset + sözleşme teslimi · render/animasyon → **WP-62**  
> **Kanıt:** paket envanteri `Kodda doğrulandı`; sahne görsel onayı `Cihazda doğrulanmalı` / ürün sahibi  
> **DOKUNMA (bu WP):** `campfire_scene.dart` ve `classroom/**` kodu yok

---

## 1. Amaç

Mevcut sahne (WP-45) vektör `CustomPainter` ile işlevseldir; R2, **tekrar kullanılabilir PNG katmanları** ve durum dilini sabitler. WP-62 bu sözleşmeyi tüketen katmanlı renderer’ı kurar; asset yok/bozuksa mevcut painter fallback kalır.

**Kapsam dışı bu WP’de:** hayvan/karakter PNG’leri (`references/campfire` tasarımcı brief’i), grup verisi, tema motoru.

---

## 2. Sanat yönü (Odak Kampı kimliği)

| Karar | Seçim |
|---|---|
| Atmosfer | Gece kampı: sıcak ateş, soğuk orman zemin; abartısız chibi sahne ile uyumlu yumuşak siluet |
| Stil | Yumuşak alpha kenarlı, “sticker/layer” PNG; fotoreal değil |
| Gece / gündüz | **Gece varsayılan** (mevcut sahne). Gündüz varyantı R2’de yok; ileride ayrı paket |
| Hareket | Alev 3 katman + duman + köz parçacıkları ayrı hızda (WP-62); reduce-motion → tek kare, ticker yok |
| Dikkat | Alev merkezi odak; duman ve köz dekoratif, metrik/üye etiketini bastırmaz |

### 2.1 Renk / kontrast

| Yüzey | Renk notu | Erişilebilirlik |
|---|---|---|
| Alev çekirdek | Açık sarı–krem `#FFE68C` | Koyu gece zemin üzerinde AA |
| Alev dış | Turuncu–kırmızı `#DC4614` | Parıltı, metin değil |
| Odun | Kahve `#5C3A22` | Siluet okunur |
| Zemin | Koyu toprak `#2A2016` | Üye adı/süre **uygulama metni** (tema token); PNG metin taşımaz |
| Duman | Soğuk gri, düşük alpha | Reduce-motion’da opacity düşürülebilir |

**Kural:** PNG içinde yazı, UI ikonu veya marka filigranı yok.

---

## 3. Sahne durum matrisi (boş / az / yoğun)

`studyingCount` (çalışan üye sayısı) → durum. Eşikler WP-62’de sabitlemek için burada:

| Durum | Koşul | Görsel |
|---|---|---|
| **empty** | `studyingCount == 0` | `ground` + `stones` + `wood` + `coals` + zayıf `glow` (≤0.35). Alev katmanları **gizli** veya opacity ≤0.15. Duman/ember yok. |
| **low** | `1 … 2` çalışan | + `flame_back/mid/front` opacity ~0.55–0.75; `glow` orta; `smoke` hafif; ember seyrek |
| **high** | `≥ 3` çalışan | Tam alev opacity 0.9–1.0; `glow` güçlü; `smoke` + `ember_sheet` parçacıkları aktif |

Mevcut kodda intensity kabaca  
`studyingCount==0 → 0.24` else `clamp(0.55 + n*0.09, 0.55, 1.0)` — WP-62 bu tabloya hizalar.

| Durum | Katman seti (alttan üste) |
|---|---|
| empty | ground → glow(↓) → stones → wood → coals |
| low | ground → glow → stones → wood → coals → flame×3 → smoke(↓) |
| high | ground → glow → stones → wood → coals → flame×3 → smoke → ember particles |

---

## 4. Dosya sözleşmesi

### 4.1 Konum ve yoğunluk

```
app/assets/campfire/
  inventory.json          # envanter + lisans
  ground.png              # 512×512  (1.0x)
  glow.png
  wood.png
  stones.png
  coals.png
  flame_back.png
  flame_mid.png
  flame_front.png
  smoke.png
  ember_sheet.png         # 512×128 (4 kare yatay)
  2.0x/                   # 1024×1024 (ember 1024×256)
    … aynı dosya adları
```

Flutter **resolution-aware** kuralı: `Image.asset('assets/campfire/ground.png')` cihaz DPR’ye göre `2.0x/` seçer.

### 4.2 İsim / ölçü / alpha

| Kural | Değer |
|---|---|
| İsim | `snake_case`, İngilizce, `.png` |
| Format | PNG-32, **straight alpha** (premultiplied değil) |
| Matte | Yok — şeffaf dışında piksel yok |
| Anchor | Ateş tabanı tuval merkezi `(0.5, 0.5)`; zemin/odun hafif altta |
| 1.0x canvas | 512 px kare (ember_sheet: 512×128) |
| 2.0x canvas | 1024 px kare (ember_sheet: 1024×256) |
| Düşük bellek | Yalnız 1.0x yükle (WP-62: `filterQuality` + isteğe bağlı 2.0x atlama bayrağı) |

### 4.3 Z-order (WP-62 Stack)

1. `ground`  
2. `glow`  
3. `stones`  
4. `wood`  
5. `coals`  
6. `flame_back`  
7. `flame_mid`  
8. `flame_front`  
9. `smoke`  
10. `ember_sheet` parçacıkları (sprite)  
11. (kod) üye critter’lar / etiketler — asset değil

---

## 5. Üretim kaynağı ve lisans

| Alan | Kayıt |
|---|---|
| Kaynak | `scripts/generate_campfire_assets.py` — yordamsal RGBA (elipse/alev/odun) |
| Üçüncü taraf stock | **Yok** |
| `references/campfire/**` | Yalnız stil ilhamı; dosyalar kopyalanmadı, sahiplik belirsiz görseller **pakete girmedi** |
| Lisans | Proje first-party; Odak Kampı kullanımına özel |
| Yeniden üretim | `python3 scripts/generate_campfire_assets.py` |

İleride sanatçı PNG’si gelirse: aynı isim/ölçü/anchor ile üzerine yazılır; bu belge §4 bozulmaz; `inventory.json` `source` alanı güncellenir.

---

## 6. Flutter manifest

`app/pubspec.yaml`:

```yaml
assets:
  - assets/release_notes.json
  - assets/campfire/
```

Klasör bildirimi `inventory.json` + tüm PNG ve `2.0x/` varyantlarını kapsar.

**Geri alma:** `assets/campfire/` dizinini ve pubspec satırını birlikte kaldır; WP-62 devreye girmeden uygulama eski painter ile çalışır.

---

## 7. Düşük bellek / reduce-motion / hata

| Koşul | Karar |
|---|---|
| Düşük RAM / düşük DPR | 1.0x yeterli; 2.0x decode etme |
| `disableAnimations` | Alev tek kare (`flame_mid` + `flame_front`); smoke/ember opacity 0 veya statik |
| Asset load fail | WP-62 mevcut `StoneFirePainter` fallback (`Kodda doğrulandı` mevcut kod) |
| APK boyutu | Bu paket ~0.5–0.6 MB ham PNG; gerekirse ileride webp (ayrı WP) |

---

## 8. Smoke / kabul

### 8.1 Otomatik (`Kodda doğrulandı`)

- `app/test/assets/campfire_assets_test.dart`: zorunlu dosyalar var; `rootBundle` yükler; PNG imza `89 50 4E 47`; inventory JSON parse.
- `flutter analyze` 0 (bu kulvar).

### 8.2 Ürün / cihaz (`Cihazda doğrulanmalı`)

- 360 dp telefon ve tablet: ateş merkezi crop olmaz, üye halkası okunur.  
- empty/low/high üç durum görsel olarak ayırt edilir (WP-62 sonrası).  
- Ürün sahibi görsel yönü onaylar → WP-62 başlar.

---

## 9. WP-62 el sıkışması (kısa)

WP-62 **yalnız** şu yolları okur:

- `assets/campfire/<layer>.png` (+ resolution variants)
- Bu belgedeki durum matrisi ve z-order

WP-62 **yazmaz:** `app/assets/campfire/**`, `pubspec.yaml` asset satırı.

---

## 10. Envanter özeti

| Dosya | Rol | 1.0x |
|---|---|---|
| ground.png | Zemin/açıklık | 512² |
| glow.png | Sıcak ışık | 512² |
| stones.png | Taş halka | 512² |
| wood.png | Odun | 512² |
| coals.png | Empty/low köz | 512² |
| flame_back.png | Alev dış | 512² |
| flame_mid.png | Alev orta | 512² |
| flame_front.png | Alev çekirdek | 512² |
| smoke.png | Duman | 512² |
| ember_sheet.png | 4 kare köz | 512×128 |
| inventory.json | Meta + lisans | — |

Tam meta: `app/assets/campfire/inventory.json`.

---

## 11. Değişiklik günlüğü

| Tarih | Not |
|---|---|
| 2026-07-14 | WP-61: sözleşme + first-party PNG seti + pubspec + smoke test. Render yok. |
