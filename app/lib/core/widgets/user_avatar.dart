import 'package:flutter/material.dart';

/// Kullanıcı avatarı: `avatarUrl` varsa fotoğrafı, yoksa adın baş harfini gösterir.
/// Her yerde (profil, sınıf listesi, leaderboard) aynı görünüm için ortak widget.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.radius = 20,
  });

  final String displayName;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;
    final initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundImage: hasPhoto ? NetworkImage(avatarUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              initial,
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}
