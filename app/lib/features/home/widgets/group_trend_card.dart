import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/daily_bar_chart.dart';
import '../dashboard_card.dart';
import 'group_card_shell.dart';

/// "Grup günlük trendi" kartı (§3.11): grubun son günlerdeki toplam çalışma
/// çubuk grafiği. Büyük boyutta 14 gün.
class GroupTrendCard extends ConsumerWidget {
  const GroupTrendCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final group = ref.watch(userGroupProvider).value;
    if (group == null) return const GroupCardShell(title: 'Grup günlük trendi');

    final stats = ref.watch(groupDailyStatsProvider).value ?? const [];
    final isLarge = size == DashboardCardSize.large;
    final days = isLarge ? 14 : 7;
    final series = lastNDays(const [], days, totals: groupDayTotals(stats));
    final total = series.fold<int>(0, (s, d) => s + d.seconds);

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
                  Text('Grup günlük trendi',
                      style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(formatHuman(total),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: isLarge ? 200 : 150,
              child: DailyBarChart(
                  days: series, goalSeconds: group.dailyGoalMinutes * 60),
            ),
          ],
        ),
      ),
    );
  }
}
