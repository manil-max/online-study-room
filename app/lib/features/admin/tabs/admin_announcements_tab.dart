import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/announcement.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
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

class _AnnouncementCard extends ConsumerStatefulWidget {
  const _AnnouncementCard({required this.announcement});

  final Announcement announcement;

  @override
  ConsumerState<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends ConsumerState<_AnnouncementCard> {
  bool _isDeleting = false;

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adminDuyuruSilmeBasligi),
        content: Text(
          l10n.adminDuyuruSilmeAciklamasi(widget.announcement.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.adminIptal),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.adminSil),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _isDeleting) return;

    setState(() => _isDeleting = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .deleteAnnouncement(widget.announcement.id);
      ref.invalidate(adminAnnouncementsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminIslemBasarili)));
      }
    } on AdminException catch (e) {
      // 🔴 WP-771: `catch (_)` sunucunun cevabini tamamen yutuyordu. Silme
      // dogrudan tabloya gider; RLS reddi burada tanisiz kayboluyordu.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final targetType = switch (widget.announcement.targetType) {
      'group' => l10n.adminGrubaOzel,
      'user' => l10n.adminKullaniciyaOzel,
      _ => l10n.adminHerkese,
    };
    return Card(
      child: ListTile(
        title: Text(widget.announcement.title),
        subtitle: Text(
          l10n.adminAnnouncementmessagenhedefAnnouncementtargettypeAnnouncementtargetid(
            widget.announcement.targetId ?? l10n.adminYok,
            widget.announcement.message,
            targetType,
          ),
        ),
        trailing: IconButton(
          tooltip: l10n.adminSil,
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: _isDeleting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.delete, color: theme.colorScheme.error),
          onPressed: _isDeleting ? null : _delete,
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
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _targetIdController = TextEditingController();
  String _targetType = 'all';
  bool _isLoading = false;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final targetId = _targetIdController.text.trim();

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
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminIslemBasarili)));
      }
    } on AdminException catch (e) {
      // 🔴 WP-771: olusturma da dogrudan tabloya insert eder; reddi jenerik
      // metne cevirmek tanisiz birakiyordu.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
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

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context).adminGerekliAlanlarDoldurulmalidir;
    }
    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _targetIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adminYeniDuyuru),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: l10n.adminBaslik),
                validator: _required,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(labelText: l10n.adminMesaj),
                maxLines: 3,
                validator: _required,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _targetType,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(l10n.adminHerkese),
                  ),
                  DropdownMenuItem(
                    value: 'group',
                    child: Text(l10n.adminGrubaOzel),
                  ),
                  DropdownMenuItem(
                    value: 'user',
                    child: Text(l10n.adminKullaniciyaOzel),
                  ),
                ],
                onChanged: _isLoading
                    ? null
                    : (val) {
                        if (val == null) return;
                        _targetIdController.clear();
                        setState(() => _targetType = val);
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
                          key: const ValueKey('announcement-group-target'),
                          isExpanded: true,
                          items: groups
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g.id,
                                  child: Text(
                                    g.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _isLoading
                              ? null
                              : (val) => _targetIdController.text = val ?? '',
                          validator: _required,
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
                ref
                    .watch(adminUsersProvider)
                    .when(
                      data: (users) {
                        if (users.isEmpty) {
                          return Text(l10n.adminKullaniciBulunamadi);
                        }
                        return DropdownButtonFormField<String>(
                          key: const ValueKey('announcement-user-target'),
                          isExpanded: true,
                          items: users
                              .map(
                                (user) => DropdownMenuItem(
                                  value: user.id,
                                  child: Text(
                                    user.email,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _isLoading
                              ? null
                              : (val) => _targetIdController.text = val ?? '',
                          validator: _required,
                          decoration: InputDecoration(
                            labelText: l10n.adminKullaniciSecin,
                          ),
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text(l10n.authBeklenmeyenBirHataOlustu),
                    ),
              ],
            ],
          ),
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
