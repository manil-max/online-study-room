# AR / DE dil paketleri — kalite notu (WP-155 / WP-166)

## Durum

- `app_ar.arb` ve `app_de.arb` **İngilizce baseline** kopyasıdır (makine/iske iskelet).
- Bu, **tam insan çevirisi değildir**.
- EN/TR üretim dilleri olarak korunur ve regresyon testleriyle doğrulanır.
- RTL altyapısı Arapça locale için aktiftir (`Directionality` RTL); metin kalitesi ayrı iştir.

## Sahip aksiyonu

1. Profesyonel AR çeviri turu  
2. Profesyonel DE çeviri turu  
3. Çeviri sonrası `flutter gen-l10n` + UI smoke (RTL cihaz)

## İşaretleme

Mağaza / sürüm notlarında AR/DE için “tam dil desteği” iddiası **yapma** ta ki çeviri turu bitsin.
