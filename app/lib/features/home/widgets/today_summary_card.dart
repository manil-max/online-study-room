import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';

/// Bugünün özeti: toplam süre + ders bazında oransal dağılım (§3.9 kart).
class TodaySummaryCard extends ConsumerWidget {
  const TodaySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];
    final now = DateTime.now();
    final today = sessions.where((s) => isSameDay(s.day, now)).toList();
    final total = totalSeconds(today);
    final breakdown = subjectBreakdown(today);

    Subject? subjectFor(String? id) {
      for (final s in subjects) {
        if (s.id == id) return s;
      }
      return null;
    }

    final maxSeconds =
        breakdown.isEmpty ? 1 : breakdown.first.value.clamp(1, 1 << 30);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Bugün özeti', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  formatHuman(total),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (breakdown.isEmpty)
              Text(
                'Bugün henüz çalışma kaydın yok. Sayaçtan başla!',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final entry in breakdown) ...[
                Builder(
                  builder: (_) {
                    final subject = subjectFor(entry.key);
                    final name = subject?.name ?? 'Genel';
                    final color = subject != null
                        ? subjectColor(subject.color)
                        : theme.colorScheme.onSurfaceVariant;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(radius: 5, backgroundColor: color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(name,
                                  style: theme.textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              formatHuman(entry.value),
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: entry.value / maxSeconds,
                            minHeight: 8,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ],
          ],
        ),
      ),
    );
  }
}
