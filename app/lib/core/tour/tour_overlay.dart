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
class TourOverlay extends StatelessWidget {
  const TourOverlay({
    super.key,
    required this.step,
    required this.index,
    required this.total,
    required this.strings,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int total;
  final TourOverlayStrings strings;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  Rect? _anchorRect(BuildContext context) {
    final anchorContext = step.anchor?.currentContext;
    final renderObject = anchorContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (overlay is! RenderBox || !overlay.hasSize) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: overlay);
    return topLeft & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final anchor = _anchorRect(context);
    return Semantics(
      label: '${step.title == null ? '' : '${step.title}. '}${step.text}',
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: const Key('tour-barrier'),
            behavior: HitTestBehavior.opaque,
            onTap: onNext,
            child: CustomPaint(painter: _SpotlightPainter(anchor)),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Semantics(
                button: true,
                label: strings.skip,
                child: TextButton(
                  key: const Key('tour-skip-button'),
                  onPressed: onSkip,
                  child: Text(strings.skip),
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
                      if (step.title case final title?) ...[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(step.text),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              strings.stepCounter(index + 1, total),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          FilledButton(
                            key: const Key('tour-next-button'),
                            onPressed: onNext,
                            child: Text(strings.next),
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
