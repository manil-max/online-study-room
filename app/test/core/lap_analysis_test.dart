import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/lap_analysis.dart';

void main() {
  group('formatCountdown', () {
    test('bir saatin altı → mm:ss', () {
      expect(formatCountdown(const Duration(minutes: 5, seconds: 9)), '05:09');
    });

    test('bir saat ve üzeri → h:mm:ss', () {
      expect(
        formatCountdown(const Duration(hours: 1, minutes: 0, seconds: 5)),
        '1:00:05',
      );
    });

    test('negatif süre 00:00\'a kırpılır', () {
      expect(formatCountdown(const Duration(seconds: -5)), '00:00');
    });
  });
}
