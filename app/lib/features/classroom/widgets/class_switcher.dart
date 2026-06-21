import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/study_group.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/repositories/group_repository.dart';

/// Sınıf değiştirici alt sayfası (Instagram hesap değiştirme mantığı, §3.8):
/// katılınan sınıflar listelenir, dokununca aktif sınıf değişir; ayrıca
/// "Sınıf oluştur" ve "Sınıfa katıl". "Sınıflar" sekmesine basılı tutunca veya
/// üstteki sınıf adına dokununca açılır.
Future<void> showClassSwitcher(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _ClassSwitcherSheet(),
  );
}

class _ClassSwitcherSheet extends ConsumerWidget {
  const _ClassSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groups = ref.watch(userGroupsProvider).value ?? const <StudyGroup>[];
    final activeId = ref.watch(userGroupProvider).value?.id;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sınıflarım', style: theme.textTheme.titleMedium),
            ),
          ),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Henüz bir sınıfta değilsin. Aşağıdan oluştur veya katıl.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          for (final g in groups)
            ListTile(
              selected: g.id == activeId,
              leading: CircleAvatar(
                backgroundColor: g.id == activeId
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: g.id == activeId
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                child: Text(
                  g.name.isNotEmpty ? g.name.characters.first.toUpperCase() : '?',
                ),
              ),
              title: Text(g.name),
              subtitle: Text('Kod: ${g.inviteCode}'),
              trailing: g.id == activeId
                  ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                ref.read(activeGroupIdProvider.notifier).select(g.id);
                Navigator.pop(context);
              },
            ),
          const Divider(height: 8),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Sınıf oluştur'),
            onTap: () async {
              final ok = await createGroupFlow(context, ref);
              if (ok && context.mounted) Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Sınıfa katıl'),
            onTap: () async {
              final ok = await joinGroupFlow(context, ref);
              if (ok && context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Sınıf oluşturma akışı: ad sorar, oluşturur, yeni sınıfı aktif yapar.
/// Başarılıysa true döner.
Future<bool> createGroupFlow(BuildContext context, WidgetRef ref) async {
  final name = await _promptText(
    context,
    title: 'Sınıf oluştur',
    label: 'Sınıf adı',
    action: 'Oluştur',
  );
  if (name == null || name.trim().isEmpty) return false;

  final user = ref.read(authStateProvider).value;
  if (user == null) return false;
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final group = await ref
        .read(groupRepositoryProvider)
        .createGroup(name: name, creator: user);
    ref.read(activeGroupIdProvider.notifier).select(group.id);
    return true;
  } on GroupException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// Sınıfa katılma akışı: davet kodu sorar, katar, o sınıfı aktif yapar.
/// Başarılıysa true döner.
Future<bool> joinGroupFlow(BuildContext context, WidgetRef ref) async {
  final code = await _promptText(
    context,
    title: 'Sınıfa katıl',
    label: 'Davet kodu',
    action: 'Katıl',
    uppercase: true,
  );
  if (code == null || code.trim().isEmpty) return false;

  final user = ref.read(authStateProvider).value;
  if (user == null) return false;
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final group = await ref
        .read(groupRepositoryProvider)
        .joinGroup(inviteCode: code, member: user);
    ref.read(activeGroupIdProvider.notifier).select(group.id);
    return true;
  } on GroupException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// Tek alanlı metin diyaloğu (ad / kod). İptal → null.
Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  bool uppercase = false,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization:
            uppercase ? TextCapitalization.characters : TextCapitalization.words,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (_) => Navigator.pop(ctx, controller.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(action),
        ),
      ],
    ),
  );
}
