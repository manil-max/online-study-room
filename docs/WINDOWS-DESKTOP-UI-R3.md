# Windows Desktop UI R3 — Masaüstü görsel dil (WP-71)

> **Amaç:** PC/laptop’ta “büyütülmüş mobil app” hissini bırakmak.  
> **Referanslar (sentez, kopya değil):** Microsoft Fluent 2 / WinUI 3 NavigationView; Apple macOS HIG sidebar.  
> **Kapsam:** Sol navigasyon + shell yoğunluğu; mobil alt nav / yuvarlak “tatlı” dil korunur.

## Referans sentezi (2024–2026)

| Kaynak | Alınan ders |
|---|---|
| **WinUI NavigationView** | Sol rail/sidebar dikey; seçili öğe **dikdörtgen/hafif radius** (mobil pill değil); kompakt ikon / geniş etiket; ayırıcı çizgi; keskin yüzey ayrımı |
| **Fluent 2** | Düşük elevation, 1px outline, keskin köşeler (2–4 dp), sakin gri yüzey + vurgu rengi |
| **macOS sidebar** | Dar liste, sade seçim arka planı, başlık alanı abartısız; içerik alanı dolu |
| **Odak Kampı** | Sol rail zaten var; R2’de fazla panel/başlık kaldırıldı; R3: **köşe + indicator + rail yoğunluğu** |

## Kararlar (WP-71)

1. Desktop NavigationRail: `indicatorShape` ≈ 4–6 dp (yumuşak 16–28 değil).  
2. Leading logo kutusu: radius 4–6 (14 değil).  
3. Rail arka plan: `surfaceContainerLowest` / düşük kontrast; `VerticalDivider` net.  
4. Küçük pencere birinci sınıf: sağ bağlam paneli yok (zaten kaldırıldı).  
5. Tema: “Hazır palet” seçimi **aileyi kamp ateşine zorlamaz** (lacivert→turuncu bug).

## Kanıt etiketleri

- Araştırma sentezi: bu dosya  
- Kod: `desktop_home_shell.dart`, `theme_settings.dart`, `theme_presets.dart`, `main.dart`  
- Cihaz: `Cihazda doğrulanmalı`
