import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/anchored_menu.dart';
import '../../../data/models/study_group.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/repositories/group_repository.dart';
import 'class_detail_screen.dart';
import 'group_discovery_screen.dart';

/// Sınıf değiştirici (Instagram hesap değiştirme mantığı, §3.8): katılınan
/// sınıflar listelenir, dokununca aktif sınıf değişir; ayrıca "Sınıf oluştur" /
/// "Sınıfa katıl". Alttan açılan pencere yerine **basılan yerde** açılır (§3.12).
///
/// Sağ üstteki ↔ ikonundan tetiklenirse [context] o ikonun context'idir (menü
/// ona göre konumlanır); sekmeye basılı tutunca [at] basış konumudur.
/// [switchOnly] true ise yalnızca grup değiştirme (oluştur/katıl/⋮ gizli) —
/// İstatistik gibi yerlerde sadece geçiş için.
Future<void> showClassSwitcher(
  BuildContext context,
  WidgetRef ref, {
  Offset? at,
  bool switchOnly = false,
}) {
  final theme = Theme.of(context);
  final groups = ref.read(userGroupsProvider).value ?? const <StudyGroup>[];
  final activeId = ref.read(userGroupProvider).value?.id;

  final items = <PopupMenuEntry<void>>[
    PopupMenuItem<void>(
      enabled: false,
      height: 32,
      child: Text(
        AppLocalizations.of(context).classroomGruplarim,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    if (groups.isEmpty)
      PopupMenuItem<void>(
        enabled: false,
        child: Text(
          AppLocalizations.of(context).classroomHenuzGrupYok,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
                g.name.isNotEmpty ? g.name.characters.first.toUpperCase() : '?',
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
        child: Row(
          children: [
            Icon(Icons.add, size: 20),
            SizedBox(width: 12),
            Text(AppLocalizations.of(context).classroomGrupOlustur),
          ],
        ),
      ),
      PopupMenuItem<void>(
        onTap: () => joinGroupFlow(context, ref),
        child: Row(
          children: [
            Icon(Icons.login, size: 20),
            SizedBox(width: 12),
            Text(AppLocalizations.of(context).classroomGrubaKatil),
          ],
        ),
      ),
      PopupMenuItem<void>(
        onTap: () => Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => const GroupDiscoveryScreen())),
        child: Row(
          children: [
            const Icon(Icons.travel_explore, size: 20),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context).groupDiscoveryAction),
          ],
        ),
      ),
    ],
  ];

  return at != null
      ? showMenuAtPosition<void>(
          context: context,
          globalPosition: at,
          items: items,
        )
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
      tooltip: AppLocalizations.of(context).classroomGrupBilgileriVeAyarlari,
      icon: const Icon(Icons.more_vert, size: 20),
      visualDensity: VisualDensity.compact,
      onPressed: () {
        final nav = Navigator.of(context, rootNavigator: true);
        Navigator.of(context).pop(); // menüyü kapat
        nav.push(
          MaterialPageRoute(builder: (_) => ClassDetailScreen(group: group)),
        );
      },
    );
  }
}

/// Sınıf oluşturma akışı: ad sorar, oluşturur, yeni sınıfı aktif yapar.
/// Başarılıysa true döner.
Future<bool> createGroupFlow(BuildContext context, WidgetRef ref) async {
  final draft = await _promptCreateGroup(context);
  if (draft == null || draft.name.trim().isEmpty) return false;

  final user = ref.read(authStateProvider).value;
  if (user == null) return false;
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final genericError = AppLocalizations.of(
    context,
  ).authBeklenmeyenBirHataOlustu;
  try {
    final group = await ref
        .read(groupRepositoryProvider)
        .createGroup(
          name: draft.name,
          creator: user,
          visibility: draft.visibility,
        );
    ref.read(activeGroupIdProvider.notifier).select(group.id);
    return true;
  } on GroupException {
    messenger.showSnackBar(SnackBar(content: Text(genericError)));
    return false;
  }
}

class _CreateGroupDraft {
  const _CreateGroupDraft({required this.name, required this.visibility});

  final String name;
  final GroupVisibility visibility;
}

Future<_CreateGroupDraft?> _promptCreateGroup(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<_CreateGroupDraft>(
    context: context,
    builder: (ctx) {
      var visibility = GroupVisibility.private;
      final l10n = AppLocalizations.of(ctx);
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.classroomGrupOlustur),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l10n.classroomGrupAdi),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.groupDiscoveryPrivacyTitle,
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                ),
                RadioGroup<GroupVisibility>(
                  groupValue: visibility,
                  onChanged: (value) => setState(() => visibility = value!),
                  child: Column(
                    children: [
                      RadioListTile<GroupVisibility>(
                        contentPadding: EdgeInsets.zero,
                        value: GroupVisibility.private,
                        title: Text(l10n.groupDiscoveryPrivate),
                        subtitle: Text(l10n.groupDiscoveryPrivateDescription),
                      ),
                      RadioListTile<GroupVisibility>(
                        contentPadding: EdgeInsets.zero,
                        value: GroupVisibility.public,
                        title: Text(l10n.groupDiscoveryPublic),
                        subtitle: Text(l10n.groupDiscoveryPublicDescription),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.classroomVazgec),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                _CreateGroupDraft(
                  name: controller.text,
                  visibility: visibility,
                ),
              ),
              child: Text(l10n.classroomOlustur),
            ),
          ],
        ),
      );
    },
  );
}

/// Sınıfa katılma akışı: davet kodu sorar, katar, o sınıfı aktif yapar.
/// Başarılıysa true döner.
Future<bool> joinGroupFlow(BuildContext context, WidgetRef ref) async {
  final code = await _promptText(
    context,
    title: AppLocalizations.of(context).classroomGrubaKatil,
    label: AppLocalizations.of(context).classroomDavetKodu,
    action: AppLocalizations.of(context).classroomKatil,
    uppercase: true,
  );
  if (code == null || code.trim().isEmpty) return false;

  final user = ref.read(authStateProvider).value;
  if (user == null) return false;
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final genericError = AppLocalizations.of(
    context,
  ).authBeklenmeyenBirHataOlustu;
  try {
    final group = await ref
        .read(groupRepositoryProvider)
        .joinGroup(inviteCode: code, member: user);
    ref.read(activeGroupIdProvider.notifier).select(group.id);
    return true;
  } on GroupException {
    messenger.showSnackBar(SnackBar(content: Text(genericError)));
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
        textCapitalization: uppercase
            ? TextCapitalization.characters
            : TextCapitalization.words,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (_) => Navigator.pop(ctx, controller.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppLocalizations.of(context).classroomVazgec),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(action),
        ),
      ],
    ),
  );
}
