import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/timer_preset.dart';
import 'package:online_study_room/data/repositories/alarm_repository.dart';

class InMemoryAlarmRepository implements AlarmRepository {
  final Map<String, AlarmRule> _alarms = {};
  final Map<String, TimerPreset> _presets = {};
  final Map<String, TimerInstance> _instances = {};

  @override
  Future<void> deleteAlarm(String id) async {
    _alarms.remove(id);
  }

  @override
  Future<void> deleteTimerInstance(String id) async {
    _instances.remove(id);
  }

  @override
  Future<void> deleteTimerPreset(String id) async {
    _presets.remove(id);
  }

  @override
  Future<List<AlarmRule>> getAlarms() async {
    return _alarms.values.toList();
  }

  @override
  Future<List<TimerInstance>> getTimerInstances() async {
    return _instances.values.toList();
  }

  @override
  Future<List<TimerPreset>> getTimerPresets() async {
    return _presets.values.toList();
  }

  @override
  Future<void> saveAlarm(AlarmRule alarm) async {
    _alarms[alarm.id] = alarm;
  }

  @override
  Future<void> saveTimerInstance(TimerInstance instance) async {
    _instances[instance.id] = instance;
  }

  @override
  Future<void> saveTimerPreset(TimerPreset preset) async {
    _presets[preset.id] = preset;
  }
}
