# Tema-bağlama denetimi (WP-141)

**Tarih:** 2026-07-18  
**Kapsam:** `lib/features/**` hardcoded `Colors.*` / `Color(0x…)` (timer FGS/widget hariç).

## Düzeltildi (ihlal → scheme)

| Dosya | Önce | Sonra |
|---|---|---|
| `clock_widgets_screen.dart` | `Colors.green` / `Colors.orange` | `colorScheme.primary` / `tertiary` |
| `achievement_showcase.dart` tier rozet | `Colors.black87` | `colorScheme.onPrimary` |
| `report_issue_dialog.dart` iptal ikon | `Colors.white` | `colorScheme.onInverseSurface` |

## Meşru bırakıldı (yorumla işaretli)

| Dosya | Gerekçe |
|---|---|
| `custom_palette_editor.dart` | Kullanıcı renk seçici örnek palet (token değil) |
| `alarm_ringing_screen.dart` | Tam ekran alarm uyarı illustrasyonu (siyah + kırmızı glow) |
| `stopwatch_screen.dart` lap yeşil/kırmızı | En hızlı/yavaş vurgu; metin/ikon semantiği de var |
| `world_clock_screen.dart` gündüz/gece gradient | Atmosfer illustrasyonu |
| `desktop_navigation_pane.dart` `Colors.transparent` | Hover/focus şeffaflık (görünür “gri” değil) |
| `home_screen` / charts transparent | Overlay/tooltip altyapı |

## Karar bekliyor (değiştirilmedi)

- Diğer `Color(0x…)` chart/kamp ateşi/illustrasyon sabitleri — görsel yeniden tasarım riski; ürün onayı olmadan dokunulmadı.
- `core/theme/**` token yeniden yazımı — kapsam dışı.

## Kabul

- Gerekçesiz sabit **metin/ikon** gri-siyah-beyaz (taranan ihlaller): **0**
- İki tema: scheme tüketimi karanlık/aydınlıkta okunur (cihaz smoke önerilir)

## Analyze

`flutter analyze` → **0 issue**.
