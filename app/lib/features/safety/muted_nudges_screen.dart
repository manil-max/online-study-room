import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../core/l10n/nudge_error_text.dart';
import '../../core/widgets/crowned_avatar.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/nudge_mute.dart';
import '../../data/providers/nudge_providers.dart';
import '../../data/repositories/nudge_repository.dart';

/// WP-444: Ayarlar → Dürtmesi susturulanlar.
///
/// Engelleme ekranından (`blocked_users_screen.dart`) bilinçli olarak ayrıdır:
/// susturma engelleme değildir, bu yüzden aynı listeye karıştırılmaz ve ekran
/// kapsamı açıklayan bir metinle açılır.
class MutedNudgesScreen extends ConsumerWidget {
  const MutedNudgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(nudgeMutesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyMutedNudgesTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.safetyActionFailed),
          ),
        ),
        data: (mutes) {
          return ListView(
            padding: getSafeVerticalPadding(
              context,
              horizontal: 12,
              vertical: 12,
            ),
            children: [
              // Kapsam açıklaması: kullanıcı susturmayı engellemeyle karıştırmasın.
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(
                  l10n.safetyMutedNudgesExplainer,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (mutes.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.safetyMutedNudgesEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              else
                for (final mute in mutes) ...[
                  _MutedNudgeTile(mute: mute),
                  const SizedBox(height: 6),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _MutedNudgeTile extends ConsumerStatefulWidget {
  const _MutedNudgeTile({required this.mute});

  final NudgeMute mute;

  @override
  ConsumerState<_MutedNudgeTile> createState() => _MutedNudgeTileState();
}

class _MutedNudgeTileState extends ConsumerState<_MutedNudgeTile> {
  bool _busy = false;

  Future<void> _unmute() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(nudgeRepositoryProvider)
          .unmuteNudgesFrom(widget.mute.mutedUserId);
      ref.invalidate(mutedNudgeSenderIdsProvider);
      ref.invalidate(nudgeMutesProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.safetyNudgesUnmuted)));
    } on NudgeException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.localize(l10n))));
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
    final mute = widget.mute;
    final rawName = mute.displayName?.trim() ?? '';
    // Ad okunamıyorsa maskeli ad: liste boş satır göstermez.
    final name = rawName.isEmpty ? l10n.safetyMutedUserFallbackName : rawName;

    return Card(
      child: ListTile(
        leading: Semantics(
          label: name,
          child: LiveCrownedAvatar(
            userId: mute.mutedUserId,
            displayName: name,
            avatarUrl: mute.avatarUrl,
            radius: 20,
          ),
        ),
        title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _busy ? null : _unmute,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.safetyUnmuteNudges, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
