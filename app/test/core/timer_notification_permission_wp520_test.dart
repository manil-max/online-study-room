import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';

/// WP-520: bildirim izni diyaloğu açıkken ikinci `Başlat`.
///
/// Sahada olan: kullanıcı hızlıca iki kez başlatıyor, ikinci izin isteği
/// Android tarafında `permissionRequestInProgress` ile reddediliyor ve
/// yakalanmamış `PlatformException` düşüyor. Bu dosya iki şeyi ölçer:
/// (a) diyalog açıkken ikinci çağrı platforma İKİNCİ kez gitmez,
/// (b) platform yine de hata fırlatırsa çağıran hata almaz, normal tamamlanır.
const MethodChannel _channel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;

  int permissionCalls() =>
      calls.where((m) => m == 'requestNotificationsPermission').length;

  void mockPlatform(Future<Object?> Function(MethodCall call) onPermission) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call.method);
          if (call.method == 'requestNotificationsPermission') {
            return onPermission(call);
          }
          // `initialize` bool döndürmek zorunda; launch details boş olabilir.
          if (call.method == 'getNotificationAppLaunchDetails') return null;
          return true;
        });
  }

  setUp(() {
    calls = <String>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // Platform implementasyonu kayıtlı olmazsa
    // `resolvePlatformSpecificImplementation` null döner ve test hiçbir şey
    // ölçmez.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('izin diyaloğu açıkken ikinci istek platforma gitmez', () async {
    final dialog = Completer<bool>();
    mockPlatform((_) => dialog.future);
    final service = TimerNotificationService.forTest();

    final first = service.requestPermissionIfNeeded();
    await pumpEventQueue();
    expect(permissionCalls(), 1, reason: 'ilk basış izin diyaloğunu açar');

    // Diyalog hâlâ açık (dialog tamamlanmadı) — ikinci `Başlat`.
    final second = service.requestPermissionIfNeeded();
    await pumpEventQueue();
    expect(
      permissionCalls(),
      1,
      reason: 'ikinci basış platforma ikinci istek göndermemeli',
    );

    dialog.complete(true);
    // İkisi de hata değil, normal tamamlanır (ikincisi ilkin sonucunu paylaşır).
    await expectLater(first, completes);
    await expectLater(second, completes);
  });

  test('platform PlatformException fırlatınca çağıran hata almaz', () async {
    mockPlatform(
      (_) => throw PlatformException(
        code: 'permissionRequestInProgress',
        message: 'Another permission request is already in progress',
      ),
    );
    final service = TimerNotificationService.forTest();

    // Yakalanmamış PlatformException yerine sessiz/normal tamamlanma.
    await expectLater(service.requestPermissionIfNeeded(), completes);
    expect(permissionCalls(), 1);
  });

  test('başarısız istekten sonra bir sonraki başlatma yeniden dener', () async {
    var fail = true;
    mockPlatform((_) async {
      if (fail) {
        throw PlatformException(code: 'permissionRequestInProgress');
      }
      return true;
    });
    final service = TimerNotificationService.forTest();

    await expectLater(service.requestPermissionIfNeeded(), completes);
    fail = false;
    await expectLater(service.requestPermissionIfNeeded(), completes);
    // Kilit açılmadıysa burada 1'de kalırdı: izin bir daha hiç istenmezdi.
    expect(permissionCalls(), 2);
  });
}
