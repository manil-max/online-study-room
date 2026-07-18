import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';
import '../../../data/providers/stats_period_provider.dart';
import '../stats_l10n.dart';

/// Üst dönem seçici: Bugün / Hafta / Ay / Yıl / Tümü / Özel + kıyas (WP-178).
class StatsPeriodBar extends ConsumerWidget {
  const StatsPeriodBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(statsPeriodProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // SegmentedButton 6 dilimde taşar — Wrap + FilterChip.
    final chips = StatsPeriod.values
        .where((p) => p != StatsPeriod.custom)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final p in chips)
                FilterChip(
                  label: Text(statsPeriodLabel(l10n, p)),
                  selected: sel.period == p,
                  onSelected: (_) =>
                      ref.read(statsPeriodProvider.notifier).setPeriod(p),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                ),
              FilterChip(
                label: Text(l10n.analyticsCustomRange),
                selected: sel.period == StatsPeriod.custom,
                onSelected: (_) => _pickCustom(context, ref, sel),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            dense: true,
            title: Text(
              l10n.analyticsComparePrevious,
              style: theme.textTheme.bodySmall,
            ),
            value: sel.comparePrevious,
            onChanged: (v) =>
                ref.read(statsPeriodProvider.notifier).setComparePrevious(v),
          ),
          if (sel.period == StatsPeriod.custom &&
              sel.customFrom != null &&
              sel.customTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${dayOf(sel.customFrom!)} → ${dayOf(sel.customTo!)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickCustom(
    BuildContext context,
    WidgetRef ref,
    StatsPeriodSelection sel,
  ) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: dayOf(now),
      initialDateRange: DateTimeRange(
        start: sel.customFrom ?? startOfMonth(now),
        end: sel.customTo ?? dayOf(now),
      ),
    );
    if (range == null) return;
    ref.read(statsPeriodProvider.notifier).setCustomRange(
          range.start,
          range.end,
        );
  }
}
