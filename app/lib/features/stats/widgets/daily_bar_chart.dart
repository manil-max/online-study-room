import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';

/// Günlük çalışma süresini çubuk grafikle gösterir (y ekseni: dakika).
/// Veri serisi eski → yeni sıralı `DayTotal` listesidir (bkz. [lastNDays]).
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({super.key, required this.days});

  final List<DayTotal> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSeconds =
        days.fold<int>(0, (m, d) => d.seconds > m ? d.seconds : m);
    // Üst boşluk için %20 pay; hiç veri yoksa 60 dk'lık nominal eksen.
    final maxMinutes = maxSeconds / 60;
    final maxY = maxMinutes <= 0 ? 60.0 : maxMinutes * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceBetween,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) {
              final d = days[group.x];
              return BarTooltipItem(
                '${d.day.day}.${d.day.month}\n${formatHuman(d.seconds)}',
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
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
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) {
                  return const SizedBox.shrink();
                }
                // Kalabalık seride her 3 günde bir etiket göster.
                if (days.length > 10 && i % 3 != 0) {
                  return const SizedBox.shrink();
                }
                final d = days[i].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${d.day}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
              barRods: [
                BarChartRodData(
                  toY: days[i].seconds / 60,
                  color: theme.colorScheme.primary,
                  width: days.length > 10 ? 8 : 16,
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
