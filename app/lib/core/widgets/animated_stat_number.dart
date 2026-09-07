import 'package:flutter/material.dart';

import '../theme/motion_tokens.dart';

/// İstatistik/pano kartlarındaki sayıyı eski değerden yenisine **geçirir**.
///
/// Kartlardaki sayılar oturum bitince tek karede zıplıyordu; kullanıcı neyin
/// değiştiğini göremiyordu. Burada değer sayısal olarak yumuşatılır, metin her
/// karede [format] ile yeniden üretilir — yani "1sa 30dk" gibi biçimli süreler
/// de aradan geçer.
///
/// 🔴 Canlı sayaç için **kullanılmaz**: saniyede bir değişen bir sayıyı
/// yumuşatmak gürültü üretir ve boşuna kare çizer.
///
/// 🔴 Erişilebilirlik: `MediaQuery.disableAnimations` açıkken süre sıfırdır,
/// yani değer doğrudan son hâline geçer (bkz. [MotionTokens.resolve]).
class AnimatedStatNumber extends StatelessWidget {
  const AnimatedStatNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.maxLines,
  });

  /// Geçişin hedefi (saniye, gün sayısı… — birim [format]'ın işi).
  final int value;

  /// Ara değeri kullanıcıya görünen metne çevirir.
  final String Function(int value) format;

  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // `begin` verilmez: ilk çizimde hedef değer olduğu gibi gösterilir,
      // kart açılırken sıfırdan sayma tiyatrosu yapılmaz.
      tween: Tween<double>(end: value.toDouble()),
      duration: MotionTokens.resolve(context, MotionTokens.statNumber),
      curve: MotionTokens.enter,
      builder: (context, current, _) =>
          Text(format(current.round()), style: style, maxLines: maxLines),
    );
  }
}
