import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/grid/grid_reflow.dart';
import 'package:online_study_room/features/stats/analytics/analytics_card_config.dart';
import 'package:online_study_room/features/stats/analytics/analytics_card_type.dart';
import 'package:online_study_room/features/stats/analytics/analytics_period.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_analytics_layout_repository.dart';

void main() {
  test('encode/decode analytics card config', () {
    const c = AnalyticsCardConfig(
      AnalyticsCardType.trendLine,
      x: 0,
      y: 2,
      w: 6,
      h: 3,
      comparePrevious: true,
    );
    final again = AnalyticsCardConfig.decode(c.encode());
    expect(again?.type, AnalyticsCardType.trendLine);
    expect(again?.y, 2);
    expect(again?.comparePrevious, isTrue);
  });

  test('grid_reflow accepts analytics bounds', () {
    final items = defaultPersonalLayout().map((c) => c.toBounds()).toList();
    expect(items, isNotEmpty);
    final moved = placeGridItem(
      items: items,
      id: items.first.id,
      x: 0,
      y: 0,
      w: items.first.w,
      h: items.first.h,
      columns: 6,
    );
    expect(moved, isNotEmpty);
  });

  test('in_memory layout repo roundtrip', () async {
    final repo = InMemoryAnalyticsLayoutRepository();
    final layout = defaultGroupLayout();
    await repo.save(AnalyticsSurface.groupStats, layout);
    final loaded = await repo.load(AnalyticsSurface.groupStats);
    expect(loaded.length, layout.length);
  });

  test('AnalyticsPeriod year and previous range', () {
    final p = const AnalyticsPeriod(
      AnalyticsPeriodKind.week,
      compare: AnalyticsCompare.previousEqualLength,
    );
    final now = DateTime(2026, 7, 15, 12);
    final (from, to) = p.range(now: now);
    final prev = p.previousRange(now: now);
    expect(prev, isNotNull);
    expect(from.isBefore(to) || from.isAtSameMomentAs(to), isTrue);
    expect(prev!.$2.isBefore(from) || prev.$2.isAtSameMomentAs(from), isTrue);
  });

  test('full catalog has 22 types', () {
    expect(AnalyticsCardType.values.length, 22);
  });
}
