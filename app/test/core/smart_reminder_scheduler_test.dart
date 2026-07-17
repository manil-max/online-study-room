import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart';
import 'package:online_study_room/core/notifications/smart_reminder_scheduler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  });

  test('nextStreakFire is after now at 20:00', () {
    final now = DateTime(2026, 7, 15, 10, 0); // Wed morning
    final next = SmartReminderScheduler.nextStreakFire(now: now);
    expect(next.hour, 20);
    expect(next.minute, 0);
    expect(next.isAfter(tz.TZDateTime.from(now, tz.local)), isTrue);
  });

  test('nextStreakFire rolls to tomorrow after 20:00', () {
    final now = DateTime(2026, 7, 15, 21, 0);
    final next = SmartReminderScheduler.nextStreakFire(now: now);
    expect(next.hour, 20);
    expect(next.isAfter(tz.TZDateTime.from(now, tz.local)), isTrue);
    // En az bir takvim günü ileri (TZ kayması dahil).
    expect(next.difference(tz.TZDateTime.from(now, tz.local)).inHours >= 1, isTrue);
  });

  test('nextWeeklyFire is Sunday 18:00', () {
    final now = DateTime(2026, 7, 15, 12); // Wednesday
    final next = SmartReminderScheduler.nextWeeklyFire(now: now);
    expect(next.weekday, DateTime.sunday);
    expect(next.hour, 18);
  });

  test('quiet hours blocks scheduling decision', () {
    const prefs = NotificationPreferences(
      nudgeNotificationsEnabled: true,
      remindersEnabled: true,
      announcementsEnabled: true,
      updatesEnabled: true,
      quietHoursEnabled: true,
      quietStartMinutes: 19 * 60,
      quietEndMinutes: 21 * 60,
      smartStreakReminderEnabled: true,
    );
    // 20:00 is inside quiet → isWithinQuietHours true
    final probe = DateTime(2000, 1, 1, 20, 0);
    expect(prefs.isWithinQuietHours(probe), isTrue);
  });

  test('opt-out defaults for smart flags', () {
    const prefs = NotificationPreferences(
      nudgeNotificationsEnabled: true,
      remindersEnabled: true,
      announcementsEnabled: true,
      updatesEnabled: true,
      quietHoursEnabled: false,
      quietStartMinutes: 0,
      quietEndMinutes: 0,
    );
    expect(prefs.smartStreakReminderEnabled, isFalse);
    expect(prefs.smartWeeklySummaryEnabled, isFalse);
  });
}
