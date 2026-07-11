import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/timer_preset.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final alarmNotificationServiceProvider = Provider<AlarmNotificationService>((ref) {
  return AlarmNotificationService.instance;
});

class AlarmNotificationService {
  AlarmNotificationService._(this._plugin);

  static final instance = AlarmNotificationService._(
    FlutterLocalNotificationsPlugin(),
  );

  static const String _channelId = 'personal_alarms';
  static const String _channelName = 'Alarmlar ve Zamanlayıcılar';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);

    _initialized = true;
  }

  Future<void> scheduleAlarm(AlarmRule alarm) async {
    await initialize();

    // Bu MVP sürümünde exact alarm yetkisi gerekmeden temel planlama yapıyoruz.
    // İleride SCHEDULE_EXACT_ALARM izniyle 'zonedSchedule' exact yapılabilir.
    
    // Eğer alarm aktif değilse iptal et (veya planlamadan çık)
    if (!alarm.isActive) {
      await cancelAlarm(alarm.id);
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      alarm.hour,
      alarm.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'), // varsa
    );

    await _plugin.zonedSchedule(
      id: alarm.id.hashCode,
      title: 'Alarm: ${alarm.label.isNotEmpty ? alarm.label : "Kişisel Alarm"}',
      body: 'Zamanı geldi!',
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: alarm.days.isNotEmpty ? DateTimeComponents.dayOfWeekAndTime : null,
    );
  }

  Future<void> cancelAlarm(String id) async {
    await _plugin.cancel(id: id.hashCode);
  }

  Future<void> scheduleTimer(TimerInstance instance) async {
    await initialize();

    if (instance.status != TimerStateStatus.running || instance.remainingSeconds <= 0) {
      await cancelAlarm(instance.id);
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = now.add(Duration(seconds: instance.remainingSeconds));

    final details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.zonedSchedule(
      id: instance.id.hashCode,
      title: 'Zamanlayıcı Bitti',
      body: instance.label,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> showImmediate(String title, String body) async {
    await initialize();
    final details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.max,
      priority: Priority.high,
    );
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
    );
  }
}
