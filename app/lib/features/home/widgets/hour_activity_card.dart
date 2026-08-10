import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/hour_activity_chart.dart';
import '../dashboard_card.dart';
import 'card_data_gate.dart';
import 'card_scaffold.dart';

/// "Çalışma saatleri" kartı (§3.11): günün hangi saatlerinde çalıştığını gösterir.
/// Büyük boyutta daha uzun grafik.
class HourActivityCard extends ConsumerWidget {
  const HourActivityCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    // WP-495C: yükleniyorken boş saat dağılımı yanlış iddiadır.
    final gate = cardDataGate(
      context,
      title: AppLocalizations.of(context).homeCalismaSaatleri,
      sources: [sessionsAsync],
    );
    if (gate != null) return gate;
    final sessions = sessionsAsync.value!;
    final hourly = hourlyTotals(sessions);

    return CardScaffold(
      // 🔴 WP-659 — burada çıplak `Text` vardı (satır sayısı sınırsız).
      // Ölçüldü: 160×160 hücrede "Çalışma saatleri" başlığı **72 px**e (üç
      // satıra) sarıyor, gövdeye 128 px'lik kutudan 36 px kalıyor ve grafiğin
      // sabit parçaları (tepe satırı + saat ekseni ≈ 44 px) taşıyordu:
      // `RenderFlex overflowed by 8.0 px` (yazı ölçeği 1.3'te 16 px, 1.6'da
      // 44 px). Bu kaydırma değil düpedüz KIRPMA — kullanıcı kesilen kısmı
      // hiçbir şekilde göremiyordu.
      //
      // `CardScaffold` başlığa 44 px ayırır (`cardShouldFill` → headerReserve);
      // o rezerv **tek satırlık** başlık varsayar. `cardTitle` tam bu yüzden
      // var: tek satır + ellipsis.
      header: cardTitle(context, AppLocalizations.of(context).homeCalismaSaatleri),
      bodyBuilder: (context, bodyHeight) =>
          HourActivityChart(hourly: hourly, height: bodyHeight),
    );
  }
}
