import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/core/notifications/native_alarm_bridge.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/timer_preset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeAlarmBridge mirror', () {
    test('writes active alarms with future triggerAtMs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bridge = NativeAlarmBridge.instance;
      final now = DateTime(2026, 7, 13, 10, 0);

      await bridge.writeAlarmMirror(
        prefs,
        [
          const AlarmRule(
            id: 'a1',
            hour: 7,
            minute: 0,
            isActive: true,
            label: 'Sabah',
          ),
          const AlarmRule(
            id: 'a2',
            hour: 22,
            minute: 0,
            isActive: false,
            label: 'Kapalı',
          ),
          const AlarmRule(
            id: 'a3',
            hour: 15,
            minute: 30,
            isActive: true,
            label: 'Öğleden',
          ),
        ],
        now,
      );

      final raw = prefs.getString(NativeAlarmBridge.mirrorAlarmsKey)!;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      // a2 kapalı → yok; a1 yarın 07:00; a3 bugün 15:30
      expect(list.length, 2);
      expect(list.map((e) => e['id']), containsAll(['a1', 'a3']));
      for (final e in list) {
        expect(e['triggerAtMs'], greaterThan(now.millisecondsSinceEpoch));
        expect(e['active'], isTrue);
      }
    });

    test('writes only running timers', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bridge = NativeAlarmBridge.instance;
      final nowMs = DateTime(2026, 7, 13, 12).millisecondsSinceEpoch;

      await bridge.writeTimerMirror(
        prefs,
        [
          TimerInstance(
            id: 't1',
            label: 'Makarna',
            durationSeconds: 600,
            remainingSeconds: 300,
            status: TimerStateStatus.running,
            endsAtEpochMs: nowMs + 300000,
          ),
          TimerInstance(
            id: 't2',
            label: 'Durdu',
            durationSeconds: 600,
            remainingSeconds: 300,
            status: TimerStateStatus.paused,
          ),
        ],
        nowMs,
      );

      final raw = prefs.getString(NativeAlarmBridge.mirrorTimersKey)!;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      expect(list.length, 1);
      expect(list.first['id'], 't1');
      expect(list.first['endsAtMs'], nowMs + 300000);
    });

    test('consumePendingRing clears key', () async {
      SharedPreferences.setMockInitialValues({
        NativeAlarmBridge.pendingRingKey:
            '{"kind":"alarm","id":"x","label":"A","at":1}',
      });
      final prefs = await SharedPreferences.getInstance();
      final bridge = NativeAlarmBridge.instance;
      final once = bridge.consumePendingRing(prefs);
      expect(once?['id'], 'x');
      expect(bridge.consumePendingRing(prefs), isNull);
    });
  });
}
