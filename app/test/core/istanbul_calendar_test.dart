import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';

/// Europe/Istanbul, 2016'dan beri kalıcı UTC+3 (yaz saati yok). Testler UTC
/// girdi kullanır; böylece CI (UTC) ve yerel makinede aynı sonucu üretir ve
/// gün-sınırı kayması (projenin tek takvim kuralı) deterministik doğrulanır.
void main() {
  group('istanbulDay', () {
    test('gün anahtarına indirger, saat bilgisini düşürür', () {
      final day = istanbulDay(DateTime.utc(2026, 3, 15, 9, 30));
      // UTC 09:30 → İstanbul 12:30, aynı gün.
      expect(day, DateTime(2026, 3, 15));
      expect(day.hour, 0);
      expect(day.minute, 0);
      expect(day.second, 0);
    });

    test('gece yarısını UTC+3 ile bir sonraki güne taşır', () {
      // UTC 22:00 → İstanbul ertesi gün 01:00.
      final day = istanbulDay(DateTime.utc(2026, 1, 1, 22, 0));
      expect(day, DateTime(2026, 1, 2));
    });

    test('erken UTC saati aynı İstanbul gününde kalır', () {
      // UTC 05:00 → İstanbul 08:00, aynı gün.
      final day = istanbulDay(DateTime.utc(2026, 1, 1, 5, 0));
      expect(day, DateTime(2026, 1, 1));
    });

    test('ay/yıl sınırını doğru döndürür', () {
      // UTC 31 Aralık 22:00 → İstanbul 1 Ocak 01:00 (yıl döner).
      final day = istanbulDay(DateTime.utc(2025, 12, 31, 22, 0));
      expect(day, DateTime(2026, 1, 1));
    });
  });

  group('istanbulHour', () {
    test('UTC saatine +3 uygular', () {
      expect(istanbulHour(DateTime.utc(2026, 1, 1, 5, 0)), 8);
    });

    test('gün sınırında sarar (22:00 UTC → 01:00)', () {
      expect(istanbulHour(DateTime.utc(2026, 1, 1, 22, 0)), 1);
    });
  });

  group('istanbulWeekday', () {
    test('1 Ocak 2026 Perşembe günüdür (weekday 4)', () {
      expect(istanbulWeekday(DateTime.utc(2026, 1, 1, 12, 0)), DateTime.thursday);
    });

    test('gece yarısı sarması hafta gününü de kaydırır', () {
      // UTC 1 Ocak 22:00 → İstanbul 2 Ocak (Cuma) 01:00.
      expect(istanbulWeekday(DateTime.utc(2026, 1, 1, 22, 0)), DateTime.friday);
    });
  });

  group('calendarDay', () {
    test('verilen değerin saatini düşürür (zaman dilimi çevirmeden)', () {
      final day = calendarDay(DateTime(2026, 7, 14, 23, 59, 59));
      expect(day, DateTime(2026, 7, 14));
      expect(day.hour, 0);
    });
  });
}
