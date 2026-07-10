import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/study_heatmap.dart';
import '../dashboard_card.dart';
import 'card_scaffold.dart';

/// GitHub tarzı çalışma yoğunluğu ısı haritası kartı (§3.11). Boyut, gösterilen
/// hafta sayısını belirler (küçük 9, orta 15, büyük 26 hafta).
class HeatmapCard extends ConsumerWidget {
  const HeatmapCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(userSessionsProvider).value ?? const [];

    return CardScaffold(
      header: cardTitle(context, 'Çalışma takvimi'),
      bodyBuilder: (context, bodyHeight) => SizedBox(
        height: bodyHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Her hafta ortalama 18px yer kaplıyor (kutu + boşluk + eksen).
            final weeks =
                ((constraints.maxWidth - 40) / 18).floor().clamp(4, 52);
            // Dikey + yatay kaydırma → kısa/dar hücrede taşma olmaz (§2E).
            return SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: StudyHeatmap(sessions: sessions, weeks: weeks),
              ),
            );
          },
        ),
      ),
    );
  }
}
