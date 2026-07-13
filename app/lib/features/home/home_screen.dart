import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../desktop/desktop_page_scaffold.dart';
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
    final columns = ref.watch(dashboardGridColumnsProvider);
    final layout = ref.watch(dashboardLayoutProvider);
    final body = layout.isEmpty
        ? _EmptyDashboard(onEdit: () => showCardPicker(context))
        : SingleChildScrollView(
            controller: _scroll,
            padding: getSafeVerticalPadding(
              context,
              horizontal: isDesktopWindow ? 24 : 16,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: DesktopBreakpoints.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_editing) ...[
                      Text(
                        'Kartı tutup sürükle; hedef hücreye bırakınca komşular yer açar. '
                        'Boyut için karta dokun, aşağıdaki −/+ ile genişlik ve '
                        'yüksekliği ayarla (ya da köşelerden çek).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _MatrixGrid(
                      layout: layout,
                      columns: columns,
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
                        subtitle: const Text(
                          'Sayaç varsayılan Ana Sayfa’dadır.',
                        ),
                        value: ref.watch(classroomShowTimerProvider),
                        onChanged: ref
                            .read(classroomShowTimerProvider.notifier)
                            .set,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );

    if (isDesktopWindow) {
      return DesktopPageScaffold(
        title: _editing ? 'Panoyu düzenle' : 'Ana Sayfa',
        subtitle: _editing
            ? 'Kartları sürükle, yeniden boyutlandır ve çalışma alanını kişiselleştir.'
            : 'Bugünkü odağın, grubun ve çalışma ritmin tek görünümde.',
        icon: Icons.space_dashboard_outlined,
        actions: _editing
            ? [
                TextButton.icon(
                  onPressed: () => _setEditing(false),
                  icon: const Icon(Icons.check),
                  label: const Text('Bitti'),
                ),
                OutlinedButton.icon(
                  onPressed: ref
                      .read(dashboardLayoutProvider.notifier)
                      .compactUp,
                  icon: const Icon(Icons.vertical_align_top),
                  label: const Text('Yukarı topla'),
                ),
                OutlinedButton.icon(
                  onPressed: _confirmResetDashboard,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Sıfırla'),
                ),
                FilledButton.icon(
                  onPressed: () => showCardPicker(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Kart ekle'),
                ),
              ]
            : [
                FilledButton.tonalIcon(
                  onPressed: () => _setEditing(true),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Panoyu düzenle'),
                ),
              ],
        child: body,
      );
    }

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
              tooltip: 'Boşlukları yukarı topla',
              icon: const Icon(Icons.vertical_align_top),
              onPressed: ref.read(dashboardLayoutProvider.notifier).compactUp,
            ),
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
      body: body,
    );
  }
}

const double _kGap = 8.0;

class _MatrixGrid extends StatefulWidget {
  const _MatrixGrid({
    required this.layout,
    required this.columns,
    required this.editing,
    required this.onLongPressCard,
    required this.onMoveCard,
    required this.onResizeCard,
    required this.onCommit,
    required this.onRemove,
  });

  final List<DashboardCardConfig> layout;
  final int columns;
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
  DashboardCardType? _selected;

  void _clearTarget() {
    if (_target != null) setState(() => _target = null);
  }

  void _selectCard(DashboardCardType type) {
    if (_selected != type) setState(() => _selected = type);
  }

