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

    test('previous equal-length period abuts current', () {
      final sel = StatsPeriodSelection(
        period: StatsPeriod.custom,
        customFrom: DateTime(2026, 7, 1),
        customTo: DateTime(2026, 7, 10),
        comparePrevious: true,
      );
      final (from, to) = sel.range(now: now);
      final prev = sel.previousRange(now: now);
      expect(prev, isNotNull);
      final (pf, pt) = prev!;
      expect(to.difference(from).inSeconds, pt.difference(pf).inSeconds);
      expect(pt.isBefore(from), isTrue);
    });

    test('compare off → previous null', () {
      const sel = StatsPeriodSelection(period: StatsPeriod.week);
      expect(sel.previousRange(now: now), isNull);
    });
  });
}
