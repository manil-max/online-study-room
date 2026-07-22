import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:online_study_room/features/clock/clock_screen.dart';
import 'package:online_study_room/features/clock/widgets/standby_clock_view.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';

class MockTimerNotificationService implements TimerNotificationService {
  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();
  Future<void> show(TimerNotificationSnapshot snapshot) async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<void> requestPermissionIfNeeded() async {}
  @override
  Future<void> showRunning(TimerNotificationSnapshot snapshot) async {}
}

class MockStudyTimerNotifier extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await initializeDateFormatting('tr_TR', null);
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
        studyRepositoryProvider.overrideWithValue(InMemoryStudyRepository()),
        timerNotificationServiceProvider.overrideWithValue(
          MockTimerNotificationService(),
        ),
        studyTimerProvider.overrideWith(() => MockStudyTimerNotifier()),
      ],
      child: const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClockScreen(),
      ),
    );
  }

  testWidgets('ClockScreen keeps only Alarm Timer and Tasks in Tools', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.text('Araçlar'), findsOneWidget);
    expect(find.byKey(const Key('clock_tab_alarm')), findsOneWidget);
    expect(find.byKey(const Key('clock_tab_timer')), findsOneWidget);
    expect(find.byKey(const Key('clock_tab_tasks')), findsOneWidget);
    expect(find.byKey(const Key('clock_tab_home')), findsNothing);
    expect(find.byKey(const Key('clock_tab_stopwatch')), findsNothing);
    expect(find.byKey(const Key('clock_tab_world')), findsNothing);
    expect(
      ClockTab.values,
      equals(const [ClockTab.alarm, ClockTab.multiTimer, ClockTab.tasks]),
    );
  });

  testWidgets('ClockScreen shows StandByClockView in landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.byType(StandByClockView), findsOneWidget);
  });
}
