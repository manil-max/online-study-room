import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/achievement_ledger_engine.dart';
import '../../../core/stats/progression_visuals.dart';
import '../../../core/widgets/crown_tiers_sheet.dart';
import '../../../core/widgets/crowned_avatar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../data/models/achievement.dart';
import '../../../data/models/gamification_profile.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/achievement_reward_provider.dart';
import '../../../data/providers/gamification_providers.dart';
import '../social_profile_screen.dart';
import 'achievement_showcase.dart';
import 'unread_message_badge.dart';

/// Profil özeti: taç + XP satırı + başarım rozetleri (WP-187/192, WP-712).
///
/// Level/quest/streak/freeze/total UI yok. Backend XP'ye yazılmaz —
/// yalnız görüntü (`CrownXpHeader` + sunucu profil XP).
class GamificationCard extends ConsumerWidget {
  const GamificationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gamificationProgressSyncProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authProfile = ref.watch(authStateProvider).value;
    final summaryAsync = ref.watch(gamificationSummaryProvider);
    // WP-421: zincirin son halkasi. Bekleyen odul varsa Profil'de de gorunur;
    // kullanici Basarimlar'i acmadan yeni basarimi fark eder.
    final pendingRewards =
        ref.watch(pendingAchievementRewardSummaryProvider).value?.pendingCount ??
        0;

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
                data: (achs) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _BadgeSummary(
                      displayName: authProfile.displayName,
                      avatarUrl: authProfile.avatarUrl,
                      profile: summary.profile,
                      achievements: achs,
                    ),
                    if (pendingRewards > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: UnreadMessageBadge(
                          key: const Key('achievements-pending-badge'),
                          count: pendingRewards,
                        ),
                      ),
                  ],
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
            // 🔴 WP-591: metin zaten dogruydu, eksik olan CIKISTI.
            error: (error, stackTrace) => ErrorRetryView(
              dense: true,
              message: l10n.profileBasarilarYuklenemedi,
              onRetry: () => ref.invalidate(gamificationSummaryProvider),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CrownedAvatar(
              displayName: displayName,
              avatarUrl: avatarUrl,
              radius: 28,
              crownRank: rank,
              // WP-234: taça basınca tüm rütbeler ve XP eşikleri görünür.
              onTap: () => showCrownTiers(context, currentXp: profile.xp),
            ),
            const SizedBox(width: 12),
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
        // 🔴 WP-712 — sahip: "alttaki barı ve altındaki renklerle kademeleri
        // sil; sadece hangi taça sahip olduğu ve sağında XP kalsın, XP'yi de
        // XP/XP yap." Bar + yüzde metni + "Sonraki taç" başlığı üç ayrı satır
        // olarak üst üste diziliydi (madde 2); üçünün taşıdığı bilgi tek
        // satırda: rütbe adı + `XP / sonraki eşik`. Kademelerin tamamı bu
        // satıra basınca açılan sayfada (madde 6).
        CrownXpHeader(
          rank: rank,
          xp: profile.xp,
          onTap: () => showCrownTiers(context, currentXp: profile.xp),
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
                  badgeId: id,
                  iconKey: byId[id]?.iconKey ?? 'emoji_events',
                  label: byId[id]?.name ?? id,
                  tier: tierById[id] ?? 1,
                  isSecret: byId[id]?.isSecret ?? false,
                ),
            ],
          ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.badgeId,
    required this.iconKey,
    required this.label,
    required this.tier,
    required this.isSecret,
  });

  final String badgeId;
  final String iconKey;
  final String label;
  final int tier;
  final bool isSecret;

  @override
  Widget build(BuildContext context) {
    final color = badgeVisualColor(
      tier: tier.clamp(1, 6),
      unlocked: true,
      isSecret: isSecret,
      secretLocked: false,
      scheme: Theme.of(context).colorScheme,
    );
    return Semantics(
      label: label,
      child: Container(
        key: ValueKey('profile_badge_$badgeId'),
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
