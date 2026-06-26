import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_card.dart';
import 'dashboard_providers.dart';
import 'widgets/card_picker.dart';

/// Ana Sayfa: kişiye özel, **özelleştirilebilir** serbest ızgara (§2 FAZ 6).
/// Kartlar [kGridColumns] sütunlu bir akış ızgarasında, her biri 1..12 hücre
/// **genişliğinde** dizilir; yükseklik içeriğe göre otomatiktir.
///
/// Normal modda kartlar görünür ve etkileşimlidir. Bir kartı **gövdesine basılı
/// tutunca** düzenleme moduna geçilir: kart doğrudan gövdesinden sürüklenerek
/// sıralanır (komşular animasyonla yer açar — Android ana ekran hissi), sağ alt
/// köşeden tutup çekerek **serbestçe genişletilip daraltılır**, × ile kaldırılır,
/// sağ üstten + ile yeni kart eklenir.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _editing = false;

  // Görünüm ↔ düzenleme geçişinde kaydırma konumunu korur (§2F): kullanıcı hangi
  // kartı düzenlemek için basılı tuttuysa ekran oraya sabit kalır, başa zıplamaz.
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
          : _editing
              ? _EditableGrid(layout: layout, scroll: _scroll)
              : SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  child: _GridDashboard(
                    layout: layout,
                    onLongPressCard: () => _setEditing(true),
                  ),
                ),
    );
  }
}

const double _kGap = 12.0;

/// Bir kart listesini, genişlikleri toplamı [kGridColumns]'u aşmayacak şekilde
/// satırlara böler (akış yerleşimi). Her satır, taşan kartı bir sonraki satıra
/// indirir; tek kart bir satırdan geniş olamaz (genişlik zaten 1..12 sınırlı).
List<List<T>> _packRows<T>(List<T> items, int Function(T) widthOf) {
  final rows = <List<T>>[];
  var current = <T>[];
  var used = 0;
  for (final item in items) {
    final w = widthOf(item).clamp(1, kGridColumns);
    if (current.isNotEmpty && used + w > kGridColumns) {
      rows.add(current);
      current = <T>[];
      used = 0;
    }
    current.add(item);
    used += w;
  }
  if (current.isNotEmpty) rows.add(current);
  return rows;
}

/// Bir satırı, kartların genişliğiyle orantılı `Expanded(flex)` hücrelere yayar.
/// Satır tam dolmadıysa kalan boşluk için şeffaf bir esnek alan bırakılır.
Widget _row<T>({
  required List<T> rowItems,
  required int Function(T) widthOf,
  required Widget Function(T) build,
}) {
  final children = <Widget>[];
  var used = 0;
  for (var i = 0; i < rowItems.length; i++) {
    final item = rowItems[i];
    final w = widthOf(item).clamp(1, kGridColumns);
    used += w;
    children.add(Expanded(
      flex: w,
      child: Padding(
        padding: EdgeInsets.only(right: i == rowItems.length - 1 ? 0 : _kGap),
        child: build(item),
      ),
    ));
  }
  final remaining = kGridColumns - used;
  if (remaining > 0) children.add(Spacer(flex: remaining));
  return Padding(
    padding: const EdgeInsets.only(bottom: _kGap),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

/// Normal mod: kartları serbest ızgarada (genişliklerine göre) gösterir. Bir
/// karta **basılı tutmak** düzenleme moduna geçirir (Android ana ekran kalıbı).
class _GridDashboard extends StatelessWidget {
  const _GridDashboard({required this.layout, required this.onLongPressCard});

  final List<DashboardCardConfig> layout;
  final VoidCallback onLongPressCard;

  @override
  Widget build(BuildContext context) {
    final rows = _packRows<DashboardCardConfig>(layout, (c) => c.width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in rows)
          _row<DashboardCardConfig>(
            rowItems: r,
            widthOf: (c) => c.width,
            build: (c) => GestureDetector(
              onLongPress: onLongPressCard,
              child: _HoverLift(
                  child: dashboardCardFor(c.type, c.size,
                      height: c.effectiveHeight)),
            ),
          ),
      ],
    );
  }
}

/// Düzenleme modunda akış paketlemesi için bir slot: gerçek kart ya da (sürükleme
/// sırasında) bırakma boşluğu (placeholder).
class _Slot {
  _Slot.card(this.origIndex, this.width) : isPlaceholder = false;
  _Slot.placeholder(this.width)
      : isPlaceholder = true,
        origIndex = null;

  final bool isPlaceholder;
  final int? origIndex; // layout'taki gerçek indeks
  final int width; // ızgara genişliği (hücre)
}

