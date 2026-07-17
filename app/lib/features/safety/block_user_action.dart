import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../data/providers/moderation_providers.dart';
import '../../data/repositories/moderation_repository.dart';

/// WP-125: ortak engelle onay diyaloğu + `block_user` RPC.
Future<void> confirmAndBlockUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.safetyBlockConfirmTitle),
      content: Text(l10n.safetyBlockConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.safetyCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.safetyBlockConfirmAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(moderationRepositoryProvider).blockUser(userId);
    ref.invalidate(blockedUserIdsProvider);
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.safetyUserBlocked)));
  } on ModerationException catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.safetyActionFailed)));
  }
}
