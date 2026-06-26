import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_card.dart';
import 'dashboard_providers.dart';
import 'widgets/card_picker.dart';

/// Ana Sayfa: kişiye özel, özelleştirilebilir 6xN matris (§2.2).
/// Kartlar kalıcı `x,y,w,h` hücrelerine göre `Stack + AnimatedPositioned`
/// içinde çizilir.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _editing = false;

  // Görünüm <-> düzenleme geçişinde kaydırma konumunu korur (§2F).
  final ScrollController _scroll = ScrollController();

  void _setEditing(bool value) => setState(() => _editing = value);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(dashboardLayoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Kartları düzenle' : 'Ana Sayfa'),
        leading: _editing
            ? IconButton(
                tooltip: 'Bitti',
                icon: const Icon(Icons.check),
                onPressed: () => _setEditing(false),
              )
            : null,
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Kart ekle',
              icon: const Icon(Icons.add),
              onPressed: () => showCardPicker(context),
            )
          else
            IconButton(
              tooltip: 'Kartları düzenle',
              icon: const Icon(Icons.dashboard_customize_outlined),
              onPressed: () => _setEditing(true),
            ),
        ],
      ),
      body: layout.isEmpty
          ? _EmptyDashboard(onEdit: () => showCardPicker(context))
          : SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_editing) ...[
                    Text(
                      'Kartlar 6 sütunlu matriste duruyor. Şimdilik kaldırma/ekleme aktif; '
                      'sürükleme ve hücreye snap boyutlandırma sıradaki adımda gelecek.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _MatrixGrid(
                    layout: layout,
                    editing: _editing,
                    onLongPressCard: () => _setEditing(true),
                    onRemove: ref
                        .read(dashboardLayoutProvider.notifier)
                        .removeCard,
                  ),
                  if (_editing) ...[
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Gruplar ekranında da sayaç göster'),
                      subtitle: const Text('Sayaç varsayılan Ana Sayfa’dadır.'),
                      value: ref.watch(classroomShowTimerProvider),
                      onChanged: ref
                          .read(classroomShowTimerProvider.notifier)
                          .set,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

const double _kGap = 8.0;

class _MatrixGrid extends StatelessWidget {
  const _MatrixGrid({
    required this.layout,
    required this.editing,
    required this.onLongPressCard,
    required this.onRemove,
  });

  final List<DashboardCardConfig> layout;
  final bool editing;
  final VoidCallback onLongPressCard;
  final ValueChanged<DashboardCardType> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell =
            (constraints.maxWidth - (kGridColumns - 1) * _kGap) / kGridColumns;
        final totalRows = layout.fold<int>(
          1,
          (max, c) => max > c.y + c.h ? max : c.y + c.h,
        );
        final height = totalRows * cell + (totalRows - 1) * _kGap;

        double leftOf(DashboardCardConfig c) => c.x * (cell + _kGap);
        double topOf(DashboardCardConfig c) => c.y * (cell + _kGap);
        double widthOf(DashboardCardConfig c) => c.w * cell + (c.w - 1) * _kGap;
        double heightOf(DashboardCardConfig c) =>
            c.h * cell + (c.h - 1) * _kGap;

        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (editing) _GridBackdrop(cell: cell, rows: totalRows),
              for (final c in layout)
                AnimatedPositioned(
                  key: ValueKey(c.type),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  left: leftOf(c),
                  top: topOf(c),
                  width: widthOf(c),
                  height: heightOf(c),
                  child: _MatrixCard(
                    config: c,
                    height: heightOf(c),
                    editing: editing,
                    onLongPressCard: onLongPressCard,
                    onRemove: () => onRemove(c.type),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GridBackdrop extends StatelessWidget {
  const _GridBackdrop({required this.cell, required this.rows});

  final double cell;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        for (var y = 0; y < rows; y++)
          for (var x = 0; x < kGridColumns; x++)
            Positioned(
              left: x * (cell + _kGap),
              top: y * (cell + _kGap),
              width: cell,
              height: cell,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _MatrixCard extends StatelessWidget {
  const _MatrixCard({
    required this.config,
    required this.height,
    required this.editing,
    required this.onLongPressCard,
    required this.onRemove,
  });

  final DashboardCardConfig config;
  final double height;
  final bool editing;
  final VoidCallback onLongPressCard;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = dashboardCardFor(config.type, config.size, height: height);

    if (!editing) {
      return GestureDetector(
        onLongPress: onLongPressCard,
        child: _HoverLift(child: card),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: IgnorePointer(child: card)),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.75),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          left: 6,
          right: 6,
          child: Center(
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest,
              elevation: 2,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      config.type.icon,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${config.w}×${config.h}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kaldır',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      icon: Icon(
                        Icons.remove_circle_outline,
                        size: 17,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: onRemove,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HoverLift extends StatefulWidget {
  const _HoverLift({required this.child});

  final Widget child;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.012 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.22),
                      blurRadius: 18,
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
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
            Icon(
              Icons.dashboard_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Ana Sayfan boş', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Görmek istediğin kartları ekle (sayaç, bugün özeti, sıralama, grafik).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