  /// Panelin bağlanacağı kart: kullanıcı seçtiyse o, seçmediyse (ya da seçtiği
  /// kart silindiyse) ilk kart. Düzen boşsa `null`.
  DashboardCardType? _effectiveSelected() {
    final layout = widget.layout;
    if (layout.isEmpty) return null;
    final chosen = _selected;
    if (chosen != null && layout.any((c) => c.type == chosen)) return chosen;
    return layout.first.type;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell =
            (constraints.maxWidth - (widget.columns - 1) * _kGap) /
            widget.columns;
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
        final selectedType = _effectiveSelected();

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
            widget.columns - config.w,
          );
          final y = (local.dy / stride).floor().clamp(0, 9999);
          final next = _DragTargetCell(config.type, x, y);
          if (_target?.type != next.type ||
              _target?.x != next.x ||
              _target?.y != next.y) {
            setState(() => _target = next);
          }
        }

        final grid = DragTarget<DashboardCardType>(
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
                    _GridBackdrop(
                      cell: cell,
                      rows: totalRows,
                      columns: widget.columns,
                    ),
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
                        columns: widget.columns,
                        cell: cell,
                        width: widthOf(c),
                        height: heightOf(c),
                        editing: widget.editing,
                        selected: widget.editing && selectedType == c.type,
                        onSelect: () => _selectCard(c.type),
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

        if (!widget.editing) return grid;

        final selectedConfig = selectedType == null
            ? null
            : widget.layout.where((c) => c.type == selectedType).firstOrNull;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            grid,
            if (selectedConfig != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _SizePanel(
                  config: selectedConfig,
                  columns: widget.columns,
                  onResize: (w, h) => widget.onResizeCard(
                    selectedConfig.type,
                    selectedConfig.x,
                    selectedConfig.y,
                    w,
                    h,
                    true,
                  ),
                ),
              ),
          ],
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
  const _GridBackdrop({
    required this.cell,
    required this.rows,
    required this.columns,
  });

  final double cell;
  final int rows;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        for (var y = 0; y < rows; y++)
          for (var x = 0; x < columns; x++)
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
    required this.columns,
    required this.cell,
    required this.width,
    required this.height,
    required this.editing,
    required this.selected,
    required this.onSelect,
    required this.onLongPressCard,
    required this.onResize,
    required this.onCommit,
    required this.onRemove,
  });

  final DashboardCardConfig config;
  final int columns;
  final double cell;
  final double width;
  final double height;
  final bool editing;
  final bool selected;
  final VoidCallback onSelect;
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
    widget.onSelect();
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
      w = (start.w + colDelta).clamp(1, widget.columns - start.x);
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
      widget.config.sizeForColumns(widget.columns),
      height: widget.height,
    );

    if (!widget.editing) {
      return GestureDetector(
        onLongPress: widget.onLongPressCard,
        onSecondaryTap: widget.onLongPressCard,
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
                  color: theme.colorScheme.primary.withValues(
                    alpha: widget.selected ? 1.0 : 0.60,
                  ),
                  width: widget.selected ? 2 : 1,
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

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: widget.onSelect,
      child: LongPressDraggable<DashboardCardType>(
        data: widget.config.type,
        onDragStarted: widget.onSelect,
        feedback: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Opacity(
            opacity: 0.6,
            child: Material(
              color: Colors.transparent,
              child: dashboardCardFor(
                widget.config.type,
                widget.config.sizeForColumns(widget.columns),
                height: widget.height,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.28, child: editCard),
        child: editCard,
      ),
    );
  }
}

/// Seçili kartın altındaki dokunmatik dostu boyut paneli: köşeden sürüklemek
/// yerine büyük −/+ düğmeleriyle genişlik/yükseklik ayarlanır (uzun-basma ile
/// taşıma çakışması olmadan). Sürükleme yolu da ayrıca korunur.
class _SizePanel extends StatelessWidget {
  const _SizePanel({
    required this.config,
    required this.columns,
    required this.onResize,
  });

  final DashboardCardConfig config;
  final int columns;
  final void Function(int w, int h) onResize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.type.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Boyut ${config.w}×${config.h} • dokun ve ayarla',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SizeStepper(
            icon: Icons.swap_horiz,
            onDecrease: config.w > 1
                ? () => onResize(config.w - 1, config.h)
                : null,
            onIncrease: config.w < columns
                ? () => onResize(config.w + 1, config.h)
                : null,
          ),
          const SizedBox(width: 6),
          _SizeStepper(
            icon: Icons.swap_vert,
            onDecrease: config.h > 1
                ? () => onResize(config.w, config.h - 1)
                : null,
            onIncrease: () => onResize(config.w, config.h + 1),
          ),
        ],
      ),
    );
  }
}

/// [−] [yön ikonu] [+] üçlüsü; her buton 40px dokunma hedefi (parmak için).
class _SizeStepper extends StatelessWidget {
  const _SizeStepper({
    required this.icon,
    required this.onDecrease,
    required this.onIncrease,
  });

  final IconData icon;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(icon: Icons.remove, onTap: onDecrease),
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          _StepButton(icon: Icons.add, onTap: onIncrease),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.28),
        ),
      ),
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
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.16),
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
