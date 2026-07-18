import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Alan dolgulu çizgi (LineChart belowBarData) + eksenler (WP-203).
///
/// Sol Y ekseni ([yUnit] son ekiyle), yatay ızgara ve — [labels] verilirse —
/// seyrek X ekseni etiketleri gösterir. Böylece çıplak/anlamsız görünmez.
class AreaLineChart extends StatelessWidget {
  const AreaLineChart({
    super.key,
    required this.values,
    this.labels = const [],
    this.yUnit = '',
  });

  final List<double> values;

  /// X ekseni etiketleri (values ile aynı uzunlukta olmalı); boşsa X gizli.
  final List<String> labels;

  /// Y ekseni birim son eki (ör. 's' = saat). Boşsa yalın sayı.
  final String yUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxV = values.fold<double>(0, (m, v) => v > m ? v : m);
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.15;
    final interval = _niceInterval(maxY);
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    String yLabel(double v) {
      final s = v == v.roundToDouble()
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(1);
      return yUnit.isEmpty ? s : '$s$yUnit';
    }

    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontSize: 9,
    );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value <= 0 || value > maxY) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(yLabel(value), style: labelStyle),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: labels.isNotEmpty,
              reservedSize: 18,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                // Seyrek etiket: ~4 tik + son gün.
                final step = (labels.length / 4).ceil().clamp(1, 1 << 30);
                if (i % step != 0 && i != labels.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(labels[i], style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: scheme.primary,
            barWidth: 2,
            dotData: FlDotData(show: values.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.20),
            ),
          ),
        ],
      ),
    );
  }
}

/// Y ekseni için okunur tik aralığı.
double _niceInterval(double maxY) {
  if (maxY <= 4) return 1;
  if (maxY <= 8) return 2;
  if (maxY <= 20) return 5;
  if (maxY <= 60) return 15;
  return (maxY / 4).ceilToDouble();
}
