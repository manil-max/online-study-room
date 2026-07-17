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

  // WP-146: 2016 sonrası TR kalıcı UTC+3 — eski DST tarihleri de +3 kalır.
  group('WP-146 day boundary and permanent +3', () {
    test('İstanbul gece yarısı ±1 sn aynı/sonraki gün', () {
      // 2026-06-15 00:00:00 Istanbul = 2026-06-14 21:00:00 UTC
      final justBefore = DateTime.utc(2026, 6, 14, 20, 59, 59);
      final justAfter = DateTime.utc(2026, 6, 14, 21, 0, 1);
      expect(istanbulDay(justBefore), DateTime(2026, 6, 14));
      expect(istanbulDay(justAfter), DateTime(2026, 6, 15));
    });

    test('eski AB DST bahar geçiş tarihi hâlâ UTC+3 (kayma yok)', () {
      // 2015 öncesi AB "son Mart Pazar" — 2026-03-29 01:00 UTC civarı.
      // TR kalıcı +3: UTC 00:30 → Istanbul 03:30 (aynı gün 29).
      final spring = DateTime.utc(2026, 3, 29, 0, 30);
      expect(istanbulDay(spring), DateTime(2026, 3, 29));
      expect(istanbulHour(spring), 3);
    });

    test('eski AB DST sonbahar geçiş tarihi hâlâ UTC+3', () {
      // 2026-10-25 00:30 UTC → Istanbul 03:30, gün 25.
      final autumn = DateTime.utc(2026, 10, 25, 0, 30);
      expect(istanbulDay(autumn), DateTime(2026, 10, 25));
      expect(istanbulHour(autumn), 3);
    });

    test('cihaz TZ fark etmez: aynı UTC anı aynı Istanbul günü', () {
      final utc = DateTime.utc(2026, 7, 17, 21, 30); // Istanbul 18th 00:30
      expect(istanbulDay(utc), DateTime(2026, 7, 18));
      // Local DateTime with offset baked as UTC wall — still convert via TZ.
      final asLocalWall = DateTime.parse('2026-07-17T21:30:00.000Z');
      expect(istanbulDay(asLocalWall), DateTime(2026, 7, 18));
    });
  });
}
