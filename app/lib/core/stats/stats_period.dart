import 'study_stats.dart';

/// İstatistik / grup ortak dönem filtresi.
/// WP-178: +year +custom; kıyas [StatsPeriodSelection.comparePrevious].
enum StatsPeriod { today, week, month, year, all, custom }

/// Üst bar + özel aralık + kıyas state (WP-178).
class StatsPeriodSelection {
  const StatsPeriodSelection({
    this.period = StatsPeriod.week,
    this.customFrom,
    this.customTo,
    this.comparePrevious = false,
  });

  final StatsPeriod period;
  final DateTime? customFrom;
  final DateTime? customTo;
  final bool comparePrevious;

  StatsPeriodSelection copyWith({
    StatsPeriod? period,
    DateTime? customFrom,
    DateTime? customTo,
    bool? comparePrevious,
    bool clearCustom = false,
  }) {
    return StatsPeriodSelection(
      period: period ?? this.period,
      customFrom: clearCustom ? null : (customFrom ?? this.customFrom),
      customTo: clearCustom ? null : (customTo ?? this.customTo),
      comparePrevious: comparePrevious ?? this.comparePrevious,
    );
  }

  (DateTime from, DateTime to) range({DateTime? now}) {
    final n = now ?? DateTime.now();
    return switch (period) {
      StatsPeriod.today => (dayOf(n), n),
      StatsPeriod.week => (startOfWeek(n), n),
      StatsPeriod.month => (startOfMonth(n), n),
      StatsPeriod.year => (startOfYear(n), n),
      StatsPeriod.all => (DateTime(2000), n),
      StatsPeriod.custom => () {
          final a = dayOf(customFrom ?? n);
          final b = dayOf(customTo ?? n);
          return a.isBefore(b) || a.isAtSameMomentAs(b) ? (a, b) : (b, a);
        }(),
    };
  }

  /// Önceki eşit uzunlukta dönem (kıyas açıkken).
  (DateTime from, DateTime to)? previousRange({DateTime? now}) {
    if (!comparePrevious) return null;
    final (from, to) = range(now: now);
    final len = to.difference(from);
    if (len.inSeconds <= 0) return null;
    final prevTo = from.subtract(const Duration(seconds: 1));
    final prevFrom = prevTo.subtract(len);
    return (prevFrom, prevTo);
  }
}

extension StatsPeriodX on StatsPeriod {
  /// Dönem aralığı (from, to) — Istanbul gün sınırı.
  /// [custom] için [StatsPeriodSelection.range] kullan.
  (DateTime from, DateTime to) range({DateTime? now}) {
    return StatsPeriodSelection(period: this).range(now: now);
  }

  /// 7 / 14 / 30 gün seçicilere eşleme (varsa en yakın).
  int chartDays({List<int> options = const [7, 14, 30]}) {
    final preferred = switch (this) {
      StatsPeriod.today => 7,
      StatsPeriod.week => 7,
      StatsPeriod.month => 30,
      StatsPeriod.year => 30,
      StatsPeriod.all => options.isEmpty ? 30 : options.last,
      StatsPeriod.custom => 30,
    };
    if (options.isEmpty) return preferred;
    if (options.contains(preferred)) return preferred;
    return options.reduce(
      (a, b) => (a - preferred).abs() <= (b - preferred).abs() ? a : b,
    );
  }
}
