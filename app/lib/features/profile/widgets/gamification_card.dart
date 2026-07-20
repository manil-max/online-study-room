import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/achievement_ledger_engine.dart';
import '../../../core/stats/progression_visuals.dart';
import '../../../core/widgets/crowned_avatar.dart';
import '../../../data/models/achievement.dart';
import '../../../data/models/gamification_profile.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/gamification_providers.dart';
import '../social_profile_screen.dart';
import 'achievement_showcase.dart';

/// Profil özeti: taç + taç XP barı + başarım rozetleri (WP-187/192).
///
/// Level/quest/streak/freeze/total UI yok. Backend XP'ye yazılmaz —
/// yalnız görüntü (`xpBarMetrics` + sunucu profil XP).
class GamificationCard extends ConsumerWidget {
  const GamificationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gamificationProgressSyncProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authProfile = ref.watch(authStateProvider).value;
    final summaryAsync = ref.watch(gamificationSummaryProvider);

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
              if (summary == null || authProfile == null) {
                return Text(
                  l10n.profileBasarilarGirisYaptiktanSonra,
                  style: theme.textTheme.bodyMedium,
                );
              }
              final achsAsync = ref.watch(
                userAchievementsProvider(authProfile.id),
              );
              return achsAsync.when(
                data: (achs) => _BadgeSummary(
                  displayName: authProfile.displayName,
                  avatarUrl: authProfile.avatarUrl,
                  profile: summary.profile,
                  achievements: achs,
                ),
                loading: () => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) => _BadgeSummary(
                  displayName: authProfile.displayName,
                  avatarUrl: authProfile.avatarUrl,
                  profile: summary.profile,
                  achievements: const [],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Text(
              l10n.profileBasarilarYuklenemedi,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeSummary extends StatelessWidget {
  const _BadgeSummary({
    required this.displayName,
    this.avatarUrl,
    required this.profile,
    required this.achievements,
  });

  final String displayName;
  final String? avatarUrl;
  final GamificationProfile profile;
  final List<UserAchievement> achievements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dict = kAchievementDictV3(l10n);
    final rank = profile.crownRank;
    final rankColor = crownColorFor(rank, theme.colorScheme);
    final bar = xpBarMetrics(profile.xp);
    final atMax = profile.xp >= kCrownXpThresholds.last;

    final unlockedIds = {
      for (final a in achievements)
        if (a.isUnlocked) a.achievementId,
    };
    final showcaseIds = <String>[
      ...profile.selectedBadges.where(unlockedIds.contains),
    ];
    if (showcaseIds.isEmpty) {
      for (final a in achievements) {
        if (a.isUnlocked && !showcaseIds.contains(a.achievementId)) {
          showcaseIds.add(a.achievementId);
        }
        if (showcaseIds.length >= 6) break;
      }
    }

    final byId = {for (final d in dict) d.id: d};
    final tierById = {for (final a in achievements) a.achievementId: a.tier};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CrownedAvatar(
              displayName: displayName,
              avatarUrl: avatarUrl,
              radius: 28,
              crownRank: rank,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.profileBasarilar,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    crownLabel(rank, l10n),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: rankColor,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // WP-192: taç XP barı (level değil — bir sonraki taç eşiği)
        Text(
          atMax ? l10n.profileCrownMax : l10n.profileNextCrown,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          label: atMax
              ? '${profile.xp} XP · ${l10n.profileCrownMax}'
              : '${bar.earned} / ${bar.requiredXp} XP · '
                    '${(bar.progress * 100).round()}%',
          value: '${(bar.progress * 100).round()}%',
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: atMax ? 1 : bar.progress,
                minHeight: 8,
                color: rankColor,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          atMax
              ? '${profile.xp} XP'
              : '${bar.earned} / ${bar.requiredXp} XP '
                    '(${(bar.progress * 100).round()}%)',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (showcaseIds.isEmpty)
          Text(
            l10n.profileRozetlerinSerilerinVeIlerlemen,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final id in showcaseIds.take(6))
                _BadgeChip(
                  iconKey: byId[id]?.iconKey ?? 'emoji_events',
                  label: byId[id]?.name ?? id,
                  tier: tierById[id] ?? 1,
                ),
            ],
          ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.iconKey,
    required this.label,
    required this.tier,
  });

  final String iconKey;
  final String label;
  final int tier;

  @override
  Widget build(BuildContext context) {
    final color = tierColorFor(tier.clamp(1, 6));
    return Semantics(
      label: label,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Icon(achievementIconData(iconKey), color: color, size: 22),
      ),
    );
  }
}
