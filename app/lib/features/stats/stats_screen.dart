import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/navigation/nav_index.dart';
import '../../core/tour/tour_host.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/study_providers.dart';
import '../tours/app_tours.dart';
import 'widgets/class_stats_view.dart';
import 'widgets/personal_stats_view.dart';
import 'widgets/stats_period_bar.dart';

/// İstatistik sekmesi: Kişisel + Grup (klasik ListView — WP-170).
/// Özelleştirilebilir ızgara kaldırıldı; zenginleştirme WP-175 planında.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  final _periodTourAnchor = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    final page = DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: isDesktopWindow
              ? null
              : Text(AppLocalizations.of(context).statsIstatistik),
          toolbarHeight: isDesktopWindow ? 0 : kToolbarHeight,
          bottom: TabBar(
            tabs: [
              Tab(text: AppLocalizations.of(context).statsKisisel),
              Tab(text: AppLocalizations.of(context).statsGrup),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyedSubtree(key: _periodTourAnchor, child: const StatsPeriodBar()),
            const Expanded(
              child: TabBarView(children: [_PersonalTab(), _ClassTab()]),
            ),
          ],
        ),
      ),
    );

    if (ref.watch(navIndexProvider) != AppTab.stats.index ||
        sessionsAsync.asData == null) {
      return page;
    }

    final definition = AppTours.stats(
      AppLocalizations.of(context),
      periodAnchor: _periodTourAnchor,
      hasSessions: sessionsAsync.asData!.value.isNotEmpty,
    );
    return TourHost(definition: definition, child: page);
  }
}

class _PersonalTab extends ConsumerWidget {
  const _PersonalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    final summaryAsync = ref.watch(userStudySummaryProvider);
    final l10n = AppLocalizations.of(context);
    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.authBeklenmeyenBirHataOlustu,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(userSessionsProvider),
                child: Text(l10n.classroomYenile),
              ),
            ],
          ),
        ),
      ),
      data: (sessions) => PersonalStatsView(
        sessions: sessions,
        summary: summaryAsync.asData?.value,
      ),
    );
  }
}

class _ClassTab extends ConsumerWidget {
  const _ClassTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final group = ref.watch(userGroupProvider).value;
    if (group == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context).statsGrupIstatistikleriniGormekIcin,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final statsAsync = ref.watch(groupDailyStatsProvider);
    final members = ref.watch(groupMembersProvider).value ?? const [];
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    final l10n = AppLocalizations.of(context);
    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.authBeklenmeyenBirHataOlustu,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(groupDailyStatsProvider),
                child: Text(l10n.classroomYenile),
              ),
            ],
          ),
        ),
      ),
      data: (stats) => ClassStatsView(
        stats: stats,
        members: members,
        currentUserId: currentUserId,
        groupName: group.name,
        groupGoalMinutes: group.dailyGoalMinutes,
        groupAvatarPath: group.avatarPath,
        groupAvatarUpdatedAt: group.avatarUpdatedAt,
      ),
    );
  }
}
