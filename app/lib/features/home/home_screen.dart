import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/anchored_menu.dart';
import 'dashboard_card.dart';
import 'dashboard_providers.dart';

/// Ana Sayfa: kişiye özel, **özelleştirilebilir** kontrol paneli (§3.9/§3.11).
/// Normalde kartlar masonry düzeninde görünür. Bir kartı **basılı tutunca** (veya
/// sağ üst düzenle) düzenleme moduna geçilir: kartlar sürükle-bırakla sıralanır,
/// kart üstündeki S/M/L ile boyutlandırılır, × ile kaldırılır, + ile eklenir.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _editing = false;

  void _setEditing(bool value) => setState(() => _editing = value);

  Future<void> _showAddMenu(BuildContext anchorContext) async {
    final used = ref.read(dashboardLayoutProvider).map((c) => c.type).toSet();
    final available =
        DashboardCardType.values.where((t) => !used.contains(t)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm kartlar zaten ekli.')),
      );
      return;
    }
    final theme = Theme.of(anchorContext);
    final picked = await showAnchoredMenu<DashboardCardType>(
      context: anchorContext,
      items: [
        PopupMenuItem<DashboardCardType>(
          enabled: false,
          height: 32,
          child: Text('Kart ekle',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        for (final t in available)
          PopupMenuItem<DashboardCardType>(
            value: t,
            child: Row(
              children: [
                Icon(t.icon, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(t.title)),
              ],
            ),
          ),
      ],
    );
    if (picked != null) {
      ref.read(dashboardLayoutProvider.notifier).toggle(picked);
    }
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
            Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Kart ekle',
                icon: const Icon(Icons.add),
                onPressed: () => _showAddMenu(ctx),
              ),
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
          ? _EmptyDashboard(
              onEdit: () {
                _setEditing(true);
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _showAddMenuFromNowhere());
              },
            )
          : _editing
              ? _EditableDashboard(layout: layout)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _MasonryDashboard(
                    layout: layout,
                    onLongPressCard: () => _setEditing(true),
                  ),
                ),
    );
  }

  // Boş panoda "Kart ekle"ye basınca: düzenleme moduna geç; menüyü AppBar'daki +
  // üzerinden açmak yerine basit bir geri bildirim verelim (kullanıcı + ile ekler).
  void _showAddMenuFromNowhere() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sağ üstteki + ile kart ekle.')),
      );
    }
  }
}

/// Ana Sayfa kartlarını **masonry** (taşlama) düzeninde yerleştirir: küçük (yarım
/// genişlik) kartlar iki bağımsız sütuna paylaştırılır — böylece kısa bir kartın
/// altında uzun komşusu yüzünden boşluk kalmaz. Orta/büyük kartlar tam satır kaplar.
class _MasonryDashboard extends StatelessWidget {
  const _MasonryDashboard({required this.layout, required this.onLongPressCard});

  final List<DashboardCardConfig> layout;
  final VoidCallback onLongPressCard;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    final rows = <Widget>[];
    final pending = <DashboardCardConfig>[];

    Widget cardOf(DashboardCardConfig c) => Padding(
          padding: const EdgeInsets.only(bottom: gap),
          // Basılı tut → düzenleme modu (Android ana ekran kalıbı).
          child: GestureDetector(
            onLongPress: onLongPressCard,
            child: dashboardCardFor(c.type, c.size),
          ),
        );

    void flushPending() {
      if (pending.isEmpty) return;
      final left = <Widget>[];
      final right = <Widget>[];
      for (var i = 0; i < pending.length; i++) {
        (i.isEven ? left : right).add(cardOf(pending[i]));
      }
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: right),
          ),
        ],
      ));
      pending.clear();
    }

    for (final card in layout) {
      if (card.size.isHalfWidth) {
        pending.add(card);
      } else {
        flushPending();
        rows.add(cardOf(card));
      }
    }
    flushPending();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// Düzenleme modu: kartlar tek sütunda **sürükle-bırakla** sıralanır; her kartın
/// üstünde boyut (S/M/L) + kaldır kontrolleri vardır. Altta "Gruplar'da sayaç" anahtarı.
class _EditableDashboard extends ConsumerWidget {
  const _EditableDashboard({required this.layout});

  final List<DashboardCardConfig> layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dashboardLayoutProvider.notifier);
    final showTimerInClass = ref.watch(classroomShowTimerProvider);

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            buildDefaultDragHandles: false,
            itemCount: layout.length,
            onReorderItem: notifier.reorderItem,
            itemBuilder: (context, index) {
              final card = layout[index];
              return Padding(
                key: ValueKey(card.type),
                padding: const EdgeInsets.only(bottom: 12),
                child: _EditableCard(
                  index: index,
                  card: card,
                  onSize: (s) => notifier.setSize(card.type, s),
                  onRemove: () => notifier.toggle(card.type),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: const Text('Gruplar ekranında da sayaç göster'),
          subtitle: const Text('Sayaç varsayılan Ana Sayfa’dadır.'),
          value: showTimerInClass,
          onChanged: ref.read(classroomShowTimerProvider.notifier).set,
        ),
      ],
    );
  }
}

/// Düzenleme modunda tek bir kart: üstte kontrol çubuğu (sürükle tutamacı, başlık,
/// S/M/L boyut, kaldır) + altında **canlı kartın önizlemesi**.
class _EditableCard extends StatelessWidget {
  const _EditableCard({
    required this.index,
    required this.card,
    required this.onSize,
    required this.onRemove,
  });

  final int index;
  final DashboardCardConfig card;
  final ValueChanged<DashboardCardSize> onSize;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kontrol çubuğu.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_indicator,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(card.type.title,
                      style: theme.textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis),
                ),
                _SizeSelector(size: card.size, onSize: onSize),
                IconButton(
                  tooltip: 'Kaldır',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.remove_circle_outline,
                      color: theme.colorScheme.error),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
          // Canlı önizleme (etkileşim düzenlemeyi bozmasın diye yok sayılır).
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: IgnorePointer(
              child: dashboardCardFor(card.type, card.size),
            ),
          ),
        ],
      ),
    );
  }
}

/// S / M / L boyut seçici (düzenleme çubuğu için kompakt).
class _SizeSelector extends StatelessWidget {
  const _SizeSelector({required this.size, required this.onSize});

  final DashboardCardSize size;
  final ValueChanged<DashboardCardSize> onSize;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DashboardCardSize>(
      segments: [
        for (final s in DashboardCardSize.values)
          ButtonSegment(value: s, icon: Icon(s.icon), tooltip: s.label),
      ],
      selected: {size},
      onSelectionChanged: (s) => onSize(s.first),
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
