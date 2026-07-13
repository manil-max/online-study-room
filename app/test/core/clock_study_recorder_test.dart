import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/clock_study_recorder.dart';

void main() {
  test('minDurationSeconds is 30', () {
    expect(ClockStudyRecorder.minDurationSeconds, 30);
  });
}
