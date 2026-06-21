import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';

/// Günlük çalışma süresini çizgi grafikle gösterir (y ekseni: dakika). Veri serisi
/// eski → yeni sıralı `DayTotal` listesidir. Dokunulan noktada tarih + süre ipucu.
class DailyLineChart extends StatelessWidget {
  const DailyLineChart({super.key, required this.days});

  final List<DayTotal> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSeconds =
        days.fold<int>(0, (m, d) => d.seconds > m ? d.seconds : m);
    final maxMinutes = maxSeconds / 60;
    final maxY = maxMinutes <= 0 ? 60.0 : maxMinutes * 1.2;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          // İmleç çizgiye yakın olduğunda da ipucu açılsın (nokta üstüne tam
          // gelmek zor olmasın).
          touchSpotThreshold: 30,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${days[s.x.toInt()].day.day}.${days[s.x.toInt()].day.month}\n'
                  '${formatHuman(days[s.x.toInt()].seconds)}',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
            ],
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
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                // Kalabalık seride her 3 günde bir etiket göster.
                if (days.length > 10 && i % 3 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${days[i].day.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < days.length; i++)
                FlSpot(i.toDouble(), days[i].seconds / 60),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(show: days.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
