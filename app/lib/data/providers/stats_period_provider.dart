import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/stats/stats_period.dart';
import '../../core/stats/study_stats.dart';

/// Kişisel + Grup istatistik sekmeleri için ortak dönem (WP-178).
class StatsPeriodNotifier extends Notifier<StatsPeriodSelection> {
  @override
  StatsPeriodSelection build() => const StatsPeriodSelection();

  void setPeriod(StatsPeriod period) {
    // WP-554: dönem türü değişince gezinme her zaman "içinde bulunulan
    // döneme" döner; aksi hâlde Hafta'da -3 iken Ay'a basınca sessizce
    // 3 ay öncesi açılırdı.
    state = state.copyWith(period: period, offset: 0);
  }

  /// Eski API uyumu (sadece kind).
  void set(StatsPeriod period) => setPeriod(period);

  /// WP-554: seçili dönem türünde [delta] kadar ileri/geri git (-1 = önceki).
  /// Gelecek yok — [StatsPeriodSelection.shifted] 0'da kırpar.
  void shift(int delta) {
    state = state.shifted(delta);
  }

  /// WP-742: seçili dönem TÜRÜNÜ koruyarak [date]i İÇEREN döneme atlar
  /// (takvim düğmesinin model karşılığı). `all` / `custom` sessiz no-op'tur;
  /// o dönemlerde "kaçıncı dönem" tanımlı değildir.
  ///
  /// Gelecek yok: sonuç pozitifse [StatsPeriodSelection.shifted] ile aynı
  /// sözleşmeye uyup `0`a kırpılır.
  ///
  /// [now] enjekte edilebilir — test gerçek saate bağlanmasın.
  void jumpTo(DateTime date, {DateTime? now}) {
    if (!state.supportsNavigation) return;
    final target = dayOf(date);
    final base = dayOf(now ?? DateTime.now());
    final delta = switch (state.period) {
      StatsPeriod.day => _dayNumber(target) - _dayNumber(base),
      StatsPeriod.week => _mondayNumber(target) - _mondayNumber(base),
      StatsPeriod.month =>
        (target.year * 12 + target.month) - (base.year * 12 + base.month),
      StatsPeriod.year => target.year - base.year,
      StatsPeriod.all || StatsPeriod.custom => 0,
    };
    state = state.copyWith(offset: delta > 0 ? 0 : delta);
  }

  void setCustomRange(DateTime from, DateTime to) {
    final a = from.isBefore(to) ? from : to;
    final b = from.isBefore(to) ? to : from;
    state = state.copyWith(
      period: StatsPeriod.custom,
      customFrom: a,
      customTo: b,
      offset: 0,
    );
  }
}

/// Bir gün anahtarının takvim gün numarası (1970-01-01 = 0).
///
/// 🔴 WP-742: gün/hafta farkı `a.difference(b).inDays` ile HESAPLANMAZ.
/// [dayOf] cihazın **yerel** gece yarısını üretir; yaz saati uygulayan bir
/// bölgede iki yerel gece yarısının arası 23 ya da 25 saattir ve `inDays`
/// tam bölme yaptığı için 23 saati `0` güne yuvarlar. Ayrıca `date` bir gün
/// anahtarı değil de gün ortası bir "an" olarak gelirse kısmî gün farkı
/// tamamen kaybolur (14 saat geriye → `inDays == 0`, doğrusu `-1`).
///
/// Çözüm: bileşenler `DateTime.utc` ile yeniden kurulur — UTC'de her gün tam
/// 24 saattir, bölme kesin sonuç verir. `floor` negatif tarafta da doğrudur
/// (`~/` sıfıra doğru kırpar).
int _dayNumber(DateTime dayKey) =>
    (DateTime.utc(
              dayKey.year,
              dayKey.month,
              dayKey.day,
            ).millisecondsSinceEpoch /
            Duration.millisecondsPerDay)
        .floor();

/// Pazartesi başlangıçlı hafta numarası. 1970-01-01 Perşembeydi, yani gün
/// numarası `+3` kaydırılınca Pazartesi hafta sınırına oturur.
///
/// `study_stats.startOfWeek` burada kasten kullanılmadı: o yardımcı
/// `Duration(days: …)` çıkarır ve yaz saati geçişinin olduğu haftada gece
/// yarısını kaçırır (ayrı bulgu, bu WP'nin kapsamı dışında).
int _mondayNumber(DateTime dayKey) => ((_dayNumber(dayKey) + 3) / 7).floor();

final statsPeriodProvider =
    NotifierProvider<StatsPeriodNotifier, StatsPeriodSelection>(
      StatsPeriodNotifier.new,
    );

/// Kind-only okuma kolaylığı (eski switch'ler için).
extension StatsPeriodSelectionWatch on StatsPeriodSelection {
  StatsPeriod get kind => period;
}
