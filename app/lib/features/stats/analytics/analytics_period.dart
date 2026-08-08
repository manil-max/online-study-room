import '../../../core/stats/istanbul_calendar.dart';
import '../../../core/stats/stats_period.dart';

/// WP-163: genişletilmiş dönem (year + custom + kıyas).
enum AnalyticsPeriodKind { today, week, month, year, all, custom }

class AnalyticsPeriod {
  const AnalyticsPeriod(
    this.kind, {
    this.customFrom,
    this.customTo,
    this.offset = 0,
  });

  final AnalyticsPeriodKind kind;
  final DateTime? customFrom;
  final DateTime? customTo;

  /// 🔴 WP-561: WP-554 ile gelen dönem gezinmesi bu katmana hiç taşınmıyordu;
  /// "Geçen hafta" başlığının altında **bu haftanın** toplamı çıkıyordu.
  /// `==`/`hashCode`'a dâhildir — aksi hâlde family provider cache'i iki farklı
  /// dönemi aynı anahtarda toplar ve yanlış veri servis eder.
  final int offset;

  static const week = AnalyticsPeriod(AnalyticsPeriodKind.week);

  @override
  bool operator ==(Object other) =>
      other is AnalyticsPeriod &&
      other.kind == kind &&
      other.customFrom == customFrom &&
      other.customTo == customTo &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(kind, customFrom, customTo, offset);

  (DateTime from, DateTime to) range({DateTime? now}) {
    final n = now ?? DateTime.now();
    return switch (kind) {
      AnalyticsPeriodKind.today => _stats(StatsPeriod.today).range(now: n),
      AnalyticsPeriodKind.week => _stats(StatsPeriod.week).range(now: n),
      AnalyticsPeriodKind.month => _stats(StatsPeriod.month).range(now: n),
      AnalyticsPeriodKind.year => _stats(StatsPeriod.year).range(now: n),
      AnalyticsPeriodKind.all => StatsPeriod.all.range(now: n),
      AnalyticsPeriodKind.custom => (
        customFrom ?? istanbulDay(n),
        customTo ?? n,
      ),
    };
  }

  StatsPeriodSelection _stats(StatsPeriod p) =>
      StatsPeriodSelection(period: p, offset: offset);
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
    // WP-561: gezinme (WP-554 okları) buradan geçmeden analytics katmanına
    // ulaşamıyordu.
    offset: s.supportsNavigation ? s.offset : 0,
  );
}
