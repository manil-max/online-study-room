import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/week_hour_heatmap.dart';
import '../dashboard_card.dart';

/// "Haftalık ritim" kartı (§3.11): haftanın hangi gün/saatlerinde çalıştığın
/// (7 gün × 24 saat ısı haritası).
class RhythmCard extends ConsumerWidget {
  const RhythmCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Haftalık ritim', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            WeekHourHeatmap(grid: weekdayHourTotals(sessions)),
          ],
        ),
      ),
    );
  }
}
