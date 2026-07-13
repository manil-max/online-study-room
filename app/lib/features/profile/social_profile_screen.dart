import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/safe_screen_padding.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/achievement_ledger.dart';
import '../../data/models/gamification_profile.dart';
import '../../data/models/profile.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/gamification_providers.dart';
import 'widgets/achievement_showcase.dart';

/// Sosyal profil vitrini (Başarım 3.0 R2 / WP-57).
///
/// Ortak grup üyesinin XP/taç/rozetlerini salt-okunur gösterir (RLS:
/// `can_see_user_sessions`). Kendi profilinde vitrin rozeti seçilebilir.
class SocialProfileScreen extends ConsumerWidget {
  const SocialProfileScreen({
    super.key,
    required this.profile,
    this.newlyAwarded = const [],
  });

  final Profile profile;
  final List<AchievementAward> newlyAwarded;

  static Future<void> open(
    BuildContext context,
    Profile profile, {
    List<AchievementAward> newlyAwarded = const [],
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SocialProfileScreen(
          profile: profile,
          newlyAwarded: newlyAwarded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selfId = ref.watch(authStateProvider).value?.id;
    final isSelf = selfId != null && selfId == profile.id;

    if (isSelf) {
      ref.watch(gamificationProgressSyncProvider);
    }

    final gamificationAsync =
        ref.watch(gamificationProfileProvider(profile.id));
    final achievementsAsync =
        ref.watch(userAchievementsProvider(profile.id));
    final liveAwards = isSelf
        ? ref.watch(lastAchievementAwardsProvider)
        : const <AchievementAward>[];
    final confettiAwards =
        newlyAwarded.isNotEmpty ? newlyAwarded : liveAwards;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelf ? 'Başarı Yolculuğum' : 'Sosyal profil'),
      ),
      body: ListView(
        padding: getSafeVerticalPadding(context, horizontal: 20, vertical: 16),
        children: [
          Center(
            child: UserAvatar(
              displayName: profile.displayName,
              avatarUrl: profile.avatarUrl,
              radius: 44,
            ),
          ),
          const SizedBox(height: 12),
          gamificationAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Profil yüklenemedi. Ortak gruba üye olmayabilirsiniz.\n$err',
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
            data: (gamification) {
              return achievementsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text(
                  'Başarımlar yüklenemedi: $err',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                data: (achs) {
                  return AchievementShowcase(
                    gamification: gamification,
                    userAchievements: achs,
                    displayName: profile.displayName,
                    isSelf: isSelf,
                    compact: false,
                    showCatalog: true,
                    forceConfettiAwards: confettiAwards,
                    onToggleShowcaseBadge: isSelf
                        ? (badgeId) => _toggleBadge(
                              context,
                              ref,
                              gamification,
                              badgeId,
                            )
                        : null,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _toggleBadge(
    BuildContext context,
    WidgetRef ref,
    GamificationProfile gamification,
    String badgeId,
  ) {
    final selected = List<String>.from(gamification.selectedBadges);
    final isSelected = selected.contains(badgeId);
    if (isSelected) {
      selected.remove(badgeId);
    } else {
      if (selected.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vitrine en fazla 3 rozet ekleyebilirsiniz.'),
          ),
        );
        return;
      }
      selected.add(badgeId);
    }
    ref.read(gamificationRepositoryProvider).updateProfile(
          gamification.copyWith(selectedBadges: selected),
        );
  }
}
