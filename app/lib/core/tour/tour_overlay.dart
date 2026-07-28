import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tour_models.dart';

/// WP-323: Motorun yerelleştirilmiş sabit metinleri.
///
/// Tur adımlarının içeriği çağıran ekrana (WP-324) aittir; bu küçük yapı yalnız
/// motorun her turda ortak olan kontrol metinlerini taşır.
@immutable
class TourOverlayStrings {
  const TourOverlayStrings({
    required this.skip,
    required this.next,
    required this.stepCounter,
  });

  final String skip;
  final String next;
  final String Function(int current, int total) stepCounter;
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
    required this.total,
    required this.strings,
    required this.onNext,
    required this.onSkip,
    required this.onAnchorLost,
    this.remeasure,
  });

  final TourStep step;
  final int index;
  final int total;
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
          SafeArea(
            child: Align(
              // Sağ üstteki hedef denetimlerle (özellikle kart düzenleme ve
              // grup değiştiriciyle) aynı dokunma alanını paylaşma.
              alignment: Alignment.topLeft,
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
          CustomSingleChildLayout(
            delegate: _TourBubbleLayout(anchor),
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
                      if (widget.step.title case final title?) ...[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(widget.step.text),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.strings.stepCounter(
                                widget.index + 1,
                                widget.total,
                              ),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          FilledButton(
                            key: const Key('tour-next-button'),
                            onPressed: widget.onNext,
                            child: Text(widget.strings.next),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

class _TourBubbleLayout extends SingleChildLayoutDelegate {
  const _TourBubbleLayout(this.anchor);

  final Rect? anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.max(0.0, math.min(360.0, constraints.maxWidth - 32));
    final maxHeight = math.max(0.0, constraints.maxHeight - 32);
    return BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const margin = 16.0;
    final target = anchor;
    if (target == null) {
      return Offset(
        (size.width - childSize.width) / 2,
        (size.height - childSize.height) / 2,
      );
    }
    final horizontal = (target.center.dx - childSize.width / 2).clamp(
      margin,
      math.max(margin, size.width - childSize.width - margin),
    );
    final below = target.bottom + margin;
    final above = target.top - childSize.height - margin;
    final vertical = below + childSize.height <= size.height - margin
        ? below
        : above >= margin
        ? above
        : (size.height - childSize.height) / 2;
    return Offset(
      horizontal.toDouble(),
      vertical
          .clamp(
            margin,
            math.max(margin, size.height - childSize.height - margin),
          )
          .toDouble(),
    );
  }

  @override
  bool shouldRelayout(_TourBubbleLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}
