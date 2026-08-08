import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/study_heatmap.dart';
import '../dashboard_card.dart';
import 'card_data_gate.dart';
import 'card_scaffold.dart';

/// GitHub tarzı çalışma yoğunluğu ısı haritası kartı (§3.11). Boyut, gösterilen
/// hafta sayısını belirler (küçük 9, orta 15, büyük 26 hafta).
class HeatmapCard extends ConsumerWidget {
  const HeatmapCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    // WP-495C: veri gelmeden boş ısı haritası çizmek "hiç çalışmamışsın" der.
    final gate = cardDataGate(
      context,
      title: AppLocalizations.of(context).homeCalismaTakvimi,
      sources: [sessionsAsync],
    );
    if (gate != null) return gate;
    final sessions = sessionsAsync.value!;

    return CardScaffold(
      header: cardTitle(
        context,
        AppLocalizations.of(context).homeCalismaTakvimi,
      ),
      bodyBuilder: (context, bodyHeight) => SizedBox(
        height: bodyHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Her hafta ortalama 18px yer kaplıyor (kutu + boşluk + eksen).
            final weeks = ((constraints.maxWidth - 40) / 18).floor().clamp(
              4,
              52,
            );
            // Dikey + yatay kaydırma → kısa/dar hücrede taşma olmaz (§2E).
            // WP-508: ısı haritası gerçekten taşabilir, o yüzden kaydırma
            // korunur — ama yalnız taşma varken; sığdığında iki eksende de
            // sürükleme dış sayfaya bırakılır.
            return cardScrollIfOverflows(
              child: cardScrollIfOverflows(
                axis: Axis.horizontal,
                child: StudyHeatmap(sessions: sessions, weeks: weeks),
              ),
            );
          },
        ),
      ),
    );
  }
}
