import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';

/// WP-563: **sayaç bildiriminin metnini Dart üretmez.**
///
/// WP-134-137 SSOT geçişinden sonra kullanıcının gördüğü canlı sayaç bildirimi
/// foreground service'in TEK bildirimidir (`StudyTimerService.kt`). Dart
/// tarafındaki `showRunning` / `TimerNotificationSnapshot` yolu o günden beri
/// hiçbir üretim çağrısı olmadan duruyordu; testi vardı ve yeşildi, ama
/// sahadaki bildirimle ilgisi yoktu (false-green). WP-563 o yüzeyi sildi.
///
/// Bu dosya yüzeyin geri doğmasını engeller. İki bağımsız kapı:
///
/// 1. **Derleme zamanı:** [_ExhaustiveGateway] arayüzün TAMAMINI kapsar.
///    Arayüze bildirim gösteren bir üye eklenirse bu sınıf soyut üyeyi
///    gerçeklemediği için dosya DERLENMEZ.
/// 2. **Kaynak taraması:** somut servis dosyasında bildirim gösteren hiçbir
///    çağrı/inşa bulunmamalı. (1. kapı yalnız arayüzü görür; birisi sadece
///    somut sınıfa metot eklerse bunu bu kapı yakalar.)
///
/// Kasıtlı yanlış girdiyle sınandı: arayüze sahte bir `showRunning`
/// eklendiğinde 1. kapı derleme hatasıyla, servise `_plugin.show(...)`
/// eklendiğinde 2. kapı `expect` hatasıyla KIRMIZIya döndü.
class _ExhaustiveGateway implements TimerNotificationGateway {
  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();

  @override
  Future<void> requestPermissionIfNeeded() async {}

  @override
  Future<void> cancel() async {}
}

const _servicePath = 'lib/core/notifications/timer_notification_service.dart';

/// Yorum satırları ayıklanmış kaynak: kapı prozayı değil KODU ölçer.
String _serviceCode() {
  final source = File(_servicePath).readAsStringSync();
  return source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  test('kapi gercekten dosyayi goruyor (bos yere yesil kalmasin)', () {
    expect(
      File(_servicePath).existsSync(),
      isTrue,
      reason: '$_servicePath bulunamadi — kapi hicbir sey olcmuyor',
    );
    expect(_serviceCode(), contains('class TimerNotificationService'));
  });

  test('gateway yuzeyi yalniz komut/izin/iptal — gosterme yolu yok', () {
    // Derleme zamani iddiasi: _ExhaustiveGateway arayuzun tamamini kapsar.
    // Arayuze yeni bir soyut uye eklenirse bu dosya derlenmez.
    final container = ProviderContainer(
      overrides: [
        timerNotificationServiceProvider.overrideWithValue(
          _ExhaustiveGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final gateway = container.read(timerNotificationServiceProvider);
    expect(gateway, isA<TimerNotificationGateway>());
    // Uc canli yuzey de calisir durumda.
    expect(gateway.commands, isA<Stream<TimerNotificationAction>>());
    expect(gateway.requestPermissionIfNeeded(), completes);
    expect(gateway.cancel(), completes);
  });

  test('servis dosyasi bildirim GOSTERMEZ', () {
    final code = _serviceCode();

    // `show` ailesinin tamami: `_plugin.show(`, `showRunning`, `showWhen:`,
    // `showProgress:`, `showsUserInterface:` ... hicbiri olmamali.
    expect(
      code.toLowerCase(),
      isNot(contains('show')),
      reason:
          'Dart tarafi sayac bildirimi gostermemeli — bildirimi Kotlin '
          '(StudyTimerService.kt) uretir; ikisi birden gosterirse cift '
          'bildirim cikar ve metin iki kaynaktan uretilir.',
    );

    // Bildirim icerigini insa eden tipler de bulunmamali.
    for (final forbidden in const [
      'AndroidNotificationDetails',
      'NotificationDetails(',
      'AndroidNotificationAction',
      'TimerNotificationSnapshot',
    ]) {
      expect(
        code,
        isNot(contains(forbidden)),
        reason: '$forbidden bildirim icerigi uretir — bu dosyaya ait degil',
      );
    }
  });

  test('eski 7001 bildirimini iptal etme yolu KORUNUR', () {
    final code = _serviceCode();
    // Eski surumden guncelleyen cihazda tepside asili kalmis
    // flutter_local_notifications bildirimini temizleyen tek yol budur.
    expect(code, contains('static const int _notificationId = 7001;'));
    expect(code, contains('_plugin.cancel(id: _notificationId)'));
  });

  test('lib/ icinde showRunning cagrisi kalmadi', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    expect(
      dartFiles.length,
      greaterThan(100),
      reason: 'tarama dosya gormuyor — kapi bos',
    );

    final offenders = dartFiles
        .where((f) => f.readAsStringSync().contains('showRunning'))
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toList();

    expect(offenders, isEmpty);
  });
}
