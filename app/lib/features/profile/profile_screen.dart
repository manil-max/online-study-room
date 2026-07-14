import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/widgets/crowned_avatar.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../desktop/desktop_surface.dart';
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

    // Windows: içerik okuma genişliğinde ortalanır (full-bleed mobil liste değil).
    return Scaffold(
      appBar: isDesktopWindow
          ? null
          : AppBar(title: Text(AppLocalizations.of(context).profileProfil)),
      body: ListView(
        padding: getSafeVerticalPadding(context, horizontal: 24, vertical: 24),
        children: [
          DesktopReadingBody(
            maxWidth: DesktopSurface.readingWidth,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        CrownedAvatar(
                          displayName: AppLocalizations.of(
                            context,
                          ).profileMisafir,
                          radius: 48,
                        ),
                      if (profile != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: theme.colorScheme.primary,
                            shape: CircleBorder(),
                            child: InkWell(
                              customBorder: CircleBorder(),
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
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        profile?.displayName.isNotEmpty == true
                            ? profile!.displayName
                            : AppLocalizations.of(context).profileMisafir,
                        style: theme.textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile != null)
                      IconButton(
                        tooltip: AppLocalizations.of(context).profileAdiDuzenle,
                        icon: Icon(Icons.edit, size: 18),
                        onPressed: () =>
                            _editName(context, ref, profile.displayName),
                      ),
                  ],
                ),
                SizedBox(height: 24),
                GamificationCard(),
                SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.history),
                        title: Text(
                          AppLocalizations.of(context).profileCalismaKayitlarim,
                        ),
                        subtitle: Text(
                          AppLocalizations.of(
                            context,
                          ).profileManuelSureEkleDuzenle,
                        ),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () => showDesktopPanel<void>(
                          context: context,
                          builder: (_) => SessionHistoryScreen(),
                        ),
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.settings_outlined),
                        title: Text(
                          AppLocalizations.of(context).profileAyarlar,
                        ),
                        subtitle: Text(
                          AppLocalizations.of(
                            context,
                          ).profileGorunumAnaSayfaSayac,
                        ),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () => showDesktopPanel<void>(
                          context: context,
                          builder: (_) => SettingsScreen(),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  icon: Icon(Icons.logout),
                  label: Text(AppLocalizations.of(context).profileCikisYap),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _editName(
  BuildContext context,
  WidgetRef ref,
  String current,
) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: current);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.profileGorunenAdiDuzenle),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l10n.profileGorunenAd),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.profileVazgec),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(l10n.profileKaydet),
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
  } on AuthException {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
    );
  }
}

Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
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
      SnackBar(content: Text(l10n.profileProfilFotografiGuncellendi)),
    );
  } on AuthException {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
    );
  }
}
