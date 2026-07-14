import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../camp_critter.dart' show Ember, StoneFirePainter;
import 'campfire_activity.dart';
import 'campfire_assets.dart';

/// WP-62: PNG katmanlı kamp ateşi.
///
/// Asset yüklenemezse [StoneFirePainter] fallback. reduce-motion'da alev/duman
/// salınımı ve köz parçacıkları statik kalır (sürekli ticker üst sahnede
/// zaten durdurulur).
class LayeredCampfireFire extends StatelessWidget {
  const LayeredCampfireFire({
    super.key,
    required this.t,
    required this.studyingCount,
    required this.embers,
    required this.cx,
    required this.fireY,
    required this.reduceMotion,
  });

  final double t;
  final int studyingCount;
  final List<Ember> embers;
  final double cx;
  final double fireY;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final activity = campfireActivityFor(studyingCount);
    final intensity = campfireIntensityFor(studyingCount);
    // Ateş paketi ~ sahne yüksekliğine orantılı; merkez fireY.
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            (math.min(constraints.maxWidth, constraints.maxHeight) * 0.42)
                .clamp(120.0, 220.0);
        final left = cx - side / 2;
        final top = fireY - side * 0.52;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              top: top,
              width: side,
              height: side,
              child: _LayerStack(
                t: t,
                activity: activity,
                intensity: intensity,
                reduceMotion: reduceMotion,
                embers: embers,
                fallback: CustomPaint(
                  size: Size(side, side),
                  painter: StoneFirePainter(
                    t: t,
                    intensity: intensity,
                    embers: embers,
                    cx: side / 2,
                    fireY: side * 0.52,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LayerStack extends StatefulWidget {
  const _LayerStack({
    required this.t,
    required this.activity,
    required this.intensity,
    required this.reduceMotion,
    required this.embers,
    required this.fallback,
  });

  final double t;
  final CampfireActivity activity;
  final double intensity;
  final bool reduceMotion;
  final List<Ember> embers;
  final Widget fallback;

  @override
  State<_LayerStack> createState() => _LayerStackState();
}

class _LayerStackState extends State<_LayerStack> {
  /// Herhangi bir zorunlu katman fail olursa tüm stack vektöre düşer.
  bool _useFallback = false;

  void _onAssetFailed() {
    if (!_useFallback && mounted) {
      setState(() => _useFallback = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useFallback) return widget.fallback;

    final a = widget.activity;
    final t = widget.reduceMotion ? 0.55 : widget.t;
    final flick = math.sin(t * 2 * math.pi);
    final flick2 = math.sin(t * 2 * math.pi * 1.7 + 1.1);

    final glowOp = switch (a) {
      CampfireActivity.empty => 0.28,
      CampfireActivity.low => 0.55 + flick.abs() * 0.08,
      CampfireActivity.high => 0.85 + flick.abs() * 0.12,
    };
    final flameOp = switch (a) {
      CampfireActivity.empty => 0.12,
      CampfireActivity.low => 0.62 + flick * 0.06,
      CampfireActivity.high => 0.92 + flick * 0.05,
    }.clamp(0.0, 1.0);
    final smokeOp = switch (a) {
      CampfireActivity.empty => 0.0,
      CampfireActivity.low => 0.22,
      CampfireActivity.high => 0.45 + flick2.abs() * 0.08,
    };
    final coalsOp = switch (a) {
      CampfireActivity.empty => 0.9,
      CampfireActivity.low => 0.55,
      CampfireActivity.high => 0.35,
    };

    final flameScaleY = a == CampfireActivity.empty
        ? 0.92
        : (widget.reduceMotion ? 1.0 : 0.96 + flick.abs() * 0.08);
    final smokeDy = widget.reduceMotion
        ? 0.0
        : -6.0 * flick2.abs() - (a == CampfireActivity.high ? 4.0 : 0.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        _png(CampfireAssets.ground, 1),
        _png(CampfireAssets.glow, glowOp),
        _png(CampfireAssets.stones, 1),
        _png(CampfireAssets.wood, 1),
        _png(CampfireAssets.coals, coalsOp),
        Transform.scale(
          scaleY: flameScaleY,
          alignment: Alignment.bottomCenter,
          child: _png(CampfireAssets.flameBack, flameOp * 0.85),
        ),
        Transform.scale(
          scaleY: flameScaleY * 1.02,
          alignment: Alignment.bottomCenter,
          child: _png(CampfireAssets.flameMid, flameOp),
        ),
        Transform.scale(
          scaleY: flameScaleY * 1.04,
          alignment: Alignment.bottomCenter,
          child: _png(
            CampfireAssets.flameFront,
            flameOp * 1.05 > 1 ? 1 : flameOp * 1.05,
          ),
        ),
        if (smokeOp > 0.01)
          Transform.translate(
            offset: Offset(flick * 3, smokeDy),
            child: _png(CampfireAssets.smoke, smokeOp),
          ),
        if (a == CampfireActivity.high && !widget.reduceMotion)
          CustomPaint(
            painter: _EmberSpritePainter(
              t: t,
              embers: widget.embers,
              intensity: widget.intensity,
            ),
          ),
      ],
    );
  }

  Widget _png(String asset, double opacity) {
    final o = opacity.clamp(0.0, 1.0);
    if (o <= 0.01) return const SizedBox.shrink();
    return Opacity(
      opacity: o,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          // setState build sırasında olmasın.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onAssetFailed();
          });
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

/// Köz parçacıkları — küçük daire (ember_sheet decode maliyeti yok; sheet
/// asset smoke ile doğrulanır, runtime'da hafif painter).
class _EmberSpritePainter extends CustomPainter {
  _EmberSpritePainter({
    required this.t,
    required this.embers,
    required this.intensity,
  });

  final double t;
  final List<Ember> embers;
  final double intensity;

  static const _ember = Color(0xFFFFA028);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseY = size.height * 0.58;
    final riseTop = size.height * 0.12;
    final riseSpan = baseY - riseTop;
    for (final e in embers) {
      final prog = (t * e.speed + e.phase) % 1.0;
      final y = baseY - prog * riseSpan;
      final swayX = math.sin(prog * math.pi * 3 + e.phase * 6) * 14 * e.sway;
      final x = cx + e.xOffset * (size.width * 0.12) + swayX;
      final alpha = ((1 - prog) * intensity).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        e.size * (1 - prog * 0.5),
        Paint()..color = _ember.withValues(alpha: alpha * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmberSpritePainter old) =>
      old.t != t || old.intensity != intensity;
}
