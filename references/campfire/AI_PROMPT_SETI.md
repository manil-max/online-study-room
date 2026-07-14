# Kamp Ateşi — Basit AI Prompt Seti

Amaç: Tasarımcıya gerek kalmadan, bir görsel AI (Gemini "Nano Banana", CharacterGen,
Midjourney vb.) ile **sade ve tatlı** kamp ateşi hayvanları üretmek.
Profesyonel spec değil — "otursun, çalışınca azıcık renklensin, marşmelov ısıtsın" yeter.

> Nasıl kullanılır:
> 1. Önce **A) Master prompt** ile bir hayvanın temel halini çıkar (referans).
> 2. O görseli AI'a referans verip **B) Poz promptları** ile 3 pozu üret.
> 3. Beğenince C listesindeki 12 hayvana çoğalt.
> 4. Önce **1 hayvan** dene (bear), sahneye koy, tutarsa gerisini üret.

---

## A) Master prompt (temel hayvan — 1 kez, referans için)

```
Cute chubby cartoon BEAR character, simple flat style, soft rounded shapes,
big friendly eyes, sitting cross-legged. Front view, facing viewer, slightly
looking down. Full body, centered. Plain TRANSPARENT background (no scene,
no fire, no ground, no shadow). Soft warm lighting from below-front.
Clean vector-like illustration, cozy and friendly. Single character only.
```

- Her yeni hayvan için `BEAR` yerine türü yaz (aşağıdaki liste).
- **Şeffaf arka plan** ve **tek karakter** vurgusunu koru — sahneyi uygulama çiziyor.

---

## B) Poz promptları (aynı hayvanı referans vererek)

Referans görseli ekle + "same character, same style, same size" de. Sadece pozu değiştir.

### 1. `idle` — boşta oturuyor
```
Same bear, sitting relaxed, hands in lap, awake, calm smile.
No laptop. Transparent background, same size and position.
```

### 2. `working` — çalışıyor (azıcık renkli/parlak)
```
Same bear, sitting, holding a small open laptop on its lap, both paws on
keyboard, looking at the screen, focused and slightly happy. Colors a touch
warmer and brighter (glowing softly). Transparent background, same size.
```

### 3. `roasting` — marşmelov ısıtıyor
```
Same bear, sitting, one arm reaching forward holding a thin stick with a
white marshmallow on the end, extending down-forward (toward where the fire is),
cozy happy expression. Transparent background, same size and position.
```

> İstersen 4. poz `sleepy` (gözler kapalı, uyuyor) ekleyebilirsin ama şart değil.

---

## C) Hayvan listesi (Master prompt'ta türü değiştir)

Öncelik sırası — ilk 6'sı yeterli başlar:

1. bear (ayı)
2. fox (tilki)
3. rabbit (tavşan)
4. cat (kedi)
5. dog (köpek)
6. panda (panda)
7. owl (baykuş)
8. penguin (penguen)
9. koala (koala)
10. frog (kurbağa)
11. tiger (kaplan)
12. hedgehog (kirpi)

---

## D) Dosya isimleri (kod bunu bekliyor)

```
<hayvan>_<poz>.png
```
Örnek:
```
bear_idle.png      bear_working.png      bear_roasting.png
fox_idle.png       fox_working.png       fox_roasting.png
```
- Küçük harf, İngilizce.
- Klasör: `assets/critters/`

---

## E) Basit kurallar (uyulması yeterli olan minimum)

- **Şeffaf PNG**, kare (1024×1024 iyi olur, 512 de olur).
- Hayvan **ortada**, öne baksın.
- 3 poz aynı boyda/oturuşta olsun ki sahnede zıplamasın (referansı hep göster).
- Sahne yok: **ateş, arka plan, gölge, isim/süre yazısı** → hepsini uygulama çiziyor.
- Stil hepsi aynı kalsın (aynı model, aynı master prompt dilini kullan).

---

## F) Test adımı (48 dosya üretmeden önce)

Sadece **bear**'in 3 pozunu üret → uygulamaya koy → ekran görüntüsü al.
Boyut/hiza/renk iyiyse formatı sabitle, gerisini üret. Yanlış üretim riskini keser.
