import '../../../core/stats/istanbul_calendar.dart';
import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';

/// WP-163: genişletilmiş dönem (year + custom + kıyas).
enum AnalyticsPeriodKind { today, week, month, year, all, custom }

class AnalyticsPeriod {
  const AnalyticsPeriod(
    this.kind, {
    this.customFrom,
    this.customTo,
    this.compare = AnalyticsCompare.none,
  });

  final AnalyticsPeriodKind kind;
  final DateTime? customFrom;
  final DateTime? customTo;
  final AnalyticsCompare compare;

  static const week = AnalyticsPeriod(AnalyticsPeriodKind.week);

  (DateTime from, DateTime to) range({DateTime? now}) {
    final n = now ?? DateTime.now();
    return switch (kind) {
      AnalyticsPeriodKind.today => StatsPeriod.today.range(now: n),
      AnalyticsPeriodKind.week => StatsPeriod.week.range(now: n),
      AnalyticsPeriodKind.month => StatsPeriod.month.range(now: n),
      AnalyticsPeriodKind.year => (startOfYear(n), n),
      AnalyticsPeriodKind.all => StatsPeriod.all.range(now: n),
      AnalyticsPeriodKind.custom => (
          customFrom ?? istanbulDay(n),
          customTo ?? n,
        ),
    };
  }

  /// Önceki eşit uzunlukta dönem (kıyas).
  (DateTime from, DateTime to)? previousRange({DateTime? now}) {
    if (compare == AnalyticsCompare.none) return null;
    final (from, to) = range(now: now);
    final len = to.difference(from);
    final prevTo = from.subtract(const Duration(seconds: 1));
    final prevFrom = prevTo.subtract(len);
    return (prevFrom, prevTo);
  }
}

enum AnalyticsCompare { none, previousEqualLength }

/// StatsPeriod → AnalyticsPeriod köprüsü (flag geçişi).
AnalyticsPeriod analyticsPeriodFromStats(StatsPeriod p) {
  return switch (p) {
    StatsPeriod.today => const AnalyticsPeriod(AnalyticsPeriodKind.today),
    StatsPeriod.week => const AnalyticsPeriod(AnalyticsPeriodKind.week),
    StatsPeriod.month => const AnalyticsPeriod(AnalyticsPeriodKind.month),
    StatsPeriod.all => const AnalyticsPeriod(AnalyticsPeriodKind.all),
  };
}
