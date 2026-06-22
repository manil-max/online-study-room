import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/study_records.dart';
import '../dashboard_card.dart';

/// "Rekorlar" kartı (§3.11): toplam, rekor seri, en verimli gün, aktif gün,
/// en çok çalışılan ders — renkli stat döşemeleri.
class RecordsCard extends ConsumerWidget {
  const RecordsCard({super.key, this.size = DashboardCardSize.medium});

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
            Text('Rekorlar', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            StudyRecords(sessions: sessions),
          ],
        ),
      ),
    );
  }
}
