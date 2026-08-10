import 'package:flutter/material.dart';

import '../../core/desktop/desktop_window.dart';

/// 🔴 WP-672 / SPEC §0 — BU DOSYA ARTIK ETKISIZDIR.
///
/// Eskiden `DesktopHomeShell` butun govdeyi bu sarmalayiciya sariyor ve
/// iceriye SAHTE bir MediaQuery veriyordu. Olculen sonuc:
///
/// | gercek pencere | olcek | uygulamanin GORDUGU genislik | boyanan pane |
/// |---:|---:|---:|---:|
/// | 1100 | 1.00 | 1100 | 176 |
/// | 1600 | 1.45 | 1100 | 256 |
/// | 2000 | 1.50 | 1333 | 264 |
/// | 2560 | 1.50 | 1707 | 264 |
///
/// Yani 1100–1650 bandinda hicbir kirilim noktasi tetiklenmiyor, ustunde ise
/// arayuz yeniden duzenlenmiyor yalnizca BUYUTULUYORDU. Sahibin "mobilin
/// penceresi gibi olmus" cumlesinin birebir karsiligi budur. Ustelik bu,
/// Windows'un KENDI DPI olceginin ustune binen ikinci bir olcekti (%150
/// ayarli 4K ekranda 1.5 × 1.5 = 2.25 kat).
///
/// Sarmalayici `DesktopHomeShell`ten KALDIRILDI. Tur, gecis doneminde ithal
/// eden kod kirilmasin diye duruyor ama artik cocugu oldugu gibi dondurur.
const double kDesktopReferenceWidth = 1100;

/// Eski API uyumu (testler / doc).
const Size kDesktopDesignSize = Size(kDesktopReferenceWidth, 720);

/// SPEC §8 iddia 1: `desktopProportionalScale(viewport: Size(2000, 1200))`
/// **1.0** doner (once 1.5 donuyordu).
///
/// Varsayilan tavan da taban da 1 — masaustu ne buyutulur ne kucultulur,
/// REFLOW eder. Cagri yeri acikca baska bir aralik vermedikce fonksiyon
/// sabit 1 dondurur.
double desktopProportionalScale({
  required Size viewport,
  Size design = kDesktopDesignSize,
  double maxScale = 1,
  double minScale = 1,
}) {
  if (viewport.width <= 0) return 1;
  final raw = viewport.width / design.width;
  return raw.clamp(minScale, maxScale);
}

/// 🔴 KULLANMAYIN — SPEC §0 KARAR 0 ile devre disi birakildi.
///
/// Varsayilan parametrelerle olcek her zaman 1'dir, yani cocuk hicbir
/// donusumden gecmez ve MediaQuery ezilmez. Yeni cagri yeri EKLEMEYIN;
/// masaustu genisligi kirilim noktalariyla karsilanir.
@Deprecated(
  'WP-672/SPEC §0: masaustu ZOOM etmez, REFLOW eder. '
  'Sarmalayici DesktopHomeShell\'ten kaldirildi.',
)
class DesktopProportionalScale extends StatelessWidget {
  const DesktopProportionalScale({
    required this.child,
    this.referenceWidth = kDesktopReferenceWidth,
    this.maxScale = 1,
    this.minScale = 1,
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
        // Olcek 1 → hicbir sey yapma. FittedBox/MediaQuery ezmesi yok.
        if (scale == 1) return child;

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
