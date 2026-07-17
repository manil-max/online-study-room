import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/study_stats.dart';
import '../../../data/providers/analytics_period_provider.dart';
import 'analytics_period.dart';

/// WP-164: flag açıkken today/week/month/year/all/custom + kıyas.
class AnalyticsPeriodBar extends ConsumerWidget {
  const AnalyticsPeriodBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final period = ref.watch(analyticsPeriodProvider);
    final notifier = ref.read(analyticsPeriodProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final kind in AnalyticsPeriodKind.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: Semantics(
                      button: true,
                      selected: period.kind == kind,
                      label: _kindLabel(l10n, kind),
                      child: FilterChip(
                        label: Text(_kindLabel(l10n, kind)),
                        selected: period.kind == kind,
                        onSelected: (_) async {
                          if (kind == AnalyticsPeriodKind.custom) {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 1),
                              ),
                              initialDateRange: DateTimeRange(
                                start: period.customFrom ??
                                    dayOf(DateTime.now())
                                        .subtract(const Duration(days: 6)),
                                end: period.customTo ?? dayOf(DateTime.now()),
                              ),
                            );
                            if (range != null) {
                              notifier.setCustomRange(
                                dayOf(range.start),
                                dayOf(range.end),
                              );
                            }
                          } else {
                            notifier.setKind(kind);
                          }
                        },
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        visualDensity: VisualDensity.standard,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            toggled: period.compare == AnalyticsCompare.previousEqualLength,
            label: l10n.analyticsComparePrevious,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.analyticsComparePrevious),
              value: period.compare == AnalyticsCompare.previousEqualLength,
              onChanged: (v) => notifier.setCompare(
                v
                    ? AnalyticsCompare.previousEqualLength
                    : AnalyticsCompare.none,
              ),
            ),
          ),
          if (period.kind == AnalyticsPeriodKind.custom &&
              period.customFrom != null &&
              period.customTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${_fmt(period.customFrom!)} – ${_fmt(period.customTo!)}',
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  static String _kindLabel(AppLocalizations l10n, AnalyticsPeriodKind k) {
    return switch (k) {
      AnalyticsPeriodKind.today => l10n.statsBugun,
      AnalyticsPeriodKind.week => l10n.statsHafta,
      AnalyticsPeriodKind.month => l10n.statsAy,
      AnalyticsPeriodKind.year => l10n.analyticsYear,
      AnalyticsPeriodKind.all => l10n.statsTumu,
      AnalyticsPeriodKind.custom => l10n.analyticsCustomRange,
    };
  }

  static String _fmt(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
