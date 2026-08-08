import 'study_stats.dart';

/// İstatistik / grup ortak dönem filtresi.
/// WP-178: +year +custom.
enum StatsPeriod { today, week, month, year, all, custom }

/// Üst bar + özel aralık state (WP-178).
///
/// WP-554: [offset] ile geçmiş dönemlere tek dokunuşla gidilebilir. Önceden
/// "geçen hafta"ya bakmanın tek yolu Özel → takvim → iki ucu ayrı ayrı sürükle
/// zinciriydi (en az 5 etkileşim).
class StatsPeriodSelection {
  const StatsPeriodSelection({
    this.period = StatsPeriod.week,
    this.customFrom,
    this.customTo,
    this.offset = 0,
  });

  final StatsPeriod period;
  final DateTime? customFrom;
  final DateTime? customTo;

  /// Kaçıncı dönemdeyiz: `0` = içinde bulunduğumuz dönem, `-1` = bir önceki,
  /// `-2` = iki önceki… **Pozitif değer yoktur**: geleceğe bakılmaz, [shifted]
  /// 0'da durur. Yalnız [supportsNavigation] doğruysa anlamlıdır.
  final int offset;

  StatsPeriodSelection copyWith({
    StatsPeriod? period,
    DateTime? customFrom,
    DateTime? customTo,
    bool clearCustom = false,
    int? offset,
  }) {
    return StatsPeriodSelection(
      period: period ?? this.period,
      customFrom: clearCustom ? null : (customFrom ?? this.customFrom),
      customTo: clearCustom ? null : (customTo ?? this.customTo),
      offset: offset ?? this.offset,
    );
  }

  /// İleri/geri gezinme yalnız sabit uzunluklu takvim dönemlerinde anlamlı.
  /// `today` günün canlı toplamı, `all` başlangıçtan bugüne, `custom` zaten
  /// kullanıcının çizdiği aralıktır — hiçbirinde "bir önceki" tanımlı değil.
  bool get supportsNavigation =>
      period == StatsPeriod.week ||
      period == StatsPeriod.month ||
      period == StatsPeriod.year;

  /// Geçmişin sonu yok; geri ok gezinilebilir dönemlerde hep açık.
  bool get canGoBack => supportsNavigation;

  /// 🔴 Gelecek yok: içinde bulunduğumuz dönemdeyken (`offset == 0`) ileri ok
  /// **devre dışıdır** (gizlenmez — kullanıcı sınırda olduğunu görmeli).
  bool get canGoForward => supportsNavigation && offset < 0;

  /// [delta] kadar kaydırılmış seçim. Gezinilemeyen dönemde aynen döner,
  /// geleceğe taşarsa 0'da kırpılır.
  StatsPeriodSelection shifted(int delta) {
    if (!supportsNavigation) return this;
    final next = offset + delta;
    return copyWith(offset: next > 0 ? 0 : next);
  }

  (DateTime from, DateTime to) range({DateTime? now}) {
    final n = now ?? DateTime.now();
    if (offset != 0 && supportsNavigation) {
      final (from, endExclusive) = _shiftedBounds(n);
      // Geçmiş dönem kapalıdır: `to` dönemin son anıdır, "şimdi" değil.
      return (from, endExclusive.subtract(const Duration(milliseconds: 1)));
    }
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

  /// Kaydırılmış dönemin [from, endExclusive) sınırları. Takvim aritmetiği
  /// `DateTime` taşma normalleştirmesiyle yapılır (Aralık + 1 → Ocak).
  (DateTime from, DateTime endExclusive) _shiftedBounds(DateTime n) {
    switch (period) {
      case StatsPeriod.week:
        final s = startOfWeek(n);
        final from = DateTime(s.year, s.month, s.day + 7 * offset);
        return (from, DateTime(from.year, from.month, from.day + 7));
      case StatsPeriod.month:
        final from = DateTime(n.year, n.month + offset, 1);
        return (from, DateTime(from.year, from.month + 1, 1));
      case StatsPeriod.year:
        final from = DateTime(n.year + offset, 1, 1);
        return (from, DateTime(from.year + 1, 1, 1));
      case StatsPeriod.today:
      case StatsPeriod.all:
      case StatsPeriod.custom:
        // `supportsNavigation` bu dalları zaten eler; savunma amaçlı.
        final d = dayOf(n);
        return (d, DateTime(d.year, d.month, d.day + 1));
    }
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
