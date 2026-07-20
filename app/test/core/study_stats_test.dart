import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

bool _tzReady = false;

void _ensureTz() {
  if (_tzReady) return;
  tz_data.initializeTimeZones();
  _tzReady = true;
}

/// CI (UTC) ve yerel makinede aynı duvar saatini üretmek için Europe/Istanbul.
DateTime _ist(int y, int m, int d, [int h = 12, int min = 0]) {
  _ensureTz();
  return tz.TZDateTime(tz.getLocation('Europe/Istanbul'), y, m, d, h, min);
}

StudySession _s(String user, DateTime start, int seconds) => StudySession(
      id: '$user-${start.toIso8601String()}',
      userId: user,
      start: start,
      end: start.add(Duration(seconds: seconds)),
      durationSeconds: seconds,
      source: StudySource.live,
    );

void main() {
  test('resolveTodayDisplayTotal: freeze dünse gece yarısından sonra düşer', () {
    // Dün 1s 5dk freeze; bugün kayıtlı 0 → ekran 0 (eski bug: 1s 5dk kalırdı).
    final yesterday = DateTime(2026, 7, 15);
    final today = DateTime(2026, 7, 16);
    final r = resolveTodayDisplayTotal(
      recordedToday: 0,
      liveWorkSeconds: 0,
      frozenTotal: 3900, // 1s 5dk
      frozenOnDay: yesterday,
      today: today,
    );
    expect(r.total, 0);
    expect(r.keepFrozen, isNull);
  });

  test('resolveTodayDisplayTotal: aynı günde freeze kaydı gelene kadar tutar', () {
    final today = DateTime(2026, 7, 16);
    final r = resolveTodayDisplayTotal(
      recordedToday: 0,
      liveWorkSeconds: 0,
      frozenTotal: 3900,
      frozenOnDay: today,
      today: today,
    );
    expect(r.total, 3900);
    expect(r.keepFrozen, 3900);

    final caughtUp = resolveTodayDisplayTotal(
      recordedToday: 3900,
      liveWorkSeconds: 0,
      frozenTotal: 3900,
      frozenOnDay: today,
      today: today,
    );
    expect(caughtUp.total, 3900);
    expect(caughtUp.keepFrozen, isNull);
  });

  test('WP-239: freeze = görünen toplam iken recorded yetişince ŞİŞMEZ', () {
    // Senaryo: 1s kayıtlı + 1s canlı kronometre → ekranda 2s (7200sn).
    // Durdur'a basılınca biten oturum offline cache'e SENKRON yazılıp
    // recorded provider'ı stop'tan ÖNCE güncellenebiliyor (recorded=7200).
    final today = DateTime(2026, 7, 20);

    // DOĞRU (WP-239): freeze = durdurma anında görünen toplam (7200).
    // recorded sonradan 7200'e ulaşınca sonuç 7200 kalır — çift sayım yok.
    final correct = resolveTodayDisplayTotal(
      recordedToday: 7200, // yeni oturumu zaten içeriyor
      liveWorkSeconds: 0, // durdu
      frozenTotal: 7200, // = son görünen toplam
      frozenOnDay: today,
      today: today,
    );
    expect(correct.total, 7200, reason: '2 saat görünmeli, 3 saat değil');

    // Eski bug: freeze = recorded(7200) + extra(3600) = 10800 hesaplanıyordu;
    // fonksiyon frozen'ı sadık taşıdığı için ekran 3 saat (10800) gösterirdi.
    // Bu assert, şişmenin kaynağının YANLIŞ freeze girdisi olduğunu belgeler.
    final buggyInput = resolveTodayDisplayTotal(
      recordedToday: 7200,
      liveWorkSeconds: 0,
      frozenTotal: 10800, // recorded + extra (çift)
      frozenOnDay: today,
      today: today,
    );
    expect(buggyInput.total, 10800,
        reason: 'fonksiyon frozen\'ı taşır; kök neden widget freeze hesabında');
  });

  test('StudySession.day UTC start için Istanbul günü kullanır', () {
    // UTC 21:30 → Istanbul 00:30 ertesi gün.
    final s = _s('u1', DateTime.utc(2026, 7, 15, 21, 30), 600);
    expect(s.day, DateTime(2026, 7, 16));
    expect(secondsOnDay([s], DateTime(2026, 7, 16)), 600);
    expect(secondsOnDay([s], DateTime(2026, 7, 15)), 0);
  });

  test('startOfWeek Pazartesi 00:00 verir', () {
    // 2026-06-21 bir Pazar (İstanbul).
    final monday = startOfWeek(_ist(2026, 6, 21, 15, 30));
    expect(monday, DateTime(2026, 6, 15));
  });

  test('totalSeconds ve inRange', () {
    final sessions = [
      _s('u1', _ist(2026, 6, 18, 9), 600),
      _s('u1', _ist(2026, 6, 20, 9), 1200),
      _s('u1', _ist(2026, 6, 25, 9), 300),
    ];
    expect(totalSeconds(sessions), 2100);
    final ranged =
        inRange(sessions, _ist(2026, 6, 18), _ist(2026, 6, 20));
    expect(totalSeconds(ranged), 1800);
  });

  test('secondsOnDay yalnızca o günü toplar', () {
    final sessions = [
      _s('u1', _ist(2026, 6, 20, 8), 600),
      _s('u1', _ist(2026, 6, 20, 14), 900),
      _s('u1', _ist(2026, 6, 21, 8), 300),
    ];
    expect(secondsOnDay(sessions, _ist(2026, 6, 20)), 1500);
  });

  test('lastNDays eski→yeni sıralı, boş günler 0', () {
    final sessions = [
      _s('u1', _ist(2026, 6, 19, 8), 600),
      _s('u1', _ist(2026, 6, 21, 8), 1200),
    ];
    // Gece 23:00 yerel UTC’de ertesi güne kaymasın diye İstanbul 23:00.
    final series = lastNDays(sessions, 3, today: _ist(2026, 6, 21, 23));
    expect(series.map((d) => d.day).toList(),
        [DateTime(2026, 6, 19), DateTime(2026, 6, 20), DateTime(2026, 6, 21)]);
    expect(series.map((d) => d.seconds).toList(), [600, 0, 1200]);
  });

  test('dailyRange aralıktaki her günü verir, boş günler 0', () {
    final sessions = [
      _s('u1', _ist(2026, 6, 18, 8), 600),
      _s('u1', _ist(2026, 6, 20, 8), 1200),
    ];
    final series =
        dailyRange(sessions, _ist(2026, 6, 18), _ist(2026, 6, 20));
    expect(series.map((d) => d.day).toList(),
        [DateTime(2026, 6, 18), DateTime(2026, 6, 19), DateTime(2026, 6, 20)]);
    expect(series.map((d) => d.seconds).toList(), [600, 0, 1200]);
  });

  test('dailyRange ters aralıkta boş liste', () {
    final series =
        dailyRange(const [], _ist(2026, 6, 20), _ist(2026, 6, 18));
    expect(series, isEmpty);
  });

  test('dailyAverageSeconds boş günleri paydaya katar', () {
    final sessions = [
      _s('u1', _ist(2026, 6, 20, 8), 600),
      _s('u1', _ist(2026, 6, 22, 8), 600),
    ];
    // 20–22 arası 3 gün, toplam 1200 → ortalama 400.
    final avg = dailyAverageSeconds(
      sessions,
      _ist(2026, 6, 20),
      _ist(2026, 6, 22),
    );
    expect(avg, 400);
  });

  test('weekdayWeekendSplit hafta içi/sonu ayırır', () {
    final sessions = [
      _s('u1', _ist(2026, 6, 19, 8), 600), // Cuma → hafta içi
      _s('u1', _ist(2026, 6, 20, 8), 900), // Cumartesi → hafta sonu
      _s('u1', _ist(2026, 6, 21, 8), 300), // Pazar → hafta sonu
    ];
    final split = weekdayWeekendSplit(sessions);
    expect(split.weekday, 600);
    expect(split.weekend, 1200);
  });

  test('leaderboard kullanıcı başına toplar ve büyükten küçüğe sıralar', () {
    final sessions = [
      _s('u1', _ist(2026, 6, 20, 8), 600),
      _s('u2', _ist(2026, 6, 20, 8), 1500),
      _s('u1', _ist(2026, 6, 21, 8), 300),
    ];
    final board = leaderboard(sessions);
    expect(board.map((e) => e.key).toList(), ['u2', 'u1']);
    expect(board.first.value, 1500);
    expect(board.last.value, 900);
  });

  group('currentStreak (günlük hedefe bağlı seri)', () {
    // Hedef: 1 saat (3600 sn). today = 2026-06-21 (İstanbul).
    const goal = 3600;
    final today = _ist(2026, 6, 21, 20);

    test('hiç oturum yoksa 0', () {
      expect(currentStreak(const [], goal, today: today), 0);
    });

    test('bugün hedefi tutturduysa bugünden geriye sayar', () {
      final sessions = [
        _s('u1', _ist(2026, 6, 21, 8), 3600), // bugün ✓
        _s('u1', _ist(2026, 6, 20, 8), 4000), // dün ✓
        _s('u1', _ist(2026, 6, 19, 8), 1000), // 2 gün önce ✗
      ];
      expect(currentStreak(sessions, goal, today: today), 2);
    });

    test('bugün henüz hedefte değilse seri kırılmaz (dünden sayar)', () {
      final sessions = [
        _s('u1', _ist(2026, 6, 21, 8), 1000), // bugün ✗ (gün sürüyor)
        _s('u1', _ist(2026, 6, 20, 8), 3600), // dün ✓
        _s('u1', _ist(2026, 6, 19, 8), 3700), // 2 gün önce ✓
      ];
      expect(currentStreak(sessions, goal, today: today), 2);
    });

    test('bugün ve dün hedefte değilse 0', () {
      final sessions = [
        _s('u1', _ist(2026, 6, 21, 8), 1000), // bugün ✗
        _s('u1', _ist(2026, 6, 20, 8), 1000), // dün ✗
      ];
      expect(currentStreak(sessions, goal, today: today), 0);
    });

    test('hedef 0/negatifse 0 döner (sonsuz döngü olmaz)', () {
      final sessions = [_s('u1', _ist(2026, 6, 21, 8), 3600)];
      expect(currentStreak(sessions, 0, today: today), 0);
    });
  });

  test('subjectBreakdown derse göre toplar (null=derssiz) ve sıralar', () {
    StudySession s(String? subjectId, int seconds) => StudySession(
          id: '$subjectId-$seconds',
          userId: 'u1',
          subjectId: subjectId,
          start: _ist(2026, 6, 20, 8),
          end: _ist(2026, 6, 20, 8).add(Duration(seconds: seconds)),
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
      _s('u1', _ist(2026, 6, 20, 9, 30), 600), // 09:00
      _s('u1', _ist(2026, 6, 21, 9, 5), 300), // 09:00 (toplanır)
      _s('u1', _ist(2026, 6, 20, 14, 0), 1200), // 14:00
      _s('u1', _ist(2026, 6, 20, 0, 10), 100), // 00:00
    ]);
    expect(totals.length, 24);
    expect(totals[9], 900); // 600 + 300
    expect(totals[14], 1200);
    expect(totals[0], 100);
    expect(totals[10], 0); // boş saat
  });

  test('weekdayHourTotals gün (Pzt=0..Paz=6) × saat ızgarası', () {
    // 2026-06-22 Pazartesi, 2026-06-21 Pazar (İstanbul).
    final grid = weekdayHourTotals([
      _s('u1', _ist(2026, 6, 22, 9, 0), 600), // Pzt(0) 09
      _s('u1', _ist(2026, 6, 22, 9, 30), 200), // Pzt(0) 09 (toplanır)
      _s('u1', _ist(2026, 6, 21, 14, 0), 900), // Paz(6) 14
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
      _s('u1', _ist(2026, 6, 18, 9), 600),
      _s('u1', _ist(2026, 6, 19, 9), 600),
      _s('u1', _ist(2026, 6, 20, 9), 600),
      _s('u1', _ist(2026, 6, 23, 9), 600),
      _s('u1', _ist(2026, 6, 24, 9), 600),
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
