import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/crowned_avatar.dart';
import '../../core/widgets/safe_screen_padding.dart';
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
        builder: (_) =>
            SocialProfileScreen(profile: profile, newlyAwarded: newlyAwarded),
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

    final gamificationAsync = ref.watch(
      gamificationProfileProvider(profile.id),
    );
    final achievementsAsync = ref.watch(userAchievementsProvider(profile.id));
    final liveAwards = isSelf
        ? ref.watch(lastAchievementAwardsProvider)
        : const <AchievementAward>[];
    final confettiAwards = newlyAwarded.isNotEmpty ? newlyAwarded : liveAwards;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSelf
              ? AppLocalizations.of(context).profileBasarYolculugum
              : AppLocalizations.of(context).profileSosyalProfil,
        ),
      ),
      body: ListView(
        padding: getSafeVerticalPadding(context, horizontal: 20, vertical: 16),
        children: [
          gamificationAsync.when(
            loading: () => Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.profileBeklenmeyenBirHataOlustu,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
            data: (gamification) {
              return achievementsAsync.when(
                loading: () => Column(
                  children: [
                    CrownedAvatar(
                      displayName: profile.displayName,
                      avatarUrl: profile.avatarUrl,
                      radius: 44,
                      crownRank: gamification.crownRank,
                    ),
                    SizedBox(height: 24),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
                error: (err, _) => Text(
                  l10n.profileBasarimlarYuklenemedi,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                data: (achs) {
                  return Column(
                    children: [
                      CrownedAvatar(
                        displayName: profile.displayName,
                        avatarUrl: profile.avatarUrl,
                        radius: 44,
                        crownRank: gamification.crownRank,
                      ),
                      SizedBox(height: 16),
                      AchievementShowcase(
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
                      ),
                    ],
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
          SnackBar(
            content: Text(AppLocalizations.of(context).profileVitrineEnFazla3),
          ),
        );
        return;
      }
      selected.add(badgeId);
    }
    ref
        .read(gamificationRepositoryProvider)
        .updateProfile(gamification.copyWith(selectedBadges: selected));
  }
}
