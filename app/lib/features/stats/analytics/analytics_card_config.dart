import '../../../core/grid/grid_reflow.dart';
import 'analytics_card_type.dart';

/// WP-158: ızgara yerleşim birimi. Format: `type:x:y:w:h`
class AnalyticsCardConfig {
  const AnalyticsCardConfig(
    this.type, {
    this.x = 0,
    this.y = 0,
    this.w = 6,
    this.h = 3,
    this.comparePrevious = false,
  });

  final AnalyticsCardType type;
  final int x;
  final int y;
  final int w;
  final int h;
  final bool comparePrevious;

  String get id => '${type.name}_${x}_$y';

  String encode() =>
      '${type.name}:$x:$y:$w:$h${comparePrevious ? ':cmp1' : ''}';

  GridItemBounds toBounds() =>
      GridItemBounds(id: id, x: x, y: y, w: w, h: h);

  AnalyticsCardConfig copyWith({
    int? x,
    int? y,
    int? w,
    int? h,
    bool? comparePrevious,
  }) {
    return AnalyticsCardConfig(
      type,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      comparePrevious: comparePrevious ?? this.comparePrevious,
    );
  }

  static AnalyticsCardConfig? decode(String raw) {
    final parts = raw.split(':');
    if (parts.isEmpty) return null;
    final type = AnalyticsCardType.values
        .where((t) => t.name == parts[0])
        .firstOrNull;
    if (type == null) return null;
    if (parts.length < 5) {
      final (dw, dh) = type.defaultCells;
      return AnalyticsCardConfig(type, w: dw, h: dh);
    }
    final x = int.tryParse(parts[1]) ?? 0;
    final y = int.tryParse(parts[2]) ?? 0;
    final w = int.tryParse(parts[3]) ?? type.defaultCells.$1;
    final h = int.tryParse(parts[4]) ?? type.defaultCells.$2;
    final cmp = parts.length > 5 && parts[5] == 'cmp1';
    return AnalyticsCardConfig(
      type,
      x: x,
      y: y,
      w: w.clamp(1, 6),
      h: h.clamp(1, 8),
      comparePrevious: cmp,
    );
  }

  static List<AnalyticsCardConfig> decodeList(List<String> raw) {
    final out = <AnalyticsCardConfig>[];
    for (final r in raw) {
      final c = decode(r);
      if (c != null) out.add(c);
    }
    return out;
  }

  static List<String> encodeList(List<AnalyticsCardConfig> items) =>
      [for (final c in items) c.encode()];
}

List<AnalyticsCardConfig> defaultPersonalLayout() {
  return const [
    AnalyticsCardConfig(AnalyticsCardType.totalPeriod, x: 0, y: 0, w: 3, h: 2),
    AnalyticsCardConfig(AnalyticsCardType.goalGauge, x: 3, y: 0, w: 3, h: 2),
    AnalyticsCardConfig(AnalyticsCardType.trendLine, x: 0, y: 2, w: 6, h: 3),
    AnalyticsCardConfig(AnalyticsCardType.subjectDonut, x: 0, y: 5, w: 3, h: 3),
    AnalyticsCardConfig(AnalyticsCardType.streakHeatmap, x: 3, y: 5, w: 3, h: 3),
    AnalyticsCardConfig(AnalyticsCardType.hourOfDay, x: 0, y: 8, w: 6, h: 3),
    AnalyticsCardConfig(AnalyticsCardType.records, x: 0, y: 11, w: 6, h: 2),
  ];
}

List<AnalyticsCardConfig> defaultGroupLayout() {
  return const [
    AnalyticsCardConfig(AnalyticsCardType.groupTotal, x: 0, y: 0, w: 3, h: 2),
    AnalyticsCardConfig(AnalyticsCardType.groupGoalGauge, x: 3, y: 0, w: 3, h: 2),
    AnalyticsCardConfig(AnalyticsCardType.groupTrend, x: 0, y: 2, w: 6, h: 3),
    AnalyticsCardConfig(AnalyticsCardType.groupLeaderboard, x: 0, y: 5, w: 6, h: 3),
    AnalyticsCardConfig(AnalyticsCardType.groupMemberDonut, x: 0, y: 8, w: 3, h: 3),
    AnalyticsCardConfig(AnalyticsCardType.groupHeatTable, x: 3, y: 8, w: 3, h: 3),
    AnalyticsCardConfig(AnalyticsCardType.groupStreak, x: 0, y: 11, w: 6, h: 2),
  ];
}
