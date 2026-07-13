import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/profile.dart';
import '../../../data/providers/gamification_providers.dart';
import '../social_profile_screen.dart';
import 'achievement_showcase.dart';

/// Kamp ateşi / grup üyesi dokunuşu — kompakt vitrin; tam ekran için detay.
class SocialProfileDialog extends ConsumerWidget {
  const SocialProfileDialog({
    super.key,
    required this.profile,
  });

  final Profile profile;

  static void show(BuildContext context, Profile profile) {
    showDialog<void>(
      context: context,
      builder: (context) => SocialProfileDialog(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamificationAsync =
        ref.watch(gamificationProfileProvider(profile.id));
    final achievementsAsync =
        ref.watch(userAchievementsProvider(profile.id));
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_full),
                    tooltip: 'Tam profil',
                    onPressed: () {
                      Navigator.of(context).pop();
                      SocialProfileScreen.open(context, profile);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              gamificationAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Profil görüntülenemiyor (ortak grup gerekir).',
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
                data: (gamification) {
                  return achievementsAsync.when(
                    loading: () => const SizedBox(
                      height: 48,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const Text('Başarımlar yüklenemedi'),
                    data: (achs) => AchievementShowcase(
                      gamification: gamification,
                      userAchievements: achs,
                      isSelf: false,
                      compact: true,
                      showCatalog: false,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
