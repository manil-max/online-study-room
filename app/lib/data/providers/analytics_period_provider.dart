import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/stats/analytics/analytics_period.dart';

/// WP-164: flag açıkken genişletilmiş dönem + kıyas.
class AnalyticsPeriodNotifier extends Notifier<AnalyticsPeriod> {
  @override
  AnalyticsPeriod build() => const AnalyticsPeriod(AnalyticsPeriodKind.week);

  void set(AnalyticsPeriod period) => state = period;

  void setKind(AnalyticsPeriodKind kind) {
    state = AnalyticsPeriod(
      kind,
      customFrom: state.customFrom,
      customTo: state.customTo,
      compare: state.compare,
    );
  }

  void setCompare(AnalyticsCompare compare) {
    state = AnalyticsPeriod(
      state.kind,
      customFrom: state.customFrom,
      customTo: state.customTo,
      compare: compare,
    );
  }

  void setCustomRange(DateTime from, DateTime to) {
    state = AnalyticsPeriod(
      AnalyticsPeriodKind.custom,
      customFrom: from,
      customTo: to,
      compare: state.compare,
    );
  }
}

final analyticsPeriodProvider =
    NotifierProvider<AnalyticsPeriodNotifier, AnalyticsPeriod>(
  AnalyticsPeriodNotifier.new,
);
