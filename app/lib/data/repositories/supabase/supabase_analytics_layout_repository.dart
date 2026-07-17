import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/stats/analytics/analytics_card_config.dart';
import '../../../features/stats/analytics/analytics_card_type.dart';
import '../analytics_layout_repository.dart';

/// WP-158 v1: bulut yok — prefs (Supabase kullanıcı oturumu ile aynı cihaz).
/// Anahtarlar dashboard_layout_* ile **çakışmaz**.
class SupabaseAnalyticsLayoutRepository implements AnalyticsLayoutRepository {
  SupabaseAnalyticsLayoutRepository(this._prefs);

  final SharedPreferences _prefs;

  static const personalKey = 'stats_layout_v1';
  static const groupKey = 'group_stats_layout_v1';

  String _key(AnalyticsSurface s) => switch (s) {
        AnalyticsSurface.personalStats => personalKey,
        AnalyticsSurface.groupStats => groupKey,
      };

  @override
  Future<List<AnalyticsCardConfig>> load(AnalyticsSurface surface) async {
    final raw = _prefs.getStringList(_key(surface));
    if (raw == null || raw.isEmpty) {
      return surface == AnalyticsSurface.personalStats
          ? defaultPersonalLayout()
          : defaultGroupLayout();
    }
    final decoded = AnalyticsCardConfig.decodeList(raw);
    return decoded.isEmpty
        ? (surface == AnalyticsSurface.personalStats
            ? defaultPersonalLayout()
            : defaultGroupLayout())
        : decoded;
  }

  @override
  Future<void> save(
    AnalyticsSurface surface,
    List<AnalyticsCardConfig> layout,
  ) async {
    await _prefs.setStringList(
      _key(surface),
      AnalyticsCardConfig.encodeList(layout),
    );
  }

  @override
  Future<void> reset(AnalyticsSurface surface) async {
    await _prefs.remove(_key(surface));
  }
}
