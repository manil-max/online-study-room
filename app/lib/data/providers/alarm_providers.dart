import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/timer_preset.dart';
import 'package:online_study_room/data/repositories/alarm_repository.dart';
import 'package:online_study_room/data/repositories/local/local_alarm_repository.dart';
import 'package:online_study_room/core/notifications/alarm_notification_service.dart';

final alarmRepositoryProvider = Provider<AlarmRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalAlarmRepository(prefs);
});

// --- Alarms ---

final alarmsProvider = AsyncNotifierProvider<AlarmsNotifier, List<AlarmRule>>(() {
  return AlarmsNotifier();
});

class AlarmsNotifier extends AsyncNotifier<List<AlarmRule>> {
  @override
  FutureOr<List<AlarmRule>> build() async {
    final repo = ref.watch(alarmRepositoryProvider);
    return repo.getAlarms();
  }

  Future<void> saveAlarm(AlarmRule alarm) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.saveAlarm(alarm);
    await ref.read(alarmNotificationServiceProvider).scheduleAlarm(alarm);
    ref.invalidateSelf();
  }

  Future<void> deleteAlarm(String id) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.deleteAlarm(id);
    await AlarmNotificationService.instance.cancelAlarm(id);
    ref.invalidateSelf();
  }

  Future<void> toggleAlarm(String id, bool isActive) async {
    final alarms = state.value ?? [];
    final index = alarms.indexWhere((e) => e.id == id);
    if (index >= 0) {
      final updated = alarms[index].copyWith(isActive: isActive);
      await saveAlarm(updated);
    }
  }
}

// --- Timer Presets ---

final timerPresetsProvider = AsyncNotifierProvider<TimerPresetsNotifier, List<TimerPreset>>(() {
  return TimerPresetsNotifier();
});

class TimerPresetsNotifier extends AsyncNotifier<List<TimerPreset>> {
  @override
  FutureOr<List<TimerPreset>> build() async {
    final repo = ref.watch(alarmRepositoryProvider);
    return repo.getTimerPresets();
  }

  Future<void> savePreset(TimerPreset preset) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.saveTimerPreset(preset);
    ref.invalidateSelf();
  }

  Future<void> deletePreset(String id) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.deleteTimerPreset(id);
    ref.invalidateSelf();
  }
}

// --- Active Timer Instances ---

final timerInstancesProvider = AsyncNotifierProvider<TimerInstancesNotifier, List<TimerInstance>>(() {
  return TimerInstancesNotifier();
});

class TimerInstancesNotifier extends AsyncNotifier<List<TimerInstance>> {
  Timer? _ticker;

  @override
  FutureOr<List<TimerInstance>> build() async {
    final repo = ref.watch(alarmRepositoryProvider);
    final instances = await repo.getTimerInstances();
    
    // Uygulama kapalıyken geçen süreyi hesapla ve güncelle
    final now = DateTime.now();
    final adjusted = instances.map((inst) {
      if (inst.status == TimerStateStatus.running && inst.lastUpdatedAt != null) {
        final diff = now.difference(inst.lastUpdatedAt!).inSeconds;
        final newRemaining = inst.remainingSeconds - diff;
        if (newRemaining <= 0) {
          return inst.copyWith(remainingSeconds: 0, status: TimerStateStatus.done, lastUpdatedAt: now);
        }
        return inst.copyWith(remainingSeconds: newRemaining, lastUpdatedAt: now);
      }
      return inst;
    }).toList();

    _startTicker();
    
    // Eğer değişiklik olduysa arka planda kaydet (UI bloklamamak için async)
    if (instances.toString() != adjusted.toString()) {
      Future.microtask(() async {
        for (final inst in adjusted) {
          await repo.saveTimerInstance(inst);
        }
        ref.invalidateSelf();
      });
    }

    ref.onDispose(() {
      _ticker?.cancel();
    });

    return adjusted;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.value == null) return;
      
      var hasChanges = false;
      final currentList = state.value!;
      final now = DateTime.now();
      
      final updatedList = currentList.map((inst) {
        if (inst.status == TimerStateStatus.running) {
          hasChanges = true;
          final newRemaining = inst.remainingSeconds - 1;
          if (newRemaining <= 0) {
            // Timer bitti
            ref.read(alarmNotificationServiceProvider).showImmediate('Zamanlayıcı', '${inst.label} süresi doldu!');
            return inst.copyWith(remainingSeconds: 0, status: TimerStateStatus.done, lastUpdatedAt: now);
          }
          return inst.copyWith(remainingSeconds: newRemaining, lastUpdatedAt: now);
        }
        return inst;
      }).toList();

      if (hasChanges) {
        state = AsyncData(updatedList);
        // Sürekli repo kaydı yapmak maliyetlidir. Bu MVP'de her tick'te kaydetmiyoruz.
        // Yalnızca state değişimi tetikliyoruz. Pause/Resume/Done anında kaydedeceğiz.
      }
    });
  }

  Future<void> addInstance(TimerInstance instance) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.saveTimerInstance(instance);
    if (instance.status == TimerStateStatus.running) {
      await ref.read(alarmNotificationServiceProvider).scheduleTimer(instance);
    }
    ref.invalidateSelf();
  }

  Future<void> pauseInstance(String id) async {
    await _updateInstanceStatus(id, TimerStateStatus.paused);
  }

  Future<void> resumeInstance(String id) async {
    await _updateInstanceStatus(id, TimerStateStatus.running);
  }

  Future<void> stopInstance(String id) async {
    await _updateInstanceStatus(id, TimerStateStatus.initial);
  }

  Future<void> deleteInstance(String id) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.deleteTimerInstance(id);
    await AlarmNotificationService.instance.cancelAlarm(id);
    ref.invalidateSelf();
  }

  Future<void> _updateInstanceStatus(String id, TimerStateStatus status) async {
    final instances = state.value ?? [];
    final index = instances.indexWhere((e) => e.id == id);
    if (index >= 0) {
      var inst = instances[index];
      if (status == TimerStateStatus.initial) {
        inst = inst.copyWith(status: status, remainingSeconds: inst.durationSeconds, lastUpdatedAt: DateTime.now());
        await ref.read(alarmNotificationServiceProvider).cancelAlarm(inst.id);
      } else {
        inst = inst.copyWith(status: status, lastUpdatedAt: DateTime.now());
        if (status == TimerStateStatus.running) {
          await ref.read(alarmNotificationServiceProvider).scheduleTimer(inst);
        } else if (status == TimerStateStatus.paused || status == TimerStateStatus.done) {
          await ref.read(alarmNotificationServiceProvider).cancelAlarm(inst.id);
        }
      }
      final repo = ref.read(alarmRepositoryProvider);
      await repo.saveTimerInstance(inst);
      ref.invalidateSelf();
    }
  }
}
