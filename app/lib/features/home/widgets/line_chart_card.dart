import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/daily_line_chart.dart';
import '../dashboard_card.dart';

/// Günlük çalışma eğilimini çizgi grafikle gösterir (§3.11 kart). Büyük boyutta
/// son 30 günü ve daha uzun bir grafik gösterir; aksi hâlde 14 gün.
class LineChartCard extends ConsumerWidget {
  const LineChartCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    final isLarge = size == DashboardCardSize.large;
    final dayCount = isLarge ? 30 : 14;
    final series = lastNDays(sessions, dayCount);
    final total = series.fold<int>(0, (sum, d) => sum + d.seconds);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text('Eğilim ($dayCount gün)',
                      style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    formatHuman(total),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: isLarge ? 220 : 160,
              child: DailyLineChart(days: series),
            ),
          ],
        ),
      ),
    );
  }
}
