import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/desktop/desktop_window.dart';

/// Windows varsayılan pencere (desktop_window_io ile aynı).
///
/// Tüm kabuk bu “tasarım tuvali” üzerinde kurulur; gerçek pencere
/// büyüyüp küçülünce **layout değişmez**, yalnızca oransal ölçeklenir.
/// Mobil reflow (sütun kırılması, kart ezilmesi) yok.
const Size kDesktopDesignSize = Size(1100, 720);

/// Pencere / tasarım oranından ölçek hesaplar.
///
/// Küçük pencerede sığdırmak için serbestçe küçülür; büyük monitörde
/// [maxScale] ile abartılı şişme engellenir (letterbox kalır).
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

/// Tüm çocuk ağacını sabit tasarım boyutunda çizer, pencereye oransal sığdırır.
///
/// - MediaQuery.size = [designSize] → breakpoint / grid hep aynı
/// - FittedBox → font, kart, pane, boşluk aynı oranda büyür/küçülür
/// - Letterbox kenarları surface rengi
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
        final painted = Size(
          designSize.width * scale,
          designSize.height * scale,
        );
        final scheme = Theme.of(context).colorScheme;
        final parent = MediaQuery.of(context);

        return ColoredBox(
          color: scheme.surfaceContainerLowest,
          child: Center(
            child: SizedBox(
              width: painted.width,
              height: painted.height,
              child: FittedBox(
                fit: BoxFit.fill,
                alignment: Alignment.center,
                child: SizedBox(
                  width: designSize.width,
                  height: designSize.height,
                  child: MediaQuery(
                    data: parent.copyWith(
                      size: designSize,
                      // Metin zaten FittedBox ile ölçeklenir; ek textScale yok
                      // (çift ölçek olmasın).
                    ),
                    child: child,
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
