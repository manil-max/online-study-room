import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/stats/stats_period.dart';

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

final statsPeriodProvider =
    NotifierProvider<StatsPeriodNotifier, StatsPeriodSelection>(
      StatsPeriodNotifier.new,
    );

/// Kind-only okuma kolaylığı (eski switch'ler için).
extension StatsPeriodSelectionWatch on StatsPeriodSelection {
  StatsPeriod get kind => period;
}
