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
import 'package:online_study_room/features/clock/stopwatch_screen.dart';
import 'package:online_study_room/features/clock/widgets/standby_clock_view.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
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

  testWidgets('ClockScreen renders Saat Merkezi segments', (tester) async {
    tester.view.physicalSize = const Size(1440, 2560);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.text('Saat Merkezi'), findsOneWidget);
    expect(find.byType(SegmentedButton<ClockTab>), findsOneWidget);

    // Segment ikonları mevcut (6 alan)
    expect(find.byIcon(Icons.schedule), findsWidgets);
    expect(find.byIcon(Icons.public), findsWidgets);
    expect(find.byIcon(Icons.alarm), findsWidgets);
    expect(find.byIcon(Icons.hourglass_empty), findsWidgets);
    expect(find.byIcon(Icons.timer_outlined), findsWidgets);
    expect(find.byIcon(Icons.av_timer), findsWidgets);
  });

  testWidgets('Odak tab shows StudyTimerCard; Kronometre is separate',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 2560);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    // Odak: çalışma sayacı
    await tester.ensureVisible(find.byKey(const Key('clock_tab_focus')));
    await tester.tap(find.byKey(const Key('clock_tab_focus')));
    await tester.pump();
    expect(find.byType(StudyTimerCard), findsOneWidget);

    // Kronometre: ayrı motor (StudyTimerCard yok)
    await tester.ensureVisible(find.byKey(const Key('clock_tab_stopwatch')));
    await tester.tap(find.byKey(const Key('clock_tab_stopwatch')));
    await tester.pump();
    expect(find.byType(StudyTimerCard), findsNothing);
    expect(find.byType(StopwatchScreen), findsOneWidget);
  });

  testWidgets('ClockScreen shows StandByClockView in landscape', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.byType(StandByClockView), findsOneWidget);
    expect(find.byType(SegmentedButton<ClockTab>), findsNothing);
  });
}
