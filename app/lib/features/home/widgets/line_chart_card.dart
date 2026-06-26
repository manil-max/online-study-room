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
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 280;
          final isLarge = constraints.maxWidth >= 400;
          final chartHeight = isLarge ? 220.0 : (isCompact ? 140.0 : 160.0);

          Widget selector = isCompact
              ? DropdownButton<int>(
                  value: _days,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: const [
                    DropdownMenuItem(value: 14, child: Text('14 gün')),
                    DropdownMenuItem(value: 30, child: Text('30 gün')),
                    DropdownMenuItem(value: 90, child: Text('90 gün')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _days = v);
                  },
                )
              : SegmentedButton<int>(
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
                );

          final series = lastNDays(sessions, _days);
          final total = series.fold<int>(0, (sum, d) => sum + d.seconds);

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Text('Eğilim', style: theme.textTheme.titleMedium),
                        const Spacer(),
                        if (isCompact) selector,
                        if (!isCompact)
                          Text(
                            formatHuman(total),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: theme.colorScheme.primary),
                          ),
                      ],
                    ),
                  ),
                  if (isCompact) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        formatHuman(total),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                  if (!isCompact) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: selector,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: chartHeight,
                    child: DailyLineChart(days: series),
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
