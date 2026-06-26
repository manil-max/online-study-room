import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../dashboard_card.dart';
import 'group_card_shell.dart';

/// "Grup hedefi" kartı (§3.11): grubun bugünkü TOPLAM çalışması / günlük grup
/// hedefi (halka) + grup serisi (üst üste hedef tutulan gün).
class GroupGoalCard extends ConsumerWidget {
  const GroupGoalCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final group = ref.watch(userGroupProvider).value;
    if (group == null) return const GroupCardShell(title: 'Grup hedefi');

    final stats = ref.watch(groupDailyStatsProvider).value ?? const [];
    final dayTotals = groupDayTotals(stats);
    final goalSeconds = group.dailyGoalMinutes * 60;
    final todayTotal = dayTotals[dayOf(DateTime.now())] ?? 0;
    final pct =
        goalSeconds <= 0 ? 0.0 : (todayTotal / goalSeconds).clamp(0.0, 1.0);
    final reached = goalSeconds > 0 && todayTotal >= goalSeconds;
    final streak = currentStreak(const [], goalSeconds, totals: dayTotals);
    final fire = subjectColor('chart-5');
    final ringColor =
        reached ? subjectColor('chart-2') : theme.colorScheme.primary;

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 220;
          final isLarge = constraints.maxWidth >= 400;
          final ringSize = isCompact ? 64.0 : (isLarge ? 116.0 : 76.0);

          final ring = SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: isCompact ? 6 : (isLarge ? 11 : 8),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                  ),
                ),
                Text('%${(pct * 100).round()}',
                    style: (isLarge
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.titleMedium)
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          );

          if (isCompact) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Grup hedefi', style: theme.textTheme.labelMedium),
                        const Spacer(),
                        if (reached)
                          Icon(Icons.check_circle, color: subjectColor('chart-2'), size: 16),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(child: ring),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${formatHuman(todayTotal)} / ${formatHuman(goalSeconds)}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: fire.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department, color: fire, size: 16),
                          const SizedBox(width: 4),
                          Text('$streak',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(color: fire, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Grup hedefi', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Flexible(
                        child: Text(group.name,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ring,
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatHuman(todayTotal)} / ${formatHuman(goalSeconds)}',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text('grup toplamı (bugün)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.local_fire_department,
                                    size: 18, color: fire),
                                const SizedBox(width: 4),
                                Text('$streak',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                        color: fire, fontWeight: FontWeight.w800)),
                                const SizedBox(width: 4),
                                Text('grup serisi',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
