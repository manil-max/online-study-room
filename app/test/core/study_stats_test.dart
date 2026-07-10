import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/study_session.dart';

StudySession _s(String user, DateTime start, int seconds) => StudySession(
      id: '$user-${start.toIso8601String()}',
      userId: user,
      start: start,
      end: start.add(Duration(seconds: seconds)),
      durationSeconds: seconds,
      source: StudySource.live,
    );

void main() {
  test('startOfWeek Pazartesi 00:00 verir', () {
    // 2026-06-21 bir Pazar.
    final monday = startOfWeek(DateTime(2026, 6, 21, 15, 30));
    expect(monday, DateTime(2026, 6, 15));
  });

  test('totalSeconds ve inRange', () {
    final sessions = [
      _s('u1', DateTime(2026, 6, 18, 9), 600),
      _s('u1', DateTime(2026, 6, 20, 9), 1200),
      _s('u1', DateTime(2026, 6, 25, 9), 300),
    ];
    expect(totalSeconds(sessions), 2100);
    final ranged = inRange(sessions, DateTime(2026, 6, 18), DateTime(2026, 6, 20));
    expect(totalSeconds(ranged), 1800);
  });

  test('secondsOnDay yalnızca o günü toplar', () {
    final sessions = [
      _s('u1', DateTime(2026, 6, 20, 8), 600),
      _s('u1', DateTime(2026, 6, 20, 14), 900),
      _s('u1', DateTime(2026, 6, 21, 8), 300),
    ];
    expect(secondsOnDay(sessions, DateTime(2026, 6, 20)), 1500);
  });

  test('lastNDays eski→yeni sıralı, boş günler 0', () {
    final sessions = [
      _s('u1', DateTime(2026, 6, 19, 8), 600),
      _s('u1', DateTime(2026, 6, 21, 8), 1200),
    ];
    final series = lastNDays(sessions, 3, today: DateTime(2026, 6, 21, 23));
    expect(series.map((d) => d.day).toList(),
        [DateTime(2026, 6, 19), DateTime(2026, 6, 20), DateTime(2026, 6, 21)]);
    expect(series.map((d) => d.seconds).toList(), [600, 0, 1200]);
  });

  test('dailyRange aralıktaki her günü verir, boş günler 0', () {
    final sessions = [
      _s('u1', DateTime(2026, 6, 18, 8), 600),
      _s('u1', DateTime(2026, 6, 20, 8), 1200),
    ];
    final series = dailyRange(sessions, DateTime(2026, 6, 18), DateTime(2026, 6, 20));
    expect(series.map((d) => d.day).toList(),
        [DateTime(2026, 6, 18), DateTime(2026, 6, 19), DateTime(2026, 6, 20)]);
    expect(series.map((d) => d.seconds).toList(), [600, 0, 1200]);
  });

  test('dailyRange ters aralıkta boş liste', () {
    final series = dailyRange(const [], DateTime(2026, 6, 20), DateTime(2026, 6, 18));
    expect(series, isEmpty);
  });

  test('dailyAverageSeconds boş günleri paydaya katar', () {
    final sessions = [
      _s('u1', DateTime(2026, 6, 20, 8), 600),
      _s('u1', DateTime(2026, 6, 22, 8), 600),
    ];
    // 20–22 arası 3 gün, toplam 1200 → ortalama 400.
    final avg = dailyAverageSeconds(sessions, DateTime(2026, 6, 20), DateTime(2026, 6, 22));
    expect(avg, 400);
  });

  test('weekdayWeekendSplit hafta içi/sonu ayırır', () {
    final sessions = [
      _s('u1', DateTime(2026, 6, 19, 8), 600), // Cuma → hafta içi
      _s('u1', DateTime(2026, 6, 20, 8), 900), // Cumartesi → hafta sonu
      _s('u1', DateTime(2026, 6, 21, 8), 300), // Pazar → hafta sonu
    ];
    final split = weekdayWeekendSplit(sessions);
    expect(split.weekday, 600);
    expect(split.weekend, 1200);
  });

  test('leaderboard kullanıcı başına toplar ve büyükten küçüğe sıralar', () {
    final sessions = [
      _s('u1', DateTime(2026, 6, 20, 8), 600),
      _s('u2', DateTime(2026, 6, 20, 8), 1500),
      _s('u1', DateTime(2026, 6, 21, 8), 300),
    ];
    final board = leaderboard(sessions);
    expect(board.map((e) => e.key).toList(), ['u2', 'u1']);
    expect(board.first.value, 1500);
    expect(board.last.value, 900);
  });

  group('currentStreak (günlük hedefe bağlı seri)', () {
    // Hedef: 1 saat (3600 sn). today = 2026-06-21.
    const goal = 3600;
    final today = DateTime(2026, 6, 21, 20);

    test('hiç oturum yoksa 0', () {
      expect(currentStreak(const [], goal, today: today), 0);
    });

    test('bugün hedefi tutturduysa bugünden geriye sayar', () {
      final sessions = [
        _s('u1', DateTime(2026, 6, 21, 8), 3600), // bugün ✓
        _s('u1', DateTime(2026, 6, 20, 8), 4000), // dün ✓
        _s('u1', DateTime(2026, 6, 19, 8), 1000), // 2 gün önce ✗
      ];
      expect(currentStreak(sessions, goal, today: today), 2);
    });

    test('bugün henüz hedefte değilse seri kırılmaz (dünden sayar)', () {
      final sessions = [
        _s('u1', DateTime(2026, 6, 21, 8), 1000), // bugün ✗ (gün sürüyor)
        _s('u1', DateTime(2026, 6, 20, 8), 3600), // dün ✓
        _s('u1', DateTime(2026, 6, 19, 8), 3700), // 2 gün önce ✓
      ];
      expect(currentStreak(sessions, goal, today: today), 2);
    });

    test('bugün ve dün hedefte değilse 0', () {
      final sessions = [
        _s('u1', DateTime(2026, 6, 21, 8), 1000), // bugün ✗
        _s('u1', DateTime(2026, 6, 20, 8), 1000), // dün ✗
      ];
      expect(currentStreak(sessions, goal, today: today), 0);
    });

    test('hedef 0/negatifse 0 döner (sonsuz döngü olmaz)', () {
      final sessions = [_s('u1', DateTime(2026, 6, 21, 8), 3600)];
      expect(currentStreak(sessions, 0, today: today), 0);
    });
  });

  test('subjectBreakdown derse göre toplar (null=derssiz) ve sıralar', () {
    StudySession s(String? subjectId, int seconds) => StudySession(
          id: '$subjectId-$seconds',
          userId: 'u1',
          subjectId: subjectId,
          start: DateTime(2026, 6, 20, 8),
          end: DateTime(2026, 6, 20, 8).add(Duration(seconds: seconds)),
          durationSeconds: seconds,
          source: StudySource.live,
        );
    final breakdown = subjectBreakdown([
      s('mat', 600),
      s('fiz', 1500),
      s('mat', 300),
      s(null, 200),
    ]);
    expect(breakdown.map((e) => e.key).toList(), ['fiz', 'mat', null]);
    expect(breakdown.first.value, 1500);
    expect(breakdown[1].value, 900); // mat: 600 + 300
    expect(breakdown.last.key, isNull); // derssiz en sonda
    expect(breakdown.last.value, 200);
  });

  test('hourlyTotals oturumu başlangıç saatine yazar (0–23)', () {
    final totals = hourlyTotals([
      _s('u1', DateTime(2026, 6, 20, 9, 30), 600), // 09:00
      _s('u1', DateTime(2026, 6, 21, 9, 5), 300), // 09:00 (toplanır)
      _s('u1', DateTime(2026, 6, 20, 14, 0), 1200), // 14:00
      _s('u1', DateTime(2026, 6, 20, 0, 10), 100), // 00:00
    ]);
    expect(totals.length, 24);
    expect(totals[9], 900); // 600 + 300
    expect(totals[14], 1200);
    expect(totals[0], 100);
    expect(totals[10], 0); // boş saat
  });

  test('weekdayHourTotals gün (Pzt=0..Paz=6) × saat ızgarası', () {
    // 2026-06-22 Pazartesi, 2026-06-21 Pazar.
    final grid = weekdayHourTotals([
      _s('u1', DateTime(2026, 6, 22, 9, 0), 600), // Pzt(0) 09
      _s('u1', DateTime(2026, 6, 22, 9, 30), 200), // Pzt(0) 09 (toplanır)
      _s('u1', DateTime(2026, 6, 21, 14, 0), 900), // Paz(6) 14
    ]);
    expect(grid.length, 7);
    expect(grid[0].length, 24);
    expect(grid[0][9], 800); // 600 + 200
    expect(grid[6][14], 900);
    expect(grid[3][12], 0);
  });

  test('longestStudyStreak en uzun üst üste çalışılan gün serisi', () {
    expect(longestStudyStreak(const []), 0);
    // 18,19,20 (3 ardışık), boşluk, 23,24 (2 ardışık) → en uzun 3.
    final s = [
      _s('u1', DateTime(2026, 6, 18, 9), 600),
      _s('u1', DateTime(2026, 6, 19, 9), 600),
      _s('u1', DateTime(2026, 6, 20, 9), 600),
      _s('u1', DateTime(2026, 6, 23, 9), 600),
      _s('u1', DateTime(2026, 6, 24, 9), 600),
    ];
    expect(longestStudyStreak(s), 3);
  });

  group('tüm-zamanlar metrikleri (gün→saniye haritası, §WP-10)', () {
    final totals = {
      DateTime(2026, 6, 18): 600,
      DateTime(2026, 6, 19): 0, // çalışılmamış
      DateTime(2026, 6, 20): 1500,
      DateTime(2026, 6, 21): 1500, // tepe eşitliği → en erken (20) kazanır
    };

    test('totalOfDayTotals tüm günleri toplar', () {
      expect(totalOfDayTotals(totals), 3600);
      expect(totalOfDayTotals(const {}), 0);
    });

    test('activeDayCount yalnız >0 günleri sayar', () {
      expect(activeDayCount(totals), 3);
      expect(activeDayCount(const {}), 0);
    });

    test('peakDay en yoğun günü verir, eşitlikte en erken', () {
      final peak = peakDay(totals);
      expect(peak, isNotNull);
      expect(peak!.seconds, 1500);
      expect(peak.day, DateTime(2026, 6, 20));
    });

    test('peakDay veri yoksa/hepsi 0 ise null', () {
      expect(peakDay(const {}), isNull);
      expect(peakDay({DateTime(2026, 6, 18): 0}), isNull);
    });
  });
}
