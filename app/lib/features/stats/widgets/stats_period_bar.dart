import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/stats_period.dart';
import '../../../data/providers/stats_period_provider.dart';

/// Üst dönem seçici: Bugün / Hafta / Ay / Tümü.
class StatsPeriodBar extends ConsumerWidget {
  const StatsPeriodBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Center(
        child: SegmentedButton<StatsPeriod>(
          segments: [
            for (final p in StatsPeriod.values)
              ButtonSegment(value: p, label: Text(p.labelTr)),
          ],
          selected: {period},
          onSelectionChanged: (s) =>
              ref.read(statsPeriodProvider.notifier).set(s.first),
          showSelectedIcon: false,
        ),
      ),
    );
  }
}
