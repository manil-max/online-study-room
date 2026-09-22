// WP-907 — Bildirim Merkezi'nin ikinci sekmesi iOS'ta Android widget
// kataloğunu ve "masaüstü" başlığını göstermez; yalnız İzinler ekranına
// giden düğmeyi taşır. Android ve Windows değişmedi.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/clock/clock_widgets_screen.dart';
import 'package:online_study_room/features/notifications/notification_permissions_screen.dart';
import 'package:online_study_room/features/permissions/permissions_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _tr = AppLocalizationsTr();

Future<void> _pumpSecondTab(
  WidgetTester tester, {
  required ClockPermissionSnapshot snapshot,
}) async {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  ClockPermissions.debugSnapshotOverride = snapshot;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = InMemoryAuthRepository();
  addTearDown(repo.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NotificationPermissionsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.security_outlined));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    ClockPermissions.debugSnapshotOverride = null;
  });

  testWidgets(
    'iOS: widget kataloğu ve masaüstü dili yok, İzinler düğmesi var',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await _pumpSecondTab(
        tester,
        snapshot: const ClockPermissionSnapshot.notificationsOnly(
          notifications: true,
        ),
      );

      expect(find.byType(ClockWidgetsScreen), findsNothing);
      expect(
        find.byKey(const Key('notification-ios-permissions-tab')),
        findsOneWidget,
      );
      expect(find.text(_tr.clockMasaustuAndroidIzinBilgisi), findsNothing);
      expect(find.text(_tr.clockMasaustuWidgetVeIzinYok), findsNothing);
      expect(find.text(_tr.clockWidgetVeIzinler), findsNothing);
      expect(find.text(_tr.clockIzinlerYalnizAndroid), findsNothing);

      await tester.tap(
        find.byKey(const Key('notification-ios-open-permissions')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PermissionsScreen), findsOneWidget);
      expect(find.text(_tr.permissionsRevokeHintIos), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('Android: widget sekmesi değişmedi', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _pumpSecondTab(tester, snapshot: ClockPermissionSnapshot.ok);

    expect(find.byType(ClockWidgetsScreen), findsOneWidget);
    expect(
      find.byKey(const Key('notification-ios-permissions-tab')),
      findsNothing,
    );
    expect(find.text(_tr.clockWidgetVeIzinler), findsOneWidget);
    expect(
      find.byKey(const Key('clock_widgets_open_permissions')),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows: masaüstü bilgi sekmesi değişmedi', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await _pumpSecondTab(tester, snapshot: ClockPermissionSnapshot.unsupported);

    expect(find.byType(ClockWidgetsScreen), findsOneWidget);
    expect(
      find.byKey(const Key('notification-ios-permissions-tab')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('clock_widgets_desktop_limit_banner')),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
