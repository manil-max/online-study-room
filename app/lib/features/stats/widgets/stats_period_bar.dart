import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';
import '../../../data/providers/stats_period_provider.dart';
import '../stats_l10n.dart';

/// Üst dönem seçici (WP-190): GERÇEKTEN tek yatay satır.
///
/// Chip'ler Wrap ile kırılmaz — sığmazsa yatay kaydırılır.
/// Kıyas: satır sonunda kompakt `compare_arrows` toggle (ayrı satır yok).
class StatsPeriodBar extends ConsumerWidget {
  const StatsPeriodBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(statsPeriodProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final periods = <StatsPeriod>[
      ...StatsPeriod.values.where((p) => p != StatsPeriod.custom),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tek satır: [scroll chips…] | kıyas
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        for (final p in periods) ...[
                          if (p != periods.first) const SizedBox(width: 6),
                          _PeriodChip(
                            label: statsPeriodLabel(l10n, p),
                            selected: sel.period == p,
                            onTap: () => ref
                                .read(statsPeriodProvider.notifier)
                                .setPeriod(p),
                          ),
                        ],
                        const SizedBox(width: 6),
                        _PeriodChip(
                          label: l10n.analyticsCustomRange,
                          selected: sel.period == StatsPeriod.custom,
                          onTap: () => _pickCustom(context, ref, sel),
                        ),
                      ],
                    ),
                  ),
                ),
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
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: sel.comparePrevious
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: sel.comparePrevious
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Icon(
                              Icons.compare_arrows,
                              size: 18,
                              color: sel.comparePrevious
                                  ? theme.colorScheme.onPrimaryContainer
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
          ),
          if (sel.period == StatsPeriod.custom &&
              sel.customFrom != null &&
              sel.customTo != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
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

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fg = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
