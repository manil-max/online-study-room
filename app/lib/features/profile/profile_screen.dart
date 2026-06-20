import 'package:flutter/material.dart';

/// Profil sekmesi: foto, görünen ad, ayarlar, davet kodu. Bkz. project.md §3.2.
/// Şimdilik yer tutucu — içerik Faz 1'de (hesap + profil) gelecek.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Profil', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Hesap, profil fotoğrafı ve ayarlar burada olacak.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
