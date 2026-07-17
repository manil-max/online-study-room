import '../../../core/grid/grid_reflow.dart';
import 'analytics_card_type.dart';

/// WP-158/164: ızgara yerleşim birimi. Format: `type:x:y:w:h`
///
/// [id] konumdan bağımsızdır (yalnız type) — reflow güvenilir çalışsın.
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

  /// Kart kimliği konum değişince değişmez (reflow anahtarı).
  String get id => type.name;

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

  AnalyticsCardConfig withBounds({
    int? x,
    int? y,
    int? w,
    int? h,
    int columns = 6,
  }) {
    final nextW = (w ?? this.w).clamp(1, columns);
    final nextX = (x ?? this.x).clamp(0, columns - nextW);
    return copyWith(
      x: nextX,
      y: (y ?? this.y) < 0 ? 0 : (y ?? this.y),
      w: nextW,
      h: (h ?? this.h) < 1 ? 1 : (h ?? this.h),
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
    final seen = <AnalyticsCardType>{};
    for (final r in raw) {
      final c = decode(r);
      if (c != null && seen.add(c.type)) out.add(c);
    }
    return out;
  }

  static List<String> encodeList(List<AnalyticsCardConfig> items) =>
      [for (final c in items) c.encode()];

  /// İlk uygun boş hücreye yerleştir.
  static AnalyticsCardConfig firstAvailable(
    List<AnalyticsCardConfig> existing,
    AnalyticsCardType type, {
    int columns = 6,
  }) {
    final (dw, dh) = type.defaultCells;
    final w = dw.clamp(1, columns);
    final occupied = existing.map((c) => c.toBounds()).toList();
    for (var y = 0; y < 200; y++) {
      for (var x = 0; x <= columns - w; x++) {
        final candidate = GridItemBounds(id: type.name, x: x, y: y, w: w, h: dh);
        if (occupied.every((o) => !candidate.overlaps(o))) {
          return AnalyticsCardConfig(type, x: x, y: y, w: w, h: dh);
        }
      }
    }
    final y = existing.isEmpty
        ? 0
        : existing.map((c) => c.y + c.h).reduce((a, b) => a > b ? a : b);
    return AnalyticsCardConfig(type, x: 0, y: y, w: w, h: dh);
  }
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

/// Taşıma/boyutlandırma sonrası reflow uygula; kart id sabit kalır.
List<AnalyticsCardConfig> reflowAnalyticsLayout({
  required List<AnalyticsCardConfig> layout,
  required AnalyticsCardType moving,
  required int x,
  required int y,
  required int w,
  required int h,
  int columns = 6,
}) {
  final flowed = placeGridItem(
    items: [for (final c in layout) c.toBounds()],
    id: moving.name,
    x: x,
    y: y,
    w: w,
    h: h,
    columns: columns,
  );
  final byId = {for (final b in flowed) b.id: b};
  return [
    for (final c in layout)
      c.withBounds(
        x: byId[c.id]?.x ?? c.x,
        y: byId[c.id]?.y ?? c.y,
        w: byId[c.id]?.w ?? c.w,
        h: byId[c.id]?.h ?? c.h,
        columns: columns,
      ),
  ];
}
