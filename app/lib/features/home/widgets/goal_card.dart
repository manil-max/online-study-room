import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/goal_streak.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/goal_streak_flame.dart';
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
    // WP-481: kişisel seri kanonik projeksiyondan okunur.
    // `currentStreakProvider` grace'siz eski motordu ve aynı geçmişte
    // projeksiyondan farklı sayı veriyordu.
    final userId = ref.watch(authStateProvider).value?.id;
    final streakScope = userId == null
        ? null
        : GoalStreakScope.personal(userId);
    final pct = goalSeconds <= 0
        ? 0.0
        : (recorded / goalSeconds).clamp(0.0, 1.0);
    final reached = recorded >= goalSeconds && goalSeconds > 0;
    final ringColor = reached
        ? subjectColor('chart-2')
        : theme.colorScheme.primary;
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 220;
          final isLarge = constraints.maxWidth >= 400;
          final ringSize = isCompact ? 64.0 : (isLarge ? 116.0 : 84.0);

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
                Text(
                  '%${(pct * 100).round()}',
                  style:
                      (isLarge
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.titleMedium)
                          ?.copyWith(fontWeight: FontWeight.w700),
                ),
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
                        Flexible(
                          child: Text(
                            AppLocalizations.of(context).homeGunlukHedef,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                        const Spacer(),
                        if (reached)
                          Icon(
                            Icons.check_circle,
                            color: subjectColor('chart-2'),
                            size: 16,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(child: ring),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${formatHuman(recorded)} / ${formatHuman(goalSeconds)}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Minik kartta rozet tam sığmıyor; içerik kırpılmak yerine
                    // ölçekleniyor. (WP-496'dan sonra rozette yazı yok; kapsam
                    // bilgisi `Semantics` etiketinde duruyor.)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: GoalStreakBadge(
                        scope: streakScope,
                        size: GoalStreakFlameSize.compact,
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
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context).homeGunlukHedef,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const Spacer(),
                      if (reached)
                        Icon(
                          Icons.check_circle,
                          color: subjectColor('chart-2'),
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
                              '${formatHuman(recorded)} / ${formatHuman(goalSeconds)}',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reached
                                  ? AppLocalizations.of(context).homeBitti
                                  : '${AppLocalizations.of(context).homeGunlukHedef}: '
                                        '${formatHuman((goalSeconds - recorded).clamp(0, 1 << 30))}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GoalStreakBadge(scope: streakScope),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
