import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/stats/stats_period.dart';

/// Kişisel + Grup istatistik sekmeleri ve 7/14/30 seçiciler için ortak dönem.
class StatsPeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => StatsPeriod.week;

  void set(StatsPeriod period) => state = period;
}

final statsPeriodProvider =
    NotifierProvider<StatsPeriodNotifier, StatsPeriod>(StatsPeriodNotifier.new);
