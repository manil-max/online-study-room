import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/stats/stats_period.dart';

/// Kişisel + Grup istatistik sekmeleri için ortak dönem + kıyas (WP-178).
class StatsPeriodNotifier extends Notifier<StatsPeriodSelection> {
  @override
  StatsPeriodSelection build() => const StatsPeriodSelection();

  void setPeriod(StatsPeriod period) {
    state = state.copyWith(period: period);
  }

  /// Eski API uyumu (sadece kind).
  void set(StatsPeriod period) => setPeriod(period);

  void setComparePrevious(bool value) {
    state = state.copyWith(comparePrevious: value);
  }

  void setCustomRange(DateTime from, DateTime to) {
    final a = from.isBefore(to) ? from : to;
    final b = from.isBefore(to) ? to : from;
    state = state.copyWith(
      period: StatsPeriod.custom,
      customFrom: a,
      customTo: b,
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
