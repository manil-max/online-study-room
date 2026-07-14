import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

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
    expect(snapshot.body(l10n), 'Kronometre · Çalışıyor');
    expect(snapshot.body(l10n), isNot(contains('sn')));
    // Genişletilmiş görünüm anlık bir özet olarak geçen süreyi gösterebilir.
    expect(snapshot.expandedBody(l10n), contains('01:01:01'));
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
    expect(snapshot.body(l10n), 'Geri sayım');
    expect(snapshot.expandedBody(l10n), contains('00:25:00'));
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
