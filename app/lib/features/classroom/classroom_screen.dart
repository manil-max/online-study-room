import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/duration_format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/presence.dart';
import '../../data/models/profile.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/presence_providers.dart';
import '../../data/providers/study_providers.dart';
import '../../data/models/study_group.dart';
import '../../data/repositories/group_repository.dart';
import 'widgets/study_timer_card.dart';

/// Sınıf sekmesi: ana sayfa + canlı sınıf (birleşik). Bkz. project.md §3.0/§3.5.
/// Sınıf yoksa oluştur/katıl ekranı; varsa kendi sayacın + canlı üye listesi.
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const StudyTimerCard(),
        const SizedBox(height: 8),
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
          child: Text('Sınıf', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 4),
        const _LiveMembers(),
      ],
    );
  }
}

/// Canlı sınıf listesi: her üyenin durumu (çalışıyor/mola/çevrimdışı), anlık
/// süresi ve bugünkü toplamı. Çalışan üyeler üstte. Anlık süreleri her saniye
/// yenilemek için kendi periyodik zamanlayıcısı vardır (bkz. project.md §3.5).
class _LiveMembers extends ConsumerStatefulWidget {
  const _LiveMembers();

  @override
  ConsumerState<_LiveMembers> createState() => _LiveMembersState();
}

class _LiveMembersState extends ConsumerState<_LiveMembers> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider);
    final presenceList = ref.watch(groupPresenceProvider).value ?? const [];
    final todayByUser = ref.watch(groupTodaySecondsProvider);

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Üyeler yüklenemedi: $e'),
      data: (members) {
        final presenceByUser = {for (final p in presenceList) p.userId: p};
        final now = DateTime.now();

        // Çalışanlar üstte; aynı grupta isme göre sırala.
        final sorted = [...members]..sort((a, b) {
            final aStudying =
                presenceByUser[a.id]?.status == PresenceStatus.studying;
            final bStudying =
                presenceByUser[b.id]?.status == PresenceStatus.studying;
            if (aStudying != bStudying) return aStudying ? -1 : 1;
            return a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                );
          });

        return Column(
          children: [
            for (final m in sorted)
              _MemberTile(
                member: m,
                presence: presenceByUser[m.id],
                recordedToday: todayByUser[m.id] ?? 0,
                now: now,
              ),
          ],
        );
      },
    );
  }
}

/// Tek bir üyenin canlı kartı.
class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.presence,
    required this.recordedToday,
    required this.now,
  });

  final Profile member;
  final Presence? presence;
  final int recordedToday;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = presence?.status ?? PresenceStatus.offline;
    final isStudying = status == PresenceStatus.studying;

    // Anlık süre: yalnızca çalışırken, başlangıç anından bu yana.
    final startedAt = presence?.startedAt;
    final liveExtra = (isStudying && startedAt != null)
        ? now.difference(startedAt).inSeconds
        : 0;
    final todayTotal = recordedToday + (liveExtra > 0 ? liveExtra : 0);

    final (Color dotColor, String label) = switch (status) {
      PresenceStatus.studying => (Colors.green, 'Çalışıyor'),
      PresenceStatus.onBreak => (Colors.orange, 'Mola'),
      PresenceStatus.offline => (theme.colorScheme.outline, 'Çevrimdışı'),
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Stack(
        children: [
          UserAvatar(
            displayName: member.displayName,
            avatarUrl: member.avatarUrl,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(member.displayName),
      subtitle: Text('$label · Bugün ${formatHumanSeconds(todayTotal)}'),
      trailing: isStudying
          ? Text(
              formatHms(liveExtra),
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.green,
                fontFeatures: const [],
              ),
            )
          : null,
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
