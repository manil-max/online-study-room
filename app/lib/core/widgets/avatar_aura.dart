/// Taçlı avatarın arkasındaki kademe renginde aura (WP-298).
///
/// Sahip kararı (2026-07-25): efekt **yalnız profil ve sosyal profil**
/// ekranında görünür, listelerde görünmez. Gerekçe teknik: liderlik/sohbet/ısı
/// tablosunda ekranda 10–20 avatar var; her birine ticker takmak
/// `p95 ≤ 16.7 ms` bütçesini gerçekten tehdit eder. Profilde tek örnek var.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Kademeye göre aura yoğunluğu; `0` → aura hiç çizilmez.
///
/// Sahip kararı: aura **altın kademede başlar** ve yukarı doğru kademe kademe
/// artar (bronz/gümüşte yok). Ayrım bilinçli: aura bir ödül sinyali, her
/// kademede aynı görünürse ödül olmaz.
///
/// ⚠️ Bu tablo **görsel** ayrımdır; XP eşikleri ve kademe→renk eşlemesi
/// (`crownRankForXp`, `tierColorFor`) buna dokunmaz.
double auraIntensityForTier(int tier) {
  switch (tier.clamp(1, 6)) {
    case 1:
    case 2:
      return 0; // bronz, gümüş
    case 3:
      return 0.45; // altın — ilk ve en hafif
    case 4:
      return 0.62; // elmas
    case 5:
      return 0.80; // zümrüt
    case 6:
    default:
      return 1.0; // immortal
  }
}

/// Işıltı noktalarının çizilmeye başladığı yoğunluk eşiği.
const double kAuraSparkThreshold = 0.75;

/// Auranın **dış yarıçapı**, taç tabanının katı olarak.
///
/// 🔴 `1.5` seçilirken ölçüldü: taç uçları merkezden `1.73 × taban` yukarıda,
/// yani aura **dikey olarak kutunun içinde kalıyor**. Yalnız yanlara taşıyor
/// (kutu yarım genişliği ~`1.04 × taban`). Bu önemli: iki ekranda da avatar bir
/// `ListView`'ın içinde ve `ListView` dikeyde kırpar — aura yukarı taşsaydı
/// listenin tepesinde kesilirdi.
const double kAuraOuterRadius = 1.5;

/// Aurayı çizen katman. Kendi ticker'ını yönetir, "hareketi azalt" açıkken
/// durur.
///
/// ⚠️ Test notu: bu katman `repeat()` ile sürekli animasyon çalıştırır, o yüzden
/// aurası açık bir avatarı içeren ağaçta **`pumpAndSettle()` asla dönmez**.
/// Testte ya `MediaQuery(disableAnimations: true)` ile sarmalanır ya da
/// `pump(Duration)` kullanılır.
class AvatarAuraLayer extends StatefulWidget {
  const AvatarAuraLayer({
    super.key,
    required this.color,
    required this.intensity,
    required this.base,
    required this.center,
  });

  final Color color;

  /// `auraIntensityForTier` çıktısı (0–1).
  final double intensity;

  /// Taç geometrisinin taban yarıçapı (avatar + halka).
  final double base;

  /// Avatar merkezinin bu katmanın kutusundaki konumu.
  final Offset center;

  @override
  State<AvatarAuraLayer> createState() => _AvatarAuraLayerState();
}

class _AvatarAuraLayerState extends State<AvatarAuraLayer>
    with SingleTickerProviderStateMixin {
  // Uzun devir bilinçli: aura fark edilir ama dikkat çekmez. Kısa devirde
  // profil ekranı huzursuz görünüyor.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
      // Durağan hâlde de aura görünür kalır; hoş bir faza sabitlenir.
      _controller.value = 0.15;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intensity <= 0) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: AvatarAuraPainter(
          color: widget.color,
          intensity: widget.intensity,
          base: widget.base,
          center: widget.center,
          t: _controller.value,
        ),
      ),
    );
  }
}

/// Auranın tek çizim noktası.
///
/// Üç katman: (1) nefes alan hâle, (2) farklı hızlarda dönen üç sis kuşağı,
/// (3) yalnız üst kademelerde yörüngedeki ışıltı noktaları.
///
/// ⚠️ Bilinçli olarak **`MaskFilter.blur` ve özel shader kullanılmadı.** Yumuşak
/// görünüm, her kuşağı iki geçişte (geniş+soluk / dar+parlak) çizip
/// `SweepGradient` ile uçlarını söndürerek elde ediliyor. Blur filtresi daha
/// güzel bir sis verirdi ama ölçülemeyen bir GPU maliyeti ve shader derleme
/// riski getiriyordu; kartın `p95 ≤ 16.7 ms` bütçesi cihazsız doğrulanamıyor.
class AvatarAuraPainter extends CustomPainter {
  AvatarAuraPainter({
    required this.color,
    required this.intensity,
    required this.base,
    required this.center,
    required this.t,
  });

