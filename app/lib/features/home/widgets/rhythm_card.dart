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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 🔴 WP-643 kök neden. Burada iç içe iki `cardScrollIfOverflows`
            // vardı (dikey + yatay). Yatay kaydırıcı çocuğuna **sınırsız**
            // genişlik verir; `WeekHourHeatmap` ise hücre boyutunu
            // `constraints.maxWidth`ten türetir ve sınırsız genişlikte
            // `320.0` SABİT yedeğine düşer. Sonuç: ızgara kartın gerçek
            // genişliğini hiç kullanmıyor, ölçüsü kart büyüdükçe DEĞİŞMİYOR
            // ve dikey kaydırıcı her boyutta ayakta kalıyordu — sahibin
            // "kartı ne kadar büyütürsem büyüteyim gene var" dediği tam bu.
            // Ölçüm (WP-643 envanteri): içerik boyu 328×160'ta da 328×265'te
            // de 258 px sabit; dikey kaydırma payı 174 px ve 69 px.
            // Üstelik yatay kaydırıcı da payı sıfırdan büyükte kalıyordu
            // (328 px kartta 32 px), yani kart iki eksende birden jest yutuyordu.
            //
            // Isı haritası bir **desendir**: parça parça kaydırılarak değil
            // bütün hâlinde okunur. Bu yüzden çözüm kaydırma değil ölçekleme:
            // sığıyorsa olduğu gibi, sığmıyorsa küçülerek çizilir. Kartta hiç
            // `Scrollable` kalmadığı için dikey sürükleme her zaman dış
            // sayfaya gider (WP-508'in aradığı davranış), taşan içerik de
            // kırpılmaz (WP-497 geri gelmez) — yalnız küçülür.
            const minWidth = 30.0 + 24 * (6.0 + 2.0); // etiket + en küçük hücre
            final available = constraints.maxWidth;
            final width = available.isFinite && available > minWidth
                ? available
                : minWidth;
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: WeekHourHeatmap(grid: weekdayHourTotals(sessions)),
              ),
            );
          },
        ),
      ),
    );
  }
}
