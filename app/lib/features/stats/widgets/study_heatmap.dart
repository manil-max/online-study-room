import 'package:flutter/material.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/study_session.dart';

const _kMonths = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];

/// GitHub tarzı çalışma yoğunluğu ısı haritası (yalnızca görsel — başlık/Card
/// çağıran tarafta). Sütunlar haftaları, satırlar haftanın günlerini gösterir;
/// renk koyuluğu o günkü süreyle artar. Her hücre dokunulabilir (tarih + süre).
class StudyHeatmap extends StatelessWidget {
  const StudyHeatmap({
    super.key,
    required this.sessions,
    this.weeks = 15,
  });

  final List<StudySession> sessions;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = dailyTotals(sessions);
    final maxSeconds = totals.values.fold<int>(0, (m, v) => v > m ? v : m);

    final today = dayOf(DateTime.now());
    final firstMonday =
        startOfWeek(today).subtract(Duration(days: (weeks - 1) * 7));

    const cell = 13.0;
    const gap = 3.0;

    int levelOf(int seconds) {
      if (seconds <= 0) return 0;
      if (maxSeconds <= 0) return 1;
      final r = seconds / maxSeconds;
      if (r <= 0.25) return 1;
      if (r <= 0.5) return 2;
      if (r <= 0.75) return 3;
      return 4;
    }

    Color colorFor(int level) {
      if (level == 0) return theme.colorScheme.surfaceContainerHighest;
      const alphas = [0.25, 0.45, 0.7, 1.0];
      return theme.colorScheme.primary.withValues(alpha: alphas[level - 1]);
    }

    final columns = <Widget>[];
    var prevMonth = -1;
    for (var w = 0; w < weeks; w++) {
      final weekStart = firstMonday.add(Duration(days: w * 7));
      final showMonth = weekStart.month != prevMonth;
      prevMonth = weekStart.month;

      final cells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        final isFuture = day.isAfter(today);
        final seconds = totals[day] ?? 0;
        cells.add(Padding(
          padding: const EdgeInsets.only(bottom: gap),
          child: isFuture
              ? const SizedBox(width: cell, height: cell)
              : Tooltip(
                  message:
                      '${day.day} ${_kMonths[day.month - 1]} · ${formatHuman(seconds)}',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Container(
                    width: cell,
                    height: cell,
                    decoration: BoxDecoration(
                      color: colorFor(levelOf(seconds)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
        ));
      }

      columns.add(Padding(
        padding: const EdgeInsets.only(right: gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 14,
              child: showMonth
                  ? Text(_kMonths[weekStart.month - 1],
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant))
                  : null,
            ),
            ...cells,
          ],
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // en yeni haftalar (sağ) öncelikli görünür
          child: Row(children: columns),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Az',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 6),
            for (var l = 0; l <= 4; l++) ...[
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: colorFor(l),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 3),
            ],
            const SizedBox(width: 3),
            Text('Çok',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
