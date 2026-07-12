import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_window.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/study_providers.dart';
import '../desktop/desktop_page_scaffold.dart';
import 'widgets/class_stats_view.dart';
import 'widgets/personal_stats_view.dart';

/// İstatistik sekmesi: Kişisel + Sınıf (ortak) istatistikler. Bkz. project.md §3.4.
/// Veriler `study_sessions` üzerinden hesaplanır; Kişisel görünüm hazır,
/// Sınıf (leaderboard) görünümü Faz 3c'de gelecek.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: isDesktopWindow
          ? DesktopPageScaffold(
              title: 'İstatistik',
              subtitle:
                  'Çalışma ritmini incele, dönemleri karşılaştır ve grubundaki ilerlemeyi gör.',
              icon: Icons.query_stats_outlined,
              child: Column(
                children: [
                  const DesktopContent(
                    padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
                    maxWidth: 720,
                    child: DesktopPanel(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: TabBar(
                        tabs: [
                          Tab(text: 'Kişisel'),
                          Tab(text: 'Grup'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(children: [_PersonalTab(), _ClassTab()]),
                  ),
                ],
              ),
            )
          : Scaffold(
              appBar: AppBar(
                title: const Text('İstatistik'),
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

/// Kişisel istatistikler: giriş yapan kullanıcının kendi oturumları.
class _PersonalTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('İstatistik yüklenemedi: $e')),
      data: (sessions) => PersonalStatsView(sessions: sessions),
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
