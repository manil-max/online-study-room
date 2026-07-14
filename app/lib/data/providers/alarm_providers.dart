import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/alarm_notification_service.dart';
import '../../core/notifications/native_alarm_bridge.dart';
import '../../core/l10n/system_localizations.dart';
import '../../core/prefs/app_prefs.dart';
import '../../core/time_engine/alarm_scheduler.dart';
import '../../core/time_engine/clock_study_recorder.dart';
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

final epochClockProvider = Provider<EpochClock>(
  (ref) => const SystemEpochClock(),
);

// ─── Exact alarm izin durumu ───────────────────────────────────────────────

final exactAlarmStatusProvider = FutureProvider<ExactAlarmStatus>((ref) async {
  return ref.watch(alarmNotificationServiceProvider).exactAlarmStatus();
});

// ─── Alarms ────────────────────────────────────────────────────────────────

final alarmsProvider = AsyncNotifierProvider<AlarmsNotifier, List<AlarmRule>>(
  AlarmsNotifier.new,
);

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
    // Alarm kaydı öncesi bildirim izni (Android 13+) — sessizce dene
    try {
      // ignore: avoid_dynamic_calls
      await ref.read(alarmNotificationServiceProvider).exactAlarmStatus();
    } catch (_) {}
    final repo = ref.read(alarmRepositoryProvider);
    await repo.saveAlarm(alarm);
    await _syncNative();
    ref.invalidateSelf();
  }

  Future<void> deleteAlarm(String id) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.deleteAlarm(id);
    await ref.read(alarmNotificationServiceProvider).cancelAlarm(id);
    await _syncNative();
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
    await _syncNative();
  }

  /// Mirror + her aktif alarm için native schedule (boot dayanıklı).
  Future<void> _syncNative() async {
    final repo = ref.read(alarmRepositoryProvider);
    final alarms = await repo.getAlarms();
    final now = ref.read(epochClockProvider).nowDateTime();
    final prefs = ref.read(sharedPreferencesProvider);
    final svc = ref.read(alarmNotificationServiceProvider);
    await NativeAlarmBridge.instance.writeAlarmMirror(prefs, alarms, now);
    await svc.rescheduleAll(alarms, prefs: prefs, now: now);
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
    final l10n = await loadSystemLocalizations();
    var list = await repo.getTimerPresets();
    final localizedDefaults = defaultTimerPresets(l10n);
    if (list.isEmpty) {
      for (final p in localizedDefaults) {
        await repo.saveTimerPreset(p);
      }
      list = localizedDefaults;
    } else {
      final defaultsById = {for (final p in localizedDefaults) p.id: p};
      list = [
        for (final preset in list)
          defaultsById[preset.id] == null
              ? preset
              : preset.copyWith(label: defaultsById[preset.id]!.label),
      ];
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

  /// Çalışma süresine yazılmış timer id'leri (çift XP/oturum engeli).
  final Set<String> _studyCredited = {};

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
          raw.any(
            (r) => r.id == inst.id && r.status == TimerStateStatus.running,
          )) {
        // Native ring zaten çalmış olabilir; UI yedek bildirimi
        unawaited(_showTimerDone(inst));
        // Tamamlanan süre → çalışma oturumu
        unawaited(_creditTimerStudy(inst, fullDuration: true));
      }
      unawaited(repo.saveTimerInstance(inst));
    }

    // Process death: çalışan timer'ları native AlarmManager'a yaz
    unawaited(_syncTimerNative(adjusted));

    _startTicker();
    ref.onDispose(() => _ticker?.cancel());
    return adjusted;
  }

  Future<void> _syncTimerNative(List<TimerInstance> list) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final nowMs = ref.read(epochClockProvider).nowMs();
    final svc = ref.read(alarmNotificationServiceProvider);
    await NativeAlarmBridge.instance.writeTimerMirror(prefs, list, nowMs);
    for (final inst in list) {
      if (inst.status == TimerStateStatus.running) {
        await svc.scheduleTimer(inst, prefs: prefs);
      } else {
        await svc.cancelTimer(inst.id);
      }
    }
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
            unawaited(_showTimerDone(inst));
            unawaited(
              ref.read(alarmNotificationServiceProvider).cancelTimer(inst.id),
            );
            final done = inst.copyWith(
              remainingSeconds: 0,
              status: TimerStateStatus.done,
              lastUpdatedAt: clock.nowDateTime(),
              clearEndsAt: true,
            );
            unawaited(
              ref.read(alarmRepositoryProvider).saveTimerInstance(done),
            );
            unawaited(_creditTimerStudy(done, fullDuration: true));
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
      if (changed) {
        state = AsyncData(updated);
        unawaited(_syncTimerNative(updated));
      }
    });
  }

  Future<void> addFromPreset(
    TimerPreset preset, {
    bool autoStart = true,
  }) async {
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
      final c = EpochCountdownState.initial(
        preset.durationSeconds * 1000,
      ).start(nowMs);
      inst = inst.syncedWith(c, nowMs);
    }
    await ref.read(alarmRepositoryProvider).saveTimerInstance(inst);
    final all = await ref.read(alarmRepositoryProvider).getTimerInstances();
    await _syncTimerNative(all);
    _doneNotified.remove(inst.id);
    ref.invalidateSelf();
  }

  Future<void> _showTimerDone(TimerInstance instance) async {
    final l10n = await loadSystemLocalizations();
    await ref
        .read(alarmNotificationServiceProvider)
        .showImmediate(
          l10n.coreZamanlayiciBitti,
          '${instance.label} · ${l10n.homeBitti}',
        );
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
    // Pause çalışma kaydı yazmaz; süre bitince veya Stop/Sil'de yazılır.
    await _mutate(id, (inst, nowMs) {
      final c = inst.countdown.pause(nowMs);
      return inst
          .syncedWith(c, nowMs)
          .copyWith(status: TimerStateStatus.paused, clearEndsAt: true);
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
    final before = state.value?.where((e) => e.id == id).firstOrNull;
    if (before != null &&
        (before.status == TimerStateStatus.running ||
            before.status == TimerStateStatus.paused ||
            before.status == TimerStateStatus.done)) {
      final nowMs = ref.read(epochClockProvider).nowMs();
      final rem = before.status == TimerStateStatus.running
          ? before.remainingAt(nowMs)
          : before.remainingSeconds;
      final elapsed = (before.durationSeconds - rem).clamp(
        0,
        before.durationSeconds,
      );
      if (before.status == TimerStateStatus.done) {
        unawaited(_creditTimerStudy(before, fullDuration: true));
      } else if (elapsed > 0) {
        unawaited(
          _creditTimerStudy(
            before.copyWith(remainingSeconds: rem),
            fullDuration: false,
            elapsedOverride: elapsed,
          ),
        );
      }
    }
    await _mutate(id, (inst, nowMs) {
      return inst.copyWith(
        status: TimerStateStatus.initial,
        remainingSeconds: inst.durationSeconds,
        lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
        clearEndsAt: true,
      );
    });
    // Sıfırlandıktan sonra tekrar kullanılabilsin
    _studyCredited.remove(id);
    _doneNotified.remove(id);
  }

  /// Timer süresini çalışma oturumuna yaz.
  Future<void> _creditTimerStudy(
    TimerInstance inst, {
    required bool fullDuration,
    int? elapsedOverride,
  }) async {
    if (_studyCredited.contains(inst.id)) return;
    final seconds =
        elapsedOverride ??
        (fullDuration
            ? inst.durationSeconds
            : (inst.durationSeconds - inst.remainingSeconds).clamp(
                0,
                inst.durationSeconds,
              ));
    if (seconds < ClockStudyRecorder.minDurationSeconds) return;
    _studyCredited.add(inst.id);
    final ok = await ref
        .read(clockStudyRecorderProvider)
        .recordDuration(durationSeconds: seconds);
    if (!ok) {
      // Giriş yok / çok kısa → tekrar denenebilsin
      _studyCredited.remove(inst.id);
    }
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
    final before = state.value?.where((e) => e.id == id).firstOrNull;
    if (before != null &&
        before.status != TimerStateStatus.initial &&
        !_studyCredited.contains(id)) {
      final nowMs = ref.read(epochClockProvider).nowMs();
      final rem = before.status == TimerStateStatus.running
          ? before.remainingAt(nowMs)
          : before.remainingSeconds;
      final elapsed = before.status == TimerStateStatus.done
          ? before.durationSeconds
          : (before.durationSeconds - rem).clamp(0, before.durationSeconds);
      unawaited(
        _creditTimerStudy(
          before,
          fullDuration: before.status == TimerStateStatus.done,
          elapsedOverride: elapsed,
        ),
      );
    }
    await ref.read(alarmRepositoryProvider).deleteTimerInstance(id);
    await ref.read(alarmNotificationServiceProvider).cancelTimer(id);
    _doneNotified.remove(id);
    _studyCredited.remove(id);
    final all = await ref.read(alarmRepositoryProvider).getTimerInstances();
    await _syncTimerNative(all);
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
    final inst = fn(list[index], nowMs);
    await ref.read(alarmRepositoryProvider).saveTimerInstance(inst);
    final all = await ref.read(alarmRepositoryProvider).getTimerInstances();
    final merged = <TimerInstance>[
      for (final t in all)
        if (t.id == inst.id) inst else t,
    ];
    if (!merged.any((t) => t.id == inst.id)) {
      merged.add(inst);
    }
    await _syncTimerNative(merged);
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
  static const _creditedKey = 'clock_stopwatch_study_credited_ms';

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

  int get _creditedMs =>
      ref.read(sharedPreferencesProvider).getInt(_creditedKey) ?? 0;

  Future<void> _setCreditedMs(int ms) async {
    await ref.read(sharedPreferencesProvider).setInt(_creditedKey, ms);
  }

  /// Henüz çalışma kaydına yazılmamış süreyi yaz (pause / reset).
  Future<void> _creditUnrecordedStudy() async {
    final elapsed = state.elapsedMs(nowMs);
    final already = _creditedMs;
    final deltaMs = elapsed - already;
    if (deltaMs < ClockStudyRecorder.minDurationSeconds * 1000) return;
    final sec = deltaMs ~/ 1000;
    final ok = await ref
        .read(clockStudyRecorderProvider)
        .recordDuration(durationSeconds: sec);
    if (ok) {
      await _setCreditedMs(already + sec * 1000);
    }
  }

  void start() {
    state = state.start(nowMs);
    unawaited(_persist());
  }

  void pause() {
    state = state.pause(nowMs);
    unawaited(_persist());
    unawaited(_creditUnrecordedStudy());
  }

  void toggle() {
    final wasRunning = state.running;
    state = state.toggle(nowMs);
    unawaited(_persist());
    if (wasRunning && !state.running) {
      unawaited(_creditUnrecordedStudy());
    }
  }

  void reset() {
    // Sıfırlamadan önce kalan süreyi yaz
    if (state.running) {
      state = state.pause(nowMs);
    }
    unawaited(() async {
      await _creditUnrecordedStudy();
      state = state.reset();
      await _setCreditedMs(0);
      await _persist();
    }());
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

class WorldCitiesNotifier extends Notifier<List<({String label, String tz})>> {
  static const _key = 'world_clock_cities_v1';

  @override
  List<({String label, String tz})> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getStringList(_key);
    if (raw == null || raw.isEmpty) {
      return const [
        (label: 'London', tz: 'Europe/London'),
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
