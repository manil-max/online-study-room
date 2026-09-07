import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/session_scatter_chart.dart';
import '../dashboard_card.dart';
import 'card_data_gate.dart';
import 'card_scaffold.dart';

/// "Oturum dağılımı" kartı (§3.11): son günlerdeki her oturum bir nokta
/// (x = gün, y = süre, renk = ders). Büyük boyutta daha geniş aralık + uzun grafik.
class ScatterCard extends ConsumerWidget {
  const ScatterCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    // WP-495C: yükleniyorken boş dağılım yanlış iddiadır.
    final gate = cardDataGate(
      context,
      title: AppLocalizations.of(context).homeOturumDagilimi,
      sources: [sessionsAsync],
    );
    if (gate != null) return gate;
    final sessions = sessionsAsync.value!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 280;
        final isLarge = constraints.maxWidth >= 400;
        final days = isLarge ? 60 : (isCompact ? 14 : 30);

        // 🔴 WP-799: basligin altina AYNI l10n anahtari
        // (`homeOturumDagilimi`) ikinci kez yaziliyordu -- ekranda "Oturum
        // dagilimi" alt alta iki kez gorunuyordu. Baslik tek ve ortak
        // sozlesmeden gelir ([cardTitle]: titleMedium + tek satir + ellipsis).
        final header = cardTitle(
          context,
          AppLocalizations.of(context).homeOturumDagilimi,
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
