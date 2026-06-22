import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/daily_bar_chart.dart';
import '../dashboard_card.dart';

/// Günlük çalışma süresi çubuk grafiği (§3.9/§3.11 kart). Dönem filtresi (7/14/30
/// gün) satır içinde seçilebilir; toplamı da gösterir.
class WeeklyChartCard extends ConsumerStatefulWidget {
  const WeeklyChartCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  ConsumerState<WeeklyChartCard> createState() => _WeeklyChartCardState();
}

class _WeeklyChartCardState extends ConsumerState<WeeklyChartCard> {
  late int _days = widget.size == DashboardCardSize.large ? 14 : 7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
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
                  Text('Çalışma grafiği', style: theme.textTheme.titleMedium),
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
            _DayFilter(
              value: _days,
              options: const [7, 14, 30],
              onChanged: (v) => setState(() => _days = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: isLarge ? 220 : 160,
              child: DailyBarChart(days: series, goalSeconds: goalSeconds),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gün-aralığı filtresi (kart içi küçük segment butonu).
class _DayFilter extends StatelessWidget {
  const _DayFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<int>(
        segments: [
          for (final o in options)
            ButtonSegment(value: o, label: Text('$o gün')),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
