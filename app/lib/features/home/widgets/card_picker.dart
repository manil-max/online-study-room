import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../desktop/desktop_surface.dart';
import '../dashboard_card.dart';
import '../dashboard_providers.dart';

/// Kart ekleme seçici.
/// Mobil: alt sayfa · Masaüstü: ortalanmış dialog + çok sütun.
Future<void> showCardPicker(BuildContext context) {
  return showDesktopPicker<void>(
    context: context,
    builder: (ctx) {
      // Mobil bottom sheet: sınırlı yükseklik için draggable sheet.
      if (MediaQuery.sizeOf(ctx).shortestSide < 600 &&
          MediaQuery.sizeOf(ctx).width < 700) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (context, scrollController) => const _CardPickerSheet(),
        );
      }
      return const _CardPickerSheet();
    },
  );
}

class _CardPickerSheet extends ConsumerWidget {
  const _CardPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final layout = ref.watch(dashboardLayoutProvider);
    final notifier = ref.read(dashboardLayoutProvider.notifier);
    final used = layout.map((c) => c.type).toSet();
    final available = DashboardCardType.values
        .where((t) => !used.contains(t))
        .toList();
    final categoryOrder = <String>[
      '${AppLocalizations.of(context).homeSayac} & '
          '${AppLocalizations.of(context).homeGunlukHedef}',
      AppLocalizations.of(context).homeOzetler,
      AppLocalizations.of(context).homeGrafikler,
      AppLocalizations.of(context).homeIsiHaritalari,
      AppLocalizations.of(context).homeGrup,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Row(
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context).homeKartEkle,
                style: theme.textTheme.titleLarge,
              ),
              const Spacer(),
              Text(
                '${available.length} kart',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).homeKapat,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        if (available.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).homeBitti,
                      style: theme.textTheme.titleMedium,
                    ),
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
                final cols = desktopGridColumns(
                  constraints.maxWidth,
                  compact: 2,
                  medium: 3,
                  expanded: 3,
                );
                final w = (constraints.maxWidth - 40 - gap * (cols - 1)) / cols;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    for (final cat in categoryOrder)
                      if (available.any((t) => t.category(context) == cat)) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                          child: Text(
                            cat,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final t in available.where(
                              (t) => t.category(context) == cat,
                            ))
                              SizedBox(
                                width: w,
                                child: _CardTile(
                                  type: t,
                                  onAdd: () {
                                    notifier.toggle(t);
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            AppLocalizations.of(
                                              context,
                                            ).homeTtitleEklendi(
                                              t.title(context),
                                            ),
                                          ),
                                          duration: const Duration(
                                            milliseconds: 900,
                                          ),
                                        ),
                                      );
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
      borderRadius: BorderRadius.circular(8),
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(type.icon, color: theme.colorScheme.primary, size: 20),
                const Spacer(),
                Icon(
                  Icons.add_circle,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              type.title(context),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              type.description(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
