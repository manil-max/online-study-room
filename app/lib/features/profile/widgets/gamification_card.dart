import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/gamification.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/gamification_providers.dart';

class GamificationCard extends ConsumerWidget {
  const GamificationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(gamificationSummaryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: summaryAsync.when(
          data: (summary) {
            if (summary == null) {
              return Text(
                'Başarılar giriş yaptıktan sonra görünür.',
                style: theme.textTheme.bodyMedium,
              );
            }
            return _SummaryContent(summary: summary);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(
            'Başarılar yüklenemedi.',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary});

  final GamificationSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = summary.achievements.where((a) => a.unlocked).toList();
    final locked = summary.achievements.where((a) => !a.unlocked).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Başarılar', style: theme.textTheme.titleMedium),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.workspace_premium_outlined, size: 18),
              label: Text(summary.crownTier.label),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricChip(
              icon: Icons.local_fire_department_outlined,
              label: '${summary.freezeAwareStreak.streak} gün seri',
            ),
            _MetricChip(
              icon: Icons.shield_outlined,
              label: '${summary.profile.streakFreezes} koruma hakkı',
            ),
            _MetricChip(
              icon: Icons.timer_outlined,
              label: formatHuman(summary.totalSeconds),
            ),
          ],
        ),
        if (summary.freezeAwareStreak.freezesUsed > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${summary.freezeAwareStreak.freezesUsed} boş gün seri korumasıyla köprülendi.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '${summary.unlockedAchievementCount}/${summary.achievements.length} başarım açık',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final achievement in unlocked)
              _AchievementChip(achievement: achievement),
            for (final achievement in locked.take(2))
              _AchievementChip(achievement: achievement),
          ],
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.achievement});

  final AchievementStatus achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = achievement.unlocked
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = achievement.unlocked
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Tooltip(
      message: achievement.description,
      child: Chip(
        backgroundColor: color,
        avatar: Icon(
          achievement.unlocked
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          size: 18,
          color: textColor,
        ),
        label: Text(achievement.title, style: TextStyle(color: textColor)),
      ),
    );
  }
}
