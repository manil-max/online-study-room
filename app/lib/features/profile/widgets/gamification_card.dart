import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/level_curve.dart';
import '../../../core/stats/progression_visuals.dart';
import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/gamification_providers.dart';
import '../../../data/providers/study_providers.dart';
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
                  AppLocalizations.of(
                    context,
                  ).profileBasarilarGirisYaptiktanSonra,
                  style: theme.textTheme.bodyMedium,
                );
              }
              final sessions =
                  ref.watch(userSessionsProvider).asData?.value ?? const [];
              final now = DateTime.now();
              final todaySec = secondsOnDay(sessions, now);
              final weekSec =
                  totalSeconds(inRange(sessions, startOfWeek(now), now));
              return _SummaryContent(
                summary: summary,
                quests: buildQuestStatuses(
                  todaySeconds: todaySec,
                  weekSeconds: weekSec,
                ),
              );
            },
            loading: () => Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Text(
              AppLocalizations.of(context).profileBasarilarYuklenemedi,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary, required this.quests});

  final GamificationSummary summary;
  final List<QuestStatus> quests;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final rank = summary.profile.crownRank;
    final rankColor = crownColorFor(rank, theme.colorScheme);
    final bar = xpBarMetrics(summary.profile.xp);
    final lvl = levelProgress(summary.profile.xp);
    final frameUnlocked =
        isFrameUnlocked(xp: summary.profile.xp, requiredLevel: 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: theme.colorScheme.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).profileBasarilar,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(l10n.profileLevel(lvl.level)),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                Icons.workspace_premium_outlined,
                size: 18,
                color: rankColor,
              ),
              label: Text(_crownLabel(l10n, rank)),
            ),
            Icon(Icons.chevron_right),
          ],
        ),
        SizedBox(height: 10),
        // WP-154: seviye çubuğu (türetilmiş; XP server-authoritative kalır)
        Text(
          l10n.profileLevel(lvl.level),
          style: theme.textTheme.labelMedium,
        ),
        SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: lvl.progress,
            minHeight: 8,
            color: theme.colorScheme.tertiary,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${summary.profile.xp} XP → ${lvl.nextXp}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: bar.progress,
            minHeight: 6,
            color: rankColor,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${summary.profile.xp} / ${bar.next} XP',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 12),
        Text(l10n.profileQuests, style: theme.textTheme.titleSmall),
        SizedBox(height: 6),
        for (final q in quests)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              q.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: q.done
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            title: Text(switch (q.id) {
              QuestId.dailyLogin => l10n.questDailyLogin,
              QuestId.weeklyFiveHours => l10n.questWeeklyHours,
            }),
            trailing: Text(
              q.done ? l10n.questClaimed : '${q.progress}/${q.target}',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            frameUnlocked ? Icons.portrait : Icons.lock_outline,
          ),
          title: Text(l10n.cosmeticsFrame),
          trailing: Text(
            frameUnlocked ? l10n.cosmeticsUnlocked : l10n.questLocked,
            style: theme.textTheme.labelSmall,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricChip(
              icon: Icons.local_fire_department_outlined,
              label: l10n.profileSummaryfreezeawarestreakstreakGunSeri(
                '${summary.freezeAwareStreak.streak}',
              ),
            ),
            _MetricChip(
              icon: Icons.shield_outlined,
              label: l10n.profileSummaryprofilestreakfreezesKorumaHakki(
                '${summary.profile.streakFreezes}',
              ),
            ),
            _MetricChip(
              icon: Icons.timer_outlined,
              label: formatHuman(summary.totalSeconds),
            ),
          ],
        ),
        SizedBox(height: 10),
        Text(
          l10n.profileRozetlerinSerilerinVeIlerlemen,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

String _crownLabel(AppLocalizations l10n, String rank) {
  return switch (normalizeCrownRank(rank)) {
    'diamond_owl' => l10n.coreElmasTac,
    'platinum_scholar' => l10n.corePlatinTac,
    'gold_achiever' => l10n.coreAltinTac,
    'silver_learner' => l10n.coreGumusTac,
    _ => l10n.coreBronzTac,
  };
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
