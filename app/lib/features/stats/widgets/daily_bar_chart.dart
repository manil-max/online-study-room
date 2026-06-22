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

/// Günlük çalışma süresini çubuk grafikle gösterir (y ekseni: dakika). Her çubuğun
/// üstünde süre **her zaman** yazar; alt eksende tarih ay adıyla ("21 Haz").
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({super.key, required this.days});

  final List<DayTotal> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSeconds =
        days.fold<int>(0, (m, d) => d.seconds > m ? d.seconds : m);
    final maxMinutes = maxSeconds / 60;
    // Üstteki süre etiketi sığsın diye biraz daha pay (%32).
    final maxY = maxMinutes <= 0 ? 60.0 : maxMinutes * 1.32;
    final dense = days.length > 10;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceBetween,
        barTouchData: BarTouchData(
          enabled: true,
          // Süre etiketi çubuğun üstünde "her zaman" görünsün diye saydam kutu.
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
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) {
                  return const SizedBox.shrink();
                }
                if (dense && i % 3 != 0) return const SizedBox.shrink();
                final d = days[i].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${d.day}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          )),
                      Text(_kMonths[d.month - 1],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 9,
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
              // Süre etiketini her zaman göster (veri olan günlerde).
              showingTooltipIndicators: days[i].seconds > 0 ? const [0] : const [],
              barRods: [
                BarChartRodData(
                  toY: days[i].seconds / 60,
                  color: theme.colorScheme.primary,
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
