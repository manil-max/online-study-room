import '../../core/stats/stats_period.dart';
import '../../l10n/app_localizations.dart';

String statsPeriodLabel(AppLocalizations l10n, StatsPeriod period) =>
    switch (period) {
      StatsPeriod.today => l10n.statsBugun,
      StatsPeriod.week => l10n.statsHafta,
      StatsPeriod.month => l10n.statsAy,
      StatsPeriod.all => l10n.statsTumu,
    };
