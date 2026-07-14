import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminUsersProvider);
        await ref.read(adminUsersProvider.future);
      },
      child: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text(l10n.authBeklenmeyenBirHataOlustu)),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(l10n.adminKullaniciBulunamadi));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _UserCard(user: items[index]);
            },
          );
        },
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});

  final AdminUserDto user;

  Future<void> _performAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String promptTitle,
  ) async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(promptTitle),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              labelText: l10n.adminGerekceZorunlu,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.adminIptal),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.adminOnayla),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminGerekceBelirtilmelidir)),
        );
      }
      return;
    }

    try {
      await ref
          .read(adminRepositoryProvider)
          .performUserAction(
            action: action,
            targetUserId: user.id,
            reason: reason,
          );
      ref.invalidate(adminUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminIslemBasarili)));
      }
    } on AdminException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDeleted = user.deleted;
    final isSuspended = user.isSuspended;

    return Card(
      color: isDeleted ? theme.colorScheme.surfaceContainerHighest : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user.email,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: isDeleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isDeleted)
                  Chip(
                    label: Text(l10n.adminSilinmis),
                    visualDensity: VisualDensity.compact,
                  )
                else if (isSuspended)
                  Chip(
                    label: Text(l10n.adminAskida),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.errorContainer,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminIdGroupid(user.id),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.adminKayitUsercreatedattolocaltostringsubstring016(
                user.createdAt.toLocal().toString().substring(0, 16),
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (user.lastSignInAt != null)
              Text(
                l10n.adminSonGirisUserlastsigninattolocaltostringsubstring016(
                  user.lastSignInAt!.toLocal().toString().substring(0, 16),
                ),
                style: theme.textTheme.bodySmall,
              ),
            if (!isDeleted) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _performAction(
                      context,
                      ref,
                      'send_password_reset',
                      l10n.adminSifreSifirlamaEpostasiGonder,
                    ),
                    icon: const Icon(Icons.lock_reset, size: 18),
                    label: Text(l10n.adminSifreSifirla),
                  ),
                  if (isSuspended)
                    OutlinedButton.icon(
                      onPressed: () => _performAction(
                        context,
                        ref,
                        'unsuspend_user',
                        l10n.adminAskiyiKaldir,
                      ),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: Text(l10n.adminAskiKaldir),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _performAction(
                        context,
                        ref,
                        'suspend_user',
                        l10n.adminKullaniciyiAskiyaAl,
                      ),
                      icon: const Icon(Icons.pause_circle_outline, size: 18),
                      label: Text(l10n.adminAskiyaAl),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _performAction(
                      context,
                      ref,
                      'soft_delete_user',
                      l10n.adminKullaniciyiSoftDeleteYap,
                    ),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      l10n.adminSil,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
