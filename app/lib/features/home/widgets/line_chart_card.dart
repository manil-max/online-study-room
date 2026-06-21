import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/daily_line_chart.dart';
import '../dashboard_card.dart';

/// Günlük çalışma eğilimini çizgi grafikle gösterir (§3.11 kart). Dönem filtresi
/// (14/30/90 gün) satır içinde seçilebilir.
class LineChartCard extends ConsumerStatefulWidget {
  const LineChartCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  ConsumerState<LineChartCard> createState() => _LineChartCardState();
}

class _LineChartCardState extends ConsumerState<LineChartCard> {
  late int _days = widget.size == DashboardCardSize.large ? 30 : 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    final isLarge = widget.size == DashboardCardSize.large;
    final series = lastNDays(sessions, _days);
    final total = series.fold<int>(0, (sum, d) => sum + d.seconds);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text('Eğilim', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    formatHuman(total),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 14, label: Text('14 gün')),
                  ButtonSegment(value: 30, label: Text('30 gün')),
                  ButtonSegment(value: 90, label: Text('90 gün')),
                ],
                selected: {_days},
                onSelectionChanged: (s) => setState(() => _days = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: isLarge ? 220 : 160,
              child: DailyLineChart(days: series),
            ),
          ],
        ),
      ),
    );
  }
}
