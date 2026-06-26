import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/study_heatmap.dart';
import '../dashboard_card.dart';

/// GitHub tarzı çalışma yoğunluğu ısı haritası kartı (§3.11). Boyut, gösterilen
/// hafta sayısını belirler (küçük 9, orta 15, büyük 26 hafta).
class HeatmapCard extends ConsumerWidget {
  const HeatmapCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Çalışma takvimi', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Her hafta ortalama 18px yer kaplıyor (kutu + boşluk + eksen).
                  final weeks = ((constraints.maxWidth - 40) / 18).floor().clamp(4, 52);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: StudyHeatmap(sessions: sessions, weeks: weeks),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
