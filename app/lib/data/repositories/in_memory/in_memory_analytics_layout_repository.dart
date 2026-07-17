import '../../../features/stats/analytics/analytics_card_config.dart';
import '../../../features/stats/analytics/analytics_card_type.dart';
import '../analytics_layout_repository.dart';

class InMemoryAnalyticsLayoutRepository implements AnalyticsLayoutRepository {
  final _store = <AnalyticsSurface, List<AnalyticsCardConfig>>{};

  @override
  Future<List<AnalyticsCardConfig>> load(AnalyticsSurface surface) async {
    return List.unmodifiable(
      _store[surface] ??
          (surface == AnalyticsSurface.personalStats
              ? defaultPersonalLayout()
              : defaultGroupLayout()),
    );
  }

  @override
  Future<void> save(
    AnalyticsSurface surface,
    List<AnalyticsCardConfig> layout,
  ) async {
    _store[surface] = List.of(layout);
  }

  @override
  Future<void> reset(AnalyticsSurface surface) async {
    _store.remove(surface);
  }
}
