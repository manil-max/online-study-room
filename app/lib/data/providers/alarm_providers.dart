import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/alarm_notification_service.dart';
import '../../core/prefs/app_prefs.dart';
import '../../core/time_engine/alarm_scheduler.dart';
import '../../core/time_engine/epoch_clock.dart';
import '../../core/time_engine/epoch_countdown.dart';
import '../../core/time_engine/epoch_stopwatch.dart';
import '../../core/time_engine/exact_alarm_permission.dart';
import '../models/alarm_rule.dart';
import '../models/timer_preset.dart';
import '../repositories/alarm_repository.dart';
import '../repositories/local/local_alarm_repository.dart';

final alarmRepositoryProvider = Provider<AlarmRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalAlarmRepository(prefs);
});

final epochClockProvider = Provider<EpochClock>((ref) => const SystemEpochClock());

// ─── Exact alarm izin durumu ───────────────────────────────────────────────

final exactAlarmStatusProvider =
    FutureProvider<ExactAlarmStatus>((ref) async {
  return ref.watch(alarmNotificationServiceProvider).exactAlarmStatus();
});

// ─── Alarms ────────────────────────────────────────────────────────────────

final alarmsProvider =
    AsyncNotifierProvider<AlarmsNotifier, List<AlarmRule>>(AlarmsNotifier.new);

class AlarmsNotifier extends AsyncNotifier<List<AlarmRule>> {
  @override
  FutureOr<List<AlarmRule>> build() async {
    final repo = ref.watch(alarmRepositoryProvider);
    final list = await repo.getAlarms();
    list.sort((a, b) {
      final c = a.hour.compareTo(b.hour);
      return c != 0 ? c : a.minute.compareTo(b.minute);
    });
    return list;
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
    await ref.read(alarmNotificationServiceProvider).cancelAlarm(id);
    ref.invalidateSelf();
  }

  Future<void> toggleAlarm(String id, bool isActive) async {
    final alarms = state.value ?? [];
    final index = alarms.indexWhere((e) => e.id == id);
    if (index < 0) return;
    await saveAlarm(alarms[index].copyWith(isActive: isActive));
  }

  /// Bir sonraki occurrence'ı atla (veya skip'i temizle).
  Future<void> skipNext(String id, {required bool skip}) async {
    final alarms = state.value ?? [];
    final index = alarms.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final alarm = alarms[index];
    final now = ref.read(epochClockProvider).nowDateTime();
    final updated = skip
        ? alarm.copyWith(skipNextOn: AlarmScheduler.skipTargetDate(alarm, now))
        : alarm.copyWith(clearSkipNextOn: true);
    await saveAlarm(updated);
  }

  Future<void> rescheduleAll() async {
    final alarms = state.value ?? await future;
    await ref.read(alarmNotificationServiceProvider).rescheduleAll(alarms);
  }
}

// ─── Timer Presets ─────────────────────────────────────────────────────────

final timerPresetsProvider =
    AsyncNotifierProvider<TimerPresetsNotifier, List<TimerPreset>>(
  TimerPresetsNotifier.new,
);

class TimerPresetsNotifier extends AsyncNotifier<List<TimerPreset>> {
  @override
  FutureOr<List<TimerPreset>> build() async {
    final repo = ref.watch(alarmRepositoryProvider);
    var list = await repo.getTimerPresets();
    if (list.isEmpty) {
      for (final p in defaultTimerPresets()) {
        await repo.saveTimerPreset(p);
      }
      list = defaultTimerPresets();
    }
    return list;
  }

  Future<void> savePreset(TimerPreset preset) async {
    await ref.read(alarmRepositoryProvider).saveTimerPreset(preset);
    ref.invalidateSelf();
  }

  Future<void> deletePreset(String id) async {
    await ref.read(alarmRepositoryProvider).deleteTimerPreset(id);
    ref.invalidateSelf();
  }
}

// ─── Multi-timer instances (epoch) ─────────────────────────────────────────

final timerInstancesProvider =
    AsyncNotifierProvider<TimerInstancesNotifier, List<TimerInstance>>(
  TimerInstancesNotifier.new,
);

class TimerInstancesNotifier extends AsyncNotifier<List<TimerInstance>> {
  Timer? _ticker;
  final Set<String> _doneNotified = {};

