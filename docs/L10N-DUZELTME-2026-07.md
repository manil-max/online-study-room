# WP-173 — l10n derin düzeltme (2026-07-18)

## Özet

| Dil | Anahtar sayısı | EN ile birebir kalan | Not |
|---|---:|---:|---|
| **en** | 1109 | — | Şablon |
| **tr** | 1109 | 0 eksik | parity ✓ |
| **de** | 1109 | ~64 | Çoğu özel isim / marka / loanword (Focus Camp, London, Start…) |
| **ar** | 1109 | ~553 | ~50% gerçek Arapça; kalan EN fallback (MT kota) |

Dört dilde **anahtar kümesi tutarlı** (1109). Eksik key yok.

## (a) Bağlam hataları

| Anahtar | Eski EN | Yeni EN | DE | AR | Gerekçe |
|---|---|---|---|---|---|
| `classroomSaat` | Clock | **Hours** | Stunden | ساعات | Süre adımı (günlük hedef saat), cihaz saati değil |
| `classroomDakika` | Minute | **Minutes** | Minuten | دقائق | Aynı stepper |

`class_detail_screen` NumberStepper etiketleri bu anahtarları kullanır.

Diğer `*Saat` anahtarları (nav sekmesi `desktopSaat`, `clockSaat`, `profileSaat`…) **Clock/Uhr/ساعة** olarak bırakıldı — bağlam cihaz saati.

## (b) ar / de çeviri

- **de:** MyMemory + Google Translate (ücretsiz) ile toplu çeviri; marka adı `Focus Camp` korundu (yanlış “Konzentrationslager” temizlendi).
- **ar:** Offline sözlük + kısmi MT; **~556 anahtar Arapça harf içeriyor**. Kalan uzun cümleler / ICU plural EN olarak kaldı (ücretsiz MT IP kotası).
- ICU `{count, plural, …}` ve `{name}` yer tutucuları korunmaya çalışıldı.

### AR residual (ürün kararı)

Tam %100 ar için: ücretli MT veya insan çeviri turu (öneri: TR kaynak, ar hedef). Kalan ~553 satır çoğunlukla uzun achievement / admin / clock yardım metinleri.

## (c) Parity

```
en/tr/de/ar message keys = 1109
en − tr = 0
```

## Kanıt

- `Kodda doğrulandı`: arb + `classroomSaat` kullanımı
- `Cihazda doğrulanmalı`: Ayarlar dil DE/AR; manuel süre “Stunden/ساعات”
- gen-l10n: `flutter gen-l10n` (Windows Flutter)

## Risk

- MT kalitesi değişken; kritik ekranlar insan gözden geçirmeli
- AR yarım → dil AR seçilince karışık EN+AR görülebilir
