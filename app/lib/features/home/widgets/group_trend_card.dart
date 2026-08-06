import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../classroom/widgets/class_switcher.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/daily_bar_chart.dart';
import '../dashboard_card.dart';
import 'card_scaffold.dart';
import 'card_data_gate.dart';
import 'group_card_shell.dart';

/// "Grup günlük trendi" kartı (§3.11): grubun son günlerdeki toplam çalışma
/// çubuk grafiği. Büyük boyutta 14 gün.
class GroupTrendCard extends ConsumerWidget {
  const GroupTrendCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupAsync = ref.watch(userGroupProvider);
    // WP-495B: yükleniyorken davet değil iskelet (bkz. `groupCardGate`).
    final gate = groupCardGate(
      context,
      groupAsync,
      title: AppLocalizations.of(context).homeGrupGunlukTrendi,
      onCreateGroup: () => createGroupFlow(context, ref),
      onJoinGroup: () => joinGroupFlow(context, ref),
    );
    if (gate != null) return gate;
    final group = groupAsync.value!;

    final statsAsync = ref.watch(groupDailyStatsProvider);
    // WP-495C: istatistik gelmeden trend düz çizgi çizer.
    final dataGate = cardDataGate(
      context,
      title: AppLocalizations.of(context).homeGrupGunlukTrendi,
      sources: [statsAsync],
    );
    if (dataGate != null) return dataGate;
    final stats = statsAsync.value!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 280;
        final isLarge = constraints.maxWidth >= 400;
        final days = isLarge ? 14 : (isCompact ? 7 : 10);

        final series = lastNDays(const [], days, totals: groupDayTotals(stats));
        final total = series.fold<int>(0, (s, d) => s + d.seconds);

        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).homeGrupGunlukTrendi,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isCompact)
                  Text(
                    formatHuman(total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            if (isCompact) ...[
              const SizedBox(height: 4),
              Text(
                formatHuman(total),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        );

        return CardScaffold(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          header: header,
          bodyBuilder: (context, bodyHeight) => SizedBox(
            height: bodyHeight,
            child: DailyBarChart(
              days: series,
              goalSeconds: group.dailyGoalMinutes * 60,
            ),
          ),
        );
      },
    );
  }
}
