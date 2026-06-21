import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/anchored_menu.dart';
import '../../../data/models/study_group.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/repositories/group_repository.dart';
import 'class_detail_screen.dart';

/// Sınıf değiştirici (Instagram hesap değiştirme mantığı, §3.8): katılınan
/// sınıflar listelenir, dokununca aktif sınıf değişir; ayrıca "Sınıf oluştur" /
/// "Sınıfa katıl". Alttan açılan pencere yerine **basılan yerde** açılır (§3.12).
///
/// Sağ üstteki ↔ ikonundan tetiklenirse [context] o ikonun context'idir (menü
/// ona göre konumlanır); sekmeye basılı tutunca [at] basış konumudur.
/// [switchOnly] true ise yalnızca grup değiştirme (oluştur/katıl/⋮ gizli) —
/// İstatistik gibi yerlerde sadece geçiş için.
Future<void> showClassSwitcher(BuildContext context, WidgetRef ref,
    {Offset? at, bool switchOnly = false}) {
  final theme = Theme.of(context);
  final groups = ref.read(userGroupsProvider).value ?? const <StudyGroup>[];
  final activeId = ref.read(userGroupProvider).value?.id;

  final items = <PopupMenuEntry<void>>[
    PopupMenuItem<void>(
      enabled: false,
      height: 32,
      child: Text(
        'Gruplarım',
        style: theme.textTheme.labelMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    ),
    if (groups.isEmpty)
      PopupMenuItem<void>(
        enabled: false,
        child: Text(
          'Henüz grup yok',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    for (final g in groups)
      PopupMenuItem<void>(
        onTap: () => ref.read(activeGroupIdProvider.notifier).select(g.id),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: g.id == activeId
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: g.id == activeId
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              child: Text(
                g.name.isNotEmpty
                    ? g.name.characters.first.toUpperCase()
                    : '?',
                style: theme.textTheme.labelMedium,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(g.name, overflow: TextOverflow.ellipsis)),
            if (g.id == activeId)
              Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
            if (!switchOnly) _ClassDetailButton(group: g),
          ],
        ),
      ),
    if (!switchOnly) ...[
      const PopupMenuDivider(),
      PopupMenuItem<void>(
        onTap: () => createGroupFlow(context, ref),
        child: const Row(
          children: [
            Icon(Icons.add, size: 20),
            SizedBox(width: 12),
            Text('Grup oluştur'),
          ],
        ),
      ),
      PopupMenuItem<void>(
        onTap: () => joinGroupFlow(context, ref),
        child: const Row(
          children: [
            Icon(Icons.login, size: 20),
            SizedBox(width: 12),
            Text('Gruba katıl'),
          ],
        ),
      ),
    ],
  ];

  return at != null
      ? showMenuAtPosition<void>(
          context: context, globalPosition: at, items: items)
      : showAnchoredMenu<void>(context: context, items: items);
}

/// Sınıf satırındaki ⋮ — menüyü kapatıp sınıf detay/ayar ekranını açar.
/// Satırın "aktif yap" eylemini tetiklemez (iç buton dokunuşu kazanır).
class _ClassDetailButton extends StatelessWidget {
  const _ClassDetailButton({required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Grup bilgileri ve ayarları',
      icon: const Icon(Icons.more_vert, size: 20),
      visualDensity: VisualDensity.compact,
      onPressed: () {
        final nav = Navigator.of(context, rootNavigator: true);
        Navigator.of(context).pop(); // menüyü kapat
        nav.push(MaterialPageRoute(
          builder: (_) => ClassDetailScreen(group: group),
        ));
      },
    );
  }
}

/// Sınıf oluşturma akışı: ad sorar, oluşturur, yeni sınıfı aktif yapar.
/// Başarılıysa true döner.
Future<bool> createGroupFlow(BuildContext context, WidgetRef ref) async {
  final name = await _promptText(
    context,
    title: 'Grup oluştur',
    label: 'Grup adı',
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
    title: 'Gruba katıl',
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
