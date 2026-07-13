import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/widgets/crowned_avatar.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../desktop/desktop_page_scaffold.dart';
import 'session_history_screen.dart';
import 'settings_screen.dart';
import 'widgets/gamification_card.dart';

/// Profil sekmesi: foto, görünen ad, ayarlar. Grup yönetimi → Gruplar sekmesi.
/// Bkz. project.md §3.2.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(authStateProvider).value;

    if (isDesktopWindow) {
      return DesktopPageScaffold(
        title: 'Profil ve hesap',
        subtitle: 'Kimliğini, çalışma geçmişini ve tercihlerini yönet.',
        icon: Icons.person_outline,
        child: SingleChildScrollView(
          child: DesktopContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DesktopPanel(
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (profile != null)
                            LiveCrownedAvatar(
                              userId: profile.id,
                              displayName: profile.displayName,
                              avatarUrl: profile.avatarUrl,
                              radius: 42,
                            )
                          else
                            const CrownedAvatar(
                              displayName: '',
                              radius: 42,
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
                                      size: 16,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.displayName ?? 'Kullanıcı',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Odak Kampı hesabı',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (profile != null)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _editName(context, ref, profile.displayName),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Adı düzenle'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const GamificationCard(),
                const SizedBox(height: 16),
                DesktopPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: const Text('Çalışma kayıtlarım'),
                        subtitle: const Text(
                          'Oturumlarını görüntüle, düzenle veya manuel süre ekle',
                        ),
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
                          'Görünüm, pano, sayaç ve bildirim tercihleri',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.read(authRepositoryProvider).signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Hesaptan çık'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: getSafeVerticalPadding(context, horizontal: 24, vertical: 24),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (profile != null)
                  LiveCrownedAvatar(
                    userId: profile.id,
                    displayName: profile.displayName,
                    avatarUrl: profile.avatarUrl,
                    radius: 48,
                  )
                else
                  const CrownedAvatar(displayName: 'Misafir', radius: 48),
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
          const SizedBox(height: 24),
          const GamificationCard(),
          const SizedBox(height: 16),
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
