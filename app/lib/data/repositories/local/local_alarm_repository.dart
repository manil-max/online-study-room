import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/timer_preset.dart';
import 'package:online_study_room/data/repositories/alarm_repository.dart';

class LocalAlarmRepository implements AlarmRepository {
  LocalAlarmRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _alarmsKey = 'local_alarms';
  static const String _presetsKey = 'local_timer_presets';
  static const String _instancesKey = 'local_timer_instances';

  @override
  Future<List<AlarmRule>> getAlarms() async {
    final data = _prefs.getStringList(_alarmsKey);
    if (data == null) return [];
    
    return data.map((e) => AlarmRule.fromMap(jsonDecode(e))).toList();
  }

  @override
  Future<void> saveAlarm(AlarmRule alarm) async {
    final alarms = await getAlarms();
    final index = alarms.indexWhere((e) => e.id == alarm.id);
    if (index >= 0) {
      alarms[index] = alarm;
    } else {
      alarms.add(alarm);
    }
    await _prefs.setStringList(_alarmsKey, alarms.map((e) => jsonEncode(e.toMap())).toList());
  }

  @override
  Future<void> deleteAlarm(String id) async {
    final alarms = await getAlarms();
    alarms.removeWhere((e) => e.id == id);
    await _prefs.setStringList(_alarmsKey, alarms.map((e) => jsonEncode(e.toMap())).toList());
  }

  @override
  Future<List<TimerPreset>> getTimerPresets() async {
    final data = _prefs.getStringList(_presetsKey);
    if (data == null) return [];
    
    return data.map((e) => TimerPreset.fromMap(jsonDecode(e))).toList();
  }

  @override
  Future<void> saveTimerPreset(TimerPreset preset) async {
    final presets = await getTimerPresets();
    final index = presets.indexWhere((e) => e.id == preset.id);
    if (index >= 0) {
      presets[index] = preset;
    } else {
      presets.add(preset);
    }
    await _prefs.setStringList(_presetsKey, presets.map((e) => jsonEncode(e.toMap())).toList());
  }

  @override
  Future<void> deleteTimerPreset(String id) async {
    final presets = await getTimerPresets();
    presets.removeWhere((e) => e.id == id);
    await _prefs.setStringList(_presetsKey, presets.map((e) => jsonEncode(e.toMap())).toList());
  }

  @override
  Future<List<TimerInstance>> getTimerInstances() async {
    final data = _prefs.getStringList(_instancesKey);
    if (data == null) return [];
    
    return data.map((e) => TimerInstance.fromMap(jsonDecode(e))).toList();
  }

  @override
  Future<void> saveTimerInstance(TimerInstance instance) async {
    final instances = await getTimerInstances();
    final index = instances.indexWhere((e) => e.id == instance.id);
    if (index >= 0) {
      instances[index] = instance;
    } else {
      instances.add(instance);
    }
    await _prefs.setStringList(_instancesKey, instances.map((e) => jsonEncode(e.toMap())).toList());
  }

  @override
  Future<void> deleteTimerInstance(String id) async {
    final instances = await getTimerInstances();
    instances.removeWhere((e) => e.id == id);
    await _prefs.setStringList(_instancesKey, instances.map((e) => jsonEncode(e.toMap())).toList());
  }
}
