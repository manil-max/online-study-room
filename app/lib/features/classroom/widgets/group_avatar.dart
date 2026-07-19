import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/group_providers.dart';

/// Private group avatar backed by a short-lived signed URL. Loading, denied,
/// expired and missing images all fall back to the group's first letter.
class GroupAvatar extends ConsumerWidget {
  const GroupAvatar({
    super.key,
    required this.name,
    required this.avatarPath,
    required this.avatarUpdatedAt,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final String? avatarPath;
  final DateTime? avatarUpdatedAt;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = avatarPath;
    final url = path == null || path.isEmpty
        ? const AsyncData<String?>(null)
        : ref.watch(
            groupAvatarUrlProvider(
              GroupAvatarRequest(path: path, updatedAt: avatarUpdatedAt),
            ),
          );
    final theme = Theme.of(context);
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
      foregroundColor: foregroundColor ?? theme.colorScheme.onSurfaceVariant,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(fontSize: radius * .8, fontWeight: FontWeight.w600),
      ),
    );

    return Semantics(
      image: path != null,
      label: '$name grup fotoğrafı',
      child: url.when(
        data: (signedUrl) {
          if (signedUrl == null || signedUrl.isEmpty) return fallback;
          final dataSeparator = signedUrl.indexOf('base64,');
          if (signedUrl.startsWith('data:') && dataSeparator >= 0) {
            return ClipOval(
              child: Image.memory(
                base64Decode(signedUrl.substring(dataSeparator + 7)),
                key: ValueKey(
                  '$path:${avatarUpdatedAt?.millisecondsSinceEpoch}',
                ),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
            );
          }
          return ClipOval(
            child: Image.network(
              signedUrl,
              key: ValueKey('$path:${avatarUpdatedAt?.millisecondsSinceEpoch}'),
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
          );
        },
        loading: () => SizedBox.square(
          dimension: radius * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              fallback,
              SizedBox.square(
                dimension: radius,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
        error: (_, _) => fallback,
      ),
    );
  }
}
