import 'package:intl/intl.dart';

import '../../core/stats/stats_period.dart';
import '../../l10n/app_localizations.dart';

String statsPeriodLabel(AppLocalizations l10n, StatsPeriod period) =>
    switch (period) {
      // WP-742: dönem artık gezinilebildiği için etiket "Bugün" değil "Gün".
      StatsPeriod.day => l10n.statsGun,
      StatsPeriod.week => l10n.statsHafta,
      StatsPeriod.month => l10n.statsAy,
      StatsPeriod.year => l10n.analyticsYear,
      StatsPeriod.all => l10n.statsTumu,
      StatsPeriod.custom => l10n.analyticsCustomRange,
    };

/// Gezinilen dönemin başlığı — "nerede olduğunu bil". `0` ve `-1` için
/// katalogdan konuşma dili ("Bu hafta" / "Geçen ay"); daha eskisi için yerelin
/// kendi takvim biçimi (CLDR), yani ayrıca çeviri gerektirmez.
///
/// WP-743: başlık artık seçili chip'in değil, gezinme çubuğundaki seçici
/// düğmenin metnidir; bu yüzden `day` ve `custom` da gerçek bir başlık üretir
/// (eskiden ikisi de dönem adına düşüyordu, çünkü çubuk çizilmiyordu).
String statsPeriodNavTitle(
  AppLocalizations l10n,
  StatsPeriodSelection sel, {
  DateTime? now,
}) {
  final (from, to) = sel.range(now: now);
  final locale = l10n.localeName;
  switch (sel.period) {
    case StatsPeriod.day:
      if (sel.offset == 0) return l10n.statsBugun;
      if (sel.offset == -1) return l10n.statsDun;
      return DateFormat.yMMMMd(locale).format(from);
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
    case StatsPeriod.custom:
      // Aralık seçilmemişken `range` "bugün → bugün" döner; bu, kullanıcının
      // hiç çizmediği bir aralığı çizilmiş gibi gösterirdi.
      if (sel.customFrom == null || sel.customTo == null) {
        return l10n.analyticsCustomRange;
      }
      final fmt = DateFormat.yMMMd(locale);
      return '${fmt.format(from)} – ${fmt.format(to)}';
    case StatsPeriod.all:
      return statsPeriodLabel(l10n, sel.period);
  }
}

/// Başlığın altındaki küçük ikinci satır. Gün için hafta günü adı, hafta için
/// tam takvim haftasının tarih aralığı; ay/yıl/tümü/özel için boş (başlık
/// zaten tek başına yeterli).
String statsPeriodNavSubtitle(
  AppLocalizations l10n,
  StatsPeriodSelection sel, {
  DateTime? now,
}) {
  final locale = l10n.localeName;
  final (from, _) = sel.range(now: now);
  switch (sel.period) {
    case StatsPeriod.day:
      return DateFormat.EEEE(locale).format(from);
    case StatsPeriod.week:
      // 🔴 `range`in üst ucu içinde bulunulan haftada "şimdi"dir; alt satır
      // ondan üretilseydi bu hafta "17 Ağu – 20 Ağu" yazardı. Alt satır
      // haftanın KENDİSİNİ tarif eder, ne kadarının geçtiğini değil.
      final end = DateTime(from.year, from.month, from.day + 6);
      final fmt = DateFormat.MMMd(locale);
      return '${fmt.format(from)} – ${fmt.format(end)}';
    case StatsPeriod.month:
    case StatsPeriod.year:
    case StatsPeriod.all:
    case StatsPeriod.custom:
      return '';
  }
}
