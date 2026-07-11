
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/timer_preset.dart';
import 'package:online_study_room/data/repositories/local/local_alarm_repository.dart';

void main() {
  late SharedPreferences prefs;
  late LocalAlarmRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = LocalAlarmRepository(prefs);
  });

  group('LocalAlarmRepository', () {
    test('saveAlarm and getAlarms', () async {
      final alarm = AlarmRule(id: '1', hour: 7, minute: 30, label: 'Wake Up');
      await repository.saveAlarm(alarm);

      final alarms = await repository.getAlarms();
      expect(alarms.length, 1);
      expect(alarms.first.id, '1');
      expect(alarms.first.hour, 7);
      expect(alarms.first.label, 'Wake Up');
    });

    test('deleteAlarm', () async {
      final alarm = AlarmRule(id: '1', hour: 7, minute: 30);
      await repository.saveAlarm(alarm);
      await repository.deleteAlarm('1');

      final alarms = await repository.getAlarms();
      expect(alarms.isEmpty, true);
    });

    test('saveTimerInstance and getTimerInstances', () async {
      final inst = TimerInstance(
        id: 't1',
        label: 'Break',
        durationSeconds: 300,
        remainingSeconds: 300,
      );
      await repository.saveTimerInstance(inst);

      final instances = await repository.getTimerInstances();
      expect(instances.length, 1);
      expect(instances.first.id, 't1');
      expect(instances.first.durationSeconds, 300);
      expect(instances.first.status, TimerStateStatus.initial);
    });
  });
}
