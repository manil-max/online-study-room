import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_card.dart';
import 'dashboard_edit_screen.dart';
import 'dashboard_providers.dart';

/// Ana Sayfa: kişiye özel, **özelleştirilebilir** kontrol paneli (§3.9).
/// Kullanıcı kartları ekler/çıkarır/sıralar (sağ üst düzenle). Yerleşim kalıcı.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(dashboardLayoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        actions: [
          IconButton(
            tooltip: 'Kartları düzenle',
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => _openEdit(context),
          ),
        ],
      ),
      body: layout.isEmpty
          ? _EmptyDashboard(onEdit: () => _openEdit(context))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final type in layout)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: dashboardCardFor(type),
                  ),
              ],
            ),
    );
  }

  void _openEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DashboardEditScreen()),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_outlined,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Ana Sayfan boş', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Görmek istediğin kartları ekle (sayaç, bugün özeti, sıralama, grafik).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.add),
              label: const Text('Kart ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
