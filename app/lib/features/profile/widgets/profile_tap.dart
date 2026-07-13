import 'package:flutter/material.dart';

import '../../../data/models/profile.dart';
import '../social_profile_screen.dart';

/// İsim / PP görünen her yerden sosyal profil açmak için ortak giriş.
void openMemberProfile(BuildContext context, Profile profile) {
  SocialProfileScreen.open(context, profile);
}

/// [Profile] yoksa userId + görünen ad ile minimal profil kurar.
void openMemberProfileById(
  BuildContext context, {
  required String userId,
  required String displayName,
  String? avatarUrl,
  String? animal,
}) {
  openMemberProfile(
    context,
    Profile(
      id: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      animal: animal,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
}

/// Tüm satırı tıklanabilir yapan sarmalayıcı.
class ProfileTapTarget extends StatelessWidget {
  const ProfileTapTarget({
    super.key,
    required this.profile,
    required this.child,
    this.enabled = true,
  });

  final Profile? profile;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || profile == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openMemberProfile(context, profile!),
      child: child,
    );
  }
}
