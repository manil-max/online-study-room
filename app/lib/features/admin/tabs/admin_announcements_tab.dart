import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/announcement.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';

class AdminAnnouncementsTab extends ConsumerWidget {
  const AdminAnnouncementsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = ref.watch(adminAnnouncementsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const _CreateAnnouncementDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminAnnouncementsProvider);
          await ref.read(adminAnnouncementsProvider.future);
        },
        child: announcements.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text(err.toString())),
          data: (items) {
            if (items.isEmpty) {
              return const Center(child: Text('Duyuru bulunamadı.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _AnnouncementCard(announcement: items[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        title: Text(announcement.title),
        subtitle: Text('${announcement.message}\nHedef: ${announcement.targetType} ${announcement.targetId ?? ""}'),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: theme.colorScheme.error),
          onPressed: () async {
            try {
              await ref.read(adminRepositoryProvider).deleteAnnouncement(announcement.id);
              ref.invalidate(adminAnnouncementsProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
          },
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _CreateAnnouncementDialog extends ConsumerStatefulWidget {
  const _CreateAnnouncementDialog();

  @override
  ConsumerState<_CreateAnnouncementDialog> createState() => _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState extends ConsumerState<_CreateAnnouncementDialog> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _targetIdController = TextEditingController();
  String _targetType = 'all';
  bool _isLoading = false;

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final targetId = _targetIdController.text.trim();

    if (title.isEmpty || message.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final adminId = ref.read(authStateProvider).value?.id;
      if (adminId == null) throw Exception('Yetkisiz işlem');

      await ref.read(adminRepositoryProvider).createAnnouncement(
            title: title,
            message: message,
            targetType: _targetType,
            targetId: _targetType == 'all' ? null : targetId,
            adminId: adminId,
          );
      ref.invalidate(adminAnnouncementsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Duyuru'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Mesaj'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _targetType,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Herkese')),
                DropdownMenuItem(value: 'group', child: Text('Gruba Özel')),
                DropdownMenuItem(value: 'user', child: Text('Kullanıcıya Özel')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _targetType = val);
              },
              decoration: const InputDecoration(labelText: 'Hedef'),
            ),
            if (_targetType == 'group') ...[
              const SizedBox(height: 8),
              ref.watch(adminGroupsProvider).when(
                data: (groups) {
                  if (groups.isEmpty) return const Text('Hiç grup yok.');
                  return DropdownButtonFormField<String>(
                    items: groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))).toList(),
                    onChanged: (val) {
                      if (val != null) _targetIdController.text = val;
                    },
                    decoration: const InputDecoration(labelText: 'Grup Seçin'),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => const Text('Gruplar yüklenemedi.'),
              ),
            ] else if (_targetType == 'user') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _targetIdController,
                decoration: const InputDecoration(labelText: 'Kullanıcı ID'),
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Gönder'),
        ),
      ],
    );
  }
}
