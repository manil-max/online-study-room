import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/gamification_providers.dart';
import '../stats/progression_visuals.dart';
import 'user_avatar.dart';

/// Profil fotoğrafı + 5 kademeli taç halkası (üstte taç ikonu).
///
/// [crownRank] null/boş ise düz [UserAvatar] (taçsız).
class CrownedAvatar extends StatelessWidget {
  const CrownedAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.radius = 20,
    this.crownRank,
    this.onTap,
  });

  final String displayName;
  final String? avatarUrl;
  final double radius;
  final String? crownRank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rank = crownRank;
    final hasCrown = rank != null && rank.isNotEmpty;
    final color = hasCrown ? crownColorFor(rank) : null;
    // Taç halkası + ikon için ekstra pad.
    final pad = hasCrown ? radius * 0.35 : 0.0;
    final size = (radius + pad) * 2;

    Widget avatar = UserAvatar(
      displayName: displayName,
      avatarUrl: avatarUrl,
      radius: radius,
    );

    if (hasCrown && color != null) {
      avatar = SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: radius * 2 + 6,
              height: radius * 2 + 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: UserAvatar(
                displayName: displayName,
                avatarUrl: avatarUrl,
                radius: radius,
              ),
            ),
            Positioned(
              top: -2,
              child: Icon(
                Icons.workspace_premium,
                size: radius * 0.85,
                color: color,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (onTap == null) return avatar;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: avatar,
    );
  }
}

/// [userId] ile `gamification_profiles.crown_rank` canlı izler; sıralama,
/// aktif üyeler, chat, profil vb. her yerde taç göstermek için.
class LiveCrownedAvatar extends ConsumerWidget {
  const LiveCrownedAvatar({
    super.key,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.radius = 20,
    this.onTap,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(gamificationProfileProvider(userId)).asData?.value.crownRank;
    return CrownedAvatar(
      displayName: displayName,
      avatarUrl: avatarUrl,
      radius: radius,
      crownRank: rank,
      onTap: onTap,
    );
  }
}
