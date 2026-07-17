import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WP-157: hedef ilerleme göstergesi (CustomPainter + scheme).
class GaugeChart extends StatelessWidget {
  const GaugeChart({
    super.key,
    required this.progress,
    this.label,
    this.size = 120,
  });

  /// 0.0–1.0+ (1.0 = %100).
  final double progress;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (progress * 100).clamp(0, 999).round();
    return Semantics(
      label: label ?? '$pct%',
      value: '$pct%',
      child: SizedBox(
        width: size,
        height: size * 0.7,
        child: CustomPaint(
          painter: _GaugePainter(
            progress: progress.clamp(0.0, 1.0),
            track: scheme.surfaceContainerHighest,
            fill: scheme.primary,
            over: scheme.tertiary,
            raw: progress,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(top: size * 0.15),
              child: Text(
                '$pct%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.track,
    required this.fill,
    required this.over,
    required this.raw,
  });

  final double progress;
  final Color track;
  final Color fill;
  final Color over;
  final double raw;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.12;
    final rect = Rect.fromLTWH(
      stroke,
      stroke,
      size.width - stroke * 2,
      size.height * 1.4 - stroke * 2,
    );
    const start = math.pi;
    const sweep = math.pi;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = raw > 1 ? over : fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, trackPaint);
    canvas.drawArc(rect, start, sweep * progress, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.raw != raw;
}
