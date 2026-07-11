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
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';

class MockTimerNotificationService implements TimerNotificationService {
  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();
  @override
  Future<void> show(TimerNotificationSnapshot snapshot) async {}
  @override
  Future<void> cancel() async {}
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
        timerNotificationServiceProvider.overrideWithValue(MockTimerNotificationService()),
        studyTimerProvider.overrideWith(() => MockStudyTimerNotifier()),
      ],
      child: const MaterialApp(
        home: ClockScreen(),
      ),
    );
  }

  testWidgets('ClockScreen renders segments and switches views', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 2560);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(buildApp());

    await tester.pump(); // periyodik Timer yüzünden pumpAndSettle timeout olabilir

    expect(find.text('Saat'), findsWidgets);
    expect(find.text('Kronometre'), findsWidgets);
    expect(find.text('Timer'), findsWidgets);
    expect(find.text('Odak'), findsWidgets);

    // Kronometre segmentine tıkla
    await tester.tap(find.text('Kronometre').last);
    await tester.pump();

    // StudyTimerCard ekranda olmalı
    expect(find.byType(StudyTimerCard), findsOneWidget);

    // Saat sekmesine geri dön
    await tester.tap(find.text('Saat').last);
    await tester.pump();
    expect(find.byType(StudyTimerCard), findsNothing);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('ClockScreen shows StandByClockView in landscape', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(buildApp());

    await tester.pump();

    // Landscape olduğu için direkt StandByClockView render edilmeli
    expect(find.byType(StandByClockView), findsOneWidget);
    // Portre UI widget'ları olmamalı
    expect(find.text('Kronometre'), findsNothing);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
