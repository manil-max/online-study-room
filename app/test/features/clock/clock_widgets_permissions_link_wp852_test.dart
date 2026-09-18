import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';
import 'package:online_study_room/features/clock/clock_widgets_screen.dart';
import 'package:online_study_room/features/permissions/permissions_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-852 (sahip kararı): izinler Bildirim Merkezi'nden ayrılır ve TEK yerde
/// yaşar — Ayarlar → İzinler (`PermissionsScreen`, WP-848).
///
/// Widget sekmesi (`ClockWidgetsScreen`) eskiden dört izin satırını, bir geri
/// alma rehberini, "Eksik izinleri aç" ve "İzinleri yenile" düğmelerini
/// kendisi çiziyordu. Bu dosya yeni biçimi kilitler:
///  * sekmede izin SATIRI yok, yalnız durum özeti var;
///  * tek eylem İzinler ekranını açar;
///  * İzinler ekranından dönünce özet yeniden okunur (`Navigator.pop` bir
///    `resumed` olayı üretmez — ölçülmezse özet eski kalır);
///  * geri alma bilgisi İzinler ekranına taşındı.

const _missing = ClockPermissionSnapshot(
  availability: ClockPermissionAvailability.available,
  notifications: true,
  exactAlarm: false,
  batteryUnrestricted: true,
  fullScreenIntent: false,
);

Future<void> _pump(WidgetTester tester) async {
  // Katalog uzun; ListView görünmeyen çocuğu hiç kurmaz. Alan büyük tutulur
  // ki "satır yok" iddiası bedavaya geçmesin.
  tester.view.physicalSize = const Size(1080, 14000);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClockWidgetsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => ClockPermissions.debugSnapshotOverride = null);

  testWidgets('sekmede izin satırı yok; yalnız özet ve tek düğme', (
    tester,
  ) async {
    // `flutter test` varsayılan platformu android: Android kolu çizilir.
    expect(defaultTargetPlatform, TargetPlatform.android);
    ClockPermissions.debugSnapshotOverride = _missing;
    await _pump(tester);

    expect(find.text('2 izin eksik'), findsOneWidget);
    expect(
      find.byKey(const Key('clock_widgets_open_permissions')),
      findsOneWidget,
    );
    expect(find.text('İzinler ekranını aç'), findsOneWidget);

    // Eski satırların ve düğmelerin hiçbiri kalmadı.
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('Kesin alarm (Exact)'), findsNothing);
    expect(find.text('Pil kısıtlaması yok'), findsNothing);
    expect(find.text('Tam ekran alarm'), findsNothing);
    expect(find.text('İzni geri almak ister misin?'), findsNothing);
    expect(find.textContaining('Eksik izinleri aç'), findsNothing);
    expect(find.text('İzinleri yenile'), findsNothing);
    expect(find.byType(PermissionsScreen), findsNothing);
  });

  test('ekran sistem izin ayarlarını kendisi açmaz (tek yer: İzinler)', () {
    final source = File(
      'lib/features/clock/clock_widgets_screen.dart',
    ).readAsStringSync();
    for (final call in [
      'openNotificationSettings',
      'openExactAlarmSettings',
      'openBatterySettings',
      'openBatteryOptimizationManagementSettings',
      'openFullScreenSettings',
      'requestNotifications',
    ]) {
      expect(
        source.contains(call),
        isFalse,
        reason:
            '$call bu ekranda geri geldi: izinler yine iki yerde '
            'yönetiliyor (WP-852 sahip kararı: yalnız İzinler ekranı).',
      );
    }
  });

  testWidgets('düğme İzinler ekranını açar; dönünce özet yeniden okunur', (
    tester,
  ) async {
    ClockPermissions.debugSnapshotOverride = _missing;
    await _pump(tester);

    await tester.tap(find.byKey(const Key('clock_widgets_open_permissions')));
    await tester.pumpAndSettle();

    expect(find.byType(PermissionsScreen), findsOneWidget);
    expect(find.byKey(const Key('permission-row-exact-alarm')), findsOneWidget);
    // Geri alma bilgisi artık burada (widget sekmesinden taşındı).
    expect(find.byKey(const Key('permissions-revoke-hint')), findsOneWidget);

    // Kullanıcı İzinler ekranında eksikleri verdi ve geri döndü.
    ClockPermissions.debugSnapshotOverride = ClockPermissionSnapshot.ok;
    // `pageBack` İngilizce "Back" ipucunu arar; TR yerelde ipucu farklı,
    // o yüzden AppBar'ın gerçek geri düğmesine basılır (kullanıcının yolu).
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(PermissionsScreen), findsNothing);
    expect(find.text('Tüm izinler tamam'), findsOneWidget);
    expect(find.text('2 izin eksik'), findsNothing);
  });
}
