import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/time_engine.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';

void main() {
  group('EpochCountdownState', () {
    test('remaining from endsAtMs', () {
      var c = EpochCountdownState.initial(60_000).start(0);
      expect(c.remainingMs(10_000), 50_000);
      c = c.pause(10_000);
      expect(c.remainingMs(999_999), 50_000);
      c = c.addSeconds(60, 10_000);
      expect(c.durationMs, 120_000);
      expect(c.remainingMs(10_000), 110_000);
    });

    test('done at zero', () {
      final c = EpochCountdownState.initial(1000).start(0);
      expect(c.isDone(1000), isTrue);
      expect(c.isDone(500), isFalse);
    });
  });

  group('AlarmScheduler', () {
    test('one-shot rolls to tomorrow if past', () {
      final alarm = AlarmRule(id: 'a', hour: 8, minute: 0);
      final now = DateTime(2026, 7, 13, 9, 0);
      final next = AlarmScheduler.nextFire(alarm, now)!;
      expect(next.day, 14);
      expect(next.hour, 8);
    });

    test('weekday recurrence', () {
      // 2026-07-13 is Monday
      final alarm = AlarmRule(
        id: 'a',
        hour: 7,
        minute: 30,
        days: const [1, 3, 5], // Mon Wed Fri
      );
      final tue = DateTime(2026, 7, 14, 12, 0); // Tuesday
      final next = AlarmScheduler.nextFire(alarm, tue)!;
      expect(next.weekday, 3); // Wednesday
      expect(next.hour, 7);
      expect(next.minute, 30);
    });

    test('skip next occurrence', () {
      final now = DateTime(2026, 7, 13, 6, 0);
      final alarm = AlarmRule(
        id: 'a',
        hour: 7,
        minute: 0,
        days: const [1], // Monday only
        skipNextOn: DateTime(2026, 7, 13),
      );
      final next = AlarmScheduler.nextFire(alarm, now)!;
      // Next Monday
      expect(next.day, 20);
    });

    test('inactive returns null', () {
      final alarm = AlarmRule(id: 'a', hour: 8, minute: 0, isActive: false);
      expect(AlarmScheduler.nextFire(alarm, DateTime(2026, 1, 1)), isNull);
    });

    test('crescendo 0→1 over 30s', () {
      expect(AlarmScheduler.crescendoLevel(Duration.zero), 0);
      expect(
        AlarmScheduler.crescendoLevel(const Duration(seconds: 15)),
        closeTo(0.5, 0.01),
      );
      expect(
        AlarmScheduler.crescendoLevel(const Duration(seconds: 30)),
        1.0,
      );
      expect(
        AlarmScheduler.crescendoLevel(const Duration(seconds: 60)),
        1.0,
      );
    });
  });

  group('BurnInOffset', () {
    test('max displacement over 60 periods exceeds 10px', () {
      final maxD = BurnInOffset.maxDisplacementOver(
        periods: 60,
        amplitude: 12,
      );
      expect(maxD, greaterThanOrEqualTo(10));
    });
  });

  group('world clock day/night', () {
    test('hour boundaries', () {
      expect(isDaytimeHour(6), isTrue);
      expect(isDaytimeHour(17), isTrue);
      expect(isDaytimeHour(18), isFalse);
      expect(isDaytimeHour(5), isFalse);
    });
  });
}
