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
