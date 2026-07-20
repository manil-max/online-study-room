import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import 'chart_axis.dart';

/// Günlük çalışma süresini çizgi grafikle gösterir (y ekseni: dakika). Veri serisi
/// eski → yeni sıralı `DayTotal` listesidir. Dokunulan noktada tarih + süre ipucu.
class DailyLineChart extends StatelessWidget {
  const DailyLineChart({super.key, required this.days});

  final List<DayTotal> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final maxSeconds = days.fold<int>(
      0,
      (m, d) => d.seconds > m ? d.seconds : m,
    );
    final maxMinutes = maxSeconds / 60;
    final maxY = maxMinutes <= 0 ? 60.0 : maxMinutes * 1.2;
    // WP-237: Y ekseni ölçeği (eskiden hiç yoktu) + yer varken her gün etiketi.
    final yInterval = niceMinuteInterval(maxY);
    final useHours = axisUsesHours(maxMinutes);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Sol Y etiketleri için ~30px pay düşülür; kalan genişliğe göre gün adımı.
        final labelStep = axisLabelStep(days.length, constraints.maxWidth - 34);
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
                      '${DateFormat.Md(AppLocalizations.of(context).localeName).format(days[s.x.toInt()].day)}\n'
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
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: yInterval,
                  getTitlesWidget: (value, meta) {
                    if (value <= 0 || value > maxY) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        chartYLabel(value, l10n, useHours: useHours),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                    );
                  },
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
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= days.length) {
                      return const SizedBox.shrink();
                    }
                    // WP-237: yer varken her gün; dar seride çakışmayacak adım.
                    if (i % labelStep != 0 && i != days.length - 1) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${days[i].day.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yInterval,
              getDrawingHorizontalLine: (_) => FlLine(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.18),
                strokeWidth: 1,
              ),
            ),
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
      },
    );
  }
}
