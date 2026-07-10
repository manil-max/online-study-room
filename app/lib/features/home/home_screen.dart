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

  Future<void> _confirmResetDashboard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ana Sayfa’yı sıfırla'),
        content: const Text(
          'Kart düzeni varsayılana döner (eklediğin kartlar ve boyutlar sıfırlanır). Devam?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    ref.read(dashboardLayoutProvider.notifier).reset();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ana Sayfa sıfırlandı')));
  }

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
          if (_editing) ...[
            IconButton(
              tooltip: 'Ana Sayfa’yı sıfırla',
              icon: const Icon(Icons.restart_alt),
              onPressed: _confirmResetDashboard,
            ),
            IconButton(
              tooltip: 'Kart ekle',
              icon: const Icon(Icons.add),
              onPressed: () => showCardPicker(context),
            ),
          ] else
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
                      'Kartı tutup sürükle; hedef hücreye bırakınca komşular yer açar. '
                      'Köşelerden çekerek hücreye oturan genişlik ve yükseklik ayarla.',
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
                    onMoveCard: (type, x, y) => ref
                        .read(dashboardLayoutProvider.notifier)
                        .setBounds(type, x: x, y: y),
                    onResizeCard: (type, x, y, w, h, persist) => ref
                        .read(dashboardLayoutProvider.notifier)
                        .setBounds(
                          type,
                          x: x,
                          y: y,
                          w: w,
                          h: h,
                          persist: persist,
                        ),
                    onCommit: ref
                        .read(dashboardLayoutProvider.notifier)
                        .persist,
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

class _MatrixGrid extends StatefulWidget {
  const _MatrixGrid({
    required this.layout,
    required this.editing,
    required this.onLongPressCard,
    required this.onMoveCard,
    required this.onResizeCard,
    required this.onCommit,
    required this.onRemove,
  });

  final List<DashboardCardConfig> layout;
  final bool editing;
  final VoidCallback onLongPressCard;
  final void Function(DashboardCardType type, int x, int y) onMoveCard;
  final void Function(
    DashboardCardType type,
    int x,
    int y,
    int w,
    int h,
    bool persist,
  )
  onResizeCard;
  final VoidCallback onCommit;
  final ValueChanged<DashboardCardType> onRemove;

  @override
  State<_MatrixGrid> createState() => _MatrixGridState();
}

class _DragTargetCell {
  const _DragTargetCell(this.type, this.x, this.y);

  final DashboardCardType type;
  final int x;
  final int y;
}

class _MatrixGridState extends State<_MatrixGrid> {
  final GlobalKey _gridKey = GlobalKey();
  _DragTargetCell? _target;

