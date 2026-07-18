import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';
import '../../../data/providers/stats_period_provider.dart';
import '../stats_l10n.dart';

/// Üst dönem seçici: Bugün / Hafta / Ay / Yıl / Tümü / Özel + kompakt kıyas (WP-185).
///
/// All ve Custom, Today/Week/Month/Year ile aynı Wrap satırında (6 chip).
/// Kıyas: tam genişlik SwitchListTile yerine minik icon-toggle.
class StatsPeriodBar extends ConsumerWidget {
  const StatsPeriodBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(statsPeriodProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // SegmentedButton 6 dilimde taşar — Wrap + FilterChip.
    // WP-185: All (StatsPeriod.all) ve Custom aynı Wrap'te (6 chip).
    final chips = StatsPeriod.values
        .where((p) => p != StatsPeriod.custom)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final p in chips)
                FilterChip(
                  label: Text(statsPeriodLabel(l10n, p)),
                  selected: sel.period == p,
                  onSelected: (_) =>
                      ref.read(statsPeriodProvider.notifier).setPeriod(p),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              FilterChip(
                label: Text(l10n.analyticsCustomRange),
                selected: sel.period == StatsPeriod.custom,
                onSelected: (_) => _pickCustom(context, ref, sel),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              // WP-185: kompakt kıyas kontrolü — tam satır SwitchListTile yerine.
              Tooltip(
                message: l10n.analyticsComparePrevious,
                child: Semantics(
                  button: true,
                  toggled: sel.comparePrevious,
                  label: l10n.analyticsComparePrevious,
                  child: InkWell(
                    onTap: () => ref
                        .read(statsPeriodProvider.notifier)
                        .setComparePrevious(!sel.comparePrevious),
                    borderRadius: BorderRadius.circular(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sel.comparePrevious
                                ? theme.colorScheme.secondaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel.comparePrevious
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Icon(
                            Icons.compare_arrows,
                            size: 18,
                            color: sel.comparePrevious
                                ? theme.colorScheme.onSecondaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (sel.period == StatsPeriod.custom &&
              sel.customFrom != null &&
              sel.customTo != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
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
