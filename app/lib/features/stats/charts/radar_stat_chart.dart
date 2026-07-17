import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'series_palette.dart';

/// WP-157: radar — fl_chart RadarChart (1.2+).
class RadarStatChart extends StatelessWidget {
  const RadarStatChart({
    super.key,
    required this.values,
    required this.labels,
  });

  /// 0–1 normalize değerler; labels ile aynı uzunluk.
  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = SeriesPalette(scheme);
    if (values.isEmpty || values.length != labels.length) {
      return const SizedBox.shrink();
    }
    return RadarChart(
      RadarChartData(
        dataSets: [
          RadarDataSet(
            dataEntries: [
              for (final v in values) RadarEntry(value: v.clamp(0.05, 1.0)),
            ],
            fillColor: scheme.primary.withValues(alpha: 0.25),
            borderColor: scheme.primary,
            entryRadius: 2,
            borderWidth: 2,
          ),
        ],
        radarBackgroundColor: Colors.transparent,
        borderData: FlBorderData(show: false),
        radarBorderData: BorderSide(color: scheme.outlineVariant),
        tickCount: 4,
        ticksTextStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 9),
        tickBorderData: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        gridBorderData: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        getTitle: (index, angle) {
          final i = index % labels.length;
          return RadarChartTitle(
            text: palette.labeled(i, labels[i]),
            angle: angle,
          );
        },
        titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 10),
      ),
    );
  }
}
