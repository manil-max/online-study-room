import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../stats/istanbul_calendar.dart';
import 'notification_preferences.dart';

/// WP-153: seri koruma + haftalık özet zamanlaması (timer/FGS'den bağımsız).
///
/// Idempotent: her sync önce sabit id'leri iptal eder, sonra opt-in'e göre kurar.
/// Exact alarm zorlanmaz; inexactAllowWhileIdle.
class SmartReminderScheduler {
  SmartReminderScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const channelId = 'study_reminders';
  static const streakNotifId = 710001;
  static const weeklyNotifId = 710002;

  /// Seri koruma saati (İstanbul duyarlı yerel TZDateTime; varsayılan 20:00).
  static const streakHour = 20;
  static const streakMinute = 0;

  /// Haftalık özet: Pazar 18:00 (DateTime.sunday = 7).
  static const weeklyWeekday = DateTime.sunday;
  static const weeklyHour = 18;
  static const weeklyMinute = 0;

  Future<void> sync({
    required NotificationPreferences prefs,
    required String streakTitle,
    required String streakBody,
    required String weeklyTitle,
    required String weeklyBody,
    required String channelName,
    required String channelDescription,
    DateTime? now,
  }) async {
    await cancelAll();
    if (!prefs.remindersEnabled) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    if (prefs.smartStreakReminderEnabled) {
      final when = nextStreakFire(now: now);
      final probe = DateTime(2000, 1, 1, when.hour, when.minute);
      if (!prefs.isWithinQuietHours(probe)) {
        await _plugin.zonedSchedule(
          id: streakNotifId,
          title: streakTitle,
          body: streakBody,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }

    if (prefs.smartWeeklySummaryEnabled) {
      final when = nextWeeklyFire(now: now);
      final probe = DateTime(2000, 1, 1, when.hour, when.minute);
      if (!prefs.isWithinQuietHours(probe)) {
        await _plugin.zonedSchedule(
          id: weeklyNotifId,
          title: weeklyTitle,
          body: weeklyBody,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancel(id: streakNotifId);
    await _plugin.cancel(id: weeklyNotifId);
  }

  /// Bir sonraki 20:00 (yerel TZ; Istanbul gün sınırı ürün kuralı).
  static tz.TZDateTime nextStreakFire({DateTime? now}) {
    final n = now ?? DateTime.now();
    // Istanbul takvim günü üzerinde 20:00 hedeflenir.
    final day = istanbulDay(n);
    var scheduled = tz.TZDateTime(
      tz.local,
      day.year,
      day.month,
      day.day,
      streakHour,
      streakMinute,
    );
    final nowTz = tz.TZDateTime.from(n, tz.local);
    if (!scheduled.isAfter(nowTz)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime nextWeeklyFire({DateTime? now}) {
    final n = now ?? DateTime.now();
    var scheduled = tz.TZDateTime(
      tz.local,
      n.year,
      n.month,
      n.day,
      weeklyHour,
      weeklyMinute,
    );
    final nowTz = tz.TZDateTime.from(n, tz.local);
    while (scheduled.weekday != weeklyWeekday || !scheduled.isAfter(nowTz)) {
      scheduled = scheduled.add(const Duration(days: 1));
      scheduled = tz.TZDateTime(
        tz.local,
        scheduled.year,
        scheduled.month,
        scheduled.day,
        weeklyHour,
        weeklyMinute,
      );
    }
    return scheduled;
  }
}
