import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';

/// WP-290: `AppFeel` + `AppAtmosphere` token'larının **render katmanı**.
///
/// WP-288 bu iki katmanı modelledi ve `ThemeData.extensions`'a ekledi ama
/// uygulamada hiçbir tüketicisi yoktu; sihirbazın "atmosfer" ve "his" adımları
/// bu sarmalayıcı olmadan ölü anahtar olurdu (`AGENTS.md §3` DoD).
///
/// Çizim **statiktir** — animasyon yoktur, dolayısıyla "hareketi azalt" ayarı
/// altında durdurulacak bir hareket de yoktur. Hiçbir efekt açık değilse
/// (`grainStrength`, `glowStrength`, `glassOpacity` hepsi 0) child **olduğu
/// gibi** döner: Modern/Düz hislerde tek ek widget bile eklenmez.
class FeelOverlay extends StatelessWidget {
  const FeelOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feel = theme.extension<AppFeel>();
    final atmosphere = theme.extension<AppAtmosphere>();
    if (feel == null || atmosphere == null) return child;

    final spec = FeelOverlaySpec(
      feelId: feel.feelId,
      grainStrength: feel.grainStrength,
      grainKind: feel.grainKind,
      gradientStart: atmosphere.gradientStart,
      gradientEnd: atmosphere.gradientEnd,
      glowColor: atmosphere.glowColor,
      glowStrength: atmosphere.glowStrength,
      blurSigma: atmosphere.blurSigma,
      glassOpacity: atmosphere.glassOpacity,
    );
    if (!spec.paintsAnything) return child;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: FeelOverlayPainter(spec),
                isComplex: true,
                willChange: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Çizim parametreleri — eşitlik karşılaştırması `shouldRepaint` için.
@immutable
class FeelOverlaySpec {
  const FeelOverlaySpec({
    required this.feelId,
    required this.grainStrength,
    required this.grainKind,
    required this.gradientStart,
    required this.gradientEnd,
    required this.glowColor,
    required this.glowStrength,
    required this.blurSigma,
    required this.glassOpacity,
  });

  /// WP-314: hissin **kendi** imzası. Eskiden çizim yalnız gren + atmosfer
  /// alanlarına bakıyordu; zen/neon/cam/düz hislerinin gren gücü 0 olduğu için
  /// bu dördü ancak atmosferi de ezerse görünüyordu. WP-307 o ezmeyi
  /// kapatınca his seçimi önizlemede hiçbir şey değiştirmez oldu (sahip:
  /// "feels kısmı önizlemede hiçbir şey değiştirmiyor"). Artık her hissin
  /// atmosferden bağımsız kendi çizimi var.
  final String feelId;

  final double grainStrength;
  final String grainKind;
  final Color gradientStart;
  final Color gradientEnd;
  final Color glowColor;
  final double glowStrength;
  final double blurSigma;
  final double glassOpacity;

  bool get paintsGrain => grainStrength > 0 && grainKind != 'none';
  bool get paintsGlow => glowStrength > 0;
  bool get paintsGlass => glassOpacity > 0;

  /// Hissin atmosferden bağımsız imzası. `modern` ve `flat` bilerek boştur —
  /// "efekt yok" onların kimliği (ikisi hâlâ köşe/hareket karakteriyle ayrılır).
  bool get paintsSignature => switch (feelId) {
    'neon' || 'glass' || 'zen' || 'vintage' => true,
    _ => false,
  };

  bool get paintsAnything =>
      paintsGrain || paintsGlow || paintsGlass || paintsSignature;

  @override
  bool operator ==(Object other) =>
      other is FeelOverlaySpec &&
      other.feelId == feelId &&
      other.grainStrength == grainStrength &&
      other.grainKind == grainKind &&
      other.gradientStart == gradientStart &&
      other.gradientEnd == gradientEnd &&
      other.glowColor == glowColor &&
      other.glowStrength == glowStrength &&
      other.blurSigma == blurSigma &&
      other.glassOpacity == glassOpacity;

  @override
  int get hashCode => Object.hash(
    feelId,
    grainStrength,
    grainKind,
    gradientStart,
    gradientEnd,
    glowColor,
    glowStrength,
    blurSigma,
    glassOpacity,
  );
}

class FeelOverlayPainter extends CustomPainter {
  const FeelOverlayPainter(this.spec);

  final FeelOverlaySpec spec;

  /// Gren noktası sayısı ekran alanına göre sınırlanır — düşük donanımda
  /// çizim maliyeti öngörülebilir kalsın (katalog §2 performans kuralı).
  static const _maxGrainMarks = 900;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (spec.paintsGlow) _paintGlow(canvas, size);
    if (spec.paintsGlass) _paintGlass(canvas, size);
    if (spec.paintsGrain) _paintGrain(canvas, size);
    if (spec.paintsSignature) _paintSignature(canvas, size);
  }

