import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';
import '../../../data/providers/stats_period_provider.dart';
import '../stats_l10n.dart';
import 'draggable_date_range_picker.dart';

/// Zamanda gezinmenin geriye açık penceresi (yıl). `_pickCustom` bu sayıyı
/// zaten kullanıyordu; dört seçici de aynı sınırı paylaşır ki bir dönemde
/// ulaşılabilen tarih diğerinde ulaşılamaz olmasın.
const int kStatsNavYearsBack = 5;

/// Hafta seçicideki satır sayısı — [kStatsNavYearsBack] yılı kapsar.
///
/// Sayı `difference().inDays` ile HESAPLANMAZ: yaz saati uygulayan bölgede iki
/// yerel gece yarısının arası 23/25 saattir ve tam bölme kenarda bir hafta
/// kaybettirir. Kapsam yaklaşık olduğu için sabit yeterlidir.
const int _kWeekChoices = kStatsNavYearsBack * 53;

/// Dönem şeridinin ALTINDAKİ gezinme çubuğu (WP-743).
///
///     [ ‹ ]   [  Başlık / altbaşlık  🗓  ]   [ › ]
///
/// Şerit (bkz. `stats_period_bar.dart`) yalnız dönem TÜRÜNÜ seçer; "hangi
/// gün/hafta/ay/yıl" sorusunun tek cevap yeri burasıdır. Ortadaki başlık bir
/// düğmedir ve döneme uygun seçiciyi açar.
///
/// [clock] yalnız test enjeksiyonu içindir (desen: `CampfireScene.clock`);
/// üretimde `DateTime.now` kullanılır.
class StatsRangeNavigator extends ConsumerWidget {
  const StatsRangeNavigator({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(statsPeriodProvider);
    // "Tümü" başlangıçtan bugüne tek bir aralıktır; gezinilecek bir yer yok.
    if (sel.period == StatsPeriod.all) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final now = (clock ?? DateTime.now)();
    final navigable = sel.supportsNavigation;
    final isDay = sel.period == StatsPeriod.day;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (navigable)
            _PeriodNavButton(
              icon: Icons.chevron_left,
              label: isDay ? l10n.statsOncekiGun : l10n.statsPeriodPrevious,
              onTap: () => ref.read(statsPeriodProvider.notifier).shift(-1),
            ),
          Flexible(
            child: _PeriodPickerButton(
              title: statsPeriodNavTitle(l10n, sel, now: now),
              subtitle: statsPeriodNavSubtitle(l10n, sel, now: now),
              onTap: () => _openPicker(context, ref, sel, now, l10n),
            ),
          ),
          if (navigable)
            _PeriodNavButton(
              icon: Icons.chevron_right,
              label: isDay ? l10n.statsSonrakiGun : l10n.statsPeriodNext,
              // 🔴 Geleceğe bakılmaz. Buton GİZLENMEZ, devre dışı kalır;
              // gizlenen kontrol kullanıcıya "sınırdayım" demez.
              onTap: sel.canGoForward
                  ? () => ref.read(statsPeriodProvider.notifier).shift(1)
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    WidgetRef ref,
    StatsPeriodSelection sel,
    DateTime now,
    AppLocalizations l10n,
  ) async {
    switch (sel.period) {
      case StatsPeriod.day:
        await _pickDay(context, ref, sel, now, l10n);
      case StatsPeriod.week:
        await _pickWeek(context, ref, sel, now, l10n);
      case StatsPeriod.month:
        await _pickMonth(context, ref, sel, now, l10n);
      case StatsPeriod.year:
        await _pickYear(context, ref, sel, now, l10n);
      case StatsPeriod.custom:
        await pickStatsCustomRange(context, ref, sel, now: now);
      case StatsPeriod.all:
        // Çubuk bu dönemde hiç çizilmiyor; dal yalnız switch'i kapatır.
        break;
    }
  }
}

/// Gün → Flutter'ın kendi takvimi. Diğer üçü için hazır bir seçici yok, o
/// yüzden aşağıda elle kuruluyor.
Future<void> _pickDay(
  BuildContext context,
  WidgetRef ref,
  StatsPeriodSelection sel,
  DateTime now,
  AppLocalizations l10n,
) async {
  final today = dayOf(now);
  final (from, _) = sel.range(now: now);
  final picked = await showDatePicker(
    context: context,
    initialDate: from.isAfter(today) ? today : from,
    firstDate: DateTime(now.year - kStatsNavYearsBack),
    // 🔴 Gelecek seçilemez.
    lastDate: today,
    helpText: l10n.statsTarihSec,
    builder: (_, child) =>
        KeyedSubtree(key: const Key('statsDayPicker'), child: child!),
  );
  if (picked == null) return;
  ref.read(statsPeriodProvider.notifier).jumpTo(picked, now: now);
}

Future<void> _pickWeek(
  BuildContext context,
  WidgetRef ref,
  StatsPeriodSelection sel,
  DateTime now,
  AppLocalizations l10n,
) async {
  final thisMonday = startOfWeek(now);
  final (selectedMonday, _) = sel.range(now: now);
  final fmt = DateFormat.MMMd(l10n.localeName);

  final picked = await showDialog<DateTime>(
    context: context,
    builder: (ctx) => _PickerDialog(
      key: const Key('statsWeekPicker'),
      title: l10n.statsHaftaSec,
      body: ListView.builder(
        itemCount: _kWeekChoices,
        itemBuilder: (_, i) {
          // Bugünü içeren haftadan GERİYE doğru; ileri gidilemez.
          final monday = DateTime(
            thisMonday.year,
            thisMonday.month,
            thisMonday.day - 7 * i,
          );
          final sunday = DateTime(monday.year, monday.month, monday.day + 6);
          final selected = monday == selectedMonday;
          return ListTile(
            key: Key('statsWeekPickerRow_$i'),
            dense: true,
            selected: selected,
            title: Text('${fmt.format(monday)} – ${fmt.format(sunday)}'),
            trailing: selected ? const Icon(Icons.check, size: 18) : null,
            onTap: () => Navigator.pop(ctx, monday),
          );
        },
      ),
    ),
  );
  if (picked == null) return;
  ref.read(statsPeriodProvider.notifier).jumpTo(picked, now: now);
}

Future<void> _pickMonth(
  BuildContext context,
  WidgetRef ref,
  StatsPeriodSelection sel,
  DateTime now,
  AppLocalizations l10n,
) async {
  final today = dayOf(now);
  final firstYear = today.year - kStatsNavYearsBack;
  final (selectedFrom, _) = sel.range(now: now);
  final fmt = DateFormat.MMM(l10n.localeName);
  var year = selectedFrom.year;

  final picked = await showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => _PickerDialog(
        key: const Key('statsMonthPicker'),
        title: l10n.statsAySec,
        header: Row(
          children: [
            IconButton(
              key: const Key('statsMonthPickerYearPrev'),
              icon: const Icon(Icons.chevron_left),
              tooltip: l10n.statsPeriodPrevious,
              onPressed: year > firstYear
                  ? () => setState(() => year -= 1)
                  : null,
            ),
            Expanded(
              child: Text(
                '$year',
                key: const Key('statsMonthPickerYear'),
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('statsMonthPickerYearNext'),
              icon: const Icon(Icons.chevron_right),
              tooltip: l10n.statsPeriodNext,
              // 🔴 İçinde bulunulan yıldan sonrası yok.
              onPressed: year < today.year
                  ? () => setState(() => year += 1)
                  : null,
            ),
          ],
        ),
        body: GridView.count(
          crossAxisCount: 3,
          childAspectRatio: 2,
          children: [
            for (var m = 1; m <= 12; m++)
              _MonthCell(
                key: Key('statsMonthPickerCell_$m'),
                label: fmt.format(DateTime(year, m)),
                selected: selectedFrom.year == year && selectedFrom.month == m,
                // Bu yılın GELECEK ayları seçilemez.
                onTap: (year < today.year || m <= today.month)
                    ? () => Navigator.pop(ctx, DateTime(year, m))
                    : null,
              ),
          ],
        ),
      ),
    ),
  );
  if (picked == null) return;
  ref.read(statsPeriodProvider.notifier).jumpTo(picked, now: now);
}

/// Yıl → yalnız yıl listesi. Takvim GÖSTERİLMEZ: "2024'e bak" diyen kullanıcıya
/// gün seçtirmek fazladan iki karar demek.
Future<void> _pickYear(
  BuildContext context,
  WidgetRef ref,
  StatsPeriodSelection sel,
  DateTime now,
  AppLocalizations l10n,
) async {
  final today = dayOf(now);
  final (selectedFrom, _) = sel.range(now: now);

  final picked = await showDialog<int>(
    context: context,
    builder: (ctx) => _PickerDialog(
      key: const Key('statsYearPicker'),
      title: l10n.statsYilSec,
      body: ListView(
        children: [
          for (var y = today.year; y >= today.year - kStatsNavYearsBack; y--)
            ListTile(
              key: Key('statsYearPickerRow_$y'),
              dense: true,
              selected: y == selectedFrom.year,
              title: Text('$y'),
              trailing: y == selectedFrom.year
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () => Navigator.pop(ctx, y),
            ),
        ],
      ),
    ),
  );
  if (picked == null) return;
  ref.read(statsPeriodProvider.notifier).jumpTo(DateTime(picked), now: now);
}

/// Özel aralık seçicisi. Hem gezinme çubuğundaki başlık düğmesi hem de dönem
/// şeridindeki "Özel" chip'i buraya gelir: chip'e basıp aralığı SEÇMEDEN kalmak
/// kullanıcıya sessizce "bugün"ü gösterirdi.
Future<void> pickStatsCustomRange(
  BuildContext context,
  WidgetRef ref,
  StatsPeriodSelection sel, {
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final range = await showDialog<DateTimeRange>(
    context: context,
    builder: (_) => DraggableDateRangePickerDialog(
      firstDate: DateTime(at.year - kStatsNavYearsBack),
      lastDate: dayOf(at),
      initialRange: DateTimeRange(
        start: sel.customFrom ?? startOfMonth(at),
        end: sel.customTo ?? dayOf(at),
      ),
    ),
  );
  if (range == null) return;
  ref.read(statsPeriodProvider.notifier).setCustomRange(range.start, range.end);
}

/// Hafta/ay/yıl seçicilerinin ortak kabuğu.
///
/// 🔴 Alttan açılan pencere (bottom sheet) KULLANILMAZ: `Scaffold.bottomSheet`
/// bu repoda gövdeyi örten bilinen bir tuzak ve §3.12 açılır seçimlerin
/// basılan yerde açılmasını ister. `showAnchoredMenu` de bu üçü için uygun
/// değil — `PopupMenuEntry` listesi düz bir menüdür: içinde yıl gezinen bir
/// ızgara barındıramaz, kaydırma konumu denetlenemez ve her dokunuşta kapanır.
/// Dört seçicinin dördü de diyalog olunca davranış da tek tip kalıyor
/// (`showDatePicker` zaten diyalog).
class _PickerDialog extends StatelessWidget {
  const _PickerDialog({
    super.key,
    required this.title,
    required this.body,
    this.header,
  });

  final String title;
  final Widget body;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 300,
        height: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?header,
            Expanded(child: body),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).classroomVazgec),
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface.withValues(
                        alpha: enabled ? 1 : 0.38,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ortadaki başlık **düğmedir**: dokununca döneme uygun seçici açılır.
class _PeriodPickerButton extends StatelessWidget {
  const _PeriodPickerButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('statsPeriodPickerButton'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        key: const Key('statsPeriodNavTitle'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          key: const Key('statsPeriodNavSubtitle'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dönem gezinme oku. Dokunma hedefi **48dp** (Material minimumu).
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
