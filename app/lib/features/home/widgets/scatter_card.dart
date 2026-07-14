import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/session_scatter_chart.dart';
import '../dashboard_card.dart';
import 'card_scaffold.dart';

/// "Oturum dağılımı" kartı (§3.11): son günlerdeki her oturum bir nokta
/// (x = gün, y = süre, renk = ders). Büyük boyutta daha geniş aralık + uzun grafik.
class ScatterCard extends ConsumerWidget {
  const ScatterCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 280;
        final isLarge = constraints.maxWidth >= 400;
        final days = isLarge ? 60 : (isCompact ? 14 : 30);

        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).homeOturumDagilimi,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).homeOturumDagilimi,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

        return CardScaffold(
          header: header,
          headerGap: 12,
          bodyBuilder: (context, bodyHeight) => SessionScatterChart(
            sessions: sessions,
            days: days,
            height: bodyHeight,
          ),
        );
      },
    );
  }
}
