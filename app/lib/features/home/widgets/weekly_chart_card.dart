import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/daily_bar_chart.dart';

/// Son 7 günün günlük çubuk grafiği (§3.9 kart). Toplamı da gösterir.
class WeeklyChartCard extends ConsumerWidget {
  const WeeklyChartCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    final series = lastNDays(sessions, 7);
    final weekTotal = series.fold<int>(0, (sum, d) => sum + d.seconds);

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
                  Text('Son 7 gün', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    formatHuman(weekTotal),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 160, child: DailyBarChart(days: series)),
          ],
        ),
      ),
    );
  }
}