/// Düzenleme modu: kartlar serbest ızgarada. Kart **gövdesine** basılı tutup
/// sürükleyince listeden çıkar ve gideceği yerde **kesik çizgili bir boşluk**
/// belirir (diğer kartlar yer açar — Android ana ekran mantığı); bırakınca oraya
/// yerleşir. Sağ alt köşedeki tutamaçtan çekerek genişlik serbestçe ayarlanır.
class _EditableGrid extends ConsumerStatefulWidget {
  const _EditableGrid({required this.layout, required this.scroll});

  final List<DashboardCardConfig> layout;
  final ScrollController scroll;

  @override
  ConsumerState<_EditableGrid> createState() => _EditableGridState();
}

class _EditableGridState extends ConsumerState<_EditableGrid> {
  int? _from; // sürüklenen kartın layout indeksi
  int? _to; // indirgenmiş listede ekleme konumu (0..n)

  void _commit() {
    final from = _from;
    final to = _to;
    if (from != null && to != null) {
      // _to, sürüklenen çıkarılmış indirgenmiş listeye göre. Gerçek hedef indeksi:
      // to konumundan önce gelen ve from'dan büyük indeksler bir kaymış sayılır.
      final target = to.clamp(0, widget.layout.length - 1);
      ref.read(dashboardLayoutProvider.notifier).reorderItem(from, target);
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

    // Sürüklenen kart çıkarılmış indirgenmiş liste (gerçek indeksleri taşır).
    final reduced = <int>[];
    for (var i = 0; i < layout.length; i++) {
      if (i == _from) continue;
      reduced.add(i);
    }
    final dragWidth =
        _from != null ? layout[_from!].width : (kGridColumns ~/ 2);

    // Slotlar: kartlar + (sürüklerken) _to konumunda boşluk.
    final slots = <_Slot>[];
    for (var k = 0; k <= reduced.length; k++) {
      if (dragging && _to == k) slots.add(_Slot.placeholder(dragWidth));
      if (k < reduced.length) {
        final oi = reduced[k];
        slots.add(_Slot.card(oi, layout[oi].width));
      }
    }

    final rows = _packRows<_Slot>(slots, (s) => s.width);

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => dragging,
      onAcceptWithDetails: (_) => _commit(),
      builder: (context, cand, rej) => SingleChildScrollView(
        controller: widget.scroll,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Kartı gövdesinden sürükle → komşular yer açar, boşluğa bırak. '
                'Herhangi bir köşeden çekerek genişlik ve yüksekliği ayarla · '
                '× kaldır · sağ üstten + ekle.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            for (final r in rows)
              _row<_Slot>(
                rowItems: r,
                widthOf: (s) => s.width,
                build: (s) => s.isPlaceholder
                    ? const _DropPlaceholder()
                    : _EditCard(
                        key: ValueKey(layout[s.origIndex!].type),
                        config: layout[s.origIndex!],
                        origIndex: s.origIndex!,
                        onReorderHover: (i) {
                          // i = bu kartın indirgenmiş listedeki konumu.
                          final pos = reduced.indexOf(i);
                          if (pos >= 0 && _to != pos) {
                            setState(() => _to = pos);
                          }
                        },
                        onDragStart: () => setState(() {
                          _from = s.origIndex;
                          _to = reduced.indexOf(s.origIndex!).clamp(0, reduced.length);
                        }),
                        onDragCancel: _clear,
                        onAccept: _commit,
                        onRemove: () =>
                            notifier.toggle(layout[s.origIndex!].type),
                        onWidth: (w) =>
                            notifier.setWidth(layout[s.origIndex!].type, w),
                        onHeight: (h) => notifier.setHeight(
                            layout[s.origIndex!].type, h,
                            persist: false),
                        onCommit: notifier.persist,
                      ),
              ),
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
}

/// Düzenleme modundaki tek kart: gövdesinden sürüklenebilir (reorder), üstte
/// ortalanmış kontrol hapı (sürükle ipucu + boyut etiketi + kaldır ×) ve **dört
/// köşede** boyut tutamacı (genişlik = hücreye snap, yükseklik = serbest px).
/// Kartın kendisi etkileşimsizdir (IgnorePointer) — yalnızca düzenleme
/// kontrolleri tıklanır.
class _EditCard extends StatefulWidget {
  const _EditCard({
    super.key,
    required this.config,
    required this.origIndex,
    required this.onReorderHover,
    required this.onDragStart,
    required this.onDragCancel,
    required this.onAccept,
    required this.onRemove,
    required this.onWidth,
    required this.onHeight,
    required this.onCommit,
  });

  final DashboardCardConfig config;
  final int origIndex;
  final ValueChanged<int> onReorderHover; // başka kartın indeksiyle hover
  final VoidCallback onDragStart;
  final VoidCallback onDragCancel;
  final VoidCallback onAccept;
  final VoidCallback onRemove;
  final ValueChanged<int> onWidth; // ızgara genişliği (hücre)
  final ValueChanged<double> onHeight; // serbest yükseklik (px, canlı)
  final VoidCallback onCommit; // sürükleme bitince kalıcılaştır

  @override
  State<_EditCard> createState() => _EditCardState();
}

class _EditCardState extends State<_EditCard> {
  // Boyutlandırma jesti başındaki değerler + biriken kaydırma (köşe işaretine
  // göre yönlü → 4 köşeden de sezgisel büyüt/küçült).
  int? _startWidth;
  double? _startHeight;
  double _accDx = 0;
  double _accDy = 0;

  void _resizeStart() {
    _startWidth = widget.config.width;
    _startHeight = widget.config.effectiveHeight;
    _accDx = 0;
    _accDy = 0;
  }

  void _resizeUpdate(Offset delta, int signX, int signY, double cell) {
    _accDx += delta.dx * signX;
    _accDy += delta.dy * signY;
    final w = (_startWidth! + (_accDx / cell).round()).clamp(1, kGridColumns);
    if (w != widget.config.width) widget.onWidth(w);
    final h = (_startHeight! + _accDy).clamp(kMinCardHeight, kMaxCardHeight);
    if ((h - widget.config.effectiveHeight).abs() >= 0.5) widget.onHeight(h);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final body = DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != widget.origIndex,
      onMove: (_) => widget.onReorderHover(widget.origIndex),
      onAcceptWithDetails: (_) => widget.onAccept(),
      builder: (context, cand, rej) {
        final card = DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.primary, width: 1.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: IgnorePointer(
              child: dashboardCardFor(widget.config.type, widget.config.size,
                  height: widget.config.effectiveHeight),
            ),
          ),
        );

        // Gövdeden sürükle → reorder. Tüm kart basılı-tut ile taşınır.
        return LongPressDraggable<int>(
          data: widget.origIndex,
          onDragStarted: widget.onDragStart,
          onDraggableCanceled: (_, _) => widget.onDragCancel(),
          onDragEnd: (d) {
            if (!d.wasAccepted) widget.onDragCancel();
          },
          feedback: _DragChip(config: widget.config),
          childWhenDragging: Opacity(opacity: 0.35, child: card),
          child: card,
        );
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Bu kartın hücre genişliği ≈ satırdaki orantılı pay; tek hücre genişliği
        // için kartın pikselini mevcut hücre sayısına böleriz (yaklaşık snap).
        final cell =
            constraints.maxWidth / widget.config.width.clamp(1, kGridColumns);

        Widget corner({required bool left, required bool top}) {
          final signX = left ? -1 : 1;
          final signY = top ? -1 : 1;
          return Positioned(
            left: left ? -8 : null,
            right: left ? null : -8,
            top: top ? -8 : null,
            bottom: top ? null : -8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => _resizeStart(),
              onPanUpdate: (d) => _resizeUpdate(d.delta, signX, signY, cell),
              onPanEnd: (_) => widget.onCommit(),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: theme.colorScheme.surface, width: 2),
                ),
                child: Icon(Icons.open_with,
                    size: 12, color: theme.colorScheme.onPrimary),
              ),
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            body,
            // Üst ortada kontrol hapı: sürükle ipucu + boyut etiketi + kaldır.
            Positioned(
              top: -6,
              left: 0,
              right: 0,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Material(
                  color: theme.colorScheme.surfaceContainerHighest,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.drag_indicator,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.config.width}/$kGridColumns · '
                          '${widget.config.effectiveHeight.round()}px',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                        IconButton(
                          tooltip: 'Kaldır',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 30, minHeight: 30),
                          icon: Icon(Icons.remove_circle_outline,
                              size: 18, color: theme.colorScheme.error),
                          onPressed: widget.onRemove,
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ),
            corner(left: false, top: false), // sağ alt
            corner(left: true, top: false), // sol alt
            corner(left: false, top: true), // sağ üst
            corner(left: true, top: true), // sol üst
          ],
        );
      },
    );
  }
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
  const _DragChip({required this.config});

  final DashboardCardConfig config;

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
            Icon(config.type.icon,
                size: 18, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Text(config.type.title,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
          ],
        ),
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
