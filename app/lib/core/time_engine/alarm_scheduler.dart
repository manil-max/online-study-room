import '../../data/models/alarm_rule.dart';

/// Alarm bir sonraki çalma anını hesaplar (DST/timezone duyarlı, yerel DateTime).
///
/// Kurallar:
/// - [AlarmRule.days] boş → tek seferlik: bugün saat geçtiyse yarına.
/// - Gün listesi dolu → ISO hafta günü (1=Pzt … 7=Paz) eşleşen en yakın gelecek.
/// - [AlarmRule.skipNextOn] o takvim günündeki occurrence atlanır.
/// - [AlarmRule.date] set ise yalnız o günde (tekrar yok).
class AlarmScheduler {
  AlarmScheduler._();

  /// Sonraki çalma anı; aktif değilse veya bulunamazsa null.
  static DateTime? nextFire(AlarmRule alarm, DateTime now) {
    if (!alarm.isActive) return null;

    // Tek tarihli alarm
    if (alarm.date != null) {
      final d = alarm.date!;
      final candidate = DateTime(d.year, d.month, d.day, alarm.hour, alarm.minute);
      if (!candidate.isAfter(now)) return null;
      if (_isSkipped(alarm, candidate)) return null;
      return candidate;
    }

    // Tek seferlik (gün yok)
    if (alarm.days.isEmpty) {
      var candidate = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      if (_isSkipped(alarm, candidate)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    // Tekrarlayan
    final wanted = alarm.days.toSet();
    for (var offset = 0; offset < 14; offset++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      final iso = day.weekday; // 1..7
      if (!wanted.contains(iso)) continue;
      final candidate = DateTime(day.year, day.month, day.day, alarm.hour, alarm.minute);
      if (!candidate.isAfter(now)) continue;
      if (_isSkipped(alarm, candidate)) continue;
      return candidate;
    }
    return null;
  }

  static bool _isSkipped(AlarmRule alarm, DateTime candidate) {
    final skip = alarm.skipNextOn;
    if (skip == null) return false;
    return skip.year == candidate.year &&
        skip.month == candidate.month &&
        skip.day == candidate.day;
  }

  /// "Yarınki / bir sonraki" occurrence için skip tarihi üret.
  static DateTime skipTargetDate(AlarmRule alarm, DateTime now) {
    final next = nextFire(alarm, now);
    if (next != null) {
      return DateTime(next.year, next.month, next.day);
    }
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  /// Crescendo: 0.0 → 1.0 lineer, [duration] içinde (varsayılan 30 sn).
  static double crescendoLevel(
    Duration elapsed, {
    Duration duration = const Duration(seconds: 30),
  }) {
    if (duration.inMilliseconds <= 0) return 1;
    final t = elapsed.inMilliseconds / duration.inMilliseconds;
    return t.clamp(0.0, 1.0);
  }
}
