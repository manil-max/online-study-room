import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/app_prefs.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/anchored_menu.dart';

/// Saat (sayaç) görünüm stilleri (§3.12). Varsayılan sade; isteyen değiştirir.
/// Şimdilik seçim bellek-içi (uygulama yenilenince sıfırlanır) — kalıcılık sonra.
enum ClockStyle {
  /// Sade rakam (varsayılan).
  digits,

  /// Günlük hedefe göre dolan halka + ortada süre.
  ring,

  /// Hedefe yaklaştıkça rakam rengi zıt→yeşil döner.
  colorShift,

  /// Pasta dilimi gibi dolan yarış stili.
  slice,

  /// Çok ince çizgi stili (minimal/neon esintili).
  minimal,
}

extension ClockStyleInfo on ClockStyle {
  String label(BuildContext context) => switch (this) {
    ClockStyle.digits => AppLocalizations.of(context).classroomSadeRakam,
    ClockStyle.ring => AppLocalizations.of(context).classroomHedefHalkasi,
    ClockStyle.colorShift => AppLocalizations.of(context).classroomRenkGecisi,
    ClockStyle.slice => AppLocalizations.of(context).classroomYarisDilimi,
    ClockStyle.minimal => AppLocalizations.of(context).classroomMinimal,
  };

  IconData get icon => switch (this) {
    ClockStyle.digits => Icons.schedule,
    ClockStyle.ring => Icons.donut_large,
    ClockStyle.colorShift => Icons.gradient,
    ClockStyle.slice => Icons.pie_chart,
    ClockStyle.minimal => Icons.trip_origin,
  };
}

class ClockStyleNotifier extends Notifier<ClockStyle> {
  static const _key = 'clock_style';

  @override
  ClockStyle build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return ClockStyle.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ClockStyle.digits,
    );
  }

  void set(ClockStyle style) {
    state = style;
    ref.read(sharedPreferencesProvider).setString(_key, style.name);
  }
}

/// Seçili saat stili (kişiye özel, cihazda kalıcı).
final clockStyleProvider = NotifierProvider<ClockStyleNotifier, ClockStyle>(
  ClockStyleNotifier.new,
);

/// Hedefe göre renk: 0 → kırmızı (chart-5), 0.5 → amber (chart-3),
/// 1.0 → yeşil (chart-2). Aradaki değerler yumuşak geçişli.
Color goalColor(double pct) {
  final p = pct.clamp(0.0, 1.0);
  final red = subjectColor('chart-5');
  final amber = subjectColor('chart-3');
  final green = subjectColor('chart-2');
  if (p <= 0.5) return Color.lerp(red, amber, p / 0.5)!;
  return Color.lerp(amber, green, (p - 0.5) / 0.5)!;
}

/// Seçili stile göre canlı süreyi gösteren saat. [seconds] gösterilecek süre
/// (genelde mevcut oturum), [pctToGoal] bugünkü toplamın günlük hedefe oranı.
class StudyClock extends StatelessWidget {
  const StudyClock({
    super.key,
    required this.seconds,
    required this.pctToGoal,
    required this.running,
    required this.style,
    required this.fontSize,
    this.diameter = 220,
  });

  final int seconds;
  final double pctToGoal;
  final bool running;
  final ClockStyle style;
  final double fontSize;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = formatHms(seconds);

    switch (style) {
      case ClockStyle.digits:
        return _digits(
          text,
          fontSize,
          running
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        );
      case ClockStyle.colorShift:
        return _digits(text, fontSize, goalColor(pctToGoal));
      case ClockStyle.ring:
        return SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: pctToGoal.clamp(0.0, 1.0),
                  strokeWidth: 9,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    goalColor(pctToGoal),
                  ),
                ),
              ),
              _digits(
                text,
                fontSize * 0.72,
                running
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ],
          ),
        );
      case ClockStyle.slice:
        return SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CustomPaint(
                  painter: ClockPainter(
                    pctToGoal: pctToGoal.clamp(0.0, 1.0),
                    color: goalColor(pctToGoal),
                    bgColor: theme.colorScheme.surfaceContainerHighest,
                    isSlice: true,
                  ),
                ),
              ),
              // Dilim dolu olduğundan yazının arkasında daha belirgin görünmesi için gölge veya zıt renk gerekebilir,
              // şimdilik primary veya onSurface kullanıyoruz.
              _digits(
                text,
                fontSize * 0.72,
                running
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        );
      case ClockStyle.minimal:
        return SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CustomPaint(
                  painter: ClockPainter(
                    pctToGoal: pctToGoal.clamp(0.0, 1.0),
                    color: goalColor(pctToGoal),
                    bgColor: theme.colorScheme.surfaceContainerHighest,
                    isSlice: false,
                  ),
                ),
              ),
              _digits(
                text,
                fontSize * 0.72,
                running
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ],
          ),
        );
    }
  }

  Widget _digits(String text, double size, Color color) {
    return Text(
      text,
      maxLines: 1,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1,
        // Sabit genişlikli rakamlar: süre değişirken sayılar zıplamasın/oynamasın.
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Saat stili seçici (anchored menü — §3.12 "basılan yerde" kalıbı).
Future<void> showClockStyleMenu(BuildContext context, WidgetRef ref) async {
  final theme = Theme.of(context);
  final current = ref.read(clockStyleProvider);
  final result = await showAnchoredMenu<ClockStyle>(
    context: context,
    items: [
      PopupMenuItem<ClockStyle>(
        enabled: false,
        height: 32,
        child: Text(
          AppLocalizations.of(context).classroomSaatGorunumu,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      for (final s in ClockStyle.values)
        PopupMenuItem<ClockStyle>(
          value: s,
          child: Row(
            children: [
              Icon(s.icon, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(s.label(context))),
              if (s == current)
                Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
            ],
          ),
        ),
    ],
  );
  if (result != null) ref.read(clockStyleProvider.notifier).set(result);
}

class ClockPainter extends CustomPainter {
  ClockPainter({
    required this.pctToGoal,
    required this.color,
    required this.bgColor,
    required this.isSlice,
  });

  final double pctToGoal;
  final Color color;
  final Color bgColor;
  final bool isSlice;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width < size.height ? size.width / 2 : size.height / 2;

    if (isSlice) {
      // Pasta dilimi / yarış stili
      final bgPaint = Paint()
        ..color = bgColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, bgPaint);

      final slicePaint = Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      // -pi/2'den (saat 12) başla, 2*pi * pctToGoal kadar dön
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.57079632679, // -math.pi / 2
        6.28318530718 * pctToGoal, // 2 * math.pi * pctToGoal
        true,
        slicePaint,
      );
    } else {
      // Minimal stil - ekstra ince çizgi
      final bgPaint = Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, bgPaint);

      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.57079632679,
        6.28318530718 * pctToGoal,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ClockPainter oldDelegate) {
    return pctToGoal != oldDelegate.pctToGoal ||
        color != oldDelegate.color ||
        bgColor != oldDelegate.bgColor ||
        isSlice != oldDelegate.isSlice;
  }
}
