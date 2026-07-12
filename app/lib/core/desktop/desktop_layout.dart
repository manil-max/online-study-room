import 'dart:ui';

enum DesktopNavigationMode { minimal, compact, expanded }

class DesktopBreakpoints {
  const DesktopBreakpoints._();

  static const double compact = 640;
  static const double expanded = 1008;
  static const double maxContentWidth = 1440;

  static DesktopNavigationMode navigationMode(double width) {
    if (width < compact) return DesktopNavigationMode.minimal;
    if (width < expanded) return DesktopNavigationMode.compact;
    return DesktopNavigationMode.expanded;
  }
}

/// Kaydedilmiş pencereyi hâlâ bağlı bir ekranın görünür çalışma alanına taşır.
/// Ekran çıkarılmışsa primary alana ortalanır; pencere hiçbir zaman tamamen
/// ekran dışında veya çalışma alanından büyük dönmez.
Rect clampDesktopWindowBounds({
  required Rect requested,
  required List<Rect> workAreas,
  required Rect primaryWorkArea,
  Size minimumSize = const Size(720, 540),
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
