import 'package:flutter/material.dart';

import '../../../core/theme/container_roles.dart';
import '../../../core/theme/warning_tokens.dart' show kMinSurfaceContrast;

/// Zemine göre okunurluğu **garanti** bir grafik serisi rengi üretir.
///
/// Grafik çizgisi/dilimi metin değil, kullanıcı arayüzü bileşenidir; eşik
/// [kMinSurfaceContrast]. İki katman:
///  1. Açıklık zeminin parlaklığından seçilir (koyu zeminde açık, açıkta koyu).
///  2. Sonuç [ensureContrast] ile eşiğe kilitlenir — tek başına açıklık yetmez,
///     çünkü sarı ile mavi aynı HSL açıklığında çok farklı luminance taşır.
///
/// Ton (`hue`) hiç değiştirilmez: seriler birbirinden **tonla** ayrılır, yani
/// eşiğe kilitleme iki seriyi aynı renge çökertmez.
Color chartSeriesColor({
  required Color surface,
  required double hue,
  double saturation = 0.70,
}) {
  final lightness = surface.computeLuminance() > 0.4 ? 0.38 : 0.64;
  return ensureContrast(
    background: surface,
    preferred: HSLColor.fromAHSL(1, hue % 360, saturation, lightness).toColor(),
    minRatio: kMinSurfaceContrast,
  );
}

/// WP-157: erişilebilir seri renkleri.
/// Yalnız renge dayanma: her seri indeksi için [patternLabel] kullan.
///
/// 🔴 WP-627: eski sürüm 8 rengi doğrudan `ColorScheme` rollerinden alıyordu
/// (`primary`, `tertiary`, `secondary`, `error`, `primaryContainer`, …). O
/// rollerin yarısı tanımsız olduğu için Flutter fallback'i onları ana renklere
/// düşürüyordu: **8 "farklı" seriden gerçekte 4'ü farklıydı**, üstelik açık
/// temada 8 renkten 5'i yüzeye karşı 3.0 altındaydı.
///
/// Yeni kural: tonlar temanın **birincil renginden başlayarak** renk çemberine
/// eşit aralıkla yayılır. Böylece 0. seri temanın kimliğini taşır (Kamp Ateşi
/// turuncu kalır), kalanı garanti ayrık olur ve sayı 8'den fazlaya çıksa da
/// kural aynı yerde durur.
class SeriesPalette {
  const SeriesPalette(this.scheme);

  final ColorScheme scheme;

  static const _patterns = ['●', '■', '▲', '◆', '○', '□', '△', '◇'];

  /// Ayrık seri sayısı — desen sayısıyla aynı olmalı ki renk körü kullanıcı
  /// için desen eşlemesi de tekil kalsın.
  static int get seriesCount => _patterns.length;

  Color colorAt(int index) {
    final anchor = HSLColor.fromColor(scheme.primary).hue;
    final step = 360 / seriesCount;
    return chartSeriesColor(
      surface: scheme.surface,
      hue: anchor + step * (index % seriesCount),
    );
  }

  String patternLabel(int index) => _patterns[index % _patterns.length];

  /// Etiket + renk: "● Matematik"
  String labeled(int index, String name) => '${patternLabel(index)} $name';
}
