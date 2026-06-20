import 'package:flutter/material.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/study_session.dart';

/// Kişisel istatistik özeti: dönem toplamları, günlük ortalama ve
/// hafta içi / hafta sonu ayrımı. Grafikler Faz 3b'de eklenecek.
class PersonalStatsView extends StatelessWidget {
  const PersonalStatsView({super.key, required this.sessions});

  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final today = secondsOnDay(sessions, now);
    final thisWeek = totalSeconds(inRange(sessions, startOfWeek(now), now));
    final thisMonth = totalSeconds(inRange(sessions, startOfMonth(now), now));
    final thisYear = totalSeconds(inRange(sessions, startOfYear(now), now));

    // Son 30 günün günlük ortalaması (çalışılmayan günler de paydada).
    final avg30 = dailyAverageSeconds(
      sessions,
      dayOf(now).subtract(const Duration(days: 29)),
      now,
    );

    // Hafta içi / hafta sonu ayrımı (son 30 gün).
    final last30 = inRange(
      sessions,
      dayOf(now).subtract(const Duration(days: 29)),
      now,
    );
    final split = weekdayWeekendSplit(last30);

    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timelapse,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('Henüz çalışma kaydın yok',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Sınıf sekmesinden çalışmaya başlayınca istatistiklerin burada görünecek.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Dönem toplamları', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Bugün', seconds: today)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(label: 'Bu hafta', seconds: thisWeek)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Bu ay', seconds: thisMonth)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(label: 'Bu yıl', seconds: thisYear)),
          ],
        ),
        const SizedBox(height: 16),
        Text('Son 30 gün', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _StatCard(
          label: 'Günlük ortalama',
          seconds: avg30.round(),
          icon: Icons.trending_up,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Hafta içi',
                seconds: split.weekday,
                icon: Icons.work_outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Hafta sonu',
                seconds: split.weekend,
                icon: Icons.weekend_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tek bir istatistik kartı (etiket + süre).
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.seconds,
    this.icon,
  });

  final String label;
  final int seconds;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(formatHuman(seconds), style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
