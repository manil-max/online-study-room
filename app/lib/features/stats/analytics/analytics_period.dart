import '../../../core/stats/istanbul_calendar.dart';
import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';

/// WP-163: genişletilmiş dönem (year + custom + kıyas).
enum AnalyticsPeriodKind { today, week, month, year, all, custom }

class AnalyticsPeriod {
  const AnalyticsPeriod(this.kind, {this.customFrom, this.customTo});

  final AnalyticsPeriodKind kind;
  final DateTime? customFrom;
  final DateTime? customTo;

  static const week = AnalyticsPeriod(AnalyticsPeriodKind.week);

  @override
  bool operator ==(Object other) =>
      other is AnalyticsPeriod &&
      other.kind == kind &&
      other.customFrom == customFrom &&
      other.customTo == customTo;

  @override
  int get hashCode => Object.hash(kind, customFrom, customTo);

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
}

/// StatsPeriod → AnalyticsPeriod köprüsü.
AnalyticsPeriod analyticsPeriodFromStats(StatsPeriod p) {
  return switch (p) {
    StatsPeriod.today => const AnalyticsPeriod(AnalyticsPeriodKind.today),
    StatsPeriod.week => const AnalyticsPeriod(AnalyticsPeriodKind.week),
    StatsPeriod.month => const AnalyticsPeriod(AnalyticsPeriodKind.month),
    StatsPeriod.year => const AnalyticsPeriod(AnalyticsPeriodKind.year),
    StatsPeriod.all => const AnalyticsPeriod(AnalyticsPeriodKind.all),
    StatsPeriod.custom => const AnalyticsPeriod(AnalyticsPeriodKind.custom),
  };
}

/// WP-178: StatsPeriodSelection → AnalyticsPeriod.
AnalyticsPeriod analyticsPeriodFromSelection(StatsPeriodSelection s) {
  return AnalyticsPeriod(
    analyticsPeriodFromStats(s.period).kind,
    customFrom: s.customFrom,
    customTo: s.customTo,
  );
}
