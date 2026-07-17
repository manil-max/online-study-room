import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import 'social_profile_screen.dart';

/// Kendi başarı yolculuğu — WP-57 sosyal profil ekranına yönlendirir.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authStateProvider).value;
    if (profile == null) {
      return Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context).profileGirisYapmalisiniz),
        ),
      );
    }

    // Auth Profile modeli SocialProfileScreen ile aynı alanlara sahip.
    return SocialProfileScreen(profile: profile);
  }
}
