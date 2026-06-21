import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/user_avatar.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/auth_repository.dart';
import 'session_history_screen.dart';
import 'subjects_screen.dart';

/// Profil sekmesi: foto, görünen ad, ayarlar, davet kodu. Bkz. project.md §3.2.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(authStateProvider).value;

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
            child: ListTile(
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
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Derslerim'),
              subtitle: const Text('Ders (kategori) ekle, düzenle, sil'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SubjectsScreen(),
                ),
              ),
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
      BuildContext context, WidgetRef ref, String current) async {
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
    final contentType = file.mimeType ??
        (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    try {
      await ref.read(authRepositoryProvider).updateAvatar(
            bytes: bytes,
            contentType: contentType,
          );
      ref.invalidate(authStateProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafı güncellendi')),
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
