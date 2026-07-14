import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/alarm_rule.dart';
import '../../data/models/timer_preset.dart';
import '../l10n/system_localizations.dart';
import '../time_engine/alarm_scheduler.dart';

/// Flutter → Kotlin native AlarmManager köprüsü.
class NativeAlarmBridge {
  NativeAlarmBridge({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.manilmax.online_study_room/exact_alarm');

  static final instance = NativeAlarmBridge();

  final MethodChannel _channel;

  bool get _android => !kIsWeb && Platform.isAndroid;

  static const mirrorAlarmsKey = 'native_alarm_mirror_v1';
  static const mirrorTimersKey = 'native_timer_mirror_v1';
  static const pendingRingKey = 'clock_pending_ring_v1';
  static const reschedulePendingKey = 'clock_reschedule_pending';

  Future<void> scheduleAlarm(AlarmRule alarm, DateTime now) async {
    if (!_android) return;
    if (!alarm.isActive) {
      await cancel(kind: 'alarm', id: alarm.id);
      return;
    }
    final next = AlarmScheduler.nextFire(alarm, now);
    if (next == null) {
      await cancel(kind: 'alarm', id: alarm.id);
      return;
    }
    final l10n = await loadSystemLocalizations();
    try {
      await _channel.invokeMethod<void>('scheduleAlarm', {
        'id': alarm.id,
        'triggerAtMs': next.millisecondsSinceEpoch,
        'label': alarm.label.isNotEmpty ? alarm.label : l10n.coreAlarm,
        'hour': alarm.hour,
        'minute': alarm.minute,
        'crescendo': alarm.crescendo,
        'vibrate': alarm.vibrate,
        'antiSnooze': alarm.antiSnooze,
        'snoozeMin': alarm.snoozeMinutes,
      });
    } catch (_) {
      /* test / web */
    }
  }

  Future<void> scheduleTimer(TimerInstance instance, int nowMs) async {
    if (!_android) return;
    if (instance.status != TimerStateStatus.running) {
      await cancel(kind: 'timer', id: instance.id);
      return;
    }
    final ends =
        instance.endsAtEpochMs ?? (nowMs + instance.remainingAt(nowMs) * 1000);
    if (ends <= nowMs) {
      await cancel(kind: 'timer', id: instance.id);
      return;
    }
    try {
      await _channel.invokeMethod<void>('scheduleTimer', {
        'id': instance.id,
        'triggerAtMs': ends,
        'label': instance.label,
      });
    } catch (_) {}
  }

  Future<void> cancel({required String kind, required String id}) async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('cancel', {'kind': kind, 'id': id});
    } catch (_) {}
  }

  Future<void> rescheduleFromMirror() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('rescheduleFromMirror');
    } catch (_) {}
  }

  Future<void> previewRing(AlarmRule alarm) async {
    if (!_android) return;
    final l10n = await loadSystemLocalizations();
    try {
      await _channel.invokeMethod<void>('previewRing', {
        'id': alarm.id,
        'label': alarm.label.isNotEmpty ? alarm.label : l10n.coreAlarm,
        'hour': alarm.hour,
        'minute': alarm.minute,
        'crescendo': alarm.crescendo,
        'vibrate': alarm.vibrate,
        'antiSnooze': alarm.antiSnooze,
        'snoozeMin': alarm.snoozeMinutes,
      });
    } catch (_) {}
  }

  /// SharedPreferences mirror — boot receiver bunu okur.
  Future<void> writeAlarmMirror(
    SharedPreferences prefs,
    List<AlarmRule> alarms,
    DateTime now,
  ) async {
    final l10n = await loadSystemLocalizations();
    final list = <Map<String, dynamic>>[];
    for (final a in alarms) {
      if (!a.isActive) continue;
      final next = AlarmScheduler.nextFire(a, now);
      if (next == null) continue;
      list.add({
        'id': a.id,
        'active': true,
        'triggerAtMs': next.millisecondsSinceEpoch,
        'label': a.label.isNotEmpty ? a.label : l10n.coreAlarm,
        'hour': a.hour,
        'minute': a.minute,
        'crescendo': a.crescendo,
        'vibrate': a.vibrate,
        'antiSnooze': a.antiSnooze,
        'snoozeMin': a.snoozeMinutes,
      });
    }
    await prefs.setString(mirrorAlarmsKey, jsonEncode(list));
  }

  Future<void> writeTimerMirror(
    SharedPreferences prefs,
    List<TimerInstance> instances,
    int nowMs,
  ) async {
    final list = <Map<String, dynamic>>[];
    for (final t in instances) {
      if (t.status != TimerStateStatus.running) continue;
      final ends = t.endsAtEpochMs ?? (nowMs + t.remainingAt(nowMs) * 1000);
      if (ends <= nowMs) continue;
      list.add({'id': t.id, 'label': t.label, 'endsAtMs': ends});
    }
    await prefs.setString(mirrorTimersKey, jsonEncode(list));
  }

  /// Cold-start: native ring bıraktıysa payload.
  Map<String, dynamic>? consumePendingRing(SharedPreferences prefs) {
    final raw = prefs.getString(pendingRingKey);
    if (raw == null || raw.isEmpty) return null;
    prefs.remove(pendingRingKey);
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool consumeRescheduleFlag(SharedPreferences prefs) {
    final v = prefs.getBool(reschedulePendingKey) ?? false;
    if (v) prefs.setBool(reschedulePendingKey, false);
    return v;
  }
}
