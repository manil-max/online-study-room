import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/classroom/widgets/campfire/campfire_activity.dart';

void main() {
  group('campfireActivityFor', () {
    test('0 → empty', () {
      expect(campfireActivityFor(0), CampfireActivity.empty);
      expect(campfireActivityFor(-1), CampfireActivity.empty);
    });

    test('1–2 → low', () {
      expect(campfireActivityFor(1), CampfireActivity.low);
      expect(campfireActivityFor(2), CampfireActivity.low);
    });

    test('≥3 → high', () {
      expect(campfireActivityFor(3), CampfireActivity.high);
      expect(campfireActivityFor(12), CampfireActivity.high);
    });
  });

  group('campfireIntensityFor', () {
    test('matches legacy empty/low bounds', () {
      expect(campfireIntensityFor(0), 0.24);
      expect(campfireIntensityFor(1), closeTo(0.64, 0.001));
      expect(campfireIntensityFor(10), 1.0);
    });
  });
}
