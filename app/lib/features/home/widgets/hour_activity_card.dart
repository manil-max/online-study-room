import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/hour_activity_chart.dart';
import '../dashboard_card.dart';
import 'card_scaffold.dart';

/// "Çalışma saatleri" kartı (§3.11): günün hangi saatlerinde çalıştığını gösterir.
/// Büyük boyutta daha uzun grafik.
class HourActivityCard extends ConsumerWidget {
  const HourActivityCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    final hourly = hourlyTotals(sessions);

    return CardScaffold(
      header: Text(
        AppLocalizations.of(context).homeCalismaSaatleri,
        style: theme.textTheme.titleMedium,
      ),
      bodyBuilder: (context, bodyHeight) =>
          HourActivityChart(hourly: hourly, height: bodyHeight),
    );
  }
}
