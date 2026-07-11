import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';

void main() {
  test('stopwatch body has no static elapsed (live time is the chronometer)', () {
    final snapshot = TimerNotificationSnapshot(
      title: 'Odak Kampı çalışıyor',
      modeLabel: 'Kronometre',
      phaseLabel: 'Çalışma',
      startedAt: DateTime(2026),
      elapsedSeconds: 3661,
      remainingSeconds: null,
      isCountingDown: false,
      isRunning: true,
    );

    // Gövde sabit süre içermez (yoksa bildirim yenilenmediği için "0 sn"de takılır);
    // geçen süre başlıktaki canlı kronometre ile gösterilir.
    expect(snapshot.body, 'Kronometre çalışıyor');
    expect(snapshot.body, isNot(contains('sn')));
    // Genişletilmiş görünüm anlık bir özet olarak geçen süreyi gösterebilir.
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
      isRunning: true,
    );

    // Kalan süre başlıktaki geri sayan kronometre ile gösterilir; gövde faz etiketi.
    expect(snapshot.body, 'Geri sayım');
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
      isRunning: true,
    );

    expect(snapshot.hasProgress, isFalse);
  });
}
