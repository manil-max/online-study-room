import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/clock/alarms_screen.dart';
import 'package:online_study_room/core/notifications/alarm_notification_service.dart';
import 'package:online_study_room/core/time_engine/exact_alarm_permission.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/timer_preset.dart';
import 'package:online_study_room/data/providers/alarm_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_alarm_repository.dart';

class MockAlarmNotificationService implements AlarmNotificationService {
  @override
  Future<void> scheduleAlarm(
    AlarmRule alarm, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {}

  @override
  Future<void> cancelAlarm(String id) async {}

  @override
  Future<void> cancelTimer(String id) async {}

  @override
  Future<void> cancelById(String id) async {}

  @override
  Future<void> initialize({
    void Function(NotificationResponse)? onResponse,
  }) async {}

  @override
  Future<void> rescheduleAll(
    List<AlarmRule> alarms, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {}

  @override
  Future<void> scheduleTimer(
    TimerInstance instance, {
    SharedPreferences? prefs,
  }) async {}

  @override
  Future<void> showImmediate(String title, String body) async {}

  @override
  Future<ExactAlarmStatus> exactAlarmStatus() async => ExactAlarmStatus.granted;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<void> previewNativeRing(AlarmRule alarm) async {}

  @override
  bool lastUsedExact = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late SharedPreferences prefs;
  late MockAlarmNotificationService mockService;
  late InMemoryAlarmRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockService = MockAlarmNotificationService();
    repo = InMemoryAlarmRepository();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        alarmNotificationServiceProvider.overrideWithValue(mockService),
        alarmRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: AlarmsScreen(),
      ),
    );
  }

  testWidgets('AlarmsScreen shows empty state initially', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Kişisel Alarmlar'), findsOneWidget);
    expect(find.text('Henüz bir alarm oluşturmadınız.'), findsOneWidget);
  });

  testWidgets('AlarmsScreen lists alarm after repository save', (tester) async {
    await repo.saveAlarm(
      const AlarmRule(
        id: 'test-1',
        hour: 7,
        minute: 30,
        label: 'Sabah',
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Henüz bir alarm oluşturmadınız.'), findsNothing);
    expect(find.text('07:30'), findsOneWidget);
    expect(find.textContaining('Sabah'), findsWidgets);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('AlarmsScreen opens editor sheet', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Yeni alarm'), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);
    expect(find.text('Anti-snooze'), findsOneWidget);
    expect(find.text('Kademeli ses (30 sn)'), findsOneWidget);
  });
}
