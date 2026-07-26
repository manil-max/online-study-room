import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/classroom/widgets/camp_critter.dart';

void main() {
  test('marşmelov pişmesi seçilen 12 dakikalık döngüde sıfırlanır', () {
    expect(MarshmallowPainter.doneness(0, cycleMinutes: 12), 0);
    expect(MarshmallowPainter.doneness(360, cycleMinutes: 12), 0.5);
    expect(
      MarshmallowPainter.doneness(719, cycleMinutes: 12),
      closeTo(719 / 720, 0.000001),
    );
    expect(MarshmallowPainter.doneness(720, cycleMinutes: 12), 0);
    expect(
      MarshmallowPainter.doneness(750, cycleMinutes: 12),
      closeTo(30 / 720, 0.000001),
    );
  });
}