  void _clearTarget() {
    if (_target != null) setState(() => _target = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell =
            (constraints.maxWidth - (kGridColumns - 1) * _kGap) / kGridColumns;
        final baseRows = widget.layout.fold<int>(
          1,
          (max, c) => max > c.y + c.h ? max : c.y + c.h,
        );
        final draggedConfig = _target == null
            ? null
            : widget.layout.where((c) => c.type == _target!.type).firstOrNull;
        final totalRows = draggedConfig == null
            ? baseRows
            : (baseRows > _target!.y + draggedConfig.h
                  ? baseRows
                  : _target!.y + draggedConfig.h);
        final height = totalRows * cell + (totalRows - 1) * _kGap;

        double leftOf(DashboardCardConfig c) => c.x * (cell + _kGap);
        double topOf(DashboardCardConfig c) => c.y * (cell + _kGap);
        double widthOf(DashboardCardConfig c) => c.w * cell + (c.w - 1) * _kGap;
        double heightOf(DashboardCardConfig c) =>
            c.h * cell + (c.h - 1) * _kGap;

        void updateTarget(details) {
          final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          final config = widget.layout
              .where((c) => c.type == details.data)
              .firstOrNull;
          if (config == null) return;

          final local = box.globalToLocal(details.offset);
          final stride = cell + _kGap;
          final x = (local.dx / stride).floor().clamp(
            0,
            kGridColumns - config.w,
          );
          final y = (local.dy / stride).floor().clamp(0, 9999);
          final next = _DragTargetCell(config.type, x, y);
          if (_target?.type != next.type ||
              _target?.x != next.x ||
              _target?.y != next.y) {
            setState(() => _target = next);
          }
        }

        return DragTarget<DashboardCardType>(
          onWillAcceptWithDetails: (_) => widget.editing,
          onMove: updateTarget,
          onLeave: (_) => _clearTarget(),
          onAcceptWithDetails: (details) {
            final target = _target;
            if (target != null) {
              widget.onMoveCard(details.data, target.x, target.y);
            }
            _clearTarget();
          },
          builder: (context, candidateData, rejectedData) {
            return SizedBox(
              key: _gridKey,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (widget.editing)
                    _GridBackdrop(cell: cell, rows: totalRows),
                  if (draggedConfig != null && _target != null)
                    Positioned(
                      left: _target!.x * (cell + _kGap),
                      top: _target!.y * (cell + _kGap),
                      width: widthOf(draggedConfig),
                      height: heightOf(draggedConfig),
                      child: _DropGhost(),
                    ),
                  for (final c in widget.layout)
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
                        cell: cell,
                        width: widthOf(c),
                        height: heightOf(c),
                        editing: widget.editing,
                        onLongPressCard: widget.onLongPressCard,
                        onResize: (x, y, w, h, persist) =>
                            widget.onResizeCard(c.type, x, y, w, h, persist),
                        onCommit: widget.onCommit,
                        onRemove: () => widget.onRemove(c.type),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DropGhost extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.75),
          width: 1.5,
        ),
      ),
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

class _MatrixCard extends StatefulWidget {
  const _MatrixCard({
    required this.config,
    required this.cell,
    required this.width,
    required this.height,
    required this.editing,
    required this.onLongPressCard,
    required this.onResize,
    required this.onCommit,
    required this.onRemove,
  });

  final DashboardCardConfig config;
  final double cell;
  final double width;
  final double height;
  final bool editing;
  final VoidCallback onLongPressCard;
  final void Function(int x, int y, int w, int h, bool persist) onResize;
  final VoidCallback onCommit;
  final VoidCallback onRemove;

  @override
  State<_MatrixCard> createState() => _MatrixCardState();
}

class _MatrixCardState extends State<_MatrixCard> {
  DashboardCardConfig? _resizeStart;
  double _dx = 0;
  double _dy = 0;

  void _onResizeStart() {
    _resizeStart = widget.config;
    _dx = 0;
    _dy = 0;
  }

  void _onResizeUpdate(DragUpdateDetails details, _ResizeAnchor anchor) {
    final start = _resizeStart;
    if (start == null) return;
    _dx += details.delta.dx;
    _dy += details.delta.dy;
    final stride = widget.cell + _kGap;
    final colDelta = (_dx / stride).round();
    final rowDelta = (_dy / stride).round();

    var x = start.x;
    var y = start.y;
    var w = start.w;
    var h = start.h;

    if (anchor.left) {
      final right = start.x + start.w;
      x = (start.x + colDelta).clamp(0, right - 1);
      w = right - x;
    } else {
      w = (start.w + colDelta).clamp(1, kGridColumns - start.x);
    }

    if (anchor.top) {
      final bottom = start.y + start.h;
      y = (start.y + rowDelta).clamp(0, bottom - 1);
      h = bottom - y;
    } else {
      h = (start.h + rowDelta).clamp(1, 99);
    }

    widget.onResize(x, y, w, h, false);
  }

  void _onResizeEnd() {
    _resizeStart = null;
    widget.onCommit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = dashboardCardFor(
      widget.config.type,
      widget.config.size,
      height: widget.height,
    );

    if (!widget.editing) {
      return GestureDetector(
        onLongPress: widget.onLongPressCard,
        child: _HoverLift(child: card),
      );
    }

    final editCard = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: IgnorePointer(child: card)),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.60),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        // Boyutlandırma tutamaçları (kontrol hapından ÖNCE çizilir ki büyük
        // dokunma alanları hapın "kaldır" butonunu dar kartlarda örtmesin).
        _ResizeHandle(
          anchor: const _ResizeAnchor(left: true, top: true),
          onStart: _onResizeStart,
          onUpdate: _onResizeUpdate,
          onEnd: _onResizeEnd,
        ),
        _ResizeHandle(
          anchor: const _ResizeAnchor(left: false, top: true),
          onStart: _onResizeStart,
          onUpdate: _onResizeUpdate,
          onEnd: _onResizeEnd,
        ),
        _ResizeHandle(
          anchor: const _ResizeAnchor(left: true, top: false),
          onStart: _onResizeStart,
          onUpdate: _onResizeUpdate,
          onEnd: _onResizeEnd,
        ),
        _ResizeHandle(
          anchor: const _ResizeAnchor(left: false, top: false),
          onStart: _onResizeStart,
          onUpdate: _onResizeUpdate,
          onEnd: _onResizeEnd,
        ),
        Positioned(
          top: -6,
          left: 6,
          right: 6,
          child: Center(
            child: Material(
              color: theme.colorScheme.surface,
              elevation: 1,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.drag_indicator,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.config.w}×${widget.config.h}',
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
                      onPressed: widget.onRemove,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return LongPressDraggable<DashboardCardType>(
      data: widget.config.type,
      feedback: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Opacity(
          opacity: 0.6,
          child: Material(
            color: Colors.transparent,
            child: dashboardCardFor(
              widget.config.type,
              widget.config.size,
              height: widget.height,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.28, child: editCard),
      child: editCard,
    );
  }
}

class _ResizeAnchor {
  const _ResizeAnchor({required this.left, required this.top});

  final bool left;
  final bool top;
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.anchor,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final _ResizeAnchor anchor;
  final VoidCallback onStart;
  final void Function(DragUpdateDetails details, _ResizeAnchor anchor) onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Dokunma alanı bilerek görünen noktadan çok daha büyük (48px, min. parmak
    // hedefi) ve kartın dışına daha çok taşar (−22px) → telefonda kenardan
    // tutması kolaylaşır. Görünen nokta küçük/zarif kalır (launcher hissi).
    return Positioned(
      left: anchor.left ? -22 : null,
      right: anchor.left ? null : -22,
      top: anchor.top ? -22 : null,
      bottom: anchor.top ? null : -22,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onStart(),
        onPanUpdate: (details) => onUpdate(details, anchor),
        onPanEnd: (_) => onEnd(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.85),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const SizedBox(width: 12, height: 12),
            ),
          ),
        ),
      ),
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
