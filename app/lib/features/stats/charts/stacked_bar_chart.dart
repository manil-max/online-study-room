import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'series_palette.dart';

/// WP-157: yığılmış çubuk — her sütun bir gün, yığın dilimleri seri.
class StackedBarChart extends StatelessWidget {
  const StackedBarChart({
    super.key,
    required this.stacks,
    this.seriesNames = const [],
  });

  /// stacks[dayIndex][seriesIndex] = değer
  final List<List<double>> stacks;
  final List<String> seriesNames;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = SeriesPalette(scheme);
    if (stacks.isEmpty) return const SizedBox.shrink();
    final seriesCount = stacks.first.length;
    var maxY = 0.0;
    for (final col in stacks) {
      final sum = col.fold<double>(0, (a, b) => a + b);
      if (sum > maxY) maxY = sum;
    }
    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 1 : maxY * 1.1,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        barGroups: [
          for (var i = 0; i < stacks.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: stacks[i].fold<double>(0, (a, b) => a + b),
                  width: 12,
                  rodStackItems: [
                    for (var s = 0; s < seriesCount; s++)
                      BarChartRodStackItem(
                        stacks[i].take(s).fold<double>(0, (a, b) => a + b),
                        stacks[i].take(s + 1).fold<double>(0, (a, b) => a + b),
                        palette.colorAt(s),
                      ),
                  ],
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