  /// WP-314: hissin kendi imzası — atmosfer kaydırıcıları sıfır olsa da çizilir.
  void _paintSignature(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    switch (spec.feelId) {
      case 'neon':
        // Kenarlardan içeri sızan çift renkli halo: "tüp ışık" karakteri.
        for (final (alignment, color) in [
          (Alignment.topLeft, spec.glowColor),
          (Alignment.bottomRight, spec.gradientEnd),
        ]) {
          canvas.drawRect(
            rect,
            Paint()
              ..shader = RadialGradient(
                center: alignment,
                radius: 0.9,
                colors: [
                  color.withValues(alpha: 0.30),
                  color.withValues(alpha: 0),
                ],
              ).createShader(rect),
          );
        }
        // İnce iç çerçeve — neon şeridin kendisi.
        canvas.drawRect(
          rect.deflate(1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = spec.glowColor.withValues(alpha: 0.45),
        );
      case 'glass':
        // Çapraz ışık bandı: buzlu cam üzerindeki yansıma.
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.38, 0.52, 1.0],
              colors: [
                const Color(0xFFFFFFFF).withValues(alpha: 0.16),
                const Color(0xFFFFFFFF).withValues(alpha: 0.02),
                const Color(0xFFFFFFFF).withValues(alpha: 0.20),
                const Color(0xFFFFFFFF).withValues(alpha: 0.0),
              ],
            ).createShader(rect),
        );
      case 'zen':
        // Yumuşak vinyet: kenarlar geri çekilir, göz ortaya toplanır.
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              radius: 0.85,
              colors: [
                const Color(0x00000000),
                const Color(0xFF000000).withValues(alpha: 0.18),
              ],
            ).createShader(rect),
        );
      case 'vintage':
        // Sıcak solma + ağır vinyet: eski baskı hissi.
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              radius: 0.9,
              colors: [
                const Color(0x14D9A441),
                const Color(0xFF2B1A05).withValues(alpha: 0.26),
              ],
            ).createShader(rect),
        );
    }
  }

  void _paintGlow(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Degrade: atmosferin iki ucu düşük alfayla tüm ekrana ince bir renk
    // karakteri verir (opak zeminleri boğmadan).
    final tint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          spec.gradientStart.withValues(alpha: 0.16 * spec.glowStrength),
          spec.gradientEnd.withValues(alpha: 0.16 * spec.glowStrength),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, tint);

    // Parıltı: üstten radial. `blurSigma` yumuşaklığı belirler.
    final radius = size.shortestSide * (0.7 + spec.blurSigma / 40);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          spec.glowColor.withValues(alpha: 0.22 * spec.glowStrength),
          spec.glowColor.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.08),
          radius: radius,
        ),
      );
    canvas.drawRect(rect, glow);
  }

  void _paintGlass(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.14 * spec.glassOpacity),
            const Color(0xFFFFFFFF).withValues(alpha: 0.02 * spec.glassOpacity),
          ],
        ).createShader(rect),
    );
  }

  void _paintGrain(Canvas canvas, Size size) {
    // Sabit tohum: aynı tema her açılışta aynı dokuyu üretir (titreme yok).
    final random = math.Random(1907);
    final alpha = 0.06 * spec.grainStrength;
    final paint = Paint()..color = const Color(0xFF000000).withValues(alpha: alpha);
    final light = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.8);

    switch (spec.grainKind) {
      case 'paper':
        // İnce yatay çizgiler + seyrek nokta: defter/kâğıt dokusu.
        final step = 6.0;
        final linePaint = Paint()
          ..color = const Color(0xFF000000).withValues(alpha: alpha * 0.5)
          ..strokeWidth = 0.6;
        for (var y = 0.0; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }
        _scatter(canvas, size, random, paint, count: _maxGrainMarks ~/ 4, dot: 0.7);
      case 'carton':
        // Kaba lif: kısa eğik çizgiler + iri nokta.
        final fiber = Paint()
          ..color = const Color(0xFF000000).withValues(alpha: alpha * 0.7)
          ..strokeWidth = 1.1;
        final count = math.min(_maxGrainMarks ~/ 2, 400);
        for (var i = 0; i < count; i++) {
          final x = random.nextDouble() * size.width;
          final y = random.nextDouble() * size.height;
          canvas.drawLine(Offset(x, y), Offset(x + 3.5, y + 1.5), fiber);
        }
        _scatter(canvas, size, random, light, count: count ~/ 2, dot: 1.2);
      case 'film':
      default:
        _scatter(canvas, size, random, paint, count: _maxGrainMarks, dot: 0.9);
        _scatter(canvas, size, random, light, count: _maxGrainMarks ~/ 3, dot: 0.8);
    }
  }

  void _scatter(
    Canvas canvas,
    Size size,
    math.Random random,
    Paint paint, {
    required int count,
    required double dot,
  }) {
    for (var i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
          dot,
          dot,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FeelOverlayPainter oldDelegate) => oldDelegate.spec != spec;
}
