import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/number_stepper.dart';
import '../../../core/widgets/crowned_avatar.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/study_group.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/nudge_providers.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/nudge_repository.dart';
import '../../profile/widgets/social_profile_dialog.dart';
import 'class_chat_card.dart';

/// Bir sınıfın bilgi + ayarları (§3.8). Üst kısım bilgiler (davet kodu, üyeler);
/// alt kısım ayarlar (sınıftan çık) ve admin işlemleri (ad değiştir, kod yenile,
/// üye çıkar, sınıfı sil). Admin = sınıfı oluşturan (`group.createdBy`).
class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({super.key, required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = ref.watch(authStateProvider).value?.id;
    final isAdmin = userId != null && group.createdBy == userId;
    final repo = ref.read(groupRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).classroomGrup),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: AppLocalizations.of(context).classroomAdiDegistir,
              icon: const Icon(Icons.edit),
              onPressed: () => _renameDialog(context, ref),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Başlık / ad ---
          Row(
            children: [
              Expanded(
                child: Text(group.name, style: theme.textTheme.headlineSmall),
              ),
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.of(context).classroomYonetici,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Bilgiler ---
          Text(
            AppLocalizations.of(context).classroomBilgiler,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: Text(AppLocalizations.of(context).classroomDavetKodu),
                  subtitle: SelectableText(
                    group.inviteCode,
                    style: theme.textTheme.titleMedium?.copyWith(
                      letterSpacing: 2,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: AppLocalizations.of(context).classroomKopyala,
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: group.inviteCode),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).classroomDavetKoduKopyalandi,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      if (isAdmin)
                        IconButton(
                          tooltip: AppLocalizations.of(
                            context,
                          ).classroomKoduYenile,
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: () => _regenerateCode(context, ref, repo),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(
                    AppLocalizations.of(context).classroomGunlukGrupHedefi,
                  ),
                  subtitle: Text(
                    '${formatHuman(group.dailyGoalMinutes * 60)} · '
                    '${AppLocalizations.of(context).classroomBugunkuToplam}',
                  ),
                  trailing: isAdmin
                      ? IconButton(
                          tooltip: AppLocalizations.of(
                            context,
                          ).classroomHedefiDegistir,
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editGoalDialog(context, ref),
                        )
                      : null,
                  onTap: isAdmin ? () => _editGoalDialog(context, ref) : null,
                ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    AppLocalizations.of(context).classroomOlusturulma,
                  ),
                  subtitle: Text(
                    DateFormat.yMd(
                      AppLocalizations.of(context).localeName,
                    ).format(group.createdAt),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Üyeler ---
          Text(
            AppLocalizations.of(context).classroomUyeler,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _MembersCard(group: group, isAdmin: isAdmin, currentUserId: userId),
          const SizedBox(height: 16),

          // --- Sohbet ---
          ClassChatCard(group: group),
          const SizedBox(height: 16),

          // --- Ayarlar / tehlikeli işlemler ---
          Text(
            AppLocalizations.of(context).classroomAyarlar,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (!isAdmin)
            Card(
              child: ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text(
                  AppLocalizations.of(context).classroomGruptanCik,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: userId == null
                    ? null
                    : () => _leave(context, ref, repo, userId),
              ),
            ),
          if (isAdmin)
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  AppLocalizations.of(context).classroomGrubuSil,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: Text(
                  AppLocalizations.of(context).classroomTumUyelerIcinKalici,
                ),
                onTap: () => _deleteGroup(context, ref, repo),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).classroomGrupAdiniDegistir),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).classroomGrupAdi,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).classroomVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(AppLocalizations.of(context).classroomKaydet),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || name.trim() == group.name) {
      return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final navigator = Navigator.of(context);
    try {
      await ref.read(groupRepositoryProvider).updateGroupName(group.id, name);
      // groups tablosu realtime publication'da degil ve watchUserGroups yalniz
      // group_members akisiyla tetiklenir; ad degisince akis tetiklenmez. Bu yuzden
      // gruplari elle tazele ki liste/ekranlar yeni adi aninda gostersin.
      ref.invalidate(userGroupsProvider);
      navigator.pop();
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  Future<void> _editGoalDialog(BuildContext context, WidgetRef ref) async {
    var hours = group.dailyGoalMinutes ~/ 60;
    var minutes = group.dailyGoalMinutes % 60;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context).classroomGunlukGrupHedefi),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${AppLocalizations.of(context).classroomGrubunBirGundeToplamda} '
                '${AppLocalizations.of(context).classroomOGunkuGrupToplami}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: NumberStepper(
                      label: AppLocalizations.of(context).classroomSaat,
                      value: hours,
                      min: 0,
                      max: 24,
                      onChanged: (v) => setState(() => hours = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: NumberStepper(
                      label: AppLocalizations.of(context).classroomDakika,
                      value: minutes,
                      min: 0,
                      max: 59,
                      onChanged: (v) => setState(() => minutes = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).classroomVazgec),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, (hours * 60 + minutes)),
              child: Text(AppLocalizations.of(context).classroomKaydet),
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked < 1 || picked == group.dailyGoalMinutes) {
      return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final navigator = Navigator.of(context);
    try {
      await ref.read(groupRepositoryProvider).updateGroupGoal(group.id, picked);
      // Ad degisimiyle ayni tazeleme gerekcesi (bkz. _renameDialog).
      ref.invalidate(userGroupsProvider);
      navigator.pop();
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  Future<void> _regenerateCode(
    BuildContext context,
    WidgetRef ref,
    GroupRepository repo,
  ) async {
    final ok = await _confirm(
      context,
      title: AppLocalizations.of(context).classroomKoduYenile,
      message: AppLocalizations.of(context).classroomYeniBirDavetKodu,
      action: AppLocalizations.of(context).classroomYenile,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    try {
      final code = await repo.regenerateInviteCode(group.id);
      // Yeni davet kodu da groups tablosunda; akis tetiklenmez (bkz. _renameDialog).
      ref.invalidate(userGroupsProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.classroomYeniKodCode(code))),
      );
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    GroupRepository repo,
    String userId,
  ) async {
    final ok = await _confirm(
      context,
      title: AppLocalizations.of(context).classroomGruptanCik,
      message:
          '"${group.name}" · '
          '${AppLocalizations.of(context).classroomGruptanCik}. '
          '${AppLocalizations.of(context).classroomBuIslemGeriAlinamaz}',
      action: AppLocalizations.of(context).classroomCik,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final navigator = Navigator.of(context);
    try {
      await repo.leaveGroup(group.id, userId);
      ref.read(activeGroupIdProvider.notifier).select(null);
      navigator.pop();
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  Future<void> _deleteGroup(
    BuildContext context,
    WidgetRef ref,
    GroupRepository repo,
  ) async {
    final ok = await _confirm(
      context,
      title: AppLocalizations.of(context).classroomGrubuSil,
      message:
          '"${group.name}" · '
          '${AppLocalizations.of(context).classroomTumUyelerIcinKalici}. '
          '${AppLocalizations.of(context).classroomBuIslemGeriAlinamaz}',
      action: AppLocalizations.of(context).classroomSil,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final navigator = Navigator.of(context);
    try {
      await repo.deleteGroup(group.id);
      ref.read(activeGroupIdProvider.notifier).select(null);
      navigator.pop();
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }
}

/// Sınıf üyeleri listesi (canlı). Admin başkasını çıkarabilir (kendisi/üye hariç).
class _MembersCard extends ConsumerWidget {
  const _MembersCard({
    required this.group,
    required this.isAdmin,
    required this.currentUserId,
  });

  final StudyGroup group;
  final bool isAdmin;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(groupRepositoryProvider);
    final currentUser = ref.watch(authStateProvider).value;
    return Card(
      child: StreamBuilder<List<Profile>>(
        stream: repo.watchMembers(group.id),
        builder: (context, snapshot) {
          final members = snapshot.data;
          if (members == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Column(
            children: [
              for (final m in members)
                ListTile(
                  leading: LiveCrownedAvatar(
                    userId: m.id,
                    displayName: m.displayName,
                    avatarUrl: m.avatarUrl,
                    radius: 18,
                  ),
                  title: Text(
                    !m.isActive
                        ? AppLocalizations.of(context).classroomEskiGrupUyesi
                        : (m.displayName.isEmpty
                              ? AppLocalizations.of(context).classroomIsimsiz
                              : m.displayName),
                  ),
                  subtitle: m.id == group.createdBy
                      ? Text(AppLocalizations.of(context).classroomYonetici)
                      : null,
                  onTap: () => SocialProfileDialog.show(context, m),
                  trailing: m.isActive && m.id != currentUserId
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: AppLocalizations.of(
                                context,
                              ).classroomDurt,
                              icon: const Icon(
                                Icons.notifications_active_outlined,
                              ),
                              onPressed: currentUser == null
                                  ? null
                                  : () => _sendNudge(
                                      context,
                                      ref,
                                      currentUser,
                                      m,
                                    ),
                            ),
                            if (isAdmin && m.id != group.createdBy)
                              IconButton(
                                tooltip: AppLocalizations.of(
                                  context,
                                ).classroomCikar,
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: () =>
                                    _removeMember(context, repo, m),
                              ),
                          ],
                        )
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeMember(
    BuildContext context,
    GroupRepository repo,
    Profile member,
  ) async {
    final ok = await _confirm(
      context,
      title: AppLocalizations.of(context).classroomUyeyiCikar,
      message: AppLocalizations.of(
        context,
      ).classroomMemberdisplaynameGruptanCikarilsinMi(member.displayName),
      action: AppLocalizations.of(context).classroomCikar,
    );
    if (!ok) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    try {
      await repo.removeMember(group.id, member.id);
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  Future<void> _sendNudge(
    BuildContext context,
    WidgetRef ref,
    Profile sender,
    Profile recipient,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(nudgeRepositoryProvider)
          .sendNudge(groupId: group.id, sender: sender, recipient: recipient);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.classroomRecipientdisplaynameDurtuldu(recipient.displayName),
          ),
        ),
      );
    } on NudgeException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }
}

/// Basit onay diyaloğu (tehlikeli işlemler için).
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(AppLocalizations.of(context).classroomVazgec),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}
