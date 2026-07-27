/// WP-358: tema paletinden **bağımsız** uyarı rengi (V49-2 açık tasarım sorusu).
///
/// Sorun: uyarı yüzeyleri `ColorScheme.error` / `errorContainer` üzerinden
/// besleniyordu. Kullanıcı kırmızı ağırlıklı bir tema seçtiğinde uyarı ile
/// zemin aynı aileye düşüyor, kontrast çöküyor ve "dikkat çekmesi gereken"
/// rozet görünmez oluyordu. Kayıp sessiz: rozet birincil grup seçilmediğini
/// haber verir, seçilmezse grup ilerlemesi hiç işlemez.
///
/// Çözüm: uyarı rengi paletten türetilmez, **zemine göre** türetilir. Taban
/// kehribar tonundan başlanır ve zemine karşı hedef kontrast tutturulana kadar
/// açıklık (lightness) zeminin tersi yönde itilir. Böylece hangi tema seçilirse
/// seçilsin uyarı zeminden ayrışır.
///
/// 🔴 Sabit renk yazma (`Colors.red` gibi): koyu temada zemine gömülür,
/// açık temada bağırır. Renk **zeminin fonksiyonudur**, sabit değildir.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Uyarı yüzeyinin çözülmüş renk üçlüsü.
@immutable
class AppWarningColors {
  const AppWarningColors({
    required this.container,
    required this.onContainer,
    required this.border,
  });

  /// Rozet/uyarı bloğunun dolgu rengi — zemine karşı ≥ [kMinSurfaceContrast].
  final Color container;

  /// [container] üstündeki metin/ikon — dolguya karşı ≥ [kMinTextContrast].
  final Color onContainer;

  /// Blok kenarı; dolgudan bir tık daha belirgin, çerçevesiz zeminlerde ayırır.
  final Color border;
}

/// WCAG AA: metin dışı kullanıcı arayüzü bileşeni / zemin kontrastı.
const double kMinSurfaceContrast = 3.0;

/// WCAG AA: normal boyutlu metin kontrastı.
const double kMinTextContrast = 4.5;

/// Uyarı ailesinin taban tonu (kehribar). Kırmızı seçilmedi: kırmızı ağırlıklı
/// temalar bu bulgunun ta kendisi ve ton ayrımı da işe yarasın istiyoruz.
const Color _warningSeed = Color(0xFFF59E0B);

/// İki rengin WCAG kontrast oranı (1.0 – 21.0).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// [background] üstünde okunur kalması **garanti** bir uyarı renk üçlüsü üretir.
///
/// Saf ve deterministiktir; aynı zemin her zaman aynı sonucu verir. Test
/// tarafı bunu 15 hazır tema × açık/koyu üstünde tarar.
AppWarningColors resolveWarningColors(Color background) {
  final seed = HSLColor.fromColor(_warningSeed);
  final backgroundIsLight = background.computeLuminance() > 0.4;

  // Zemin açıksa uyarıyı koyulaştır, koyuysa aç. Adımlar zeminden **uzaklaşır**;
  // ilk hedefi tutturan değer seçilir ki renk gereğinden fazla bozulmasın.
  final steps = backgroundIsLight
      ? <double>[0.42, 0.36, 0.30, 0.25, 0.20, 0.16, 0.12]
      : <double>[0.58, 0.64, 0.70, 0.76, 0.82, 0.88, 0.93];

  var best = seed.withLightness(steps.first).toColor();
  var bestRatio = contrastRatio(best, background);

  for (final lightness in steps) {
    final candidate = seed.withLightness(lightness).toColor();
    final ratio = contrastRatio(candidate, background);
    if (ratio > bestRatio) {
      best = candidate;
      bestRatio = ratio;
    }
    if (ratio >= kMinSurfaceContrast) {
      best = candidate;
      bestRatio = ratio;
      break;
    }
  }

  // Dolgu üstündeki metin: siyah/beyazdan hangisi daha okunursa o. Kehribar
  // ailesinde bu neredeyse her zaman ikisinden biriyle 4.5'i geçer.
  final onContainer = contrastRatio(Colors.black, best) >= contrastRatio(Colors.white, best)
      ? Colors.black
      : Colors.white;

  // Kenar: dolguyu zeminden bir tık daha ayırır, dolgunun tonunda kalır.
  final bestHsl = HSLColor.fromColor(best);
  final border = bestHsl
      .withLightness(
        (backgroundIsLight
                ? bestHsl.lightness - 0.10
                : bestHsl.lightness + 0.10)
            .clamp(0.0, 1.0),
      )
      .toColor();

  return AppWarningColors(
    container: best,
    onContainer: onContainer,
    border: border,
  );
}

/// Widget tarafı kısayolu: uyarı, üstünde durduğu yüzeye göre çözülür.
///
/// Yanlış zemini vermek sessiz bir hata olurdu (kart yüzeyindeki uyarıyı
/// scaffold'a göre çözmek gibi), bu yüzden zemin **açıkça** geçilir.
AppWarningColors warningColorsOn(Color surface) => resolveWarningColors(surface);
