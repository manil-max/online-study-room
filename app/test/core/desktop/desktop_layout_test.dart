import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';

void main() {
  group('DesktopBreakpoints', () {
    test('Microsoft NavigationView eşiklerini uygular', () {
      expect(
        DesktopBreakpoints.navigationMode(639),
        DesktopNavigationMode.minimal,
      );
      expect(
        DesktopBreakpoints.navigationMode(640),
        DesktopNavigationMode.compact,
      );
      expect(
        DesktopBreakpoints.navigationMode(1007),
        DesktopNavigationMode.compact,
      );
      expect(
        DesktopBreakpoints.navigationMode(1008),
        DesktopNavigationMode.expanded,
      );
    });
  });

  group('clampDesktopWindowBounds', () {
    const primary = Rect.fromLTWH(0, 0, 1920, 1040);
    const secondary = Rect.fromLTWH(1920, 0, 2560, 1400);

    test('çıkarılan monitördeki pencereyi primary ekrana ortalar', () {
      final result = clampDesktopWindowBounds(
        requested: const Rect.fromLTWH(5000, 300, 1100, 720),
        workAreas: const [primary, secondary],
        primaryWorkArea: primary,
      );

      expect(result, const Rect.fromLTWH(410, 160, 1100, 720));
    });

    test('aşırı büyük pencereyi seçili çalışma alanına sığdırır', () {
      final result = clampDesktopWindowBounds(
        requested: const Rect.fromLTWH(2000, -200, 4000, 2000),
        workAreas: const [primary, secondary],
        primaryWorkArea: primary,
      );

      expect(result, secondary);
    });

    test('kısmen görünen pencereyi aynı monitörde tutar', () {
      final result = clampDesktopWindowBounds(
        requested: const Rect.fromLTWH(-100, 900, 900, 700),
        workAreas: const [primary],
        primaryWorkArea: primary,
      );

      expect(result, const Rect.fromLTWH(0, 340, 900, 700));
    });
  });
}
