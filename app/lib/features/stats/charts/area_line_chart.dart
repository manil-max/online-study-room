import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// WP-157: alan dolgulu çizgi (LineChart belowBarData).
class AreaLineChart extends StatelessWidget {
  const AreaLineChart({
    super.key,
    required this.values,
    this.labels = const [],
  });

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m);
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: scheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.22),
            ),
          ),
        ],
      ),
    );
  }
}
