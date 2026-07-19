import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/stats/study_stats.dart';
import '../../features/stats/analytics/analytics_period.dart';
import '../models/analytics_query_models.dart';
import '../models/study_session.dart';
import '../repositories/analytics_query_repository.dart';
import '../repositories/in_memory/in_memory_analytics_query_repository.dart';
import '../repositories/supabase/supabase_analytics_query_repository.dart';
import 'auth_providers.dart';
import 'group_providers.dart';
import 'offline_providers.dart';
import 'study_providers.dart';

final analyticsQueryRepositoryProvider = Provider<AnalyticsQueryRepository>((
  ref,
) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAnalyticsQueryRepository(Supabase.instance.client);
  }
  final cache = ref.watch(offlineCacheStoreProvider);
  return InMemoryAnalyticsQueryRepository(
    sessionSource: (userId) async {
      final cached = await cache.readUserSessions(userId);
      return cached ?? const [];
    },
    groupStatsSource: (groupId) async {
      return await cache.readGroupDailyStats(groupId) ?? const [];
    },
  );
});

/// Seçili dönem için kişisel gün toplamları (yıl/özel dâhil; hot window dışı).
final analyticsUserDayTotalsProvider =
    FutureProvider.family<Map<DateTime, int>, AnalyticsPeriod>((
      ref,
      period,
    ) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return const {};
      final (from, to) = period.range();
      final hot = ref.watch(userSessionsProvider).asData?.value;
      final spanDays = dayOf(to).difference(dayOf(from)).inDays;
      if (hot != null && spanDays <= 90) {
        return dailyTotals(inRange(hot, from, to));
      }
      final repo = ref.read(analyticsQueryRepositoryProvider);
      // InMemory: seed hot window so demo boş kalmasın.
      if (repo is InMemoryAnalyticsQueryRepository && hot != null) {
        repo.seedSessions(user.id, hot);
      }
      final rows = await repo.getUserDayTotals(
        userId: user.id,
        from: from,
        to: to,
      );
      if (rows.isNotEmpty) {
        return {for (final r in rows) dayOf(r.day): r.seconds};
      }
      // Fallback: hot window partial.
      if (hot != null) return dailyTotals(inRange(hot, from, to));
      return const {};
    });

/// Seçili dönem self oturumları (konu×gün, saat dağılımı vb.).
final analyticsUserSessionsInRangeProvider =
    FutureProvider.family<List<StudySession>, AnalyticsPeriod>((
      ref,
      period,
    ) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return const [];
      final (from, to) = period.range();
      final hot = ref.watch(userSessionsProvider).asData?.value;
      final spanDays = dayOf(to).difference(dayOf(from)).inDays;
      if (hot != null && spanDays <= 90) {
        return inRange(hot, from, to).toList();
      }
      final repo = ref.read(analyticsQueryRepositoryProvider);
      if (repo is InMemoryAnalyticsQueryRepository && hot != null) {
        repo.seedSessions(user.id, hot);
      }
      final rows = await repo.getUserSessionsInRange(
        userId: user.id,
        from: from,
        to: to,
      );
      if (rows.isNotEmpty) return rows;
      if (hot != null) return inRange(hot, from, to).toList();
      return const [];
    });

final analyticsGroupContributionProvider =
    FutureProvider.family<List<GroupContributionRow>, AnalyticsPeriod>((
      ref,
      period,
    ) async {
      final group = ref.watch(userGroupProvider).value;
      if (group == null) return const [];
      final (from, to) = period.range();
      final repo = ref.read(analyticsQueryRepositoryProvider);
      if (repo is InMemoryAnalyticsQueryRepository) {
        final stats = ref.watch(groupDailyStatsProvider).asData?.value;
        if (stats != null) repo.seedGroupStats(group.id, stats);
      }
      return repo.getGroupContribution(groupId: group.id, from: from, to: to);
    });

final analyticsGroupLeaderboardSeriesProvider =
    FutureProvider.family<List<GroupLeaderboardPoint>, AnalyticsPeriod>((
      ref,
      period,
    ) async {
      final group = ref.watch(userGroupProvider).value;
      if (group == null) return const [];
      final (from, to) = period.range();
      final repo = ref.read(analyticsQueryRepositoryProvider);
      if (repo is InMemoryAnalyticsQueryRepository) {
        final stats = ref.watch(groupDailyStatsProvider).asData?.value;
        if (stats != null) repo.seedGroupStats(group.id, stats);
      }
      return repo.getGroupLeaderboardSeries(
        groupId: group.id,
        from: from,
        to: to,
      );
    });

/// WP-K: Sadece server-verified finalized günlerden gelen grup alpha toplamları.
/// Boş/erişilemeyen veri, UI'da göstergeyi gizler; istemci fallback hesap yapmaz.
final groupAlphaScoresProvider = FutureProvider<Map<String, int>>((ref) async {
  final group = ref.watch(userGroupProvider).value;
  if (group == null) return const {};
  final scores = await ref
      .read(analyticsQueryRepositoryProvider)
      .getGroupAlphaScores(groupId: group.id);
  return {for (final score in scores) score.userId: score.alphaWins};
});
