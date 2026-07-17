import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/providers/analytics_layout_providers.dart';
import '../../../data/providers/analytics_period_provider.dart';
import 'analytics_card_config.dart';
import 'analytics_card_registry.dart';
import 'analytics_card_type.dart';
import 'analytics_edit_sheet.dart';
import 'analytics_period.dart';

const int kAnalyticsGridColumns = 6;
const double _kGap = 8;
const double _kMinCell = 56;

/// WP-158–164: 6 sütun hücre ızgarası; x/y/w/h gerçek render + reflow.
class AnalyticsGridView extends ConsumerStatefulWidget {
  const AnalyticsGridView({
    super.key,
    required this.surface,
  });

  final AnalyticsSurface surface;

  @override
  ConsumerState<AnalyticsGridView> createState() => _AnalyticsGridViewState();
}

class _AnalyticsGridViewState extends ConsumerState<AnalyticsGridView> {
  bool _editing = false;
  AnalyticsCardType? _selected;
  _DragTarget? _dragTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final layoutAsync = widget.surface == AnalyticsSurface.personalStats
        ? ref.watch(statsLayoutProvider)
        : ref.watch(groupStatsLayoutProvider);
    final period = ref.watch(analyticsPeriodProvider);

    return layoutAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.authBeklenmeyenBirHataOlustu)),
      data: (layout) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: _editing
                        ? l10n.analyticsEditDone
                        : l10n.homeKartlariDuzenle,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _editing = !_editing;
                        if (!_editing) {
                          _selected = null;
                          _dragTarget = null;
                        }
                      }),
                      icon: Icon(
                        _editing
                            ? Icons.check
                            : Icons.dashboard_customize_outlined,
                        size: 20,
                      ),
                      label: Text(
                        _editing
                            ? l10n.analyticsEditDone
                            : l10n.homeKartlariDuzenle,
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.homeKartEkle,
                    child: IconButton(
                      tooltip: l10n.homeKartEkle,
                      onPressed: () => showAnalyticsEditSheet(
                        context,
                        ref,
                        surface: widget.surface,
                        current: layout,
                      ),
                      icon: const Icon(Icons.add_box_outlined),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_editing)
                    Semantics(
                      button: true,
                      label: l10n.analyticsResetLayout,
                      child: TextButton(
                        onPressed: () async {
                          if (widget.surface ==
                              AnalyticsSurface.personalStats) {
                            await ref
                                .read(statsLayoutProvider.notifier)
                                .reset();
                          } else {
                            await ref
                                .read(groupStatsLayoutProvider.notifier)
                                .reset();
                          }
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        child: Text(l10n.analyticsResetLayout),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    child: _buildGrid(
                      context,
                      layout: layout,
                      period: period,
                      maxWidth: constraints.maxWidth - 16,
                      l10n: l10n,
                    ),
                  );
                },
              ),
            ),
            if (_editing && _selected != null)
              _SizeControls(
                config: layout.firstWhere(
                  (c) => c.type == _selected,
                  orElse: () => layout.first,
                ),
                onResize: (w, h) => _setBounds(_selected!, w: w, h: h),
              ),
          ],
        );
      },
    );
  }

  Future<void> _setBounds(
    AnalyticsCardType type, {
    int? x,
    int? y,
    int? w,
    int? h,
  }) async {
    if (widget.surface == AnalyticsSurface.personalStats) {
      await ref.read(statsLayoutProvider.notifier).setBounds(
            type,
            x: x,
            y: y,
            w: w,
            h: h,
          );
    } else {
      await ref.read(groupStatsLayoutProvider.notifier).setBounds(
            type,
            x: x,
            y: y,
            w: w,
            h: h,
          );
    }
  }

  Future<void> _remove(AnalyticsCardType type) async {
    if (widget.surface == AnalyticsSurface.personalStats) {
      await ref.read(statsLayoutProvider.notifier).removeCard(type);
    } else {
      await ref.read(groupStatsLayoutProvider.notifier).removeCard(type);
    }
    if (_selected == type) setState(() => _selected = null);
  }

  Widget _buildGrid(
    BuildContext context, {
    required List<AnalyticsCardConfig> layout,
    required AnalyticsPeriod period,
    required double maxWidth,
    required AppLocalizations l10n,
  }) {
    final columns = kAnalyticsGridColumns;
    final cell =
        ((maxWidth - (columns - 1) * _kGap) / columns).clamp(_kMinCell, 400.0);
    final baseRows = layout.isEmpty
        ? 1
        : layout.fold<int>(1, (m, c) => m > c.y + c.h ? m : c.y + c.h);
    final dragged = _dragTarget == null
        ? null
        : layout.where((c) => c.type == _dragTarget!.type).firstOrNull;
    final totalRows = dragged == null
        ? baseRows
        : (baseRows > _dragTarget!.y + dragged.h
            ? baseRows
            : _dragTarget!.y + dragged.h);
    final height = totalRows * cell + (totalRows - 1) * _kGap;

    double leftOf(AnalyticsCardConfig c) => c.x * (cell + _kGap);
    double topOf(AnalyticsCardConfig c) => c.y * (cell + _kGap);
    double widthOf(AnalyticsCardConfig c) => c.w * cell + (c.w - 1) * _kGap;
    double heightOf(AnalyticsCardConfig c) => c.h * cell + (c.h - 1) * _kGap;

    return DragTarget<AnalyticsCardType>(
      onWillAcceptWithDetails: (_) => _editing,
      onMove: (details) {
        if (!_editing) return;
        final config =
            layout.where((c) => c.type == details.data).firstOrNull;
        if (config == null) return;
        // Approximate from pointer via local conversion is hard without key;
        // use details.offset relative to this render box.
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final local = box.globalToLocal(details.offset);
        final stride = cell + _kGap;
        final x =
            (local.dx / stride).floor().clamp(0, columns - config.w);
        final y = (local.dy / stride).floor().clamp(0, 9999);
        final next = _DragTarget(config.type, x, y);
        if (_dragTarget?.type != next.type ||
            _dragTarget?.x != next.x ||
            _dragTarget?.y != next.y) {
          setState(() => _dragTarget = next);
        }
      },
      onLeave: (_) => setState(() => _dragTarget = null),
      onAcceptWithDetails: (details) async {
        final t = _dragTarget;
        if (t != null) {
          await _setBounds(details.data, x: t.x, y: t.y);
        }
        setState(() => _dragTarget = null);
      },
      builder: (context, candidateData, rejectedData) {
        return SizedBox(
          height: height,
          width: maxWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_editing)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridLinesPainter(
                      cell: cell,
                      gap: _kGap,
                      rows: totalRows,
                      columns: columns,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ),
              if (dragged != null && _dragTarget != null)
                Positioned(
                  left: _dragTarget!.x * (cell + _kGap),
                  top: _dragTarget!.y * (cell + _kGap),
                  width: widthOf(dragged),
                  height: heightOf(dragged),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.08),
                    ),
                  ),
                ),
              for (final c in layout)
                Positioned(
                  key: ValueKey(c.id),
                  left: leftOf(c),
                  top: topOf(c),
                  width: widthOf(c),
                  height: heightOf(c),
                  child: _GridCard(
                    config: c,
                    surface: widget.surface,
                    period: period,
                    editing: _editing,
                    selected: _selected == c.type,
                    onSelect: () => setState(() => _selected = c.type),
                    onRemove: () => _remove(c.type),
                    l10n: l10n,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DragTarget {
  const _DragTarget(this.type, this.x, this.y);
  final AnalyticsCardType type;
  final int x;
  final int y;
}

class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.config,
    required this.surface,
    required this.period,
    required this.editing,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
    required this.l10n,
  });

  final AnalyticsCardConfig config;
  final AnalyticsSurface surface;
  final AnalyticsPeriod period;
  final bool editing;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRemove;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final title = AnalyticsCardRegistry.titleFor(l10n, config.type);
    return Consumer(
      builder: (context, ref, _) {
        final card = AnalyticsCardRegistry.build(
          context: context,
          ref: ref,
          config: config,
          surface: surface,
          period: period,
        );
        if (!editing) return card;

        return Semantics(
          label: title,
          button: true,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: LongPressDraggable<AnalyticsCardType>(
                    data: config.type,
                    feedback: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 160,
                        height: 80,
                        child: Center(child: Text(title)),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.35, child: card),
                    child: GestureDetector(
                      onTap: onSelect,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: card,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Semantics(
                    button: true,
                    label: l10n.adminSil,
                    child: IconButton(
                      tooltip: l10n.adminSil,
                      onPressed: onRemove,
                      icon: const Icon(Icons.close, size: 18),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SizeControls extends StatelessWidget {
  const _SizeControls({required this.config, required this.onResize});

  final AnalyticsCardConfig config;
  final void Function(int w, int h) onResize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: l10n.analyticsCardWidth,
                child: Row(
                  children: [
                    Text(l10n.analyticsCardWidth),
                    IconButton(
                      tooltip: l10n.analyticsNarrower,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: config.w <= 1
                          ? null
                          : () => onResize(config.w - 1, config.h),
                      icon: const Icon(Icons.remove),
                    ),
                    Text('${config.w}'),
                    IconButton(
                      tooltip: l10n.analyticsWider,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: config.w >= kAnalyticsGridColumns
                          ? null
                          : () => onResize(config.w + 1, config.h),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                label: l10n.analyticsCardHeight,
                child: Row(
                  children: [
                    Text(l10n.analyticsCardHeight),
                    IconButton(
                      tooltip: l10n.analyticsShorter,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: config.h <= 1
                          ? null
                          : () => onResize(config.w, config.h - 1),
                      icon: const Icon(Icons.remove),
                    ),
                    Text('${config.h}'),
                    IconButton(
                      tooltip: l10n.analyticsTaller,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed:
                          config.h >= 8 ? null : () => onResize(config.w, config.h + 1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridLinesPainter extends CustomPainter {
  _GridLinesPainter({
    required this.cell,
    required this.gap,
    required this.rows,
    required this.columns,
    required this.color,
  });

  final double cell;
  final double gap;
  final int rows;
  final int columns;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final stride = cell + gap;
    for (var c = 0; c <= columns; c++) {
      final x = c * stride - (c == 0 ? 0 : gap / 2);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var r = 0; r <= rows; r++) {
      final y = r * stride - (r == 0 ? 0 : gap / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridLinesPainter old) =>
      old.cell != cell ||
      old.rows != rows ||
      old.columns != columns ||
      old.color != color;
}
