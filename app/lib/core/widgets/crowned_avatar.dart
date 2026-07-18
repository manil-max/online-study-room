import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/gamification_providers.dart';
import '../stats/progression_visuals.dart';
import 'user_avatar.dart';

/// Profil fotoğrafı + 5 kademeli taç halkası + gerçek taç ikonu (WP-192).
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
    // Taç halkası + ikon için ekstra pad (WP-195b: taç ~%18 daha büyük).
    final pad = hasCrown ? radius * 0.52 : 0.0;
    final size = (radius + pad) * 2;

    Widget avatar = UserAvatar(
      displayName: displayName,
      avatarUrl: avatarUrl,
      radius: radius,
    );

    if (hasCrown && color != null) {
      final ringSize = radius * 2 + 8;
      // WP-195b: taç boyutu önceki 1.15×0.75 → ~%18 artış.
      final crownW = radius * 1.36;
      final crownH = radius * 0.89;
      avatar = SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Renkli glow halka
            Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 4,
                    spreadRadius: 0,
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
            // Üstte gerçek taç (CustomPainter)
            Positioned(
              top: -radius * 0.22,
              child: CustomPaint(
                size: Size(crownW, crownH),
                painter: CrownPainter(
                  color: color,
                  outline: Colors.black.withValues(alpha: 0.35),
                ),
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

/// Basit 3 dişli taç silueti (Material madalya yerine gerçek taç).
class CrownPainter extends CustomPainter {
  CrownPainter({required this.color, this.outline});

  final Color color;
  final Color? outline;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.05, h * 0.92)
      ..lineTo(w * 0.08, h * 0.42)
      ..lineTo(w * 0.22, h * 0.62)
      ..lineTo(w * 0.38, h * 0.12)
      ..lineTo(w * 0.50, h * 0.48)
      ..lineTo(w * 0.62, h * 0.12)
      ..lineTo(w * 0.78, h * 0.62)
      ..lineTo(w * 0.92, h * 0.42)
      ..lineTo(w * 0.95, h * 0.92)
      ..close();

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);

    if (outline != null) {
      final stroke = Paint()
        ..color = outline!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, stroke);
    }

    // Band
    final band = RRect.fromLTRBR(
      w * 0.08,
      h * 0.72,
      w * 0.92,
      h * 0.92,
      const Radius.circular(2),
    );
    canvas.drawRRect(
      band,
      Paint()..color = color.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant CrownPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.outline != outline;
}

/// [userId] ile `gamification_profiles.crown_rank` canlı izler.
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
    final rank =
        ref.watch(gamificationProfileProvider(userId)).asData?.value.crownRank;
    return CrownedAvatar(
      displayName: displayName,
      avatarUrl: avatarUrl,
      radius: radius,
      crownRank: rank,
      onTap: onTap,
    );
  }
}
