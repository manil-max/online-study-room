import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/notification_auto_ask_flag.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';

/// WP-872: bildirim iznini reddeden kullanıcıya sayaç her başlatıldığında
/// sistem penceresi yeniden açılıyordu (`_showTimerSurfaces(requestPermission:
/// true)` otomatik soru bayrağına bakmıyordu). CHANGELOG v87: "reddettiyse bir
/// daha kendiliğinden sorulmaz".
///
/// İki yönlü: hiç sorulmamış cihazda ilk başlatma BİR KEZ sorar (sabotaj "hiç
/// sorma" yeşil geçmesin), sorulmuş cihazda hiç sormaz.
class _CountingTimerNotificationService implements TimerNotificationGateway {
  int requests = 0;

  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> requestPermissionIfNeeded() async => requests++;
}

class _NoopAndroidWidgetService implements AndroidWidgetGateway {
  const _NoopAndroidWidgetService();

  @override
  Future<void> refresh({Iterable<StudyHomeWidget>? widgets}) async {}

  @override
  Future<void> saveSnapshot(AndroidWidgetSnapshot snapshot) async {}

  @override
  Future<void> seedPlaceholder() async {}
}

class _Clock {
  DateTime now = DateTime.utc(2026, 9, 19, 9);
  DateTime call() => now;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, _CountingTimerNotificationService, SharedPreferences, _Clock)>
  setUpTimer(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    final service = _CountingTimerNotificationService();
    final clock = _Clock();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        studyTimerClockProvider.overrideWithValue(clock.call),
        timerNotificationServiceProvider.overrideWithValue(service),
        androidWidgetServiceProvider.overrideWithValue(
          const _NoopAndroidWidgetService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container, service, prefs, clock);
  }

  Future<void> startStop(ProviderContainer c, _Clock clock) async {
    final notifier = c.read(studyTimerProvider.notifier);
    notifier.start();
    await pumpEventQueue();
    clock.now = clock.now.add(const Duration(minutes: 5));
    await notifier.stop();
    // Kaza korkuluğu penceresinin (10 sn) dışına çık.
    clock.now = clock.now.add(const Duration(minutes: 1));
  }

  test('otomatik soru yapılmış (ret) cihazda başlatma pencere açmaz', () async {
    final (c, service, _, clock) = await setUpTimer({
      kNotificationAutoAskKey: true,
    });
    await startStop(c, clock);
    await startStop(c, clock);
    expect(
      service.requests,
      0,
      reason: 'ret eden kullanıcıya her başlatmada yeniden sorulmamalı',
    );
  });

  test('hiç sorulmamış cihazda ilk başlatma bir kez sorar, sonra sormaz', () async {
    final (c, service, prefs, clock) = await setUpTimer({});
    await startStop(c, clock);
    expect(service.requests, 1, reason: 'ilk başlatma izni bir kez istemeli');
    expect(notificationAutoAskDone(prefs), isTrue);
    await startStop(c, clock);
    await startStop(c, clock);
    expect(service.requests, 1);
  });

  test("WP-909: iOS'ta baslatma bayragi yazmaz (otomatik soru iOS'ta kalir)", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final (c, service, prefs, clock) = await setUpTimer({});
    await startStop(c, clock);
    expect(service.requests, 0);
    expect(notificationAutoAskDone(prefs), isFalse);
  });
}
