import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/number_stepper.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/study_group.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/repositories/group_repository.dart';

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
        title: const Text('Grup'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Adı değiştir',
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Yönetici',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Bilgiler ---
          Text('Bilgiler', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: const Text('Davet kodu'),
                  subtitle: SelectableText(
                    group.inviteCode,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(letterSpacing: 2),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Kopyala',
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: group.inviteCode));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Davet kodu kopyalandı')),
                            );
                          }
                        },
                      ),
                      if (isAdmin)
                        IconButton(
                          tooltip: 'Kodu yenile',
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: () => _regenerateCode(context, repo),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Günlük grup hedefi'),
                  subtitle: Text(
                    '${formatHuman(group.dailyGoalMinutes * 60)} (grup toplamı)',
                  ),
                  trailing: isAdmin
                      ? IconButton(
                          tooltip: 'Hedefi değiştir',
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editGoalDialog(context, ref),
                        )
                      : null,
                  onTap: isAdmin ? () => _editGoalDialog(context, ref) : null,
                ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Oluşturulma'),
                  subtitle: Text(
                    '${group.createdAt.day}.${group.createdAt.month}.${group.createdAt.year}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Üyeler ---
          Text('Üyeler', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _MembersCard(group: group, isAdmin: isAdmin, currentUserId: userId),
          const SizedBox(height: 16),

          // --- Sohbet (ileride) ---
          Card(
            child: ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Sohbet'),
              subtitle: const Text('Yakında'),
              enabled: false,
            ),
          ),
          const SizedBox(height: 16),

          // --- Ayarlar / tehlikeli işlemler ---
          Text('Ayarlar', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (!isAdmin)
            Card(
              child: ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text('Gruptan çık',
                    style: TextStyle(color: theme.colorScheme.error)),
                onTap: userId == null
                    ? null
                    : () => _leave(context, ref, repo, userId),
              ),
            ),
          if (isAdmin)
            Card(
              child: ListTile(
                leading: Icon(Icons.delete_outline,
                    color: theme.colorScheme.error),
                title: Text('Grubu sil',
                    style: TextStyle(color: theme.colorScheme.error)),
                subtitle: const Text('Tüm üyeler için kalıcı olarak silinir'),
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
        title: const Text('Grup adını değiştir'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Grup adı'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || name.trim() == group.name) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(groupRepositoryProvider).updateGroupName(group.id, name);
      // Bu ekran eski adı tutuyor; en basiti kapatmak (liste güncel veriyle döner).
      navigator.pop();
    } on GroupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editGoalDialog(BuildContext context, WidgetRef ref) async {
    var hours = group.dailyGoalMinutes ~/ 60;
    var minutes = group.dailyGoalMinutes % 60;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Günlük grup hedefi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Grubun bir günde toplamda çalışmayı hedeflediği süre. '
                'O günkü grup toplamı bu süreye ulaşırsa grup serisi büyür.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: NumberStepper(
                      label: 'Saat',
                      value: hours,
                      min: 0,
                      max: 24,
                      onChanged: (v) => setState(() => hours = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: NumberStepper(
                      label: 'Dakika',
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
                child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, (hours * 60 + minutes)),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked < 1 || picked == group.dailyGoalMinutes) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(groupRepositoryProvider).updateGroupGoal(group.id, picked);
      // Bu ekran eski hedefi tutuyor; en basiti kapatmak (liste güncel veriyle döner).
      navigator.pop();
    } on GroupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _regenerateCode(
      BuildContext context, GroupRepository repo) async {
    final ok = await _confirm(context,
        title: 'Kodu yenile',
        message:
            'Yeni bir davet kodu üretilecek; eski kod artık çalışmaz. Devam?',
        action: 'Yenile');
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final code = await repo.regenerateInviteCode(group.id);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Yeni kod: $code')));
    } on GroupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, GroupRepository repo,
      String userId) async {
    final ok = await _confirm(context,
        title: 'Gruptan çık',
        message: '"${group.name}" grubundan çıkmak istediğine emin misin?',
        action: 'Çık');
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await repo.leaveGroup(group.id, userId);
      ref.read(activeGroupIdProvider.notifier).select(null);
      navigator.pop();
    } on GroupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteGroup(
      BuildContext context, WidgetRef ref, GroupRepository repo) async {
    final ok = await _confirm(context,
        title: 'Grubu sil',
        message:
            '"${group.name}" grubu tüm üyeler için kalıcı olarak silinecek. '
            'Bu işlem geri alınamaz. Devam?',
        action: 'Sil');
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await repo.deleteGroup(group.id);
      ref.read(activeGroupIdProvider.notifier).select(null);
      navigator.pop();
    } on GroupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
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
                  leading: UserAvatar(
                    displayName: m.displayName,
                    avatarUrl: m.avatarUrl,
                    radius: 18,
                  ),
                  title: Text(!m.isActive
                      ? 'Eski Grup Üyesi'
                      : (m.displayName.isEmpty ? 'İsimsiz' : m.displayName)),
                  subtitle: m.id == group.createdBy
                      ? const Text('Yönetici')
                      : null,
                  trailing: (isAdmin &&
                          m.isActive &&
                          m.id != currentUserId &&
                          m.id != group.createdBy)
                      ? IconButton(
                          tooltip: 'Çıkar',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () =>
                              _removeMember(context, repo, m),
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
      BuildContext context, GroupRepository repo, Profile member) async {
    final ok = await _confirm(context,
        title: 'Üyeyi çıkar',
        message:
            '${member.displayName} gruptan çıkarılsın mı?',
        action: 'Çıkar');
    if (!ok) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.removeMember(group.id, member.id);
    } on GroupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
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
            child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}
