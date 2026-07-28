import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/stats/study_stats.dart';

void main() {
  group('StatsPeriodSelection (WP-178)', () {
    final now = DateTime(2026, 7, 18, 15, 30);

    test('year range uses calendar year start Istanbul day', () {
      final sel = const StatsPeriodSelection(period: StatsPeriod.year);
      final (from, to) = sel.range(now: now);
      expect(from, startOfYear(now));
      expect(dayOf(to), dayOf(now));
    });

    test('custom range preserved and ordered', () {
      final a = DateTime(2026, 1, 10);
      final b = DateTime(2026, 3, 5);
      final sel = StatsPeriodSelection(
        period: StatsPeriod.custom,
        customFrom: b,
        customTo: a,
      );
      final (from, to) = sel.range(now: now);
      expect(from, dayOf(a));
      expect(to, dayOf(b));
    });
  });
}
