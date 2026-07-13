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
        timerNotificationServiceProvider
            .overrideWithValue(MockTimerNotificationService()),
        studyTimerProvider.overrideWith(() => MockStudyTimerNotifier()),
      ],
      child: const MaterialApp(
        home: ClockScreen(),
      ),
    );
  }

  testWidgets('ClockScreen shows 5 equal strip tabs without Widget tab',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.text('Saat Merkezi'), findsOneWidget);
    expect(find.text('Widget'), findsNothing);
    expect(find.byKey(const Key('clock_tab_widgets')), findsNothing);
    expect(find.text('Saat'), findsOneWidget);
    expect(find.text('Alarm'), findsOneWidget);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Krono'), findsOneWidget);
    expect(find.text('Dünya'), findsOneWidget);
    // Birleşik çalışma kartı ana Saat sekmesinde
    expect(find.text('Çalışma oturumu'), findsOneWidget);
  });

  testWidgets('ClockScreen shows StandByClockView in landscape', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.byType(StandByClockView), findsOneWidget);
  });
}
