# Windows Desktop UI R3 — Masaüstü kabuk ve görsel dil (WP-71)

> **Amaç:** PC/laptop’ta “büyütülmüş mobil app” hissini bırakmak.  
> **Referanslar (sentez, kopya değil):** Microsoft WinUI 3 NavigationView + Fluent 2; Apple macOS HIG sidebars.  
> **Kapsam:** Sol navigasyon pane, yoğunluk tokenları, sayfa başlığı, master-detail seçim dili.  
> **Mobil:** alt `NavigationBar` / yuvarlak dil **dokunulmaz**.

## Araştırma özeti (birincil kaynaklar)

### WinUI NavigationView ([MS Learn](https://learn.microsoft.com/en-us/windows/apps/design/controls/navigationview))

| Kural | Değer / davranış |
|---|---|
| Auto adaptif | **Left** ≥1008 · **LeftCompact** 641–1007 · **LeftMinimal** ≤640 |
| Sol pane anatomisi | Menu (toggle) · MenuItems · FooterMenuItems · **Settings** altta |
| Seçim | Sol kenarda selection indicator; tek seçim modeli |
| İçerik margin | Minimal ~**12px**, aksi ~**24px** |
| Header | ~**52px** sabit yükseklik hissi; sayfa başlığı |

Odak Kampı uyarlaması:

- 5 ana sekme → her zaman erişilebilir (minimal’de bile **compact ikon şeridi**, tamamen gizli hamburger yok — ürün tercihi: “her zaman tüm kategoriler”).
- Settings = pane footer (WinUI `IsSettingsVisible` karşılığı), profil sekmesinden ayrı.
- Compact Focus / pin / yenile = ek footer araçları (PaneFooter).

### Fluent 2

- Düşük elevation, 1px outline, **keskin köşe (2–8)**.
- Hover: düşük alpha yüzey; seçili: secondaryContainer + primary accent bar.
- Mobil “pill” (16–28 radius) **yasak** desktop shell’de.

### macOS HIG sidebar

- Dar, sakin liste; abartısız header.
- Seçim arka planı düz / soft fill, süs yok.
- İçerik alanı dolu; chrome az.

## Mimari (kod)

| Bileşen | Dosya | Rol |
|---|---|---|
| `DesktopNavigationPane` | `features/desktop/desktop_navigation_pane.dart` | Custom sol pane (NavigationRail **değil**) |
| `DesktopHomeShell` | `features/desktop/desktop_home_shell.dart` | Kabuk: pane + IndexedStack + kısayollar |
| `DesktopSurface` | `features/desktop/desktop_surface.dart` | Panel/dialog/okuma genişliği (mobil full-bleed yok) |
| `DesktopDensity` | `features/desktop/desktop_page_scaffold.dart` | Radius 4–8, padding 12–24, commandHeight 36–40 |
| `DesktopSectionList` | aynı | Master list: sol accent + radius 4 |
| Breakpoints | `core/desktop/desktop_layout.dart` | 640 / 1008 (MS eşikleri) |

### Panel kuralı (masaüstü)

- Ayarlar / Görünüm / kayıtlar → `showDesktopPanel` (~920×680, iç Navigator)
- Kart ekle → `showDesktopPicker` (dialog, 2–3 sütun)
- Tema Stüdyosu → sol kontroller + sağ sabit önizleme (≥720)
- Profil / ayar listeleri → `DesktopReadingBody` max ~760–880 (ekranı yırtmaz)

### Pane ölçüleri

| Mod | Genişlik | Etiket |
|---|---|---|
| Expanded (≥1008) | **248** | ikon + metin |
| Compact / Minimal | **52** | yalnız ikon + tooltip |

### Etkileşim

- Hover / focus / selected durumları ayrı.
- Sol **3px** primary selection bar (WinUI left indicator).
- Ctrl+1…5 sekmeler · Ctrl+, Ayarlar · F5 yenile · Ctrl+Shift+M/P compact/pin.

### Tema (R3 fix, korunur)

“Hazır palet” (`ThemeColorSource.palette`) aileyi `campfire`’a zorlamaz → **lacivert navy mavi kalır**.

## Kasıtlı “yapmadıklarımız”

- Sağ context panelleri (küçük pencerede boğuyordu) — kapalı.
- NavigationRail stil makyajı — yetersizdi; kaldırıldı.
- Top navigation (WinUI Top mode) — 5 sekme için sol daha doğru.
- Mobil bottom bar’ı Windows’a taşımak — hayır.

## Kanıt

| Etiket | Ne |
|---|---|
| Araştırma | Bu dosya + MS Learn NavigationView |
| Kod | `desktop_navigation_pane.dart`, shell, density, section list |
| Otomatik test | `desktop_home_shell_test.dart` (expanded/compact/minimal/tap/keys) |
| Cihaz | `Cihazda doğrulanmalı` — Windows’ta resize + navy palet |

## Cihaz smoke (kullanıcı)

1. `flutter run -d windows --dart-define-from-file=env.json` (`app/`)
2. ≥1008: sol pane etiketli, Ayarlar altta metinli.
3. ~800: ikon şeridi, tooltip, içerik alanı geniş.
4. Sekme tık + Ctrl+3 vb.
5. Tema Stüdyosu → lacivert palet → shell **mavi** (turuncu aileye kayma yok).
