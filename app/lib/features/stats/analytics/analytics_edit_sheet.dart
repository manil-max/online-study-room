import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/providers/analytics_layout_providers.dart';
import 'analytics_card_config.dart';
import 'analytics_card_registry.dart';
import 'analytics_card_type.dart';

/// WP-162: kart ekle/çıkar/sıfırla (basit liste; sürükle-bırak v2).
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
    final (w, h) = type.defaultCells;
    final y = _layout.isEmpty
        ? 0
        : _layout.map((c) => c.y + c.h).reduce((a, b) => a > b ? a : b);
    setState(() {
      _layout.add(AnalyticsCardConfig(type, x: 0, y: y, w: w, h: h));
    });
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.homeKartlariDuzenle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < _layout.length; i++)
                    ListTile(
                      title: Text(
                        AnalyticsCardRegistry.titleFor(l10n, _layout[i].type),
                      ),
                      trailing: IconButton(
                        tooltip: l10n.adminSil,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeAt(i),
                      ),
                    ),
                  const Divider(),
                  Text(l10n.homeKartEkle,
                      style: Theme.of(context).textTheme.labelLarge),
                  for (final t in catalog)
                    if (!present.contains(t))
                      ListTile(
                        title: Text(AnalyticsCardRegistry.titleFor(l10n, t)),
                        trailing: IconButton(
                          tooltip: l10n.profileDersEkle,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.add),
                          onPressed: () => _add(t),
                        ),
                      ),
                ],
              ),
            ),
            TextButton(
              onPressed: _reset,
              child: Text(l10n.classroomYenile),
            ),
          ],
        ),
      ),
    );
  }
}
