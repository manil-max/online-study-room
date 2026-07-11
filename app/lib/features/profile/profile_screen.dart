import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/duration_format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/study_group.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../classroom/widgets/class_switcher.dart';
import 'session_history_screen.dart';
import 'settings_screen.dart';
import 'widgets/gamification_card.dart';

/// Profil sekmesi: foto, görünen ad, ayarlar, davet kodu. Bkz. project.md §3.2.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(authStateProvider).value;
    final activeGroup = ref.watch(userGroupProvider).value;
    final groupMembers = ref.watch(groupMembersProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Stack(
              children: [
                UserAvatar(
                  displayName: profile?.displayName ?? '',
                  avatarUrl: profile?.avatarUrl,
                  radius: 48,
                ),
                if (profile != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: theme.colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _pickAvatar(context, ref),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.photo_camera,
                            size: 18,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  profile?.displayName.isNotEmpty == true
                      ? profile!.displayName
                      : 'Misafir',
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (profile != null)
                IconButton(
                  tooltip: 'Adı düzenle',
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _editName(context, ref, profile.displayName),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Çalışma kayıtlarım'),
                  subtitle: const Text('Manuel süre ekle, düzenle, sil'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SessionHistoryScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Ayarlar'),
                  subtitle: const Text(
                    'Görünüm, Ana Sayfa, sayaç ve bildirimler',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış yap'),
          ),
          const SizedBox(height: 16),
          _ActiveGroupCard(
            group: activeGroup,
            memberCount: groupMembers.length,
            onCreateGroup: () => createGroupFlow(context, ref),
            onJoinGroup: () => joinGroupFlow(context, ref),
            onSwitchGroup: () =>
                showClassSwitcher(context, ref, switchOnly: true),
          ),
          const SizedBox(height: 16),
          const GamificationCard(),
        ],
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görünen adı düzenle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Görünen ad'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || name.trim() == current) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(name);
      ref.invalidate(authStateProvider);
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final contentType =
        file.mimeType ??
        (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    try {
      await ref
          .read(authRepositoryProvider)
          .updateAvatar(bytes: bytes, contentType: contentType);
      ref.invalidate(authStateProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafı güncellendi')),
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _ActiveGroupCard extends StatelessWidget {
  const _ActiveGroupCard({
    required this.group,
    required this.memberCount,
    required this.onCreateGroup,
    required this.onJoinGroup,
    required this.onSwitchGroup,
  });

  final StudyGroup? group;
  final int memberCount;
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;
  final VoidCallback onSwitchGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentGroup = group;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: currentGroup == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aktif grup', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Henüz bir grubun yok. Buradan oluşturabilir veya kodla katılabilirsin.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: onCreateGroup,
                        icon: const Icon(Icons.add),
                        label: const Text('Grup oluştur'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onJoinGroup,
                        icon: const Icon(Icons.login),
                        label: const Text('Koda katıl'),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Aktif grup',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onSwitchGroup,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Grup değiştir'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          currentGroup.name,
                          style: theme.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$memberCount üye',
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Günlük hedef: ${formatHuman(currentGroup.dailyGoalMinutes * 60)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Davet kodu: ${currentGroup.inviteCode}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
