import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/profile.dart';
import '../../../data/providers/gamification_providers.dart';
import '../social_profile_screen.dart';
import 'achievement_showcase.dart';

/// Kamp ateşi / grup üyesi dokunuşu — kompakt vitrin; tam ekran için detay.
class SocialProfileDialog extends ConsumerWidget {
  const SocialProfileDialog({super.key, required this.profile});

  final Profile profile;

  static void show(BuildContext context, Profile profile) {
    showDialog<void>(
      context: context,
      builder: (context) => SocialProfileDialog(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamificationAsync = ref.watch(
      gamificationProfileProvider(profile.id),
    );
    final achievementsAsync = ref.watch(userAchievementsProvider(profile.id));
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 360),
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
                    icon: Icon(Icons.open_in_full),
                    tooltip: AppLocalizations.of(context).profileTamProfil,
                    onPressed: () {
                      Navigator.of(context).pop();
                      SocialProfileScreen.open(context, profile);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: 8),
              gamificationAsync.when(
                loading: () => Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    AppLocalizations.of(
                      context,
                    ).profileBeklenmeyenBirHataOlustu,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
                data: (gamification) {
                  return achievementsAsync.when(
                    loading: () => SizedBox(
                      height: 48,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => Text(
                      AppLocalizations.of(context).profileBasarimlarYuklenemedi,
                    ),
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
