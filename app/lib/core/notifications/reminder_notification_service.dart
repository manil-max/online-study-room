import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/study_reminder.dart';
import '../l10n/system_localizations.dart';
import 'notification_preferences.dart';

final reminderNotificationServiceProvider =
    Provider<ReminderNotificationService>((ref) {
      return ReminderNotificationService.instance;
    });

/// Kişisel çalışma hatırlatıcılarını yerel bildirim olarak planlar (§WP-36).
///
/// Alarm/timer servisinden ayrıdır; kendi kanalını kullanır. Tekrarlı
/// hatırlatıcılar için her gün ayrı bir bildirim id'si planlanır. Sessiz
/// saatlerde çalacak hatırlatıcılar bilinçli olarak planlanmaz.
class ReminderNotificationService {
  ReminderNotificationService._(this._plugin);

  static final instance = ReminderNotificationService._(
    FlutterLocalNotificationsPlugin(),
  );

  static const String _channelId = 'study_reminders';

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

  Future<bool> requestPermissionIfNeeded() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Tüm hatırlatıcıları verilen tercihlere göre yeniden planlar. Önce hepsi
  /// iptal edilir, sonra uygun olanlar tekrar kurulur — böylece silme/kapatma
  /// da yansır.
  Future<void> syncAll(
    List<StudyReminder> reminders,
    NotificationPreferences prefs,
  ) async {
    await initialize();
    for (final reminder in reminders) {
      await cancel(reminder);
    }
    if (!prefs.remindersEnabled) return;
    for (final reminder in reminders) {
      await schedule(reminder, prefs);
    }
  }

  Future<void> schedule(
    StudyReminder reminder,
    NotificationPreferences prefs,
  ) async {
    await initialize();
    await cancel(reminder);
    if (!reminder.enabled || !prefs.remindersEnabled) return;
    final l10n = await loadSystemLocalizations();

    // Sessiz saatlere denk gelen hatırlatıcıyı planlama (bilinçli kısıt).
    final probe = DateTime(2000, 1, 1, reminder.hour, reminder.minute);
    if (prefs.isWithinQuietHours(probe)) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.coreCalismaHatirlaticilari,
        channelDescription: l10n.corePlanlanmisCalismaHatirlaticilari,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    final body = (reminder.body == null || reminder.body!.trim().isEmpty)
        ? l10n.coreCalismaZamani
        : reminder.body!;

    if (!reminder.repeats) {
      await _plugin.zonedSchedule(
        id: reminder.id.hashCode,
        title: reminder.title,
        body: body,
        scheduledDate: _nextDailyTime(reminder.hour, reminder.minute),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return;
    }

    for (final weekday in reminder.weekdays) {
      await _plugin.zonedSchedule(
        id: _weekdayId(reminder.id, weekday),
        title: reminder.title,
        body: body,
        scheduledDate: _nextWeekdayTime(
          weekday,
          reminder.hour,
          reminder.minute,
        ),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancel(StudyReminder reminder) async {
    await _plugin.cancel(id: reminder.id.hashCode);
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(id: _weekdayId(reminder.id, weekday));
    }
  }

  int _weekdayId(String id, int weekday) =>
      Object.hash(id, weekday) & 0x7fffffff;

  tz.TZDateTime _nextDailyTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
    var scheduled = _nextDailyTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
