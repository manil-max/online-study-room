import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_card.dart';
import 'dashboard_providers.dart';

/// Ana Sayfa düzenleme: görünen kartları **sürükle-bırakla sırala**, çıkar veya
/// yeni kart ekle (§3.9). Ayrıca sayacın Sınıflar ekranında da gösterilmesi.
class DashboardEditScreen extends ConsumerWidget {
  const DashboardEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final layout = ref.watch(dashboardLayoutProvider);
    final notifier = ref.read(dashboardLayoutProvider.notifier);
    final available = DashboardCardType.values
        .where((t) => !layout.contains(t))
        .toList();
    final showTimerInClass = ref.watch(classroomShowTimerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa’yı düzenle')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionTitle('Görünen kartlar'),
          if (layout.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Hiç kart yok. Aşağıdan ekleyebilirsin.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: layout.length,
              onReorderItem: notifier.reorderItem,
              itemBuilder: (context, index) {
                final type = layout[index];
                return ListTile(
                  key: ValueKey(type),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_handle,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  title: Text(type.title),
                  subtitle: Text(type.description),
                  trailing: IconButton(
                    tooltip: 'Kaldır',
                    icon: Icon(Icons.remove_circle_outline,
                        color: theme.colorScheme.error),
                    onPressed: () => notifier.toggle(type),
                  ),
                );
              },
            ),
          if (available.isNotEmpty) ...[
            const Divider(height: 24),
            _SectionTitle('Eklenebilir kartlar'),
            for (final type in available)
              ListTile(
                leading: Icon(type.icon),
                title: Text(type.title),
                subtitle: Text(type.description),
                trailing: IconButton(
                  tooltip: 'Ekle',
                  icon: Icon(Icons.add_circle_outline,
                      color: theme.colorScheme.primary),
                  onPressed: () => notifier.toggle(type),
                ),
              ),
          ],
          const Divider(height: 24),
          _SectionTitle('Diğer'),
          SwitchListTile(
            title: const Text('Gruplar ekranında da sayaç göster'),
            subtitle: const Text(
                'Sayaç varsayılan olarak Ana Sayfa’dadır; burada Gruplar’a da eklenir.'),
            value: showTimerInClass,
            onChanged: ref.read(classroomShowTimerProvider.notifier).set,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
