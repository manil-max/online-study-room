import 'package:flutter/material.dart';

/// Kullanıcı avatarı: `avatarUrl` varsa fotoğrafı, yoksa adın baş harfini gösterir.
/// Her yerde (profil, sınıf listesi, leaderboard) aynı görünüm için ortak widget.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.radius = 20,
    this.onTap,
    this.enableZoom = true,
  });

  final String displayName;
  final String? avatarUrl;
  final double radius;
  final VoidCallback? onTap;
  final bool enableZoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;
    final initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';

    final avatar = CircleAvatar(
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

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }

    if (hasPhoto && enableZoom) {
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  InteractiveViewer(
                    child: Image.network(avatarUrl!),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: avatar,
      );
    }

    return avatar;
  }
}
