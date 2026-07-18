import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/stats/study_stats.dart';
import '../../../data/models/daily_stat.dart';
import '../../../data/models/profile.dart';

/// Liderlik geçmişi: **Y ekseni = sıralama (1 en üstte), X ekseni = zaman**.
/// Her üye bir çizgi; kümülatif (biriken) toplama göre günlük sıra — futbol
/// ligi sezon içi sıralama grafiği gibi (WP-203).
///
/// Veri [stats] (per-user-per-gün) üzerinden hesaplanır; ek RPC gerekmez.
class LeaderboardRankChart extends StatelessWidget {
  const LeaderboardRankChart({
    super.key,
    required this.members,
    required this.memberColors,
    required this.stats,
    required this.days,
    required this.currentUserId,
    required this.emptyLabel,
    required this.namelessLabel,
  });

  final List<Profile> members;
  final Map<String, Color> memberColors;
  final List<DailyStat> stats;
  final int days;
  final String currentUserId;
  final String emptyLabel;
  final String namelessLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final memberIds = [for (final m in members) m.id];
    final n = memberIds.length;
    if (n == 0) {
      return _empty(theme);
    }

    // Pencere: bugüne kadar [days] gün (eski → yeni).
    final end = dayOf(DateTime.now());
    final window = [
      for (var i = days - 1; i >= 0; i--) end.subtract(Duration(days: i)),
    ];

    final perMember = {
      for (final id in memberIds) id: userDayTotals(stats, id),
    };
    final indexOf = {
      for (var i = 0; i < memberIds.length; i++) memberIds[i]: i,
    };

    // Kümülatif toplam → her gün sıralama; çizgi noktaları (plottedY: rank1 üstte).
    final cumulative = {for (final id in memberIds) id: 0};
    final spotsByMember = {for (final id in memberIds) id: <FlSpot>[]};
    var anyData = false;
    for (var di = 0; di < window.length; di++) {
      final day = window[di];
      for (final id in memberIds) {
        cumulative[id] = cumulative[id]! + (perMember[id]![day] ?? 0);
      }
      if (!anyData && cumulative.values.any((v) => v > 0)) anyData = true;
      final sorted = [...memberIds]
        ..sort((a, b) {
          final c = cumulative[b]!.compareTo(cumulative[a]!);
          if (c != 0) return c;
          return indexOf[a]!.compareTo(indexOf[b]!);
        });
      for (var r = 0; r < sorted.length; r++) {
        final id = sorted[r];
        // rank = r+1; plottedY: rank 1 → n (üst), rank n → 1 (alt).
        spotsByMember[id]!.add(FlSpot(di.toDouble(), (n - r).toDouble()));
      }
    }

    if (!anyData) {
      return _empty(theme);
    }

    String nameFor(Profile m) =>
        m.displayName.isEmpty ? namelessLabel : m.displayName;

    final bars = [
      for (final m in members)
        LineChartBarData(
          spots: spotsByMember[m.id]!,
          isCurved: false,
          color: memberColors[m.id]!,
          barWidth: m.id == currentUserId ? 3.5 : 2,
          dotData: FlDotData(show: window.length <= 14),
        ),
    ];

    final chartHeight = (n * 12 + 70).clamp(140, 300).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend: isim + renk (basılı tutmaya gerek yok).
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final m in members)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 3,
                    decoration: BoxDecoration(
                      color: memberColors[m.id]!,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    m.id == currentUserId ? '${nameFor(m)} •' : nameFor(m),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: m.id == currentUserId
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: chartHeight,
          child: LineChart(
            LineChartData(
              minY: 0.5,
              maxY: n + 0.5,
              lineTouchData: const LineTouchData(enabled: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: 0.20),
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
                    reservedSize: 26,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      // plottedY = value → rank = n + 1 - value.
                      final rank = n + 1 - value.round();
                      if (rank < 1 || rank > n) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '$rank.',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 18,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= window.length) {
                        return const SizedBox.shrink();
                      }
                      final step = (window.length / 4).ceil().clamp(1, 1 << 30);
                      if (i % step != 0 && i != window.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${window[i].day}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: bars,
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(ThemeData theme) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      emptyLabel,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
