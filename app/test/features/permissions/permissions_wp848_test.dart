// WP-848 — IZINLER: otomatik sistem penceresi + ayri "Izinler" ekrani.
//
// Sahip: "Uygulamayi yeni acan biri icin uygulama izinleri kendisi otomatik
// istemeli ... yoksa bildirim merkezinden ayrilsin, izin yeri ayarlarda daha
// rahat gorulsun."
//
// Olculen uc sey:
//   1. Otomatik soru BIR KEZ sorulur; Android disinda hic, retten sonra bir
//      daha hic sorulmaz.
//   2. Izinler ekrani her satirin durumunu gercek anlik goruntuden okur.
//   3. Bildirim Merkezi izinleri artik yalniz BAGLANTI olarak tasir.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';
import 'package:online_study_room/features/notifications/notification_center_screen.dart';
import 'package:online_study_room/features/permissions/notification_auto_ask.dart';
import 'package:online_study_room/features/permissions/permissions_screen.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _tr = AppLocalizationsTr();

ClockPermissionSnapshot _snapshot({
  bool notifications = false,
  bool exactAlarm = true,
  bool battery = false,
  bool fullScreen = true,
}) => ClockPermissionSnapshot(
  availability: ClockPermissionAvailability.available,
  notifications: notifications,
  exactAlarm: exactAlarm,
  batteryUnrestricted: battery,
  fullScreenIntent: fullScreen,
);

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// Otomatik sorunun sahte platformu: kac kez soruldugunu sayar.
class _FakeDevice {
  _FakeDevice(this.current);

  ClockPermissionSnapshot current;
  int requests = 0;

  /// Kullanici pencerede ne diyecek.
  bool userAllows = false;

  Future<ClockPermissionSnapshot> snapshot() async => current;

  Future<bool> request() async {
    requests++;
    if (userAllows) current = _snapshot(notifications: true);
    return userAllows;
  }
}

Future<bool> _ask(
  SharedPreferences prefs,
  _FakeDevice device, {
  bool isAndroid = true,
}) => maybeAutoAskNotificationPermission(
  prefs: prefs,
  isAndroid: isAndroid,
  snapshot: device.snapshot,
  request: device.request,
);

