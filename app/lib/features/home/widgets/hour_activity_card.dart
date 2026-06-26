import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/hour_activity_chart.dart';
import '../dashboard_card.dart';

/// "Çalışma saatleri" kartı (§3.11): günün hangi saatlerinde çalıştığını gösterir.
/// Büyük boyutta daha uzun grafik.
class HourActivityCard extends ConsumerWidget {
  const HourActivityCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    final hourly = hourlyTotals(sessions);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLarge = constraints.maxWidth >= 400;
            final isCompact = constraints.maxWidth < 280;
            final chartHeight = isLarge ? 180.0 : (isCompact ? 100.0 : 130.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Çalışma saatleri', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                HourActivityChart(
                  hourly: hourly,
                  height: chartHeight,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
