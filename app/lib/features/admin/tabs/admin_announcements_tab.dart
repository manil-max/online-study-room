import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/announcement.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

class AdminAnnouncementsTab extends ConsumerWidget {
  const AdminAnnouncementsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = ref.watch(adminAnnouncementsProvider);
    final l10n = AppLocalizations.of(context);

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
          error: (err, _) =>
              Center(child: Text(l10n.authBeklenmeyenBirHataOlustu)),
          data: (items) {
            if (items.isEmpty) {
              return Center(child: Text(l10n.adminDuyuruBulunamadi));
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
    final l10n = AppLocalizations.of(context);
    final targetType = switch (announcement.targetType) {
      'group' => l10n.adminGrubaOzel,
      'user' => l10n.adminKullaniciyaOzel,
      _ => l10n.adminHerkese,
    };
    return Card(
      child: ListTile(
        title: Text(announcement.title),
        subtitle: Text(
          l10n.adminAnnouncementmessagenhedefAnnouncementtargettypeAnnouncementtargetid(
            announcement.targetId ?? l10n.adminYok,
            announcement.message,
            targetType,
          ),
        ),
        trailing: IconButton(
          tooltip: l10n.adminSil,
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: Icon(Icons.delete, color: theme.colorScheme.error),
          onPressed: () async {
            try {
              await ref
                  .read(adminRepositoryProvider)
                  .deleteAnnouncement(announcement.id);
              ref.invalidate(adminAnnouncementsProvider);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
                );
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
  ConsumerState<_CreateAnnouncementDialog> createState() =>
      _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState
    extends ConsumerState<_CreateAnnouncementDialog> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _targetIdController = TextEditingController();
  String _targetType = 'all';
  bool _isLoading = false;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final targetId = _targetIdController.text.trim();

    if (title.isEmpty || message.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final adminId = ref.read(authStateProvider).value?.id;
      if (adminId == null) throw StateError('unauthorized');

      await ref
          .read(adminRepositoryProvider)
          .createAnnouncement(
            title: title,
            message: message,
            targetType: _targetType,
            targetId: _targetType == 'all' ? null : targetId,
            adminId: adminId,
          );
      ref.invalidate(adminAnnouncementsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adminYeniDuyuru),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: l10n.adminBaslik),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(labelText: l10n.adminMesaj),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _targetType,
              items: [
                DropdownMenuItem(value: 'all', child: Text(l10n.adminHerkese)),
                DropdownMenuItem(
                  value: 'group',
                  child: Text(l10n.adminGrubaOzel),
                ),
                DropdownMenuItem(
                  value: 'user',
                  child: Text(l10n.adminKullaniciyaOzel),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _targetType = val);
              },
              decoration: InputDecoration(labelText: l10n.adminHedef),
            ),
            if (_targetType == 'group') ...[
              const SizedBox(height: 8),
              ref
                  .watch(adminGroupsProvider)
                  .when(
                    data: (groups) {
                      if (groups.isEmpty) return Text(l10n.adminHicGrupYok);
                      return DropdownButtonFormField<String>(
                        items: groups
                            .map(
                              (g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(g.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) _targetIdController.text = val;
                        },
                        decoration: InputDecoration(
                          labelText: l10n.adminGrupSecin,
                        ),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text(l10n.adminGruplarYuklenemedi),
                  ),
            ] else if (_targetType == 'user') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _targetIdController,
                decoration: InputDecoration(labelText: l10n.adminKullaniciId),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.adminIptal),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.adminGonder),
        ),
      ],
    );
  }
}