  final Color color;
  final double intensity;
  final double base;
  final Offset center;

  /// Animasyon fazı, 0–1.
  final double t;

  /// Sis kuşakları: yarıçap çarpanı · yay genişliği (°) · devir hızı · faz ·
  /// alfa · kalınlık. Hızlar **birbirinin katı değil** ve biri ters yönde —
  /// aksi hâlde üçü kilitli görünüp tek bir halka gibi dönüyor.
  static const List<_Wisp> _wisps = <_Wisp>[
    _Wisp(1.14, 150, 1.00, 0.00, 0.34, 0.085),
    _Wisp(1.28, 120, -0.62, 0.37, 0.26, 0.070),
    _Wisp(1.42, 95, 0.38, 0.71, 0.18, 0.055),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final i = intensity;
    // Nefes: yoğunluk hafifçe salınır, konum değişmez.
    final pulse = 0.86 + 0.14 * math.sin(t * 2 * math.pi);

    final outer = base * kAuraOuterRadius;
    final haloRect = Rect.fromCircle(center: center, radius: outer);
    canvas.drawCircle(
      center,
      outer,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.26 * i * pulse),
            color.withValues(alpha: 0.10 * i * pulse),
            color.withValues(alpha: 0),
          ],
          // İlk durak avatarın kenarında: hâle avatarın altından değil,
          // kenarından dışarı doğru açılıyor.
          stops: const <double>[0.62, 0.80, 1.0],
        ).createShader(haloRect),
    );

    for (final wisp in _wisps) {
      _paintWisp(canvas, wisp, i, pulse);
    }

    if (i >= kAuraSparkThreshold) {
      _paintSparks(canvas, i, pulse);
    }
  }

  void _paintWisp(Canvas canvas, _Wisp wisp, double i, double pulse) {
    final radius = base * wisp.radius;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = wisp.sweepDeg * math.pi / 180.0;
    final start = (t * wisp.speed + wisp.phase) * 2 * math.pi;
    final width = base * wisp.width;

    // Geniş+soluk geçiş kenarı yumuşatır, dar+parlak geçiş çekirdeği verir.
    for (final pass in const <({double width, double alpha})>[
      (width: 2.6, alpha: 0.30),
      (width: 1.0, alpha: 1.0),
    ]) {
      final alpha = (wisp.alpha * i * pulse * pass.alpha).clamp(0.0, 1.0);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * pass.width
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: sweep,
          colors: <Color>[
            color.withValues(alpha: 0),
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.55),
            color.withValues(alpha: 0),
          ],
          stops: const <double>[0.0, 0.34, 0.62, 1.0],
          transform: GradientRotation(start),
        ).createShader(rect);
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  void _paintSparks(Canvas canvas, double i, double pulse) {
    // Üç nokta, farklı yarıçap ve hızda. Eşiğin (0.75) hemen üstünde belirsiz
    // görünmemeleri için alfa eşikten itibaren yeniden ölçekleniyor.
    final strength = ((i - kAuraSparkThreshold) / (1 - kAuraSparkThreshold))
        .clamp(0.0, 1.0);
    const sparks = <({double radius, double speed, double phase})>[
      (radius: 1.20, speed: 0.55, phase: 0.10),
      (radius: 1.36, speed: -0.44, phase: 0.52),
      (radius: 1.46, speed: 0.30, phase: 0.83),
    ];
    for (final spark in sparks) {
      final angle = (t * spark.speed + spark.phase) * 2 * math.pi;
      final r = base * spark.radius;
      final p = Offset(
        center.dx + r * math.sin(angle),
        center.dy - r * math.cos(angle),
      );
      final dotR = base * 0.030 * (0.8 + 0.2 * pulse);
      // Dış halka + parlak çekirdek: tek dolu daire "kir lekesi" gibi duruyor.
      canvas.drawCircle(
        p,
        dotR * 2.2,
        Paint()..color = color.withValues(alpha: 0.16 * strength * pulse),
      );
      canvas.drawCircle(
        p,
        dotR,
        Paint()..color = color.withValues(alpha: 0.62 * strength * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(covariant AvatarAuraPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.color != color ||
      oldDelegate.intensity != intensity ||
      oldDelegate.base != base ||
      oldDelegate.center != center;
}

@immutable
class _Wisp {
  const _Wisp(
    this.radius,
    this.sweepDeg,
    this.speed,
    this.phase,
    this.alpha,
    this.width,
  );

  final double radius;
  final double sweepDeg;
  final double speed;
  final double phase;
  final double alpha;
  final double width;
}
