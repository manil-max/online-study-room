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

    final sessions = ref.watch(groupSessionsProvider).value ?? const [];
    final now = DateTime.now();
    final goalSeconds = group.dailyGoalMinutes * 60;
    final todayTotal = sessions
        .where((s) => isSameDay(s.day, now))
        .fold<int>(0, (a, s) => a + s.durationSeconds);
    final pct =
        goalSeconds <= 0 ? 0.0 : (todayTotal / goalSeconds).clamp(0.0, 1.0);
    final reached = goalSeconds > 0 && todayTotal >= goalSeconds;
    final streak = currentStreak(sessions, goalSeconds);
    final fire = subjectColor('chart-5');
    final ringColor =
        reached ? subjectColor('chart-2') : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: pct,
                          strokeWidth: 8,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(ringColor),
                        ),
                      ),
                      Text('%${(pct * 100).round()}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
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
  }
}
