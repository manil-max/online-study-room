import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../core/widgets/crowned_avatar.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/profile.dart';
import '../../data/providers/moderation_providers.dart';
import '../../data/repositories/moderation_repository.dart';

/// WP-129: Ayarlar → Engellenen kullanıcılar (unblock UI).
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(blockedProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyBlockedUsersTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.safetyActionFailed),
          ),
        ),
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.safetyNoBlockedUsers,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: getSafeVerticalPadding(
              context,
              horizontal: 12,
              vertical: 12,
            ),
            itemCount: profiles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final p = profiles[index];
              return _BlockedUserTile(profile: p);
            },
          );
        },
      ),
    );
  }
}

class _BlockedUserTile extends ConsumerStatefulWidget {
  const _BlockedUserTile({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_BlockedUserTile> createState() => _BlockedUserTileState();
}

class _BlockedUserTileState extends ConsumerState<_BlockedUserTile> {
  bool _busy = false;

  Future<void> _unblock() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(moderationRepositoryProvider)
          .unblockUser(widget.profile.id);
      ref.invalidate(blockedUserIdsProvider);
      ref.invalidate(blockedProfilesProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.safetyUnblocked)));
    } on ModerationException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.safetyActionFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = widget.profile;
    final name = p.displayName.trim().isEmpty
        ? l10n.safetyBlockedUserFallbackName
        : p.displayName;

    return Card(
      child: ListTile(
        leading: LiveCrownedAvatar(
          userId: p.id,
          displayName: name,
          avatarUrl: p.avatarUrl,
          radius: 20,
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: TextButton(
          onPressed: _busy ? null : _unblock,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.safetyUnblock),
        ),
      ),
    );
  }
}
