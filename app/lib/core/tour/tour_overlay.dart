import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tour_models.dart';

/// WP-323: Motorun yerelleştirilmiş sabit metinleri.
///
/// Tur adımlarının içeriği çağıran ekrana (WP-324) aittir; bu küçük yapı yalnız
/// motorun her turda ortak olan kontrol metinlerini taşır.
/// 🔴 WP-837 (sahip): balonda **adım sayacı yok**. "2 adımın 2. adımı" satırı
/// kullanıcıya hiçbir şey öğretmiyordu; turlar zaten tek balona indirildi.
@immutable
class TourOverlayStrings {
  const TourOverlayStrings({required this.skip, required this.next});

  final String skip;
  final String next;
}

/// Tam ekran spotlight ve tanıtım balonu.
///
/// Balon, dar ekranda dahi ekran sınırları içinde tutulur. Hareketli bir geçiş
/// kullanılmadığı için sistemde "hareketi azalt" açıkken ek bir yol gerekmez.
///
/// WP-375: hedef **canlı** ölçülür. Ölçüm `build`'e değil olaya bağlıdır —
/// adım değişimi, kaydırma bildirimi ve ekran metrik değişimi. Adım başlarken
/// hedef görünür alana kaydırılır; ilan edilmiş ama bulunamayan hedefte adım
/// **sessizce ortalanmaz**, [onAnchorLost] ile atlanır.
class TourOverlay extends StatefulWidget {
  const TourOverlay({
    super.key,
    required this.step,
    required this.index,
    required this.strings,
    required this.onNext,
    required this.onSkip,
    required this.onAnchorLost,
    this.remeasure,
  });

  final TourStep step;
  final int index;
  final TourOverlayStrings strings;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  /// Hedefi ilan edilmiş ama yerleşimde bulunamayan adım için çağrılır.
  /// Motorun kararı: **adımı atla** (bkz. [kTourAnchorResolveFrames]).
  final VoidCallback onAnchorLost;

  /// Ana gövdenin kaydırma/yerleşim olaylarında tetiklenen yeniden ölçüm
  /// sinyali. [TourHost] verir; testte doğrudan da beslenebilir.
  final Listenable? remeasure;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

/// Bir hedefin yerleşime girmesi için tanınan kare sayısı.
///
/// Async veriyle gelen bir kart ilk karelerde henüz monte değildir; hemen
/// "kayıp" demek turu haksız yere kısaltır. Bu sınırdan sonra ısrar etmek de
/// kullanıcıyı bekletir — hedef gerçekten yok demektir.
const kTourAnchorResolveFrames = 20;

class _TourOverlayState extends State<TourOverlay> with WidgetsBindingObserver {
  Rect? _anchor;
  int _attempts = 0;
  bool _ensuredVisible = false;
  bool _reportedLost = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.remeasure?.addListener(_onRemeasure);
    _scheduleMeasure(ensureVisible: true);
  }

