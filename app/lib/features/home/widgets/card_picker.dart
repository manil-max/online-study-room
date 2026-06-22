import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard_card.dart';
import '../dashboard_providers.dart';

/// Kart ekleme seçici (alt sayfa): eklenebilir kartları **kategorilere göre**,
/// ikon + başlık + açıklamayla gösterir. Dokununca eklenir ve listeden çıkar;
/// sayfa açık kalır (çoklu ekleme). Eski küçük popup'ın yerine.
Future<void> showCardPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _CardPickerSheet(),
  );
}

const _kOrder = ['Sayaç & Hedef', 'Özetler', 'Grafikler', 'Isı haritaları', 'Grup'];

class _CardPickerSheet extends ConsumerWidget {
  const _CardPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final layout = ref.watch(dashboardLayoutProvider);
    final notifier = ref.read(dashboardLayoutProvider.notifier);
    final used = layout.map((c) => c.type).toSet();
    final available =
        DashboardCardType.values.where((t) => !used.contains(t)).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scroll) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.dashboard_customize_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('Kart ekle', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  Text('${available.length} kart',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (available.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: theme.colorScheme.secondary),
                        const SizedBox(height: 12),
                        Text('Tüm kartlar zaten ekli 🎉',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 10.0;
                    final w = (constraints.maxWidth - 40 - gap) / 2;
                    return ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        for (final cat in _kOrder)
                          if (available.any((t) => t.category == cat)) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                              child: Text(cat,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700)),
                            ),
                            Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final t
                                    in available.where((t) => t.category == cat))
                                  SizedBox(
                                    width: w,
                                    child: _CardTile(
                                      type: t,
                                      onAdd: () {
                                        notifier.toggle(t);
                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(SnackBar(
                                            content: Text('“${t.title}” eklendi'),
                                            duration:
                                                const Duration(milliseconds: 900),
                                          ));
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ],
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.type, required this.onAdd});

  final DashboardCardType type;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(type.icon, color: theme.colorScheme.primary, size: 20),
                const Spacer(),
                Icon(Icons.add_circle,
                    color: theme.colorScheme.primary, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(type.title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(type.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
