import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';

class AdminGroupsTab extends ConsumerWidget {
  const AdminGroupsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(adminGroupsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminGroupsProvider);
        await ref.read(adminGroupsProvider.future);
      },
      child: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Grup bulunamadı.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _GroupCard(group: items[index]);
            },
          );
        },
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group});

  final StudyGroup group;

  Future<void> _performAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String promptTitle,
  ) async {
    final reasonController = TextEditingController();
    final targetUserController = TextEditingController();
    final requiresUser = action == 'remove_group_member';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(promptTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (requiresUser) ...[
                TextField(
                  controller: targetUserController,
                  decoration: const InputDecoration(
                    labelText: 'Hedef Kullanıcı ID (Zorunlu)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Gerekçe (Zorunlu)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
    final targetUser = targetUserController.text.trim();

    if (reason.isEmpty || (requiresUser && targetUser.isEmpty)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gerekli alanlar doldurulmalıdır.')),
        );
      }
      return;
    }

    try {
      await ref.read(adminRepositoryProvider).performGroupAction(
            action: action,
            targetGroupId: group.id,
            targetUserId: requiresUser ? targetUser : null,
            reason: reason,
          );
      ref.invalidate(adminGroupsProvider);
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.name,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('ID: ${group.id}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _performAction(
                    context,
                    ref,
                    'remove_group_member',
                    'Üyeyi At',
                  ),
                  icon: const Icon(Icons.person_remove, size: 18),
                  label: const Text('Üye At'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _performAction(
                    context,
                    ref,
                    'delete_group',
                    'Grubu Sil',
                  ),
                  icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                  label: Text('Grubu Sil', style: TextStyle(color: theme.colorScheme.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
