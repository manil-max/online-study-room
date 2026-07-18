import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/achievement_ledger_engine.dart';
import '../../../data/models/achievement.dart';
import '../../../data/models/gamification_profile.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/gamification_providers.dart';
import '../social_profile_screen.dart';
import 'achievement_showcase.dart';

/// Profil özeti: yalnız başarım rozetleri (WP-187).
///
/// Kaldırıldı: seviye çubuğu / Level N / XP metni, quest, streak, freeze, total
/// saat. Backend XP/ledger'a dokunulmaz — yalnız UI sadeleşti. Dokununca
/// [SocialProfileScreen] vitrin/katalog.
class GamificationCard extends ConsumerWidget {
  const GamificationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WP-56: profil açılınca sunucu ledger'ı yeniden değerlendirir.
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
              final achsAsync =
                  ref.watch(userAchievementsProvider(authProfile.id));
              return achsAsync.when(
                data: (achs) => _BadgeSummary(
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
    required this.profile,
    required this.achievements,
  });

  final GamificationProfile profile;
  final List<UserAchievement> achievements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dict = kAchievementDictV3(l10n);

    // Vitrin seçimi öncelikli; yoksa açılmış başarımlardan ilk 6.
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
    final tierById = {
      for (final a in achievements) a.achievementId: a.tier,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
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
    final color = tierColorFor(tier.clamp(1, 5));
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
        child: Icon(
          achievementIconData(iconKey),
          color: color,
          size: 22,
        ),
      ),
    );
  }
}
