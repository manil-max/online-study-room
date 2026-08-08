import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';
import '../../../data/providers/stats_period_provider.dart';
import 'draggable_date_range_picker.dart';
import '../stats_l10n.dart';

/// Üst dönem seçici (WP-190): GERÇEKTEN tek yatay satır.
///
/// Chip'ler Wrap ile kırılmaz — sığmazsa yatay kaydırılır.
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
          // WP-554: gezinme okları şeridin İÇİNDE durur — ikinci bir satır
          // WP-190'ın "tek kompakt satır" sözleşmesini (bar < 90 px) bozardı.
          // Seçili chip aynı zamanda başlıktır: gezinildiğinde "Hafta" yerine
          // "Geçen hafta" / "Mart 2026" yazar, yani kullanıcı nerede olduğunu
          // ekstra satır olmadan görür.
          Row(
            children: [
              if (sel.supportsNavigation)
                _PeriodNavButton(
                  icon: Icons.chevron_left,
                  label: l10n.statsPeriodPrevious,
                  onTap: () => ref.read(statsPeriodProvider.notifier).shift(-1),
                ),
              Expanded(
                // Tek satır: yatay kaydırılabilen dönem chip'leri.
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
                            label: sel.period == p && sel.offset != 0
                                ? statsPeriodNavTitle(context, l10n, sel)
                                : statsPeriodLabel(l10n, p),
                            textKey: sel.period == p
                                ? const Key('statsPeriodNavTitle')
                                : null,
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
              ),
              if (sel.supportsNavigation)
                _PeriodNavButton(
                  icon: Icons.chevron_right,
                  label: l10n.statsPeriodNext,
                  // 🔴 Geleceğe bakılmaz. Buton GİZLENMEZ, devre dışı kalır;
                  // gizlenen kontrol kullanıcıya "sınırdayım" demez.
                  onTap: sel.canGoForward
                      ? () => ref.read(statsPeriodProvider.notifier).shift(1)
                      : null,
                ),
            ],
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
    final range = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => DraggableDateRangePickerDialog(
        firstDate: DateTime(now.year - 5),
        lastDate: dayOf(now),
        initialRange: DateTimeRange(
          start: sel.customFrom ?? startOfMonth(now),
          end: sel.customTo ?? dayOf(now),
        ),
      ),
    );
    if (range == null) return;
    ref
        .read(statsPeriodProvider.notifier)
        .setCustomRange(range.start, range.end);
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.textKey,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Seçili chip aynı zamanda dönem başlığıdır (WP-554); testler metni bu
  /// anahtardan okur.
  final Key? textKey;

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
            key: textKey,
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

/// WP-554: gezinilen dönemin başlığı — "nerede olduğunu bil". `0` ve `-1`
/// için katalogdan konuşma dili ("Bu hafta" / "Geçen ay"); daha eskisi için
/// yerelin kendi takvim biçimi (CLDR), yani ayrıca çeviri gerektirmez.
String statsPeriodNavTitle(
  BuildContext context,
  AppLocalizations l10n,
  StatsPeriodSelection sel, {
  DateTime? now,
}) {
  final (from, to) = sel.range(now: now);
  final locale = l10n.localeName;
  switch (sel.period) {
    case StatsPeriod.week:
      if (sel.offset == 0) return l10n.statsBuHafta;
      if (sel.offset == -1) return l10n.statsGecenHafta;
      final fmt = DateFormat.MMMd(locale);
      return '${fmt.format(from)} – ${fmt.format(to)}';
    case StatsPeriod.month:
      if (sel.offset == 0) return l10n.statsBuAy;
      if (sel.offset == -1) return l10n.statsPeriodLastMonth;
      return DateFormat.yMMMM(locale).format(from);
    case StatsPeriod.year:
      if (sel.offset == 0) return l10n.statsBuYil;
      if (sel.offset == -1) return l10n.statsPeriodLastYear;
      return from.year.toString();
    case StatsPeriod.today:
    case StatsPeriod.all:
    case StatsPeriod.custom:
      // Gezinme bu modlarda kapalı (`supportsNavigation`), şerit çizilmez.
      return statsPeriodLabel(l10n, sel.period);
  }
}

/// Dönem gezinme oku. Dokunma hedefi **48dp** (Material minimumu); repodaki
/// 28/36/40dp hedefler ayrı bir bulgudur, burada tekrarlanmaz.
/// [onTap] `null` ise buton devre dışıdır — görünür kalır, tıklanmaz.
class _PeriodNavButton extends StatelessWidget {
  const _PeriodNavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: Key(
        'statsPeriodNav_${icon == Icons.chevron_left ? 'prev' : 'next'}',
      ),
      icon: Icon(icon),
      iconSize: 22,
      onPressed: onTap,
      tooltip: label,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      visualDensity: VisualDensity.standard,
    );
  }
}
