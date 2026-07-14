import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/desktop/desktop_window.dart';

/// Windows varsayılan pencere (desktop_window_io ile aynı).
///
/// Tüm kabuk bu “tasarım tuvali” üzerinde kurulur; gerçek pencere
/// büyüyüp küçülünce **layout değişmez**, yalnızca oransal ölçeklenir.
const Size kDesktopDesignSize = Size(1100, 720);

/// Pencere / tasarım oranından ölçek hesaplar.
double desktopProportionalScale({
  required Size viewport,
  Size design = kDesktopDesignSize,
  double maxScale = 1.35,
}) {
  if (viewport.width <= 0 || viewport.height <= 0) return 1;
  final sx = viewport.width / design.width;
  final sy = viewport.height / design.height;
  final fit = math.min(sx, sy);
  if (fit > maxScale) return maxScale;
  return fit;
}

/// Sabit tasarım tuvali + oransal sığdırma.
///
/// FittedBox yerine [Transform.scale] + [RepaintBoundary]:
/// - Ölçek GPU transform (ucuz)
/// - Alt ağaç ayrı raster katmanı → saniyelik kart tick’leri tüm kabuğu yeniden
///   boyamaz
class DesktopProportionalScale extends StatelessWidget {
  const DesktopProportionalScale({
    required this.child,
    this.designSize = kDesktopDesignSize,
    this.maxScale = 1.35,
    super.key,
  });

  final Widget child;
  final Size designSize;
  final double maxScale;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindow) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final scale = desktopProportionalScale(
          viewport: viewport,
          design: designSize,
          maxScale: maxScale,
        );
        final scheme = Theme.of(context).colorScheme;
        final parent = MediaQuery.of(context);

        // Transform.scale layout boyutunu değiştirmez → dış kutu ölçekli ölçülerde.
        return ColoredBox(
          color: scheme.surfaceContainerLowest,
          child: Center(
            child: SizedBox(
              width: designSize.width * scale,
              height: designSize.height * scale,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: designSize.width,
                  maxWidth: designSize.width,
                  minHeight: designSize.height,
                  maxHeight: designSize.height,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topLeft,
                    filterQuality: FilterQuality.medium,
                    child: SizedBox(
                      width: designSize.width,
                      height: designSize.height,
                      child: MediaQuery(
                        data: parent.copyWith(size: designSize),
                        child: RepaintBoundary(child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
