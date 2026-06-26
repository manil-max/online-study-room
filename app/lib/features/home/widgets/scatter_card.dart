import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/session_scatter_chart.dart';
import '../dashboard_card.dart';

/// "Oturum dağılımı" kartı (§3.11): son günlerdeki her oturum bir nokta
/// (x = gün, y = süre, renk = ders). Büyük boyutta daha geniş aralık + uzun grafik.
class ScatterCard extends ConsumerWidget {
  const ScatterCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 280;
          final isLarge = constraints.maxWidth >= 400;
          
          final chartHeight = isLarge ? 240.0 : (isCompact ? 140.0 : 190.0);
          final days = isLarge ? 60 : (isCompact ? 14 : 30);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Oturum dağılımı', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Her nokta bir çalışma oturumu (süre/gün)',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  SessionScatterChart(
                    sessions: sessions,
                    days: days,
                    height: chartHeight,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
