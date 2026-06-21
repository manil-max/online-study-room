import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Donut grafiğinde bir dilim (ders bazında dağılım için).
class SubjectDonutSlice {
  const SubjectDonutSlice({
    required this.label,
    required this.color,
    required this.seconds,
  });

  final String label;
  final Color color;
  final int seconds;
}

/// Ders bazında dağılımı donut (halka) grafikle gösterir; ortada toplam saat.
class SubjectDonut extends StatelessWidget {
  const SubjectDonut({super.key, required this.slices, this.size = 140});

  final List<SubjectDonutSlice> slices;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = slices.fold<int>(0, (s, e) => s + e.seconds);
    final hours = (total / 3600).toStringAsFixed(1);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: size * 0.30,
              sections: [
                for (final s in slices)
                  PieChartSectionData(
                    value: s.seconds.toDouble(),
                    color: s.color,
                    radius: size * 0.17,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hours, style: theme.textTheme.titleMedium),
              Text(
                'saat',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
