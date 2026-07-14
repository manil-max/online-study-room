import 'package:flutter/material.dart';

import '../../core/desktop/desktop_window.dart';

/// Referans genişlik — “normal” pencere yoğunluğu (~varsayılan 1100).
///
/// Sabit tuval + letterbox YOK. Genişliğe göre tek [scale]; mantıksal yükseklik
/// pencereye sığacak şekilde ayarlanır → sol/sağ veya üst/alt boş şerit kalmaz,
/// tüm UI aynı oranda büyür/küçülür.
const double kDesktopReferenceWidth = 1100;

/// Eski API uyumu (testler / doc).
const Size kDesktopDesignSize = Size(kDesktopReferenceWidth, 720);

/// Genişliğe göre tek ölçek (yükseklik ayrı esner; oran bozulmaz).
double desktopProportionalScale({
  required Size viewport,
  Size design = kDesktopDesignSize,
  double maxScale = 1.5,
  double minScale = 0.65,
}) {
  if (viewport.width <= 0) return 1;
  final raw = viewport.width / design.width;
  return raw.clamp(minScale, maxScale);
}

/// Pencereyi tam dolduran, tek oranlı ölçek.
///
/// - Letterbox yok (tam ekranda kenar boşluğu yok)
/// - sx == sy → arayüz elemanları birbirine göre bozulmaz
/// - Mantıksal boyut = fiziksel / scale → layout esnek (dar/yüksek pencere OK)
class DesktopProportionalScale extends StatelessWidget {
  const DesktopProportionalScale({
    required this.child,
    this.referenceWidth = kDesktopReferenceWidth,
    this.maxScale = 1.5,
    this.minScale = 0.65,
    super.key,
  });

  final Widget child;
  final double referenceWidth;
  final double maxScale;
  final double minScale;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindow) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final vw = constraints.maxWidth;
        final vh = constraints.maxHeight;
        if (vw <= 0 || vh <= 0) return child;

        final scale = desktopProportionalScale(
          viewport: Size(vw, vh),
          design: Size(referenceWidth, 720),
          maxScale: maxScale,
          minScale: minScale,
        );

        // Mantıksal tuval: genişlik referansa yakın; yükseklik pencereye göre.
        // FittedBox.fill + (logicalW, logicalH) → scaleX = scaleY = scale,
        // boyalı alan tam vw×vh (boş şerit yok).
        final logicalW = vw / scale;
        final logicalH = vh / scale;

        final parent = MediaQuery.of(context);
        return SizedBox(
          width: vw,
          height: vh,
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.center,
            child: SizedBox(
              width: logicalW,
              height: logicalH,
              child: MediaQuery(
                data: parent.copyWith(size: Size(logicalW, logicalH)),
                child: RepaintBoundary(child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}
