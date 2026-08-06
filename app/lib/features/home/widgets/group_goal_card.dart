import 'package:online_study_room/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/goal_streak.dart';
import '../../../data/models/presence.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/presence_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../classroom/widgets/class_switcher.dart';
import '../../stats/widgets/goal_streak_flame.dart';
import '../dashboard_card.dart';
import 'card_data_gate.dart';
import 'group_card_shell.dart';

/// "Grup hedefi" kartı (§3.11): grubun bugünkü TOPLAM çalışması / günlük grup
/// hedefi (halka) + grup serisi (üst üste hedef tutulan gün).
class GroupGoalCard extends ConsumerStatefulWidget {
  const GroupGoalCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  ConsumerState<GroupGoalCard> createState() => _GroupGoalCardState();
}

class _GroupGoalCardState extends ConsumerState<GroupGoalCard> {
  Timer? _timer;
  int _virtualOffset = 0;
  int _lastDbTotal = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick(Timer timer) {
    if (!mounted) return;
    final presence = ref.read(groupPresenceProvider).value ?? const [];
    final activeCount = presence
        .where((p) => p.status == PresenceStatus.studying)
        .length;
    if (activeCount > 0) {
      setState(() {
        _virtualOffset += activeCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupAsync = ref.watch(userGroupProvider);
    // WP-495B: yükleniyorken davet değil iskelet (bkz. `groupCardGate`).
    final gate = groupCardGate(
      context,
      groupAsync,
      title: AppLocalizations.of(context).homeGrupHedefi,
      onCreateGroup: () => createGroupFlow(context, ref),
      onJoinGroup: () => joinGroupFlow(context, ref),
    );
    if (gate != null) return gate;
    final group = groupAsync.value!;

    final statsAsync = ref.watch(groupDailyStatsProvider);
    // WP-495C: istatistik gelmeden halka %0 gösterir.
    final dataGate = cardDataGate(
      context,
      title: AppLocalizations.of(context).homeGrupHedefi,
      sources: [statsAsync],
    );
    if (dataGate != null) return dataGate;
    final stats = statsAsync.value!;
    final dayTotals = groupDayTotals(stats);
    final goalSeconds = group.dailyGoalMinutes * 60;

    final dbTodayTotal = dayTotals[dayOf(DateTime.now())] ?? 0;
    if (dbTodayTotal != _lastDbTotal) {
      _lastDbTotal = dbTodayTotal;
      _virtualOffset = 0;
    }

    final todayTotal = dbTodayTotal + _virtualOffset;
    final pct = goalSeconds <= 0
        ? 0.0
        : (todayTotal / goalSeconds).clamp(0.0, 1.0);
    final reached = goalSeconds > 0 && todayTotal >= goalSeconds;
    // WP-481: grup serisi de kanonik projeksiyondan. `currentStreak()`
    // grace'siz eski motordu; sahibin istediği duraklatma orada yok.
    final streakScope = GoalStreakScope.group(
      groupId: group.id,
      timeZone: group.timeZone,
    );
    final ringColor = reached
        ? subjectColor('chart-2')
        : theme.colorScheme.primary;

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
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 1),
                    curve: Curves.linear,
                    tween: Tween<double>(end: pct),
                    builder: (context, value, _) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: isCompact ? 6 : (isLarge ? 11 : 8),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                      );
                    },
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

          // WP-172: ListView (sınırsız yükseklik) içinde nested scroll jesti yutmasın.
          final unbounded = !constraints.maxHeight.isFinite;

          Widget maybeScroll(Widget child) => unbounded
              ? child
              : SingleChildScrollView(child: child);

          if (isCompact) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: maybeScroll(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            AppLocalizations.of(context).homeGrupHedefi,
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
                        '${formatHuman(todayTotal)} / ${formatHuman(goalSeconds)}',
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
            child: maybeScroll(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context).homeGrupHedefi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          group.name,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
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
                            Text(
                              AppLocalizations.of(context).homeGrupHedefi,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GoalStreakBadge(scope: streakScope),
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
