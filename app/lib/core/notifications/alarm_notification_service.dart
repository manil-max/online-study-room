import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/alarm_rule.dart';
import '../../data/models/timer_preset.dart';
import '../time_engine/alarm_scheduler.dart';
import '../time_engine/exact_alarm_permission.dart';

final alarmNotificationServiceProvider = Provider<AlarmNotificationService>((ref) {
  return AlarmNotificationService.instance;
});

/// Kişisel alarm + çoklu timer bildirim planlayıcı (WP-58/59).
///
/// Exact alarm mümkünse `exactAllowWhileIdle`; değilse inexact + [lastUsedExact]
/// bayrağı false (UI uyarı gösterebilir).
class AlarmNotificationService {
  AlarmNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    ExactAlarmPermission? exactPermission,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _exact = exactPermission ?? ExactAlarmPermission();

  static final instance = AlarmNotificationService();

  static const String channelId = 'personal_alarms';
  static const String channelName = 'Alarmlar ve Zamanlayıcılar';
  static const String channelDesc =
      'Kişisel alarm ve çoklu timer bildirimleri (yüksek öncelik)';

  final FlutterLocalNotificationsPlugin _plugin;
  final ExactAlarmPermission _exact;
  bool _initialized = false;

  /// Son planlamada exact kullanıldı mı?
  bool lastUsedExact = true;

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    // Yerel TZ: cihaz ofsetine en yakın sabit yoksa UTC; Flutter genelde
    // local DateTime kullanır — zonedSchedule için local location set.
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {
      /* test ortamı */
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    _initialized = true;
  }

  Future<AndroidScheduleMode> _mode() async {
    if (kIsWeb) {
      lastUsedExact = false;
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    final mode = await _exact.scheduleMode();
    lastUsedExact = mode == AndroidScheduleMode.exactAllowWhileIdle;
    return mode;
  }

  AndroidNotificationDetails _alarmDetails(AlarmRule alarm) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: alarm.vibrate,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction('alarm_dismiss', 'Kapat'),
        AndroidNotificationAction('alarm_snooze', 'Ertele'),
      ],
    );
  }

  Future<void> scheduleAlarm(AlarmRule alarm) async {
    await initialize();

    if (!alarm.isActive) {
      await cancelAlarm(alarm.id);
      return;
    }

    final now = DateTime.now();
    final next = AlarmScheduler.nextFire(alarm, now);
    if (next == null) {
      await cancelAlarm(alarm.id);
      return;
    }

    final scheduled = tz.TZDateTime.from(next, tz.local);
    final mode = await _mode();

    await _plugin.zonedSchedule(
      id: _notifId(alarm.id),
      title: alarm.label.isNotEmpty ? alarm.label : 'Alarm',
      body: 'Saat ${alarm.timeLabel} — Odak Kampı',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(android: _alarmDetails(alarm)),
      androidScheduleMode: mode,
      // Tekrarlayan alarmlar için haftanın günü bileşeni; tek seferlik null.
      matchDateTimeComponents: alarm.days.isNotEmpty
          ? DateTimeComponents.dayOfWeekAndTime
          : null,
      payload: 'alarm:${alarm.id}',
    );
  }

  Future<void> cancelAlarm(String id) async {
    await initialize();
    await _plugin.cancel(id: _notifId(id));
  }

  Future<void> rescheduleAll(List<AlarmRule> alarms) async {
    for (final a in alarms) {
      await scheduleAlarm(a);
    }
  }

  Future<void> scheduleTimer(TimerInstance instance) async {
    await initialize();

    if (instance.status != TimerStateStatus.running) {
      await cancelAlarm(instance.id);
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final remainingSec = instance.remainingAt(nowMs);
    if (remainingSec <= 0) {
      await cancelAlarm(instance.id);
      return;
    }

    final scheduled =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: remainingSec));
    final mode = await _mode();

    final details = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );

    await _plugin.zonedSchedule(
      id: _notifId(instance.id),
      title: 'Zamanlayıcı bitti',
      body: instance.label,
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(android: details),
      androidScheduleMode: mode,
      payload: 'timer:${instance.id}',
    );
  }

  Future<void> showImmediate(String title, String body) async {
    await initialize();
    final details = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    );
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
    );
  }

  Future<ExactAlarmStatus> exactAlarmStatus() => _exact.status();

  Future<bool> requestExactAlarmPermission() => _exact.request();

  int _notifId(String id) => id.hashCode & 0x7fffffff;
}
