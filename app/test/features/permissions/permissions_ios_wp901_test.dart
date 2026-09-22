// WP-901 — iOS: İzinler ekranı yalnız bildirim satırını gösterir; otomatik
// bildirim sorusu iOS'ta da "bir kez sor, asla ısrar etme" kuralıyla çalışır.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';
import 'package:online_study_room/features/permissions/notification_auto_ask.dart';
import 'package:online_study_room/features/permissions/permissions_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _tr = AppLocalizationsTr();

Widget _app(Widget home) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

class _FakeIosDevice {
  bool granted = false;
  int requests = 0;
  bool userAllows = false;

  Future<ClockPermissionSnapshot> snapshot() async =>
      ClockPermissionSnapshot.notificationsOnly(notifications: granted);

  Future<bool> request() async {
    requests++;
    granted = userAllows;
    return userAllows;
  }
}

Future<bool> _askIos(
  SharedPreferences prefs,
  _FakeIosDevice device, {
  bool deferred = false,
}) => maybeAutoAskNotificationPermission(
  prefs: prefs,
  isAndroid: false,
  isIos: true,
  deferredThisSession: deferred,
  snapshot: device.snapshot,
  request: device.request,
);

Future<SharedPreferences> _prefs() {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  tearDown(() {
    ClockPermissions.debugSnapshotOverride = null;
    debugNotificationAutoAskIsAndroid = null;
    debugNotificationAutoAskIsIos = null;
  });

  group('iOS otomatik bildirim sorusu', () {
    test('ilk açılışta bir kez sorar; retten sonra bir daha sormaz', () async {
      final prefs = await _prefs();
      final device = _FakeIosDevice();

      expect(await _askIos(prefs, device), isTrue);
      expect(device.requests, 1);
      expect(notificationAutoAskDone(prefs), isTrue);

      expect(await _askIos(prefs, device), isFalse);
      expect(device.requests, 1);
    });

    test('izin zaten açıksa pencere açılmaz', () async {
      final prefs = await _prefs();
      final device = _FakeIosDevice()..granted = true;
      expect(await _askIos(prefs, device), isFalse);
      expect(device.requests, 0);
    });

    test(
      'onboarding "Şimdi değil": bu açılışta sormaz, bayrak yazmaz',
      () async {
        final prefs = await _prefs();
        final device = _FakeIosDevice();
        expect(await _askIos(prefs, device, deferred: true), isFalse);
        expect(device.requests, 0);
        expect(notificationAutoAskDone(prefs), isFalse);
      },
    );

    test('masaüstünde (iOS/Android değil) hâlâ hiç sormaz', () async {
      final prefs = await _prefs();
      final device = _FakeIosDevice();
      final asked = await maybeAutoAskNotificationPermission(
        prefs: prefs,
        isAndroid: false,
        snapshot: device.snapshot,
        request: device.request,
      );
      expect(asked, isFalse);
      expect(device.requests, 0);
      expect(notificationAutoAskDone(prefs), isFalse);
    });

    test('provider masaüstünde prefs okumadan döner (iOS tohumu false)', () {
      debugNotificationAutoAskIsAndroid = false;
      debugNotificationAutoAskIsIos = false;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        () => container.read(notificationAutoAskProvider),
        returnsNormally,
      );
    });
  });

  group('iOS İzinler ekranı', () {
    testWidgets('yalnız bildirim satırı; Android satırları ve ipucu yok', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      ClockPermissions.debugSnapshotOverride =
          const ClockPermissionSnapshot.notificationsOnly(notifications: false);
      await tester.pumpWidget(_app(const PermissionsScreen()));
      await tester.pump();

      expect(
        find.byKey(const Key('permission-row-notifications')),
        findsOneWidget,
      );
      expect(find.text(_tr.permissionsStatusMissing), findsOneWidget);
      expect(find.byKey(const Key('permission-row-exact-alarm')), findsNothing);
      expect(find.byKey(const Key('permission-row-battery')), findsNothing);
      expect(find.byKey(const Key('permission-row-full-screen')), findsNothing);
      expect(find.byKey(const Key('permissions-revoke-hint')), findsNothing);
      expect(find.text(_tr.permissionsBatteryTitle), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android anlık görüntüsü dört satırı korur', (tester) async {
      ClockPermissions.debugSnapshotOverride = ClockPermissionSnapshot.ok;
      await tester.pumpWidget(_app(const PermissionsScreen()));
      await tester.pump();
      for (final key in [
        'permission-row-notifications',
        'permission-row-exact-alarm',
        'permission-row-battery',
        'permission-row-full-screen',
        'permissions-revoke-hint',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
    });
  });
}
