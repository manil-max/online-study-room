import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:online_study_room/core/notifications/app_push_notification_service.dart';

void main() {
  testWidgets(
    'Flutter test hostu native registrant olmadan açık no-op kullanır',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await expectLater(
          AppNotificationCoordinator.instance.initialize(),
          completes,
        );
        expect(
          await AppNotificationCoordinator.instance.notificationsEnabled(),
          isFalse,
        );
        expect(
          await AppNotificationCoordinator.instance.requestPermission(),
          isFalse,
        );
        await expectLater(
          AppNotificationCoordinator.instance.showLocalTest(),
          completes,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test('gerçek adapter başlatılır, kanallar bir kez kurulur', () async {
    final adapter = _FakeLocalNotificationsAdapter(
      notificationsEnabledResult: true,
      permissionResult: true,
    );
    final coordinator = AppNotificationCoordinator.forTesting(adapter);

    await coordinator.initialize();
    await coordinator.initialize();

    expect(adapter.initializeCalls, 1);
    expect(adapter.createChannelsCalls, 1);
    expect(adapter.channels.map((channel) => channel.id), {
      'social_nudges',
      'push_system_test',
      'app_updates',
      'announcements',
    });
    expect(await coordinator.notificationsEnabled(), isTrue);
    expect(await coordinator.requestPermission(), isTrue);
  });

  test('local test bildirimi adapter sınırından geçer', () async {
    final adapter = _FakeLocalNotificationsAdapter();
    final coordinator = AppNotificationCoordinator.forTesting(adapter);

    await coordinator.showLocalTest();

    expect(adapter.shows, hasLength(1));
    expect(adapter.shows.single.id, 266001);
    expect(adapter.shows.single.payload, 'notification_center:local_test');
  });

  test('gerçek adapter init hatası mesajına bakılmadan iletilir', () async {
    final adapter = _FakeLocalNotificationsAdapter(
      initializeError: StateError('native registrant broken'),
    );
    final coordinator = AppNotificationCoordinator.forTesting(adapter);

    await expectLater(coordinator.initialize(), throwsA(isA<StateError>()));
    expect(adapter.createChannelsCalls, 0);
  });

  test('Android olmayan platform adapter çağırmaz', () async {
    final adapter = _FakeLocalNotificationsAdapter(
      notificationsEnabledResult: true,
      permissionResult: true,
    );
    final coordinator = AppNotificationCoordinator.forTesting(
      adapter,
      isAndroid: false,
    );

    expect(await coordinator.notificationsEnabled(), isFalse);
    expect(await coordinator.requestPermission(), isFalse);
    await coordinator.showLocalTest();

    expect(adapter.initializeCalls, 0);
    expect(adapter.shows, isEmpty);
  });
}

class _FakeLocalNotificationsAdapter implements AppLocalNotificationsAdapter {
  _FakeLocalNotificationsAdapter({
    this.notificationsEnabledResult = false,
    this.permissionResult = false,
    this.initializeError,
  });

  final bool notificationsEnabledResult;
  final bool permissionResult;
  final Object? initializeError;
  int initializeCalls = 0;
  int createChannelsCalls = 0;
  final channels = <AndroidNotificationChannel>[];
  final shows =
      <
        ({
          int id,
          String? title,
          String? body,
          NotificationDetails notificationDetails,
          String? payload,
        })
      >[];

  @override
  Future<void> initialize() async {
    initializeCalls++;
    final error = initializeError;
    if (error != null) throw error;
  }

  @override
  Future<void> createChannels(List<AndroidNotificationChannel> channels) async {
    createChannelsCalls++;
    this.channels.addAll(channels);
  }

  @override
  Future<bool> notificationsEnabled() async => notificationsEnabledResult;

  @override
  Future<bool> requestPermission() async => permissionResult;

  @override
  Future<void> show({
    required int id,
    required String? title,
    required String? body,
    required NotificationDetails notificationDetails,
    required String? payload,
  }) async {
    shows.add((
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    ));
  }
}
