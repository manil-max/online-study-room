import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart';

NotificationPreferences prefs({
  bool quietEnabled = true,
  int start = 22 * 60, // 22:00
  int end = 7 * 60, // 07:00
}) {
  return NotificationPreferences(
    nudgeNotificationsEnabled: true,
    remindersEnabled: true,
    announcementsEnabled: true,
    updatesEnabled: true,
    quietHoursEnabled: quietEnabled,
    quietStartMinutes: start,
    quietEndMinutes: end,
  );
}

DateTime at(int hour, int minute) => DateTime(2026, 1, 1, hour, minute);

void main() {
  group('NotificationPreferences.isWithinQuietHours', () {
    test('kapalıyken her zaman false', () {
      final p = prefs(quietEnabled: false);
      expect(p.isWithinQuietHours(at(23, 0)), isFalse);
      expect(p.isWithinQuietHours(at(3, 0)), isFalse);
    });

    test('gece yarısını saran aralık doğru değerlendirilir', () {
      final p = prefs(); // 22:00 - 07:00
      expect(p.isWithinQuietHours(at(23, 30)), isTrue);
      expect(p.isWithinQuietHours(at(2, 0)), isTrue);
      expect(p.isWithinQuietHours(at(6, 59)), isTrue);
      expect(p.isWithinQuietHours(at(7, 0)), isFalse); // bitiş dışlanır
      expect(p.isWithinQuietHours(at(12, 0)), isFalse);
      expect(p.isWithinQuietHours(at(22, 0)), isTrue); // başlangıç dahil
    });

    test('aynı gün içi (sarmayan) aralık', () {
      final p = prefs(start: 9 * 60, end: 17 * 60); // 09:00 - 17:00
      expect(p.isWithinQuietHours(at(8, 59)), isFalse);
      expect(p.isWithinQuietHours(at(9, 0)), isTrue);
      expect(p.isWithinQuietHours(at(16, 59)), isTrue);
      expect(p.isWithinQuietHours(at(17, 0)), isFalse);
    });

    test('başlangıç == bitiş ise aralık yok sayılır', () {
      final p = prefs(start: 8 * 60, end: 8 * 60);
      expect(p.isWithinQuietHours(at(8, 0)), isFalse);
    });
  });
}
