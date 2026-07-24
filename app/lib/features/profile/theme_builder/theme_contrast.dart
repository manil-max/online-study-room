import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG 2.1 kontrast yardımcıları — saf fonksiyon, widget bağımlılığı yok.
///
/// Sihirbazın renk adımı bu değerleri kullanarak AA altı seçimde uyarı gösterir
/// ve tek dokunuşla düzeltme önerir. Kaydetme **engellenmez** (WP-290 kabul).

/// Normal metin için AA eşiği.
const double kContrastAaNormal = 4.5;

/// Büyük metin (≥ 18 pt / 14 pt kalın) için AA eşiği.
const double kContrastAaLarge = 3.0;

/// [value] 0.0–1.0 aralığında tek kanal (Flutter 3.27+ `Color.r/g/b`).
double _channel(double value) {
  return value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
}

/// WCAG bağıl parlaklık (0 = siyah, 1 = beyaz).
double relativeLuminance(Color color) {
  return 0.2126 * _channel(color.r) +
      0.7152 * _channel(color.g) +
      0.0722 * _channel(color.b);
}

/// İki renk arasındaki kontrast oranı (1.0 – 21.0).
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Ön plan rengi arka planda AA'yı geçiyor mu?
bool meetsContrastAa(Color foreground, Color background, {bool large = false}) {
  final threshold = large ? kContrastAaLarge : kContrastAaNormal;
  // Kayan nokta yuvarlamasında sınırda kalan seçimler kabul edilir.
  return contrastRatio(foreground, background) >= threshold - 0.001;
}

/// AA'yı geçen en yakın ön plan rengi.
///
/// Rengin tonunu koruyup HSL parlaklığını arka planın ters yönüne doğru adım
/// adım iter; hiçbir adım yetmezse saf siyah/beyazdan uygun olanı döner.
Color fixForegroundForAa(
  Color foreground,
  Color background, {
  bool large = false,
}) {
  if (meetsContrastAa(foreground, background, large: large)) return foreground;

  final hsl = HSLColor.fromColor(foreground);
  // Arka plan koyuysa ön planı aydınlat, açıksa karart.
  final towardsLight = relativeLuminance(background) < 0.5;
  for (var step = 1; step <= 20; step++) {
    final delta = step * 0.05;
    final lightness = (towardsLight ? hsl.lightness + delta : hsl.lightness - delta)
        .clamp(0.0, 1.0);
    final candidate = hsl.withLightness(lightness).toColor();
    if (meetsContrastAa(candidate, background, large: large)) return candidate;
  }
  final white = const Color(0xFFFFFFFF);
  final black = const Color(0xFF000000);
  return contrastRatio(white, background) >= contrastRatio(black, background)
      ? white
      : black;
}

/// Zemin üstünde okunaklı bir "üzerinde" rengi (buton yazısı vb.).
Color readableOn(Color background) {
  final white = const Color(0xFFFFFFFF);
  final black = const Color(0xFF000000);
  return contrastRatio(white, background) >= contrastRatio(black, background)
      ? white
      : black;
}
