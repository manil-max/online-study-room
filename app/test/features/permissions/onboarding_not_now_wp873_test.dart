import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';
import 'package:online_study_room/features/onboarding/onboarding_screen.dart';
import 'package:online_study_room/features/permissions/notification_auto_ask.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-873: onboarding'in bildirim sayfasında "Şimdi değil" diyen kullanıcıya
/// kabuğa girer girmez sistem penceresi açılıyordu (WP-848 otomatik soru).
/// Karar: o açılışta sorulmaz, bayrak yazılmaz → bir sonraki açılış bir kez
/// sorar (sahip: "yeni açan birine otomatik sorsun").
final _en = AppLocalizationsEn();

const _denied = ClockPermissionSnapshot(
  availability: ClockPermissionAvailability.available,
  notifications: false,
  exactAlarm: true,
  batteryUnrestricted: false,
  fullScreenIntent: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(debugResetNotificationAutoAskDeferral);

  test('ertelenen açılışta sorulmaz, bayrak yazılmaz; sonraki açılış sorar', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var requests = 0;
    Future<bool> ask({required bool deferred}) =>
        maybeAutoAskNotificationPermission(
          prefs: prefs,
          isAndroid: true,
          deferredThisSession: deferred,
          snapshot: () async => _denied,
          request: () async {
            requests++;
            return false;
          },
        );

    expect(await ask(deferred: true), isFalse);
    expect(requests, 0, reason: '"Şimdi değil" hemen ardından sorulmamalı');
    expect(notificationAutoAskDone(prefs), isFalse,
        reason: 'erteleme kalıcı ret değildir');

    // Bir sonraki açılış.
    expect(await ask(deferred: false), isTrue);
    expect(requests, 1);
    expect(await ask(deferred: false), isFalse);
    expect(requests, 1);
  });

  testWidgets('onboarding "Not now" bu açılış için ertelemeyi işaretler', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(notificationAutoAskDeferredThisSession, isFalse);

    await tester.tap(find.text(_en.onboardingContinue));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_en.onboardingNotNow));
    await tester.pumpAndSettle();

    expect(notificationAutoAskDeferredThisSession, isTrue);
    expect(notificationAutoAskDone(prefs), isFalse);
  });
}
