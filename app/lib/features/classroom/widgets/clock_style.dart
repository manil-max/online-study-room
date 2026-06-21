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
}

extension ClockStyleInfo on ClockStyle {
  String get label => switch (this) {
        ClockStyle.digits => 'Sade rakam',
        ClockStyle.ring => 'Hedef halkası',
        ClockStyle.colorShift => 'Renk geçişi',
      };

  IconData get icon => switch (this) {
        ClockStyle.digits => Icons.schedule,
        ClockStyle.ring => Icons.donut_large,
        ClockStyle.colorShift => Icons.gradient,
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
final clockStyleProvider =
    NotifierProvider<ClockStyleNotifier, ClockStyle>(ClockStyleNotifier.new);

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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(goalColor(pctToGoal)),
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
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        fontFeatures: const [],
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
          'Saat görünümü',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
      for (final s in ClockStyle.values)
        PopupMenuItem<ClockStyle>(
          value: s,
          child: Row(
            children: [
              Icon(s.icon, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(s.label)),
              if (s == current)
                Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
            ],
          ),
        ),
    ],
  );
  if (result != null) ref.read(clockStyleProvider.notifier).set(result);
}
