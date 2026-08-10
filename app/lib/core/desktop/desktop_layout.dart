import 'dart:ui';

/// Pencere sinifi merdiveni — WinUI (640/1008) + Material 3 (1200/1600).
///
/// SPEC: `docs/design/DESKTOP-UI-SPEC.md` §1.2. Ilk uc deger ve esikleri
/// DEGISMEDI; `large`/`xlarge` eklendi.
enum DesktopNavigationMode { minimal, compact, expanded, large, xlarge }

class DesktopBreakpoints {
  const DesktopBreakpoints._();

  static const double compact = 640;
  static const double expanded = 1008;

  /// M3 Large — bir pencere iki pane tasiyabilir (SPEC §1.2).
  static const double large = 1200;

  /// M3 Extra-Large — uc pane / 4+ sutun (SPEC §1.2).
  static const double xlarge = 1600;

  // --- Icerik genisligi tavanlari (SPEC §2.3) ---------------------------
  // Hepsi §2.1 olcu turetiminden gelir: govde yazisi 15 px, 1 karakter ≈
  // 0.5em = 7.5 px. Hepsi 4'un katidir (WinUI olcek platosu kurali).

  /// Duz metin / prose. 80 karakter × 7.5 = 600 (WCAG 2.1 SC 1.4.8 tavani).
  ///
  /// 🔴 `DesktopSurface.readingWidth = 760` prose icin 101 karakter eder ve
  /// WCAG tavanini asar. Form icin dogru, prose icin yanlis (SPEC §2.3).
  static const double maxProseWidth = 600;

  /// Form / ayar satiri: 600 (etiket olcu tavani) + 160 (kontrol alani).
  static const double maxFormWidth = 760;

  /// Etiket–deger satirinda etiketin solu ile degerin sagi arasindaki SERT
  /// tavan (80 karakter, WCAG 1.4.8).
  static const double maxLabelValueWidth = 600;

  /// Etiket–deger HEDEFI: 66 karakter (Bringhurst ideal olcu) × 7.5 = 495 → 496.
  static const double labelValueTargetWidth = 496;

  /// Tek sayilik istatistik dosemesi tavani (SPEC §2.3).
  static const double maxStatTileWidth = 320;

  /// Grafik karti tavani (SPEC §2.3).
  static const double maxChartCardWidth = 720;

  /// Izgara / pano toplami. 1440 = 3 × 480; `large`'da 2, `xlarge`'da 3 pane'e
  /// tam bolunur.
  static const double maxContentWidth = 1440;

  /// Gezinme SERIDININ kirilimi.
  ///
  /// ⚠️ Bilincli olarak `expanded`'da DURUR: `large`/`xlarge` sutun/pane
  /// kararlaridir, serit kararlari degil. Bunlari buradan dondurmek
  /// `desktop_navigation_pane.dart`'taki `mode == expanded` testini 1200 px
  /// ustunde YANLIS'a cevirir ve serit 176 → 52 px'e coker; yani islev kaybi.
  /// Tam merdiven icin [windowClass] kullanin.
  static DesktopNavigationMode navigationMode(double width) {
    if (width < compact) return DesktopNavigationMode.minimal;
    if (width < expanded) return DesktopNavigationMode.compact;
    return DesktopNavigationMode.expanded;
  }

  /// Tam pencere sinifi merdiveni (SPEC §1.2) — sutun/pane kararlari icin.
  static DesktopNavigationMode windowClass(double width) {
    if (width < compact) return DesktopNavigationMode.minimal;
    if (width < expanded) return DesktopNavigationMode.compact;
    if (width < large) return DesktopNavigationMode.expanded;
    if (width < xlarge) return DesktopNavigationMode.large;
    return DesktopNavigationMode.xlarge;
  }
}

/// Masaüstü penceresinin açılış boyutu.
///
/// 🔴 WP-672 ÖLÇÜMÜ — eski varsayılan 1100×720 idi. Genişletilmiş sol pane
/// 176 px olduğuna göre içerik sütununa **924 px** kalıyordu. Oysa
/// `DesktopMasterDetail` eşiği 1008, `DesktopResponsiveColumns` eşiği 1080:
/// ikisi de 924'ün üstünde. Yani varsayılan pencerede masaüstünün iki sütunlu
/// düzeni **hiçbir zaman** açılmıyordu, her ekran tek sütuna düşüyordu —
/// sahibin "mobilin penceresi gibi olmuş" şikâyetinin ölçülebilir yarısı.
/// SPEC §1.2 iki-pane esigini 1200'e aldi (`DesktopResponsiveColumns` ve
/// `DesktopMasterDetail` artik oradan kirilir). Yeni varsayilan icerik sutunu:
/// 1440 − 176 = **1264 ≥ 1200** → varsayilan pencere iki pane gosterebilir.
/// (1280 secilseydi 1104 kalirdi, yine yetmezdi.) 1440 ve 900, 4'un kati.
const Size kDesktopDefaultWindowSize = Size(1440, 900);

/// Pencerenin küçültülebileceği alt sınır.
///
/// 🔴 WP-672 ÖLÇÜMÜ — eski değer 560×540 idi. Daraltılmış şerit 52 px, yani
/// içeriğe **508 px** kalıyordu: telefon genişliği. Ayrıca `DesktopPageScaffold`
/// başlık şeridi 760'ın altında dikey (mobil) yığına düşüyor, dolayısıyla
/// uygulama en küçük hâlinde masaüstü gibi değil telefon gibi görünüyordu.
/// 880 − 52 = 828 ≥ 760 ([DesktopBreakpoints.maxFormWidth]) → en küçük
/// pencerede bile başlık masaüstü satır düzeninde kalır.
///
/// Not: `desktop_layout.dart` içindeki eski varsayılan (720×540) ile
/// `desktop_window_io.dart` içindeki değer (560×540) birbirini **tutmuyordu**;
/// artık tek kaynak burası.
const Size kDesktopMinimumWindowSize = Size(880, 600);

/// Kaydedilmiş pencereyi hâlâ bağlı bir ekranın görünür çalışma alanına taşır.
/// Ekran çıkarılmışsa primary alana ortalanır; pencere hiçbir zaman tamamen
/// ekran dışında veya çalışma alanından büyük dönmez.
Rect clampDesktopWindowBounds({
  required Rect requested,
  required List<Rect> workAreas,
  required Rect primaryWorkArea,
  Size minimumSize = kDesktopMinimumWindowSize,
}) {
  final areas = workAreas.isEmpty ? [primaryWorkArea] : workAreas;
  Rect? targetArea;
  var bestIntersection = 0.0;
  for (final area in areas) {
    final intersection = requested.intersect(area);
    final visibleArea = intersection.isEmpty
        ? 0.0
        : intersection.width * intersection.height;
    if (visibleArea > bestIntersection) {
      bestIntersection = visibleArea;
      targetArea = area;
    }
  }
  targetArea ??= primaryWorkArea;

  final width = requested.width
      .clamp(minimumSize.width, targetArea.width)
      .toDouble();
  final height = requested.height
      .clamp(minimumSize.height, targetArea.height)
      .toDouble();
  if (bestIntersection == 0) {
    return Rect.fromLTWH(
      targetArea.left + (targetArea.width - width) / 2,
      targetArea.top + (targetArea.height - height) / 2,
      width,
      height,
    );
  }

  return Rect.fromLTWH(
    requested.left.clamp(targetArea.left, targetArea.right - width).toDouble(),
    requested.top.clamp(targetArea.top, targetArea.bottom - height).toDouble(),
    width,
    height,
  );
}
