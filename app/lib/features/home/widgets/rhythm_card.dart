import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/week_hour_heatmap.dart';
import '../dashboard_card.dart';
import 'card_data_gate.dart';
import 'card_scaffold.dart';

/// "Haftalık ritim" kartı (§3.11): haftanın hangi gün/saatlerinde çalıştığın
/// (7 gün × 24 saat ısı haritası).
class RhythmCard extends ConsumerWidget {
  const RhythmCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    // WP-495C: yükleniyorken boş ritim ızgarası yanlış iddiadır.
    final gate = cardDataGate(
      context,
      title: AppLocalizations.of(context).homeHaftalikRitim,
      sources: [sessionsAsync],
    );
    if (gate != null) return gate;
    final sessions = sessionsAsync.value!;

    return CardScaffold(
      header: cardTitle(
        context,
        AppLocalizations.of(context).homeHaftalikRitim,
      ),
      bodyBuilder: (context, bodyHeight) => SizedBox(
        height: bodyHeight,
        // Dikey + yatay kaydırma → kısa/dar hücrede taşma olmaz (§2E).
        // WP-508: ritim ızgarası gerçekten taşabilir, kaydırma korunur — ama
        // yalnız taşma varken; sığdığında sürükleme dış sayfaya bırakılır.
        child: cardScrollIfOverflows(
          child: cardScrollIfOverflows(
            axis: Axis.horizontal,
            child: WeekHourHeatmap(grid: weekdayHourTotals(sessions)),
          ),
        ),
      ),
    );
  }
}
