import '../../features/stats/analytics/analytics_card_config.dart';
import '../../features/stats/analytics/analytics_card_type.dart';

/// WP-158: layout persist soyutlaması (prefs v1; bulut yok).
abstract class AnalyticsLayoutRepository {
  Future<List<AnalyticsCardConfig>> load(AnalyticsSurface surface);
  Future<void> save(AnalyticsSurface surface, List<AnalyticsCardConfig> layout);
  Future<void> reset(AnalyticsSurface surface);
}
