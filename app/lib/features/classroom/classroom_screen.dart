import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/models/study_group.dart';
import '../../data/repositories/group_repository.dart';

/// Sınıf sekmesi: ana sayfa + canlı sınıf (birleşik). Bkz. project.md §3.0/§3.5.
/// Sınıf yoksa oluştur/katıl ekranı; varsa sınıf + üyeler gösterilir.
/// (Canlı çalışma sayacı ve presence Faz 2'de eklenecek.)
class ClassroomScreen extends ConsumerWidget {
  const ClassroomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(userGroupProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sınıf')),
      body: groupAsync.when(
        data: (group) =>
            group == null ? const _NoGroupView() : _GroupView(group: group),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Bir hata oluştu: $e')),
      ),
    );
  }
}

/// Henüz sınıfı olmayan kullanıcı: oluştur veya koda katıl.
class _NoGroupView extends ConsumerWidget {
  const _NoGroupView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Henüz bir sınıfta değilsin',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Yeni bir sınıf oluştur ya da davet koduyla bir sınıfa katıl.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _createGroupDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Sınıf oluştur'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _joinGroupDialog(context, ref),
              icon: const Icon(Icons.login),
              label: const Text('Koda katıl'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kullanıcının sınıfı: ad, davet kodu ve üyeler.
class _GroupView extends ConsumerWidget {
  const _GroupView({required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final membersAsync = ref.watch(groupMembersProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Davet kodu: ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                    SelectableText(
                      group.inviteCode,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kopyala',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: group.inviteCode));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Davet kodu kopyalandı')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Üyeler', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 4),
        membersAsync.when(
          data: (members) => Column(
            children: [
              for (final m in members)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(m.displayName.isNotEmpty
                        ? m.displayName.substring(0, 1).toUpperCase()
                        : '?'),
                  ),
                  title: Text(m.displayName),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Üyeler yüklenemedi: $e'),
        ),
      ],
    );
  }
}

Future<void> _createGroupDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sınıf oluştur'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Sınıf adı'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Oluştur'),
        ),
      ],
    ),
  );
  if (name == null || name.trim().isEmpty) return;

  final user = ref.read(authStateProvider).value;
  if (user == null) return;
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(groupRepositoryProvider)
        .createGroup(name: name, creator: user);
  } on GroupException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

Future<void> _joinGroupDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Koda katıl'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'Davet kodu'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Katıl'),
        ),
      ],
    ),
  );
  if (code == null || code.trim().isEmpty) return;

  final user = ref.read(authStateProvider).value;
  if (user == null) return;
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(groupRepositoryProvider)
        .joinGroup(inviteCode: code, member: user);
  } on GroupException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
