import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/alarm_rule.dart';
import '../../data/models/timer_preset.dart';
import '../time_engine/alarm_scheduler.dart';
import '../time_engine/device_timezone.dart';
import '../time_engine/exact_alarm_permission.dart';
import 'native_alarm_bridge.dart';

final alarmNotificationServiceProvider = Provider<AlarmNotificationService>((ref) {
  return AlarmNotificationService.instance;
});

/// Alarm/timer planlama: **Android'de native AlarmManager birincil**;
/// FLN yedek/status; masaüstü/web FLN veya no-op.
class AlarmNotificationService {
  AlarmNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    ExactAlarmPermission? exactPermission,
    NativeAlarmBridge? bridge,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _exact = exactPermission ?? ExactAlarmPermission(),
        _bridge = bridge ?? NativeAlarmBridge.instance;

  static final instance = AlarmNotificationService();

  static const String channelId = 'personal_alarms';
  static const String channelName = 'Alarmlar ve Zamanlayıcılar';
  static const String channelDesc =
      'Kişisel alarm ve çoklu timer (yüksek öncelik)';

  final FlutterLocalNotificationsPlugin _plugin;
  final ExactAlarmPermission _exact;
  final NativeAlarmBridge _bridge;
  bool _initialized = false;

  bool lastUsedExact = true;

  bool get _useNative => !kIsWeb && Platform.isAndroid;

  Future<void> initialize({
    void Function(NotificationResponse)? onResponse,
  }) async {
    if (_initialized) return;

    await DeviceTimezone.ensureInitialized();

    // Windows/macOS/Linux: FLN Windows settings zorunlu; Android-only init
    // MissingPlugin/Invalid argument fırlatıp log gürültüsü + boşa iş yapıyordu.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      _initialized = true;
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: alarmNotificationBg,
    );

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

  Future<void> scheduleAlarm(
    AlarmRule alarm, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    await initialize();
    final n = now ?? DateTime.now();

    if (!alarm.isActive) {
      await cancelAlarm(alarm.id);
      return;
    }

    final next = AlarmScheduler.nextFire(alarm, n);
    if (next == null) {
      await cancelAlarm(alarm.id);
      return;
    }

    // Birincil: native exact
    if (_useNative) {
      await _bridge.scheduleAlarm(alarm, n);
      return;
    }

    // Yedek: FLN (masaüstü / native yok)
    final scheduled = tz.TZDateTime.from(next, tz.local);
    final mode = await _mode();
    await _plugin.zonedSchedule(
      id: _notifId(alarm.id),
      title: alarm.label.isNotEmpty ? alarm.label : 'Alarm',
      body: 'Saat ${alarm.timeLabel} — Odak Kampı',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
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
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction('alarm_dismiss', 'Kapat'),
            AndroidNotificationAction('alarm_snooze', 'Ertele'),
          ],
        ),
      ),
      androidScheduleMode: mode,
      // Tek seferlik plan; tekrar native/nextFire ile yeniden kurulur
      // (matchDateTimeComponents skip-next ile çakışır).
      payload: 'alarm:${alarm.id}',
    );
  }

  Future<void> cancelAlarm(String id) async {
    await initialize();
    if (_useNative) {
      await _bridge.cancel(kind: 'alarm', id: id);
    }
    await _plugin.cancel(id: _notifId(id));
  }

  Future<void> rescheduleAll(
    List<AlarmRule> alarms, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    if (prefs != null) {
      await _bridge.writeAlarmMirror(prefs, alarms, n);
    }
    for (final a in alarms) {
      if (!a.isActive) {
        await cancelAlarm(a.id);
      } else {
        await scheduleAlarm(a, prefs: prefs, now: n);
      }
    }
  }

  Future<void> scheduleTimer(
    TimerInstance instance, {
    SharedPreferences? prefs,
  }) async {
    await initialize();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (instance.status != TimerStateStatus.running) {
      await cancelTimer(instance.id);
      return;
    }

    if (_useNative) {
      await _bridge.scheduleTimer(instance, nowMs);
      return;
    }

    final remainingSec = instance.remainingAt(nowMs);
    if (remainingSec <= 0) {
      await cancelTimer(instance.id);
      return;
    }

    final scheduled =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: remainingSec));
    final mode = await _mode();
    await _plugin.zonedSchedule(
      id: _notifId(instance.id),
      title: 'Zamanlayıcı bitti',
      body: instance.label,
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
        ),
      ),
      androidScheduleMode: mode,
      payload: 'timer:${instance.id}',
    );
  }

  Future<void> cancelTimer(String id) async {
    await initialize();
    if (_useNative) {
      await _bridge.cancel(kind: 'timer', id: id);
    }
    await _plugin.cancel(id: _notifId(id));
  }

  /// Geriye uyumluluk: eski API cancelAlarm(id) timer id de iptal ederdi.
  Future<void> cancelById(String id) async {
    await cancelAlarm(id);
    await cancelTimer(id);
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

  Future<void> previewNativeRing(AlarmRule alarm) =>
      _bridge.previewRing(alarm);

  Future<ExactAlarmStatus> exactAlarmStatus() => _exact.status();

  Future<bool> requestExactAlarmPermission() => _exact.request();

  int _notifId(String id) => id.hashCode & 0x7fffffff;
}

@pragma('vm:entry-point')
void alarmNotificationBg(NotificationResponse response) {
  // Background isolate: native zaten birincil; burada no-op güvenli.
}
