import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/study_providers.dart';
import '../dashboard_card.dart';

/// Günlük hedef ilerlemesi + güncel seri (§3.11 kart). Hedefe ulaşılan oran bir
/// halka göstergede; seri büyük "🔥 N gün" rozetinde gösterilir.
class GoalCard extends ConsumerWidget {
  const GoalCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recorded = ref.watch(todayRecordedSecondsProvider);
    final goalMinutes = ref.watch(dailyGoalMinutesProvider);
    final goalSeconds = goalMinutes * 60;
    final streak = ref.watch(currentStreakProvider);
    final pct = goalSeconds <= 0 ? 0.0 : (recorded / goalSeconds).clamp(0.0, 1.0);
    final reached = recorded >= goalSeconds && goalSeconds > 0;
    final fire = subjectColor('chart-5');
    final ringColor =
        reached ? subjectColor('chart-2') : theme.colorScheme.primary;
    final isLarge = size == DashboardCardSize.large;
    final ringSize = isLarge ? 116.0 : 84.0;

    final ring = SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: isLarge ? 11 : 8,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Günlük hedef', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (reached)
                  Icon(Icons.check_circle, color: subjectColor('chart-2')),
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
                        '${formatHuman(recorded)} / ${formatHuman(goalSeconds)}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reached
                            ? 'Bugünkü hedefini tuttun! 🎉'
                            : 'Hedefe ${formatHuman((goalSeconds - recorded).clamp(0, 1 << 30))} kaldı',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: fire.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department, color: fire, size: 28),
                  const SizedBox(width: 8),
                  Text('$streak',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: fire, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Text('günlük seri',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
