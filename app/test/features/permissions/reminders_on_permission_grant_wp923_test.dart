import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart';
import 'package:online_study_room/core/notifications/reminder_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/time_engine/clock_permissions.dart';
import 'package:online_study_room/features/onboarding/onboarding_screen.dart';
import 'package:online_study_room/features/permissions/notification_auto_ask.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-923: onboarding "İstersen günlük hatırlatma al" diyordu ama izin
/// verilince hiçbir hatırlatma açılmıyordu (seri koruma + haftalık özet
/// varsayılan kapalı). İzin VERİLİNCE ikisi açılır; red hiçbir şeyi
/// değiştirmez; Bildirim Merkezi'nde bilerek kapatılmış tercih ezilmez.
final _en = AppLocalizationsEn();

const _kStreak = NotificationPreferencesNotifier.kSmartStreak;
const _kWeekly = NotificationPreferencesNotifier.kSmartWeekly;

const _denied = ClockPermissionSnapshot(
  availability: ClockPermissionAvailability.available,
  notifications: false,
  exactAlarm: true,
  batteryUnrestricted: false,
  fullScreenIntent: true,
);

const _alreadyGranted = ClockPermissionSnapshot(
  availability: ClockPermissionAvailability.available,
  notifications: true,
  exactAlarm: true,
  batteryUnrestricted: false,
  fullScreenIntent: true,
);

class _FakeReminderService implements ReminderNotificationService {
  _FakeReminderService({required this.grant});

  final bool grant;
  int requests = 0;

  @override
  Future<bool> requestPermissionIfNeeded() async {
    requests++;
    return grant;
  }

  @override
  Future<void> syncSmartReminders(NotificationPreferences prefs) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(ProviderContainer, SharedPreferences)> _container(
  Map<String, Object> initial,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return (container, prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tercih kararı', () {
    test('hiç dokunulmamış tercihler izinle açılır ve kalıcı yazılır', () async {
      final (container, prefs) = await _container({});
      expect(container.read(notificationPreferencesProvider)
          .smartStreakReminderEnabled, isFalse);

      await container
          .read(notificationPreferencesProvider.notifier)
          .enableSmartRemindersAfterPermissionGrant();

      final state = container.read(notificationPreferencesProvider);
      expect(state.smartStreakReminderEnabled, isTrue);
      expect(state.smartWeeklySummaryEnabled, isTrue);
      expect(prefs.getBool(_kStreak), isTrue);
      expect(prefs.getBool(_kWeekly), isTrue);
    });

    test('bilerek kapatılmış tercih EZİLMEZ', () async {
      final (container, prefs) = await _container({_kStreak: false});

      await container
          .read(notificationPreferencesProvider.notifier)
          .enableSmartRemindersAfterPermissionGrant();

      final state = container.read(notificationPreferencesProvider);
      expect(state.smartStreakReminderEnabled, isFalse,
          reason: 'Bildirim Merkezi\'nde kapatılan seri koruma geri açıldı');
      expect(prefs.getBool(_kStreak), isFalse);
      expect(state.smartWeeklySummaryEnabled, isTrue,
          reason: 'dokunulmamış haftalık özet yine açılmalı');
    });

    test('açıldıktan sonra kapatılan tercih ikinci izin olayında açılmaz',
        () async {
      final (container, _) = await _container({});
      final notifier = container.read(notificationPreferencesProvider.notifier);
      await notifier.enableSmartRemindersAfterPermissionGrant();
      await notifier.setSmartWeeklySummaryEnabled(false);

      await notifier.enableSmartRemindersAfterPermissionGrant();

      expect(container.read(notificationPreferencesProvider)
          .smartWeeklySummaryEnabled, isFalse);
    });
  });

  group('otomatik soru (WP-848 yolu)', () {
    Future<int> ask({
      required ClockPermissionSnapshot snapshot,
      required bool grant,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var granted = 0;
      await maybeAutoAskNotificationPermission(
        prefs: prefs,
        isAndroid: true,
        snapshot: () async => snapshot,
        request: () async => grant,
        onGranted: () async => granted++,
      );
      return granted;
    }

    test('izin verilince onGranted çağrılır', () async {
      expect(await ask(snapshot: _denied, grant: true), 1);
    });

    test('red → çağrılmaz', () async {
      expect(await ask(snapshot: _denied, grant: false), 0);
    });

    test('izin zaten varsa (pencere açılmadı) çağrılmaz', () async {
      expect(await ask(snapshot: _alreadyGranted, grant: true), 0);
    });
  });

  group('onboarding "Bildirimlere izin ver"', () {
    Future<SharedPreferences> tapAllow(
      WidgetTester tester, {
      required bool grant,
      Map<String, Object> initial = const {},
    }) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues(initial);
      final prefs = await SharedPreferences.getInstance();
      final service = _FakeReminderService(grant: grant);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            reminderNotificationServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.onboardingContinue));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.onboardingAllowNotifications));
      await tester.pumpAndSettle();

      expect(service.requests, 1);
      return prefs;
    }

    testWidgets('izin verilince seri koruma ve haftalık özet açılır', (
      tester,
    ) async {
      final prefs = await tapAllow(tester, grant: true);
      expect(prefs.getBool(_kStreak), isTrue);
      expect(prefs.getBool(_kWeekly), isTrue);
    });

    testWidgets('red → tercihler değişmez (kapalı kalır)', (tester) async {
      final prefs = await tapAllow(tester, grant: false);
      expect(prefs.containsKey(_kStreak), isFalse);
      expect(prefs.containsKey(_kWeekly), isFalse);
    });

    testWidgets('önceden kapatılmış seri koruma izinle açılmaz', (
      tester,
    ) async {
      final prefs = await tapAllow(
        tester,
        grant: true,
        initial: {_kStreak: false},
      );
      expect(prefs.getBool(_kStreak), isFalse);
      expect(prefs.getBool(_kWeekly), isTrue);
    });
  });
}
