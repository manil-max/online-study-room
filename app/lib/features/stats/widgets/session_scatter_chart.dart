import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/subject_providers.dart';

List<String> _months(BuildContext context) => [
  AppLocalizations.of(context).statsOca,
  AppLocalizations.of(context).statsSub,
  AppLocalizations.of(context).statsMar,
  AppLocalizations.of(context).statsNis,
  AppLocalizations.of(context).statsMay,
  AppLocalizations.of(context).statsHaz,
  AppLocalizations.of(context).statsTem,
  AppLocalizations.of(context).statsAgu,
  AppLocalizations.of(context).statsEyl,
  AppLocalizations.of(context).statsEki,
  AppLocalizations.of(context).statsKas,
  AppLocalizations.of(context).statsAra,
];

/// Oturum dağılım grafiği (scatter): son [days] gündeki her çalışma oturumu bir
/// nokta — x = gün, y = süre (dk), renk = ders. Noktaya dokununca tarih+süre ipucu.
class SessionScatterChart extends ConsumerWidget {
  const SessionScatterChart({
    super.key,
    required this.sessions,
    this.days = 30,
    this.height = 200,
  });

  final List<StudySession> sessions;
  final int days;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final months = _months(context);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];
    final colorBySubject = {for (final s in subjects) s.id: s.color};

    final now = DateTime.now();
    final startDay = dayOf(now).subtract(Duration(days: days - 1));
    final recent = sessions.where((s) => !s.day.isBefore(startDay)).toList();

    if (recent.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            AppLocalizations.of(context).statsBuDonemdeCalismaKaydin,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    Color colorOf(String? subjectId) {
      final token = colorBySubject[subjectId];
      return token != null
          ? subjectColor(token)
          : theme.colorScheme.onSurfaceVariant;
    }

    var maxMin = 0.0;
    final spots = <ScatterSpot>[];
    for (final s in recent) {
      final x = s.day.difference(startDay).inDays.toDouble();
      final y = s.durationSeconds / 60;
      if (y > maxMin) maxMin = y;
      spots.add(
        ScatterSpot(
          x,
          y,
          dotPainter: FlDotCirclePainter(
            color: colorOf(s.subjectId).withValues(alpha: 0.85),
            radius: 5,
            strokeWidth: 1,
            strokeColor: theme.colorScheme.surface,
          ),
        ),
      );
    }
    final maxY = maxMin <= 0 ? 60.0 : maxMin * 1.2;

    DateTime dateAt(double x) => startDay.add(Duration(days: x.round()));
    // Alt eksende ~3-4 tarih etiketi (dar kartta da karışmasın).
    final step = (days / 3).ceilToDouble().clamp(1, days.toDouble()).toDouble();

    return SizedBox(
      height: height,
      child: ScatterChart(
        ScatterChartData(
          scatterSpots: spots,
          minX: -0.5,
          maxX: (days - 1) + 0.5,
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) => Text(
                  '${value.round()}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: step,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i > days - 1) return const SizedBox.shrink();
                  if (i % step.round() != 0) return const SizedBox.shrink();
                  // Sağ kenara çok yakın etiketi atla (yığılmasın).
                  if (i != 0 && (days - 1 - i) < step * 0.5) {
                    return const SizedBox.shrink();
                  }
                  final d = dateAt(i.toDouble());
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${d.day} ${months[d.month - 1]}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          scatterTouchData: ScatterTouchData(
            enabled: true,
            touchTooltipData: ScatterTouchTooltipData(
              getTooltipItems: (touchedSpot) {
                final d = dateAt(touchedSpot.x);
                final mins = touchedSpot.y.round();
                final h = mins ~/ 60;
                final m = mins % 60;
                final dur = h > 0 ? '$h sa $m dk' : '$m dk';
                return ScatterTooltipItem(
                  '${d.day} ${months[d.month - 1]}\n$dur',
                  textStyle: TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
