import 'study_stats.dart';

/// İstatistik / grup ortak dönem filtresi (Bugün · Hafta · Ay · Tümü).
enum StatsPeriod { today, week, month, all }

extension StatsPeriodX on StatsPeriod {
  String get labelTr => switch (this) {
        StatsPeriod.today => 'Bugün',
        StatsPeriod.week => 'Hafta',
        StatsPeriod.month => 'Ay',
        StatsPeriod.all => 'Tümü',
      };

  /// Dönem aralığı (from, to) — Istanbul gün sınırı.
  (DateTime from, DateTime to) range({DateTime? now}) {
    final n = now ?? DateTime.now();
    return switch (this) {
      StatsPeriod.today => (dayOf(n), n),
      StatsPeriod.week => (startOfWeek(n), n),
      StatsPeriod.month => (startOfMonth(n), n),
      // "Tümü": sıcak pencere / tüm mevcut detay (2000 başlangıç sentinel).
      StatsPeriod.all => (DateTime(2000), n),
    };
  }

  /// 7 / 14 / 30 gün seçicilere eşleme (varsa en yakın).
  /// today→7, week→7, month→30, all→30 (veya options içindeki max).
  int chartDays({List<int> options = const [7, 14, 30]}) {
    final preferred = switch (this) {
      StatsPeriod.today => 7,
      StatsPeriod.week => 7,
      StatsPeriod.month => 30,
      StatsPeriod.all => options.isEmpty ? 30 : options.last,
    };
    if (options.isEmpty) return preferred;
    if (options.contains(preferred)) return preferred;
    // En yakın seçenek
    return options.reduce(
      (a, b) => (a - preferred).abs() <= (b - preferred).abs() ? a : b,
    );
  }
}
