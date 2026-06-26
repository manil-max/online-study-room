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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 280;
          final isLarge = constraints.maxWidth >= 400;
          final chartHeight = isLarge ? 220.0 : (isCompact ? 140.0 : 160.0);

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
                        Text('Çalışma grafiği', style: theme.textTheme.titleMedium),
                        const Spacer(),
                        if (isCompact)
                          _DayFilter(
                            value: _days,
                            options: const [7, 14, 30],
                            onChanged: (v) => setState(() => _days = v),
                            isCompact: true,
                          ),
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
                    _DayFilter(
                      value: _days,
                      options: const [7, 14, 30],
                      onChanged: (v) => setState(() => _days = v),
                      isCompact: false,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: chartHeight,
                    child: DailyBarChart(days: series, goalSeconds: goalSeconds),
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

/// Gün-aralığı filtresi (kart içi küçük segment butonu veya dropdown).
class _DayFilter extends StatelessWidget {
  const _DayFilter({
    required this.value,
    required this.options,
    required this.onChanged,
    required this.isCompact,
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return DropdownButton<int>(
        value: value,
        isDense: true,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.arrow_drop_down, size: 20),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o, child: Text('$o gün')),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
    }
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