  @override
  FutureOr<List<TimerInstance>> build() async {
    final repo = ref.watch(alarmRepositoryProvider);
    final clock = ref.watch(epochClockProvider);
    final nowMs = clock.nowMs();
    final raw = await repo.getTimerInstances();

    final adjusted = raw.map((inst) {
      if (inst.status != TimerStateStatus.running) return inst;
      final rem = inst.remainingAt(nowMs);
      if (rem <= 0) {
        return inst.copyWith(
          remainingSeconds: 0,
          status: TimerStateStatus.done,
          lastUpdatedAt: clock.nowDateTime(),
          clearEndsAt: true,
        );
      }
      // endsAt yoksa lastUpdated + remaining'den türet (eski kayıt göçü)
      if (inst.endsAtEpochMs == null) {
        return inst.copyWith(
          endsAtEpochMs: nowMs + rem * 1000,
          remainingSeconds: rem,
          lastUpdatedAt: clock.nowDateTime(),
        );
      }
      return inst.copyWith(
        remainingSeconds: rem,
        lastUpdatedAt: clock.nowDateTime(),
      );
    }).toList();

    for (final inst in adjusted) {
      if (inst.status == TimerStateStatus.done &&
          raw.any((r) => r.id == inst.id && r.status == TimerStateStatus.running)) {
        unawaited(
          ref.read(alarmNotificationServiceProvider).showImmediate(
                'Zamanlayıcı',
                '${inst.label} süresi doldu!',
              ),
        );
      }
      unawaited(repo.saveTimerInstance(inst));
    }

    _startTicker();
    ref.onDispose(() => _ticker?.cancel());
    return adjusted;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final list = state.value;
      if (list == null) return;
      final clock = ref.read(epochClockProvider);
      final nowMs = clock.nowMs();
      var changed = false;
      final updated = list.map((inst) {
        if (inst.status != TimerStateStatus.running) return inst;
        final rem = inst.remainingAt(nowMs);
        if (rem <= 0) {
          changed = true;
          if (!_doneNotified.contains(inst.id)) {
            _doneNotified.add(inst.id);
            unawaited(
              ref.read(alarmNotificationServiceProvider).showImmediate(
                    'Zamanlayıcı',
                    '${inst.label} süresi doldu!',
                  ),
            );
            unawaited(
              ref.read(alarmNotificationServiceProvider).cancelAlarm(inst.id),
            );
            unawaited(
              ref.read(alarmRepositoryProvider).saveTimerInstance(
                    inst.copyWith(
                      remainingSeconds: 0,
                      status: TimerStateStatus.done,
                      lastUpdatedAt: clock.nowDateTime(),
                      clearEndsAt: true,
                    ),
                  ),
            );
          }
          return inst.copyWith(
            remainingSeconds: 0,
            status: TimerStateStatus.done,
            lastUpdatedAt: clock.nowDateTime(),
            clearEndsAt: true,
          );
        }
        if (rem != inst.remainingSeconds) {
          changed = true;
          return inst.copyWith(remainingSeconds: rem);
        }
        return inst;
      }).toList();
      if (changed) state = AsyncData(updated);
    });
  }

  Future<void> addFromPreset(TimerPreset preset, {bool autoStart = true}) async {
    final clock = ref.read(epochClockProvider);
    final nowMs = clock.nowMs();
    var inst = TimerInstance(
      id: 't_${nowMs}_${preset.id}',
      presetId: preset.id,
      label: preset.label,
      durationSeconds: preset.durationSeconds,
      remainingSeconds: preset.durationSeconds,
      status: TimerStateStatus.initial,
      lastUpdatedAt: clock.nowDateTime(),
      colorHex: preset.colorHex,
      iconCode: preset.iconCode,
    );
    if (autoStart) {
      final c = EpochCountdownState.initial(preset.durationSeconds * 1000)
          .start(nowMs);
      inst = inst.syncedWith(c, nowMs);
    }
    await ref.read(alarmRepositoryProvider).saveTimerInstance(inst);
    if (inst.status == TimerStateStatus.running) {
      await ref.read(alarmNotificationServiceProvider).scheduleTimer(inst);
    }
    _doneNotified.remove(inst.id);
    ref.invalidateSelf();
  }

  Future<void> addCustom({
    required String label,
    required int durationSeconds,
    String? colorHex,
    bool autoStart = true,
  }) async {
    final preset = TimerPreset(
      id: 'custom',
      label: label,
      durationSeconds: durationSeconds,
      colorHex: colorHex,
    );
    await addFromPreset(preset, autoStart: autoStart);
  }

  Future<void> pauseInstance(String id) async {
    await _mutate(id, (inst, nowMs) {
      final c = inst.countdown.pause(nowMs);
      return inst.syncedWith(c, nowMs).copyWith(
            status: TimerStateStatus.paused,
            clearEndsAt: true,
          );
    });
  }

  Future<void> resumeInstance(String id) async {
    await _mutate(id, (inst, nowMs) {
      final base = EpochCountdownState(
        durationMs: inst.durationSeconds * 1000,
        remainingMsWhenPaused: inst.remainingSeconds * 1000,
        running: false,
      ).start(nowMs);
      return inst.syncedWith(base, nowMs);
    });
  }

  Future<void> stopInstance(String id) async {
    await _mutate(id, (inst, nowMs) {
      return inst.copyWith(
        status: TimerStateStatus.initial,
        remainingSeconds: inst.durationSeconds,
        lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
        clearEndsAt: true,
      );
    });
  }

  Future<void> addMinute(String id, {int minutes = 1}) async {
    await _mutate(id, (inst, nowMs) {
      final c = inst.countdown.addSeconds(minutes * 60, nowMs);
      final next = inst
          .copyWith(durationSeconds: (c.durationMs / 1000).round())
          .syncedWith(c, nowMs);
      return next;
    });
  }

  Future<void> deleteInstance(String id) async {
    await ref.read(alarmRepositoryProvider).deleteTimerInstance(id);
    await ref.read(alarmNotificationServiceProvider).cancelAlarm(id);
    _doneNotified.remove(id);
    ref.invalidateSelf();
  }

  Future<void> _mutate(
    String id,
    TimerInstance Function(TimerInstance inst, int nowMs) fn,
  ) async {
    final list = state.value ?? [];
    final index = list.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final nowMs = ref.read(epochClockProvider).nowMs();
    var inst = fn(list[index], nowMs);
    await ref.read(alarmRepositoryProvider).saveTimerInstance(inst);
    if (inst.status == TimerStateStatus.running) {
      await ref.read(alarmNotificationServiceProvider).scheduleTimer(inst);
    } else {
      await ref.read(alarmNotificationServiceProvider).cancelAlarm(inst.id);
    }
    ref.invalidateSelf();
  }
}

