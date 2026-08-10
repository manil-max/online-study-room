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
            //
            // 🔴 WP-643 ölçümü (düzeltilmedi, ayrı WP): `StudyHeatmap`in hücre
            // ölçüsü SABİT (13 px) ve boyu 7 satır + gösterge = ~154 px, yani
            // kart ne kadar uzatılırsa uzatılsın içerik boyu DEĞİŞMEZ. Kısa
            // hücrede dikey kaydırıcı bu yüzden açık kalıyor (160 px yüksek
            // hücrede 70 px, 194 px'te 36 px pay; 265 px ve üstünde 0).
            // `rhythm_card`taki ölçekleme çözümü buraya doğrudan uymuyor:
            // `StudyHeatmap` kendi içinde yatay bir `SingleChildScrollView`
            // (reverse) taşıyor ve dar hücrede doğal genişliğine ihtiyaç
            // duyuyor; genişliği hücreye sabitlemek `RenderFlex` taşması
            // üretiyor. Doğru düzeltme `study_heatmap.dart`ta (bu lane'in
            // SAHİP yolu değil).
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
