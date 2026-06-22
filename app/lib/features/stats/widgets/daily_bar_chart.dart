import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/stats/study_stats.dart';

const _kMonths = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];

/// Kısa süre etiketi (çubuk üstü): "1s 30d", "45d", "" (boş gün).
String _short(int seconds) {
  if (seconds <= 0) return '';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return m > 0 ? '${h}s ${m}d' : '${h}s';
  if (m > 0) return '${m}d';
  return '${seconds}sn';
}

/// Günlük çalışma süresi çubuk grafiği (y: dakika). Süre **her zaman** çubuğun
/// üstünde; alt eksende tarih ay adıyla ("21 Haz"). [goalSeconds] verilirse günlük
/// hedef **kesikli çizgiyle** gösterilir; hedefi tutturan günler renkli, tutmayanlar
/// gri çizilir.
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({super.key, required this.days, this.goalSeconds});

  final List<DayTotal> days;
  final int? goalSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasGoal = goalSeconds != null && goalSeconds! > 0;
    final goalMin = hasGoal ? goalSeconds! / 60 : 0.0;
    final maxSeconds =
        days.fold<int>(0, (m, d) => d.seconds > m ? d.seconds : m);
    final maxMinutes = maxSeconds / 60;
    var maxY = maxMinutes <= 0 ? 60.0 : maxMinutes * 1.32;
    if (hasGoal && goalMin * 1.12 > maxY) maxY = goalMin * 1.12;
    final dense = days.length > 10;

    final reachedColor = theme.colorScheme.primary;
    final missedColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    Color barColor(int seconds) {
      if (!hasGoal) return reachedColor;
      return seconds >= goalSeconds! ? reachedColor : missedColor;
    }

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceBetween,
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (hasGoal)
              HorizontalLine(
                y: goalMin,
                color: theme.colorScheme.secondary,
                strokeWidth: 1.5,
                dashArray: const [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  // Sol üstte: sağdaki çubuk/etiketlerle çakışmasın.
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.only(left: 2, bottom: 1),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w700),
                  labelResolver: (_) => 'Hedef',
                ),
              ),
          ],
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 2,
            getTooltipItem: (group, _, rod, _) {
              final label = _short(days[group.x].seconds);
              if (label.isEmpty) return null;
              return BarTooltipItem(
                label,
                theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: dense ? 9 : 11,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) {
                  return const SizedBox.shrink();
                }
                if (dense && i % 3 != 0) return const SizedBox.shrink();
                final d = days[i].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${d.day}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          )),
                      Text(_kMonths[d.month - 1],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 9,
                            height: 1.1,
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              showingTooltipIndicators:
                  days[i].seconds > 0 ? const [0] : const [],
              barRods: [
                BarChartRodData(
                  toY: days[i].seconds / 60,
                  color: barColor(days[i].seconds),
                  width: dense ? 8 : 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
