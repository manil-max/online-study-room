import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/progression_visuals.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/gamification_providers.dart';
import '../social_profile_screen.dart';

/// Profil özeti: XP, taç, seri. Klasik başarımlar burada listelenmez —
/// dokununca [SocialProfileScreen] vitrin/katalog.
class GamificationCard extends ConsumerWidget {
  const GamificationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WP-56: profil açılınca sunucu ledger'ı yeniden değerlendirir.
    ref.watch(gamificationProgressSyncProvider);
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(gamificationSummaryProvider);
    final authProfile = ref.watch(authStateProvider).value;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: authProfile == null
            ? null
            : () => SocialProfileScreen.open(context, authProfile),
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
    final rank = summary.profile.crownRank;
    final rankColor = crownColorFor(rank, theme.colorScheme);
    final bar = xpBarMetrics(summary.profile.xp);

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
              avatar: Icon(
                Icons.workspace_premium_outlined,
                size: 18,
                color: rankColor,
              ),
              label: Text(crownLabelTr(rank)),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: bar.progress,
            minHeight: 8,
            color: rankColor,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${summary.profile.xp} XP · sonraki taç ${bar.next} · saat başına +10 XP',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
        const SizedBox(height: 10),
        Text(
          'Rozetler ve katalog için dokun',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
