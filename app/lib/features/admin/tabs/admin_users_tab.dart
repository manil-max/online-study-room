import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminUsersProvider);
        await ref.read(adminUsersProvider.future);
      },
      child: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Kullanıcı bulunamadı.'));
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
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(promptTitle),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Gerekçe (Zorunlu)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Onayla'),
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
          const SnackBar(content: Text('Gerekçe belirtilmelidir.')),
        );
      }
      return;
    }

    try {
      await ref.read(adminRepositoryProvider).performUserAction(
            action: action,
            targetUserId: user.id,
            reason: reason,
          );
      ref.invalidate(adminUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem başarılı.')),
        );
      }
    } on AdminException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
                  const Chip(
                    label: Text('Silinmiş'),
                    visualDensity: VisualDensity.compact,
                  )
                else if (isSuspended)
                  Chip(
                    label: const Text('Askıda'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.errorContainer,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('ID: ${user.id}', style: theme.textTheme.bodySmall),
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
                      'Şifre Sıfırlama E-postası Gönder',
                    ),
                    icon: const Icon(Icons.lock_reset, size: 18),
                    label: const Text('Şifre Sıfırla'),
                  ),
                  if (isSuspended)
                    OutlinedButton.icon(
                      onPressed: () => _performAction(
                        context,
                        ref,
                        'unsuspend_user',
                        'Askıyı Kaldır',
                      ),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('Askı Kaldır'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _performAction(
                        context,
                        ref,
                        'suspend_user',
                        'Kullanıcıyı Askıya Al',
                      ),
                      icon: const Icon(Icons.pause_circle_outline, size: 18),
                      label: const Text('Askıya Al'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _performAction(
                      context,
                      ref,
                      'soft_delete_user',
                      'Kullanıcıyı Soft Delete Yap',
                    ),
                    icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                    label: Text('Sil', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
