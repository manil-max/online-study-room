import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/providers/analytics_layout_providers.dart';
import 'analytics_card_config.dart';
import 'analytics_card_registry.dart';
import 'analytics_card_type.dart';
import 'analytics_grid_view.dart';

/// WP-162/164: kart ekle/sil/sırala/boyutlandır/sıfırla.
Future<void> showAnalyticsEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required AnalyticsSurface surface,
  required List<AnalyticsCardConfig> current,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _EditSheet(surface: surface, initial: current),
  );
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.surface, required this.initial});
  final AnalyticsSurface surface;
  final List<AnalyticsCardConfig> initial;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late List<AnalyticsCardConfig> _layout;

  @override
  void initState() {
    super.initState();
    _layout = List.of(widget.initial);
  }

  Future<void> _persist() async {
    if (widget.surface == AnalyticsSurface.personalStats) {
      await ref.read(statsLayoutProvider.notifier).save(_layout);
    } else {
      await ref.read(groupStatsLayoutProvider.notifier).save(_layout);
    }
  }

  void _removeAt(int i) {
    setState(() => _layout.removeAt(i));
    _persist();
  }

  void _add(AnalyticsCardType type) {
    if (_layout.any((c) => c.type == type)) return;
    final added = AnalyticsCardConfig.firstAvailable(_layout, type);
    setState(() {
      _layout = reflowAnalyticsLayout(
        layout: [..._layout, added],
        moving: type,
        x: added.x,
        y: added.y,
        w: added.w,
        h: added.h,
        columns: kAnalyticsGridColumns,
      );
    });
    _persist();
  }

  void _resize(int index, {int? w, int? h}) {
    final c = _layout[index];
    final next = reflowAnalyticsLayout(
      layout: _layout,
      moving: c.type,
      x: c.x,
      y: c.y,
      w: w ?? c.w,
      h: h ?? c.h,
      columns: kAnalyticsGridColumns,
    );
    setState(() => _layout = next);
    _persist();
  }

  void _onReorder(int oldIndex, int newIndex) {
    // onReorderItem already adjusts newIndex for removal.
    final list = [..._layout];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    // Sıra değişince dikey yığ: w/h korunur, overlap yok, id sabit.
    var cursorY = 0;
    final stacked = <AnalyticsCardConfig>[];
    for (final c in list) {
      stacked.add(c.copyWith(x: 0, y: cursorY));
      cursorY += c.h;
    }
    setState(() => _layout = stacked);
    _persist();
  }

  Future<void> _reset() async {
    if (widget.surface == AnalyticsSurface.personalStats) {
      await ref.read(statsLayoutProvider.notifier).reset();
      setState(() => _layout = defaultPersonalLayout());
    } else {
      await ref.read(groupStatsLayoutProvider.notifier).reset();
      setState(() => _layout = defaultGroupLayout());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = AnalyticsCardType.values
        .where((t) => t.allowedOn(widget.surface))
        .toList();
    final present = _layout.map((c) => c.type).toSet();
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.homeKartlariDuzenle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.homeKartiTutupSurukleHedef,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: _layout.length,
                  onReorderItem: _onReorder,
                  itemBuilder: (context, i) {
                    final c = _layout[i];
                    final title =
                        AnalyticsCardRegistry.titleFor(l10n, c.type);
                    return Material(
                      key: ValueKey(c.id),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: Semantics(
                            label: l10n.analyticsDragHandle,
                            button: true,
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ),
                        title: Text(title),
                        subtitle: Text('${c.w}×${c.h} · (${c.x},${c.y})'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              label: l10n.analyticsNarrower,
                              button: true,
                              child: IconButton(
                                tooltip: l10n.analyticsNarrower,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                icon: const Icon(Icons.remove),
                                onPressed: c.w <= 1
                                    ? null
                                    : () => _resize(i, w: c.w - 1),
                              ),
                            ),
                            Semantics(
                              label: l10n.analyticsWider,
                              button: true,
                              child: IconButton(
                                tooltip: l10n.analyticsWider,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                icon: const Icon(Icons.add),
                                onPressed: c.w >= kAnalyticsGridColumns
                                    ? null
                                    : () => _resize(i, w: c.w + 1),
                              ),
                            ),
                            Semantics(
                              label: l10n.adminSil,
                              button: true,
                              child: IconButton(
                                tooltip: l10n.adminSil,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _removeAt(i),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Text(
                l10n.homeKartEkle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in catalog)
                      if (!present.contains(t))
                        ListTile(
                          title: Text(
                            AnalyticsCardRegistry.titleFor(l10n, t),
                          ),
                          trailing: Semantics(
                            label: l10n.homeKartEkle,
                            button: true,
                            child: IconButton(
                              tooltip: l10n.homeKartEkle,
                              style: IconButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              icon: const Icon(Icons.add),
                              onPressed: () => _add(t),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: l10n.analyticsResetLayout,
                child: TextButton(
                  onPressed: _reset,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(l10n.analyticsResetLayout),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
