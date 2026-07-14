import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_window.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/study_providers.dart';
import 'widgets/class_stats_view.dart';
import 'widgets/personal_stats_view.dart';

/// İstatistik sekmesi: Kişisel + Sınıf (ortak) istatistikler. Bkz. project.md §3.4.
/// Veriler `study_sessions` üzerinden hesaplanır; Kişisel görünüm hazır,
/// Sınıf (leaderboard) görünümü Faz 3c'de gelecek.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Windows: sol rail yeter; ekstra başlık + sağ ipucu paneli yok.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: isDesktopWindow ? null : const Text('İstatistik'),
          toolbarHeight: isDesktopWindow ? 0 : kToolbarHeight,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Kişisel'),
              Tab(text: 'Grup'),
            ],
          ),
        ),
        body: TabBarView(children: [_PersonalTab(), _ClassTab()]),
      ),
    );
  }
}

/// Kişisel istatistikler: sıcak pencere detay + özet (yıl / ömür boyu).
class _PersonalTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    final summaryAsync = ref.watch(userStudySummaryProvider);
    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('İstatistik yüklenemedi: $e')),
      data: (sessions) => PersonalStatsView(
        sessions: sessions,
        summary: summaryAsync.asData?.value,
      ),
    );
  }
}

/// Sınıf (ortak) istatistikleri: dönem seçici + kıyaslamalı sıralama (leaderboard).
class _ClassTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final group = ref.watch(userGroupProvider).value;
    if (group == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Grup istatistiklerini görmek için önce bir gruba katıl.',
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

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('İstatistik yüklenemedi: $e')),
      data: (stats) => ClassStatsView(
        stats: stats,
        members: members,
        currentUserId: currentUserId,
        groupName: group.name,
        groupGoalMinutes: group.dailyGoalMinutes,
      ),
    );
  }
}
