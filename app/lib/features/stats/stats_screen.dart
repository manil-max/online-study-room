import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/stats/study_stats.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/study_session.dart';
import '../../data/providers/study_providers.dart';
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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('İstatistik'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Kişisel'),
              Tab(text: 'Sınıf'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PersonalTab(),
            _ClassTab(),
          ],
        ),
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

/// Sınıf (ortak) istatistikleri — Faz 3c'de leaderboard ile dolacak.
class _ClassTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Şimdilik sınıf toplamını basitçe gösterelim (leaderboard sonra).
    final sessions = ref.watch(groupSessionsProvider).value ?? const <StudySession>[];
    final total = totalSeconds(sessions);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Sınıf toplamı', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(formatHuman(total), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              'Kıyaslamalı sıralama (leaderboard) ve grafikler yakında.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
