import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/features/profile/widgets/manual_session_dialog.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tz_data.initializeTimeZones();
  // istanbulDay da aynı DB'yi kullanır.
  istanbulDay(DateTime.now());
  final loc = tz.getLocation('Europe/Istanbul');

  test('WP-107: manuel aralık İstanbul gününe düşer (cihaz TZ simülasyonu)', () {
    // UTC 2026-07-16 22:30 == İstanbul 2026-07-17 01:30 (yaz saati +3).
    final fakeNowUtc = DateTime.utc(2026, 7, 16, 22, 30);
    final pickedDay = DateTime(2026, 7, 17); // date picker takvim günü

    final range = manualSessionRange(
      pickedDay,
      3600, // 1 saat
      now: fakeNowUtc,
    );

    // start/end UTC instant; day anahtarı İstanbul 17 Temmuz olmalı.
    expect(istanbulDay(range.start), DateTime(2026, 7, 17));
    expect(istanbulDay(range.end), DateTime(2026, 7, 17));
    expect(range.end.difference(range.start).inSeconds, 3600);

    final endIst = tz.TZDateTime.from(range.end, loc);
    expect(endIst.hour, 1);
    expect(endIst.minute, 30);
  });

  test('WP-107: süre günün geçen kısmından uzunsa 00:00 kenet', () {
    // İstanbul 00:30'da 2 saat → start 00:00, end 02:00.
    final fakeNowUtc = DateTime.utc(2026, 7, 16, 21, 30); // IST 00:30
    final range = manualSessionRange(
      DateTime(2026, 7, 17),
      2 * 3600,
      now: fakeNowUtc,
    );
    final startIst = tz.TZDateTime.from(range.start, loc);
    final endIst = tz.TZDateTime.from(range.end, loc);
    expect(startIst.hour, 0);
    expect(startIst.minute, 0);
    expect(endIst.hour, 2);
    expect(istanbulDay(range.start), DateTime(2026, 7, 17));
  });

  test('WP-107: StudySession.toMap UTC yazar', () {
    final start = DateTime.utc(2026, 7, 17, 8, 0);
    final end = start.add(const Duration(hours: 1));
    final session = StudySession(
      id: 's1',
      userId: 'u1',
      start: start,
      end: end,
      durationSeconds: 3600,
      source: StudySource.manual,
    );
    final map = session.toMap();
    expect(map['start_time'] as String, contains('Z'));
    expect(map['end_time'] as String, contains('Z'));
    final round = StudySession.fromMap(map);
    expect(round.start.toUtc(), start);
    expect(round.end.toUtc(), end);
  });
}
