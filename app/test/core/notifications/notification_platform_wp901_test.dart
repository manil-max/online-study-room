import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_platform.dart';
import 'package:online_study_room/core/notifications/reminder_notification_service.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';

/// WP-901: FLN kurulumu iOS alanını taşır (yoksa FLN iOS'ta fırlatır) ve iOS
/// izni kurulumda değil açıkça istenir.
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('ortak kurulum hem Android hem iOS alanını taşır', () {
    expect(kLocalNotificationInitSettings.android, isNotNull);
    expect(
      kLocalNotificationInitSettings.android!.defaultIcon,
      '@mipmap/ic_launcher',
    );
    final ios = kLocalNotificationInitSettings.iOS;
    expect(ios, isNotNull);
    // İzin kurulumda sorulmaz; akış onu bir kez, bağlamıyla sorar.
    expect(ios!.requestAlertPermission, isFalse);
    expect(ios.requestSoundPermission, isFalse);
    expect(ios.requestBadgePermission, isFalse);
  });

  test('isIosTarget yalnız iOS hedefinde true', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(isIosTarget, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(isIosTarget, isFalse);
  });

  group('iOS eklentisi (sahte kanal)', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    late List<MethodCall> calls;
    var userAllows = false;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      calls = [];
      FlutterLocalNotificationsPlatform.instance =
          IOSFlutterLocalNotificationsPlugin();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'initialize' => true,
              'requestPermissions' => userAllows,
              'checkPermissions' => {'isEnabled': userAllows},
              _ => null,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'hatırlatıcı izni iOS penceresini açar, "verildi" yalanı yok',
      () async {
        // Eski yol `android?.requestNotificationsPermission() ?? true` idi:
        // iOS'ta Android eklentisi yok → pencere açmadan `true`.
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        userAllows = false;
        final service = ReminderNotificationService.forTest(
          FlutterLocalNotificationsPlugin(),
        );
        expect(await service.requestPermissionIfNeeded(), isFalse);
        final init = calls.firstWhere((c) => c.method == 'initialize');
        final args = Map<Object?, Object?>.from(init.arguments as Map);
        // İzin kurulumda sorulmaz.
        expect(args['requestAlertPermission'], isFalse);
        final request = calls.firstWhere(
          (c) => c.method == 'requestPermissions',
        );
        final requestArgs = Map<Object?, Object?>.from(
          request.arguments as Map,
        );
        expect(requestArgs['alert'], isTrue);
        expect(requestArgs['badge'], isTrue);
        expect(requestArgs['sound'], isTrue);
      },
    );

    test('ClockPermissions iOS: yalnız bildirim, Darwin durumundan', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      userAllows = true;
      final snapshot = await ClockPermissions().snapshot();
      expect(snapshot.availability, ClockPermissionAvailability.available);
      expect(snapshot.notificationsOnly, isTrue);
      expect(snapshot.notifications, isTrue);
      expect(snapshot.allOk, isTrue);
    });
  });

  test('iOS: ClockPermissions Android kanalına gitmez, fırlatmaz', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final permissions = ClockPermissions();
    // Test hostunda Darwin eklentisi çözülmez → durum bilinmiyor (yalan yok).
    final snapshot = await permissions.snapshot();
    expect(snapshot.availability, ClockPermissionAvailability.unknown);
    expect(await permissions.requestNotifications(), isFalse);
    await permissions.openExactAlarmSettings();
    await permissions.openBatterySettings();
    await permissions.openFullScreenSettings();
  });

  test('iOS anlık görüntüsü yalnız bildirimi sayar', () {
    const missing = ClockPermissionSnapshot.notificationsOnly(
      notifications: false,
    );
    expect(missing.notificationsOnly, isTrue);
    expect(missing.missingCount, 1);
    expect(missing.allOk, isFalse);
    const ok = ClockPermissionSnapshot.notificationsOnly(notifications: true);
    expect(ok.allOk, isTrue);
    expect(ok.missingCount, 0);
    // Android anlık görüntüsü varsayılan olarak dört satırlıdır.
    expect(ClockPermissionSnapshot.ok.notificationsOnly, isFalse);
  });
}
