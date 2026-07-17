import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/desktop/desktop_proportional_scale.dart';

void main() {
  group('desktopProportionalScale', () {
    test('referans genişlikte ölçek 1', () {
      expect(
        desktopProportionalScale(viewport: const Size(1100, 720)),
        closeTo(1, 0.001),
      );
    });

    test('dar pencerede oransal küçülür', () {
      final scale = desktopProportionalScale(
        viewport: const Size(550, 900),
      );
      // 550/1100 = 0.5 → minScale 0.65 tavanı
      expect(scale, closeTo(0.65, 0.001));
    });

    test('genişlik yarıysa scale yarı (minScale altında clamp yoksa)', () {
      final scale = desktopProportionalScale(
        viewport: const Size(825, 500),
        minScale: 0.1,
      );
      expect(scale, closeTo(0.75, 0.001));
    });

    test('büyük monitörde maxScale tavanı', () {
      final scale = desktopProportionalScale(
        viewport: const Size(2560, 1440),
        maxScale: 1.5,
      );
      expect(scale, 1.5);
    });

    test('ölçek yalnız genişliğe bağlı (yükseklik esnek)', () {
      final a = desktopProportionalScale(viewport: const Size(1100, 500));
      final b = desktopProportionalScale(viewport: const Size(1100, 1200));
      expect(a, closeTo(b, 0.001));
    });
  });
}
