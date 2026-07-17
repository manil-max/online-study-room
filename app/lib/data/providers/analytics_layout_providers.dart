import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/prefs/app_prefs.dart';
import '../../features/stats/analytics/analytics_card_config.dart';
import '../../features/stats/analytics/analytics_card_type.dart';
import '../repositories/analytics_layout_repository.dart';
import '../repositories/in_memory/in_memory_analytics_layout_repository.dart';
import '../repositories/supabase/supabase_analytics_layout_repository.dart';

final analyticsLayoutRepositoryProvider =
    Provider<AnalyticsLayoutRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAnalyticsLayoutRepository(
      ref.watch(sharedPreferencesProvider),
    );
  }
  return InMemoryAnalyticsLayoutRepository();
});

final statsLayoutProvider =
    AsyncNotifierProvider<StatsLayoutNotifier, List<AnalyticsCardConfig>>(
  StatsLayoutNotifier.new,
);

final groupStatsLayoutProvider =
    AsyncNotifierProvider<GroupStatsLayoutNotifier, List<AnalyticsCardConfig>>(
  GroupStatsLayoutNotifier.new,
);

class StatsLayoutNotifier extends AsyncNotifier<List<AnalyticsCardConfig>> {
  @override
  Future<List<AnalyticsCardConfig>> build() {
    return ref
        .watch(analyticsLayoutRepositoryProvider)
        .load(AnalyticsSurface.personalStats);
  }

  Future<void> save(List<AnalyticsCardConfig> layout) async {
    await ref
        .read(analyticsLayoutRepositoryProvider)
        .save(AnalyticsSurface.personalStats, layout);
    state = AsyncData(layout);
  }

  Future<void> reset() async {
    await ref
        .read(analyticsLayoutRepositoryProvider)
        .reset(AnalyticsSurface.personalStats);
    state = AsyncData(defaultPersonalLayout());
  }
}

class GroupStatsLayoutNotifier
    extends AsyncNotifier<List<AnalyticsCardConfig>> {
  @override
  Future<List<AnalyticsCardConfig>> build() {
    return ref
        .watch(analyticsLayoutRepositoryProvider)
        .load(AnalyticsSurface.groupStats);
  }

  Future<void> save(List<AnalyticsCardConfig> layout) async {
    await ref
        .read(analyticsLayoutRepositoryProvider)
        .save(AnalyticsSurface.groupStats, layout);
    state = AsyncData(layout);
  }

  Future<void> reset() async {
    await ref
        .read(analyticsLayoutRepositoryProvider)
        .reset(AnalyticsSurface.groupStats);
    state = AsyncData(defaultGroupLayout());
  }
}
