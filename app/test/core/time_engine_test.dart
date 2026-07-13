import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/time_engine.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';

void main() {
  group('EpochStopwatchState', () {
    test('elapsed ignores wall gaps via epoch', () {
      final clock = FakeEpochClock(1_000_000);
      var s = EpochStopwatchState.idle.start(clock.nowMs());
      clock.advance(const Duration(seconds: 5));
      expect(s.elapsedMs(clock.nowMs()), 5000);
      s = s.pause(clock.nowMs());
      clock.advance(const Duration(hours: 1)); // pause sırasında süre artmaz
      expect(s.elapsedMs(clock.nowMs()), 5000);
      s = s.start(clock.nowMs());
      clock.advance(const Duration(seconds: 2));
      expect(s.elapsedMs(clock.nowMs()), 7000);
    });

    test('lap records totals', () {
      final clock = FakeEpochClock(0);
      var s = EpochStopwatchState.idle.start(0);
      clock.setMs(1000);
      s = s.lap(clock.nowMs());
      clock.setMs(3000);
      s = s.lap(clock.nowMs());
      expect(s.laps, [1000, 3000]);
    });
  });

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

  group('LapAnalysis', () {
    test('fastest and slowest highlight', () {
      // totals: 10s, 25s, 35s → splits 10, 15, 10
      final a = LapAnalysis.fromTotals([10000, 25000, 35000]);
      expect(a.splitsMs, [10000, 15000, 10000]);
      expect(a.fastestIndex, 0); // first 10s (tie with last — first wins)
      expect(a.slowestIndex, 1);
    });

    test('single lap no slowest', () {
      final a = LapAnalysis.fromTotals([5000]);
      expect(a.fastestIndex, 0);
      expect(a.slowestIndex, -1);
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

  group('formatStopwatch', () {
    test('mm:ss.cc', () {
      final s = formatStopwatch(const Duration(minutes: 1, seconds: 2, milliseconds: 340));
      expect(s, '01:02.34');
    });
  });
}
