import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/clock/alarms_screen.dart';
import 'package:online_study_room/core/notifications/alarm_notification_service.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';

class MockAlarmNotificationService implements AlarmNotificationService {
  @override
  Future<void> scheduleAlarm(AlarmRule alarm) async {}
  @override
  Future<void> cancelAlarm(String id) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;
  late MockAlarmNotificationService mockService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockService = MockAlarmNotificationService();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        alarmNotificationServiceProvider.overrideWithValue(mockService),
      ],
      child: const MaterialApp(
        home: AlarmsScreen(),
      ),
    );
  }

  testWidgets('AlarmsScreen shows empty state initially', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Kişisel Alarmlar'), findsOneWidget);
    expect(find.text('Henüz bir alarm oluşturmadınız.'), findsOneWidget);
  });

  testWidgets('AlarmsScreen can add a new alarm', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Tap add button
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Time picker should appear
    expect(find.text('OK'), findsOneWidget);

    // Tap OK to confirm time
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // List should no longer be empty
    expect(find.text('Henüz bir alarm oluşturmadınız.'), findsNothing);
    expect(find.text('Yeni Alarm'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });
}
