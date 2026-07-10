import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';

void main() {
  test('notification body shows elapsed time for stopwatch', () {
    final snapshot = TimerNotificationSnapshot(
      title: 'Odak Kampı çalışıyor',
      modeLabel: 'Kronometre',
      phaseLabel: 'Çalışma',
      startedAt: DateTime(2026),
      elapsedSeconds: 3661,
      remainingSeconds: null,
      isCountingDown: false,
    );

    expect(snapshot.body, contains('Kronometre'));
    expect(snapshot.body, contains('1 sa 1 dk 1 sn'));
    expect(snapshot.expandedBody, contains('Geçen süre: 1 sa 1 dk 1 sn'));
  });

  test('notification body shows remaining time for countdown', () {
    final snapshot = TimerNotificationSnapshot(
      title: 'Odak Kampı çalışıyor',
      modeLabel: 'Geri sayım',
      phaseLabel: 'Geri sayım',
      startedAt: DateTime(2026),
      elapsedSeconds: 120,
      remainingSeconds: 1500,
      isCountingDown: true,
      progress: 120,
      progressMax: 1620,
    );

    expect(snapshot.body, contains('Kalan 00:25:00'));
    expect(snapshot.expandedBody, contains('Kalan süre: 25 dk 0 sn'));
    expect(snapshot.hasProgress, isTrue);
  });

  test('stopwatch snapshot does not expose finite progress', () {
    final snapshot = TimerNotificationSnapshot(
      title: 'Odak Kampı çalışıyor',
      modeLabel: 'Kronometre',
      phaseLabel: 'Çalışma',
      startedAt: DateTime(2026),
      elapsedSeconds: 15,
      remainingSeconds: null,
      isCountingDown: false,
    );

    expect(snapshot.hasProgress, isFalse);
  });
}
