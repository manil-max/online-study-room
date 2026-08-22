import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/stats_period.dart';
import '../../../data/providers/stats_period_provider.dart';
import '../stats_l10n.dart';
import 'stats_range_navigator.dart';

/// Üst dönem seçici (WP-190): GERÇEKTEN tek yatay satır.
///
/// Chip'ler Wrap ile kırılmaz — sığmazsa yatay kaydırılır.
///
/// WP-743: şerit yalnız dönem TÜRÜNÜ seçer. Gezinme okları ve "nerede
/// olduğunu" söyleyen başlık buradan çıktı, altındaki `StatsRangeNavigator`a
/// taşındı; chip artık her zaman düz dönem adını yazar.
class StatsPeriodBar extends ConsumerWidget {
  const StatsPeriodBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(statsPeriodProvider);
    final l10n = AppLocalizations.of(context);

    final periods = <StatsPeriod>[
      ...StatsPeriod.values.where((p) => p != StatsPeriod.custom),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 2),
      child: SizedBox(
        height: 44,
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
                  onTap: () =>
                      ref.read(statsPeriodProvider.notifier).setPeriod(p),
                ),
              ],
              const SizedBox(width: 6),
              _PeriodChip(
                label: l10n.analyticsCustomRange,
                selected: sel.period == StatsPeriod.custom,
                // Diğer chip'lerden farkı: "Özel" tek başına bir dönem
                // tarif etmez, o yüzden aralık seçicisini de açar. Aynı
                // seçici gezinme çubuğundaki takvim düğmesinden de gelir.
                onTap: () => pickStatsCustomRange(context, ref, sel),
              ),
            ],
          ),
        ),
      ),
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
