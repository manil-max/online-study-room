import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/study_providers.dart';
import '../dashboard_card.dart';

/// Hafta içi (Pzt–Cum) ile hafta sonu (Cmt–Paz) çalışma kıyası (§3.11 kart).
class WeekdayWeekendCard extends ConsumerWidget {
  const WeekdayWeekendCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    final split = weekdayWeekendSplit(sessions);
    final max = (split.weekday > split.weekend ? split.weekday : split.weekend)
        .clamp(1, 1 << 30);
    final weekdayColor = subjectColor('chart-1');
    final weekendColor = subjectColor('chart-4');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hafta içi / hafta sonu',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _Bar(
              label: 'Hafta içi',
              seconds: split.weekday,
              fraction: split.weekday / max,
              color: weekdayColor,
            ),
            const SizedBox(height: 12),
            _Bar(
              label: 'Hafta sonu',
              seconds: split.weekend,
              fraction: split.weekend / max,
              color: weekendColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.seconds,
    required this.fraction,
    required this.color,
  });

  final String label;
  final int seconds;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(formatHuman(seconds),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
