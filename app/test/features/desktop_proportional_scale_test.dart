import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/desktop/desktop_proportional_scale.dart';

void main() {
  group('desktopProportionalScale', () {
    test('tasarım boyutunda ölçek 1', () {
      expect(
        desktopProportionalScale(viewport: kDesktopDesignSize),
        closeTo(1, 0.001),
      );
    });

    test('küçük pencerede oransal küçülür (layout kırma yok)', () {
      final scale = desktopProportionalScale(
        viewport: const Size(550, 360),
      );
      // 550/1100 = 0.5, 360/720 = 0.5
      expect(scale, closeTo(0.5, 0.001));
    });

    test('yalnız genişlik daralınca en dar orana göre küçülür', () {
      final scale = desktopProportionalScale(
        viewport: const Size(825, 720),
      );
      // 825/1100 = 0.75
      expect(scale, closeTo(0.75, 0.001));
    });

    test('büyük monitörde maxScale tavanı', () {
      final scale = desktopProportionalScale(
        viewport: const Size(2560, 1440),
        maxScale: 1.35,
      );
      expect(scale, 1.35);
    });

    test('en-boy oranı bozulmaz — min(sx,sy)', () {
      final scale = desktopProportionalScale(
        viewport: const Size(2200, 720),
      );
      // genislik 2x ama yükseklik 1x → 1.0 (max 1.35 ama sy=1)
      expect(scale, closeTo(1.0, 0.001));
    });
  });
}
