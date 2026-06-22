import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_card.dart';
import 'dashboard_providers.dart';
import 'widgets/card_picker.dart';

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
            child: _HoverLift(child: dashboardCardFor(c.type, c.size)),
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

/// Düzenleme modu: kartlar gerçek ızgarada. Tutamaçtan (⠿) sürükleyince sürüklenen
/// kart listeden çıkar ve gideceği yerde **kesik çizgili bir boşluk** belirir (diğer
/// kartlar yer açar — Android ana ekran mantığı); bırakınca oraya yerleşir.
class _EditableDashboard extends ConsumerStatefulWidget {
  const _EditableDashboard({required this.layout});

  final List<DashboardCardConfig> layout;

  @override
  ConsumerState<_EditableDashboard> createState() =>
      _EditableDashboardState();
}

class _EditableDashboardState extends ConsumerState<_EditableDashboard> {
  int? _from; // sürüklenen kartın layout'taki indeksi
  int? _to; // ekleme konumu (sürüklenen çıkarılmış indirgenmiş listede 0..n)

  void _commit() {
    final from = _from;
    final to = _to;
    if (from != null && to != null) {
      ref
          .read(dashboardLayoutProvider.notifier)
          .reorderItem(from, to.clamp(0, widget.layout.length - 1));
    }
    _clear();
  }

  void _clear() {
    if (_from != null || _to != null) {
      setState(() {
        _from = null;
        _to = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = widget.layout;
    final notifier = ref.read(dashboardLayoutProvider.notifier);
    final showTimerInClass = ref.watch(classroomShowTimerProvider);
    final dragging = _from != null;
    const gap = 12.0;

    // Sürüklenen kart çıkarılmış indirgenmiş liste (origIndex taşır).
    final reduced = <int>[];
    for (var i = 0; i < layout.length; i++) {
      if (i == _from) continue;
      reduced.add(i);
    }
    final dragSize =
        _from != null ? layout[_from!].size : DashboardCardSize.medium;

    // Görsel slotlar: kartlar + (sürüklerken) _to konumunda boşluk.
    final entries = <_Slot>[];
    for (var k = 0; k <= reduced.length; k++) {
      if (dragging && _to == k) entries.add(_Slot.placeholder(dragSize));
      if (k < reduced.length) {
        final oi = reduced[k];
        entries.add(_Slot.card(oi, k, layout[oi].size));
      }
    }

    Widget slotWidget(_Slot s) => Padding(
          padding: const EdgeInsets.only(bottom: gap),
          child: s.isPlaceholder
              ? const _DropPlaceholder()
              : _editCard(s.origIndex!, s.reducedPos!, layout[s.origIndex!],
                  notifier),
        );

    // Masonry paketle (küçükler yan yana, diğerleri tam satır).
    final rows = <Widget>[];
    final pending = <_Slot>[];
    void flush() {
      if (pending.isEmpty) return;
      final left = <Widget>[];
      final right = <Widget>[];
      for (var i = 0; i < pending.length; i++) {
        (i.isEven ? left : right).add(slotWidget(pending[i]));
      }
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: left)),
          const SizedBox(width: gap),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: right)),
        ],
      ));
      pending.clear();
    }

    for (final s in entries) {
      if (s.size.isHalfWidth) {
        pending.add(s);
      } else {
        flush();
        rows.add(slotWidget(s));
      }
    }
    flush();

    // Dış hedef: boşluğa/placeholder'a bırakınca da mevcut _to'ya yerleştir.
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => dragging,
      onAcceptWithDetails: (_) => _commit(),
      builder: (context, cand, rej) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Tutamaçtan (⠿) sürükle → kartlar yer açar, boşluğa bırak. '
                'Boyut: S/M/L · × kaldır · sağ üstten + ekle.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            ...rows,
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gruplar ekranında da sayaç göster'),
              subtitle: const Text('Sayaç varsayılan Ana Sayfa’dadır.'),
              value: showTimerInClass,
              onChanged: ref.read(classroomShowTimerProvider.notifier).set,
            ),
          ],
        ),
      ),
    );
  }

  Widget _editCard(int origIndex, int reducedPos, DashboardCardConfig card,
      DashboardLayoutNotifier notifier) {
    final theme = Theme.of(context);
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != origIndex,
      onMove: (_) {
        if (_to != reducedPos) setState(() => _to = reducedPos);
      },
      onAcceptWithDetails: (_) => _commit(),
      builder: (context, cand, rej) {
        final handle = MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Draggable<int>(
            data: origIndex,
            feedback: _DragChip(card: card),
            onDragStarted: () => setState(() {
              _from = origIndex;
              _to = reducedPos;
            }),
            onDraggableCanceled: (_, _) => _clear(),
            onDragEnd: (d) {
              if (!d.wasAccepted) _clear();
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.drag_indicator,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.primary, width: 1.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 4, 2),
                child: Row(
                  children: [
                    handle,
                    const Spacer(),
                    _SizeSelector(
                        size: card.size,
                        onSize: (s) => notifier.setSize(card.type, s)),
                    IconButton(
                      tooltip: 'Kaldır',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(Icons.remove_circle_outline,
                          color: theme.colorScheme.error),
                      onPressed: () => notifier.toggle(card.type),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: IgnorePointer(
                  child: dashboardCardFor(card.type, card.size),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Masonry paketleme için bir slot: kart veya (sürükleme sırasında) boşluk.
class _Slot {
  _Slot.placeholder(this.size)
      : isPlaceholder = true,
        origIndex = null,
        reducedPos = null;
  _Slot.card(this.origIndex, this.reducedPos, this.size)
      : isPlaceholder = false;

  final bool isPlaceholder;
  final int? origIndex;
  final int? reducedPos;
  final DashboardCardSize size;
}

/// Sürüklenen kartın gideceği yeri gösteren kesik(çe) çizgili boşluk.
class _DropPlaceholder extends StatelessWidget {
  const _DropPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.secondary, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.add, color: theme.colorScheme.secondary),
    );
  }
}

/// Sürükleme sırasında parmağın altında süzülen küçük etiket.
class _DragChip extends StatelessWidget {
  const _DragChip({required this.card});

  final DashboardCardConfig card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3), blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(card.type.icon,
                size: 18, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Text(card.type.title,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}

/// Düzenleme kartının görseli: üstte kontrol çubuğu (sürükle ikonu, S/M/L, ×) +
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

/// Karta fare ile gelince hafif büyüme + parlama (dashboard "canlı" hissi).
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