Widget _app(Widget home, {List overrides = const []}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  tearDown(() {
    ClockPermissions.debugSnapshotOverride = null;
    debugNotificationAutoAskIsAndroid = null;
  });

  group('otomatik bildirim izni sorusu', () {
    test(
      'ilk kabuk acilisinda bir kez sorar, ikinci acilista sormaz',
      () async {
        final prefs = await _prefs();
        final device = _FakeDevice(_snapshot());

        expect(await _ask(prefs, device), isTrue);
        expect(device.requests, 1);
        expect(prefs.getBool(kNotificationAutoAskKey), isTrue);

        expect(await _ask(prefs, device), isFalse);
        expect(device.requests, 1, reason: 'Ayni soru ikinci kez soruldu.');
      },
    );

    test('kullanici reddettiyse bir daha kendiliginden sorulmaz', () async {
      final prefs = await _prefs();
      final device = _FakeDevice(_snapshot())..userAllows = false;

      await _ask(prefs, device);
      // Ret sonrasi izin hala yok; uygulama tekrar tekrar acilir.
      for (var open = 0; open < 3; open++) {
        expect(await _ask(prefs, device), isFalse);
      }
      expect(device.requests, 1);
    });

    test('Android disinda hic sormaz ve bayrak yazmaz', () async {
      final prefs = await _prefs();
      final device = _FakeDevice(_snapshot());

      expect(await _ask(prefs, device, isAndroid: false), isFalse);
      expect(device.requests, 0);
      expect(prefs.getBool(kNotificationAutoAskKey), isNull);
    });

    test(
      'izin zaten varsa (Android 12 ve alti dahil) pencere acilmaz',
      () async {
        final prefs = await _prefs();
        final device = _FakeDevice(_snapshot(notifications: true));

        expect(await _ask(prefs, device), isFalse);
        expect(device.requests, 0);
        // Sonradan kapatan kullaniciya da kendiliginden sorulmaz.
        expect(prefs.getBool(kNotificationAutoAskKey), isTrue);
      },
    );

    test('durum okunamazsa sormaz ve sonraki acilisa birakir', () async {
      final prefs = await _prefs();
      final device = _FakeDevice(ClockPermissionSnapshot.unknown);

      expect(await _ask(prefs, device), isFalse);
      expect(device.requests, 0);
      expect(prefs.getBool(kNotificationAutoAskKey), isNull);

      device.current = _snapshot();
      expect(await _ask(prefs, device), isTrue);
      expect(device.requests, 1);
    });

    test('onboarding dugmesi soruyu kullandiysa kabuk tekrar sormaz', () async {
      final prefs = await _prefs();
      await markNotificationAutoAskDone(prefs);
      final device = _FakeDevice(_snapshot());

      expect(await _ask(prefs, device), isFalse);
      expect(device.requests, 0);
    });

    test('provider masaustunde prefs bile okumadan doner', () {
      debugNotificationAutoAskIsAndroid = false;
      // `sharedPreferencesProvider` ezilmedi: okunsaydi UnimplementedError.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        () => container.read(notificationAutoAskProvider),
        returnsNormally,
      );
    });

    test('ana kabuk otomatik soruyu izliyor', () {
      // Tetik yeri: `HomeShell.build` → `ref.watch(notificationAutoAskProvider)`.
      // Kabuk yalniz oturum acik + onboarding bitmis kullaniciya cizilir.
      final source = File(
        'lib/core/navigation/home_shell.dart',
      ).readAsStringSync();
      expect(source, contains('ref.watch(notificationAutoAskProvider)'));
    });
  });

  group('Izinler ekrani', () {
    testWidgets('her satir durumunu anlik goruntuden okur', (tester) async {
      ClockPermissions.debugSnapshotOverride = _snapshot(
        notifications: false,
        exactAlarm: true,
        battery: false,
        fullScreen: true,
      );
      await tester.pumpWidget(_app(const PermissionsScreen()));
      await tester.pump();

      String statusOf(String key) {
        final row = find.byKey(Key(key));
        expect(row, findsOneWidget, reason: key);
        final granted = find.descendant(
          of: row,
          matching: find.text(_tr.permissionsStatusGranted),
        );
        final missing = find.descendant(
          of: row,
          matching: find.text(_tr.permissionsStatusMissing),
        );
        if (granted.evaluate().isNotEmpty) return 'granted';
        if (missing.evaluate().isNotEmpty) return 'missing';
        return 'none';
      }

      expect(statusOf('permission-row-notifications'), 'missing');
      expect(statusOf('permission-row-exact-alarm'), 'granted');
      expect(statusOf('permission-row-battery'), 'missing');
      expect(statusOf('permission-row-full-screen'), 'granted');

      // Her satir "yoksa ne bozulur" cumlesini tasir.
      for (final impact in [
        _tr.permissionsNotificationsImpact,
        _tr.permissionsExactAlarmImpact,
        _tr.permissionsBatteryImpact,
        _tr.permissionsFullScreenImpact,
      ]) {
        expect(find.text(impact), findsOneWidget);
      }
    });

    testWidgets('uygulamaya donunce durum yeniden okunur', (tester) async {
      ClockPermissions.debugSnapshotOverride = _snapshot(exactAlarm: false);
      await tester.pumpWidget(_app(const PermissionsScreen()));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('permission-row-exact-alarm')),
          matching: find.text(_tr.permissionsStatusMissing),
        ),
        findsOneWidget,
      );

      // Kullanici sistem sayfasinda izni verip geri geldi.
      ClockPermissions.debugSnapshotOverride = _snapshot(exactAlarm: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('permission-row-exact-alarm')),
          matching: find.text(_tr.permissionsStatusGranted),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Android disinda tek sade satir gosterir', (tester) async {
      ClockPermissions.debugSnapshotOverride =
          ClockPermissionSnapshot.unsupported;
      await tester.pumpWidget(_app(const PermissionsScreen()));
      await tester.pump();

      expect(find.text(_tr.permissionsNotNeeded), findsOneWidget);
      expect(
        find.byKey(const Key('permission-row-notifications')),
        findsNothing,
      );
    });

    testWidgets('durum okunamazsa "hepsi eksik" demez', (tester) async {
      ClockPermissions.debugSnapshotOverride = ClockPermissionSnapshot.unknown;
      await tester.pumpWidget(_app(const PermissionsScreen()));
      await tester.pump();

      expect(find.byKey(const Key('permissions-unknown')), findsOneWidget);
      expect(find.text(_tr.permissionsStatusMissing), findsNothing);
    });
  });

  group('baglantilar', () {
    testWidgets('Bildirim Merkezi izinleri yalniz baglanti olarak tasir', (
      tester,
    ) async {
      ClockPermissions.debugSnapshotOverride = _snapshot();
      final prefs = await _prefs();
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        _app(
          const NotificationCenterScreen(),
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('notification-open-permissions')));
      await tester.pumpAndSettle();

      expect(find.byType(PermissionsScreen), findsOneWidget);
      expect(find.byKey(const Key('permission-row-battery')), findsOneWidget);
    });

    testWidgets('Ayarlar izinleri kendi satirinda gosterir', (tester) async {
      ClockPermissions.debugSnapshotOverride = _snapshot();
      final prefs = await _prefs();
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        _app(
          const SettingsScreen(),
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        ),
      );
      await tester.pump();

      final row = find.byKey(const Key('settings-permissions'));
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(PermissionsScreen), findsOneWidget);
    });
  });
}