  @override
  void didUpdateWidget(TourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remeasure != widget.remeasure) {
      oldWidget.remeasure?.removeListener(_onRemeasure);
      widget.remeasure?.addListener(_onRemeasure);
    }
    if (oldWidget.step.id != widget.step.id ||
        oldWidget.index != widget.index) {
      _anchor = null;
      _attempts = 0;
      _ensuredVisible = false;
      _reportedLost = false;
      _scheduleMeasure(ensureVisible: true);
    }
  }

  @override
  void dispose() {
    widget.remeasure?.removeListener(_onRemeasure);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Klavye, döndürme, pencere boyutu — hepsi hedefin yerini değiştirir.
  @override
  void didChangeMetrics() => _scheduleMeasure(ensureVisible: false);

  void _onRemeasure() => _scheduleMeasure(ensureVisible: false);

  Rect? _rectOf(BuildContext anchorContext) {
    final renderObject = anchorContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    final ancestor = overlay is RenderBox && overlay.hasSize
        ? overlay
        : context.findRenderObject();
    if (ancestor is! RenderBox || !ancestor.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero, ancestor: ancestor) &
        renderObject.size;
  }

  void _scheduleMeasure({required bool ensureVisible}) {
    if (!mounted || _reportedLost) return;
    // Kasıtlı hedefsiz adım (genel karşılama): ölçülecek bir şey yok.
    if (widget.step.anchor == null) {
      if (_anchor != null) setState(() => _anchor = null);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_measure(ensureVisible: ensureVisible));
    });
    // Post-frame geri çağrımı tek başına yeni bir kare istemez; hiçbir şey
    // çizmiyorken ölçüm zinciri sessizce durur. Kareyi açıkça istiyoruz —
    // zincir zaten [kTourAnchorResolveFrames] ile sınırlı.
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _measure({required bool ensureVisible}) async {
    if (!mounted || _reportedLost) return;
    final anchorContext = widget.step.anchor?.currentContext;

    if (anchorContext == null) {
      _attempts++;
      if (_attempts >= kTourAnchorResolveFrames) {
        // 🔴 WP-375'in asıl düzeltmesi: eskiden burada hiçbir şey olmuyor,
        // balon sessizce ekranın ortasına düşüyordu. Artık davranış tanımlı.
        _reportedLost = true;
        widget.onAnchorLost();
        return;
      }
      _scheduleMeasure(ensureVisible: ensureVisible);
      return;
    }

    if (ensureVisible && !_ensuredVisible) {
      _ensuredVisible = true;
      // Kaydırılabilir bir ata yoksa anında tamamlanır — güvenlidir.
      await Scrollable.ensureVisible(
        anchorContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      _scheduleMeasure(ensureVisible: false);
      return;
    }

    final rect = _rectOf(anchorContext);
    if (rect == null) {
      _attempts++;
      if (_attempts >= kTourAnchorResolveFrames) {
        _reportedLost = true;
        widget.onAnchorLost();
        return;
      }
      _scheduleMeasure(ensureVisible: false);
      return;
    }
    if (rect != _anchor) setState(() => _anchor = rect);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final anchor = _anchor;
    return Semantics(
      label:
          '${widget.step.title == null ? '' : '${widget.step.title}. '}'
          '${widget.step.text}',
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: const Key('tour-barrier'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onNext,
            child: CustomPaint(painter: _SpotlightPainter(anchor)),
          ),
          // 🔴 WP-920: "Atla" ile balon ARTIK AYNI yerleşimde. Eskiden balon
          // ayrı bir katmandaydı ve yalnız 16 dp kenar payıyla sınırlanıyordu;
          // gövde birkaç satıra çıkınca (küçük telefon, büyük yazı) balon
          // ekranın tepesine dayanıp sol üstteki "Atla"nın ÜSTÜNE biniyor,
          // düğme dokunulamaz oluyordu. Şimdi önce "Atla" ölçülür, balon
          // onun altındaki alana sığdırılır.
          CustomMultiChildLayout(
            delegate: _TourLayout(anchor),
            children: [
              LayoutId(
                id: _TourLayout.skipId,
                child: SafeArea(
                  // Sağ üstteki hedef denetimlerle (özellikle kart düzenleme
                  // ve grup değiştiriciyle) aynı dokunma alanını paylaşma.
                  child: Semantics(
                    button: true,
                    label: widget.strings.skip,
                    child: TextButton(
                      key: const Key('tour-skip-button'),
                      onPressed: widget.onSkip,
                      child: Text(widget.strings.skip),
                    ),
                  ),
                ),
              ),
              LayoutId(
                id: _TourLayout.bubbleId,
                child: Semantics(
                  container: true,
                  child: Material(
                    key: const Key('tour-bubble'),
                    color: scheme.surface,
                    elevation: 12,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🔴 WP-920 (sahip): gövde artık birkaç cümle. Cihazda
                          // normal yazı boyunda sığar; kaydırma yalnız çok
                          // büyük yazı ölçeği + küçük ekran için emniyet ağı.
                          // Başlık da kaydırılanın içinde: sabit kalan tek şey
                          // devam düğmesidir, o hiçbir koşulda ekrandan çıkmaz.
                          Flexible(
                            child: SingleChildScrollView(
                              key: const Key('tour-bubble-scroll'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.step.title case final title?) ...[
                                    Text(
                                      title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(widget.step.text),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Sayaç kalktığı için satırda tek şey var: devam
                          // düğmesi.
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: FilledButton(
                              key: const Key('tour-next-button'),
                              onPressed: widget.onNext,
                              child: Text(widget.strings.next),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.anchor);

  final Rect? anchor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (anchor != null) {
      path.addRRect(
        RRect.fromRectAndRadius(anchor!.inflate(8), const Radius.circular(14)),
      );
    }
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .62));
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.anchor != anchor;
}

/// "Atla" düğmesini sol üste, balonu hedefin yanına yerleştirir.
///
/// WP-920: balonun üst sınırı sabit 16 dp değil, "Atla" satırının alt
/// kenarıdır (durum çubuğu payı dahil). Böylece iki düğme de her ekran boyu
/// ve yazı ölçeğinde dokunulabilir kalır.
class _TourLayout extends MultiChildLayoutDelegate {
  _TourLayout(this.anchor);

  static const skipId = 'skip';
  static const bubbleId = 'bubble';

  final Rect? anchor;

  @override
  void performLayout(Size size) {
    const margin = 16.0;
    var reservedTop = 0.0;
    if (hasChild(skipId)) {
      final skip = layoutChild(skipId, BoxConstraints.loose(size));
      positionChild(skipId, Offset.zero);
      reservedTop = skip.height;
    }
    if (!hasChild(bubbleId)) return;

    final top = math.max(margin, reservedTop);
    final maxWidth = math.max(0.0, math.min(360.0, size.width - 32));
    final maxHeight = math.max(0.0, size.height - top - margin);
    final child = layoutChild(
      bubbleId,
      BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
    );
    positionChild(bubbleId, _bubblePosition(size, child, top));
  }

  Offset _bubblePosition(Size size, Size childSize, double top) {
    const margin = 16.0;
    final target = anchor;
    final horizontal = target == null
        ? (size.width - childSize.width) / 2
        : (target.center.dx - childSize.width / 2).clamp(
            margin,
            math.max(margin, size.width - childSize.width - margin),
          );
    final double vertical;
    if (target == null) {
      vertical = (size.height - childSize.height) / 2;
    } else {
      final below = target.bottom + margin;
      final above = target.top - childSize.height - margin;
      vertical = below + childSize.height <= size.height - margin
          ? below
          : above >= top
          ? above
          : (size.height - childSize.height) / 2;
    }
    return Offset(
      horizontal.toDouble(),
      vertical
          .clamp(top, math.max(top, size.height - childSize.height - margin))
          .toDouble(),
    );
  }

  @override
  bool shouldRelayout(_TourLayout oldDelegate) => oldDelegate.anchor != anchor;
}
