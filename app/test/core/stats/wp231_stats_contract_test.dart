import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

bool _tzReady = false;

DateTime _istanbul(int day, [int hour = 12]) {
  if (!_tzReady) {
    tz_data.initializeTimeZones();
    _tzReady = true;
  }
  return tz.TZDateTime(tz.getLocation('Europe/Istanbul'), 2026, 7, day, hour);
}

StudySession _session(String id, DateTime start, int seconds) => StudySession(
  id: id,
  userId: 'u1',
  start: start,
  end: start.add(Duration(seconds: seconds)),
  durationSeconds: seconds,
  source: StudySource.live,
);

void main() {
  test('WP-231: 20 Temmuz Pazartesi dönemleri tek Istanbul sözleşmesinde kalır', () {
    final monday = _istanbul(20, 18);
    final sessions = [
      _session('month-earlier', _istanbul(1), 116760), // 32 sa 26 dk
      _session('sunday', _istanbul(19), 36000), // 10 sa
      _session('monday', _istanbul(20, 9), 2040), // 34 dk
    ];

    final today = secondsOnDay(sessions, monday);
    final calendarWeek = inRange(sessions, startOfWeek(monday), monday);
    final last7 = lastNDays(sessions, 7, today: monday);
    final month = inRange(sessions, startOfMonth(monday), monday);

    expect(today, 2040);
    expect(totalSeconds(calendarWeek), 2040);
    expect(last7.fold<int>(0, (sum, item) => sum + item.seconds), 38040);
    expect(totalSeconds(month), 154800); // 43 saat
  });
}
