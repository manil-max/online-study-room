import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/timer_preset.dart';

/// Alarm ve Timer verileri için temel repository arayüzü.
abstract class AlarmRepository {
  // --- Alarms ---
  
  /// Kayıtlı tüm alarmları getirir.
  Future<List<AlarmRule>> getAlarms();
  
  /// Bir alarmı kaydeder veya günceller.
  Future<void> saveAlarm(AlarmRule alarm);
  
  /// Bir alarmı siler.
  Future<void> deleteAlarm(String id);

  // --- Timer Presets ---
  
  /// Kayıtlı timer önayarlarını getirir.
  Future<List<TimerPreset>> getTimerPresets();
  
  /// Bir timer önayarını kaydeder veya günceller.
  Future<void> saveTimerPreset(TimerPreset preset);
  
  /// Bir timer önayarını siler.
  Future<void> deleteTimerPreset(String id);

  // --- Timer Instances (Active/Paused Timers) ---
  
  /// Son bırakılan/çalışan timer durumlarını getirir.
  Future<List<TimerInstance>> getTimerInstances();
  
  /// Bir timer durumunu günceller.
  Future<void> saveTimerInstance(TimerInstance instance);
  
  /// Bir timer durumunu siler (örn. süre bittiğinde veya kullanıcı kapattığında).
  Future<void> deleteTimerInstance(String id);
}