// ─── Lap stopwatch (WP-60) ─────────────────────────────────────────────────

final stopwatchProvider =
    NotifierProvider<StopwatchNotifier, EpochStopwatchState>(
  StopwatchNotifier.new,
);

class StopwatchNotifier extends Notifier<EpochStopwatchState> {
  static const _prefsKey = 'clock_stopwatch_state_v1';

  @override
  EpochStopwatchState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        return EpochStopwatchState.fromMap(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    return EpochStopwatchState.idle;
  }

  Future<void> _persist() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_prefsKey, jsonEncode(state.toMap()));
  }

  int get nowMs => ref.read(epochClockProvider).nowMs();

  void start() {
    state = state.start(nowMs);
    unawaited(_persist());
  }

  void pause() {
    state = state.pause(nowMs);
    unawaited(_persist());
  }

  void toggle() {
    state = state.toggle(nowMs);
    unawaited(_persist());
  }

  void reset() {
    state = state.reset();
    unawaited(_persist());
  }

  void lap() {
    state = state.lap(nowMs);
    unawaited(_persist());
  }
}

// ─── World clock cities ────────────────────────────────────────────────────

final worldCitiesProvider =
    NotifierProvider<WorldCitiesNotifier, List<({String label, String tz})>>(
  WorldCitiesNotifier.new,
);

class WorldCitiesNotifier
    extends Notifier<List<({String label, String tz})>> {
  static const _key = 'world_clock_cities_v1';

  @override
  List<({String label, String tz})> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getStringList(_key);
    if (raw == null || raw.isEmpty) {
      return const [
        (label: 'Londra', tz: 'Europe/London'),
        (label: 'New York', tz: 'America/New_York'),
        (label: 'Tokyo', tz: 'Asia/Tokyo'),
        (label: 'Dubai', tz: 'Asia/Dubai'),
      ];
    }
    return raw.map((e) {
      final parts = e.split('|');
      return (label: parts[0], tz: parts.length > 1 ? parts[1] : parts[0]);
    }).toList();
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(
      _key,
      state.map((e) => '${e.label}|${e.tz}').toList(),
    );
  }

  Future<void> add(String label, String tzId) async {
    if (state.any((e) => e.tz == tzId)) return;
    state = [...state, (label: label, tz: tzId)];
    await _save();
  }

  Future<void> remove(String tzId) async {
    state = state.where((e) => e.tz != tzId).toList();
    await _save();
  }
}
