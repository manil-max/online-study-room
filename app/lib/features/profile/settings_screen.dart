import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/dashboard_providers.dart';
import 'appearance_screen.dart';

/// Ayarlar: görünüm (tema/palet), Ana Sayfa davranışı ve sıfırlama.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showTimerInClass = ref.watch(classroomShowTimerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          const _SectionTitle('Görünüm'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Renk paleti ve tema'),
              subtitle: const Text('Açık/koyu + 5 renk paleti'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppearanceScreen()),
              ),
            ),
          ),
          const _SectionTitle('Ana Sayfa'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.timer_outlined),
                  title: const Text('Gruplar ekranında da sayaç göster'),
                  subtitle: const Text('Sayaç varsayılan Ana Sayfa’dadır.'),
                  value: showTimerInClass,
                  onChanged: ref.read(classroomShowTimerProvider.notifier).set,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.restart_alt,
                      color: theme.colorScheme.error),
                  title: const Text('Ana Sayfa’yı sıfırla'),
                  subtitle:
                      const Text('Kart düzenini varsayılana döndürür'),
                  onTap: () => _confirmReset(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ana Sayfa’yı sıfırla'),
        content: const Text(
            'Kart düzeni varsayılana döner (eklediğin kartlar ve boyutlar sıfırlanır). Devam?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sıfırla')),
        ],
      ),
    );
    if (ok == true) {
      ref.read(dashboardLayoutProvider.notifier).reset();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ana Sayfa sıfırlandı')),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}
