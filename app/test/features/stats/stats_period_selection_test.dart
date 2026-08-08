import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/stats/study_stats.dart';

void main() {
  group('StatsPeriodSelection (WP-178)', () {
    final now = DateTime(2026, 7, 18, 15, 30);

    // 🔴 WP-561: eski hâli `expect(from, startOfYear(now))` idi — "uygulama =
    // uygulama". Beklentiler artık ELLE hesaplanmış sabitler.
    test('year range uses calendar year start Istanbul day', () {
      final sel = const StatsPeriodSelection(period: StatsPeriod.year);
      final (from, to) = sel.range(now: now);
      expect(from, DateTime(2026, 1, 1));
      expect(dayOf(to), DateTime(2026, 7, 18));
    });

    test('month range: İstanbul ayının 1\'i (cihaz duvar saati değil)', () {
      // 31 Ağustos 21:30 UTC → İstanbul 1 Eylül 00:30.
      final crossing = DateTime.utc(2026, 8, 31, 21, 30);
      final sel = const StatsPeriodSelection(period: StatsPeriod.month);
      expect(sel.range(now: crossing).$1, DateTime(2026, 9, 1));
      expect(dayOf(sel.range(now: crossing).$2), DateTime(2026, 9, 1));
    });

    test('year range: yılbaşını aşan an yeni yılı verir', () {
      final crossing = DateTime.utc(2025, 12, 31, 22);
      final sel = const StatsPeriodSelection(period: StatsPeriod.year);
      expect(sel.range(now: crossing).$1, DateTime(2026, 1, 1));
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
      expect(from, DateTime(2026, 1, 10));
      expect(to, DateTime(2026, 3, 5));
    });
  });
}
