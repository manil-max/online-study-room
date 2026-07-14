import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/world_clock_math.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Testler [homeNow]'ı UTC verir → `timeZoneOffset` her makinede 0 olur ve
/// offset farkı yalnız hedef TZ'ye bağlı kalır (CI/yerelde deterministik).
void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('isDaytimeHour', () {
    test('06:00–17:59 gündüz, dışı gece', () {
      expect(isDaytimeHour(6), isTrue);
      expect(isDaytimeHour(17), isTrue);
      expect(isDaytimeHour(18), isFalse);
      expect(isDaytimeHour(5), isFalse);
      expect(isDaytimeHour(0), isFalse);
    });
  });

  group('readWorldClock', () {
    test('İstanbul UTC+3 → aynı gün, +3 sa etiketi', () {
      final r = readWorldClock(
        cityLabel: 'İstanbul',
        timeZoneId: 'Europe/Istanbul',
        homeNow: DateTime.utc(2026, 1, 1, 12, 0),
      );
      expect(r.localTime.hour, 15); // UTC 12:00 → İstanbul 15:00
      expect(r.dayLabel, 'Bugün');
      expect(r.offsetLabel, 'Bugün, +3 sa');
      expect(r.isDaytime, isTrue);
    });

    test('Tokyo geç UTC saatinde ertesi güne geçer (Yarın, +9 sa)', () {
      final r = readWorldClock(
        cityLabel: 'Tokyo',
        timeZoneId: 'Asia/Tokyo',
        homeNow: DateTime.utc(2026, 1, 1, 23, 0),
      );
      // UTC 23:00 → Tokyo ertesi gün 08:00
      expect(r.localTime.hour, 8);
      expect(r.dayLabel, 'Yarın');
      expect(r.offsetLabel, 'Yarın, +9 sa');
      expect(r.isDaytime, isTrue);
    });

    test('Los Angeles negatif offset (Dün, −8 sa) ve gece', () {
      final r = readWorldClock(
        cityLabel: 'Los Angeles',
        timeZoneId: 'America/Los_Angeles',
        homeNow: DateTime.utc(2026, 1, 1, 3, 0),
      );
      // UTC 03:00 → LA önceki gün 19:00 (kış PST = UTC−8)
      expect(r.dayLabel, 'Dün');
      expect(r.offsetLabel, 'Dün, −8 sa');
      expect(r.isDaytime, isFalse); // 19:00
    });

    test('yarım saatlik offset (Mumbai +5.5) tek ondalıkla yazılır', () {
      final r = readWorldClock(
        cityLabel: 'Mumbai',
        timeZoneId: 'Asia/Kolkata',
        homeNow: DateTime.utc(2026, 1, 1, 12, 0),
      );
      expect(r.offsetLabel, 'Bugün, +5.5 sa');
    });

    test('location parametresi verilince katalog id\'sinden bağımsız çalışır', () {
      final loc = tz.getLocation('Europe/Istanbul');
      final r = readWorldClock(
        cityLabel: 'Özel',
        timeZoneId: 'ignored',
        homeNow: DateTime.utc(2026, 6, 1, 9, 0),
        location: loc,
      );
      expect(r.localTime.hour, 12); // UTC 09:00 → İstanbul 12:00
      expect(r.offsetLabel, 'Bugün, +3 sa');
    });
  });
}
