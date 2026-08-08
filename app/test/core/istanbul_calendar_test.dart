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
      expect(
        istanbulWeekday(DateTime.utc(2026, 1, 1, 12, 0)),
        DateTime.thursday,
      );
    });

    test('gece yarısı sarması hafta gününü de kaydırır', () {
      // UTC 1 Ocak 22:00 → İstanbul 2 Ocak (Cuma) 01:00.
      expect(istanbulWeekday(DateTime.utc(2026, 1, 1, 22, 0)), DateTime.friday);
    });
  });

  // 🔴 WP-561: bu dosyanın başlığındaki "Testler UTC girdi kullanır" cümlesi
  // aynı zamanda bir KÖR NOKTAYDI: UTC(+0) ve İstanbul(+3), gün anahtarının
  // bozulduğu eşiğin (cihaz offset'i > +03:00) ALTINDA kalıyor. Aşağıdaki
  // grup eşiğin ÜSTÜNÜ de kapsar.
  group('WP-561 gün anahtarı idempotenttir (cihaz offset\'i eşiğin üstünde)', () {
    // Anahtar `DateTime(y,m,d)` ile, yani CİHAZ yerel saatinde kurulur; kod onu
    // sürekli tekrar `istanbulDay`'den geçirir. UTC+4 ve doğusunda yerel gece
    // yarısı hâlâ önceki İstanbul günündedir → ikinci çevrim bir gün geri kayar.
    final samples = [
      DateTime.utc(2026, 8, 7, 20),
      DateTime.utc(2026, 8, 7, 21, 30),
      DateTime.utc(2025, 12, 31, 22),
      DateTime.utc(2026, 3, 15, 9, 30),
    ];

    test('istanbulDay iki kez uygulanınca aynı günü verir', () {
      for (final x in samples) {
        final once = istanbulDay(x);
        expect(istanbulDay(once), once, reason: '$x');
      }
    });

    // Cihazın zaman dilimi test sürecinde değiştirilemez. Aynı hata sınıfı,
    // offset'i AÇIKÇA alan kardeş fonksiyonla kanıtlanır: cihaz offset'inin
    // (yerel UTC+3 / CI UTC) BATISINDAKİ bölgeler tam olarak "yerel gece yarısı
    // hâlâ önceki bölge gününde" durumunu üretir.
    for (final zone in const [
      'Etc/GMT+4', // UTC-4
      'Etc/GMT+11', // UTC-11
      'America/New_York',
    ]) {
      test('calendarDayInTimeZone idempotent — $zone', () {
        for (final x in samples) {
          final once = calendarDayInTimeZone(x, zone);
          expect(calendarDayInTimeZone(once, zone), once, reason: '$zone / $x');
        }
      });
    }

    test('koruma körleştirmez: UTC damgası her zaman çevrilir', () {
      expect(
        calendarDayInTimeZone(DateTime.utc(2026, 7, 1, 3, 30), 'America/New_York'),
        DateTime(2026, 6, 30),
      );
      expect(istanbulDay(DateTime.utc(2026, 8, 7, 21, 30)), DateTime(2026, 8, 8));
    });
  });

  group('calendarDay', () {
    test('verilen değerin saatini düşürür (zaman dilimi çevirmeden)', () {
      final day = calendarDay(DateTime(2026, 7, 14, 23, 59, 59));
      expect(day, DateTime(2026, 7, 14));
      expect(day.hour, 0);
    });
  });

  group('WP-326 group day-boundary chain', () {
    test('New York gününü gerçek IANA yaz saati ile hesaplar', () {
      // 2026-07-01 03:30 UTC, New York'ta önceki gün 23:30'dur (EDT).
      expect(
        calendarDayInTimeZone(
          DateTime.utc(2026, 7, 1, 3, 30),
          'America/New_York',
        ),
        DateTime(2026, 6, 30),
      );
      // Aynı UTC saati kışta EST olduğunda yine yerel günün içindedir.
      expect(
        calendarDayInTimeZone(
          DateTime.utc(2026, 1, 1, 4, 30),
          'America/New_York',
        ),
        DateTime(2025, 12, 31),
      );
    });

    test(
      'birincil grup önce gelir; geçersiz değerler güvenli sıradaki kaynağa düşer',
      () {
        expect(
          resolveStudyDayTimeZone(
            primaryGroupTimeZone: 'America/New_York',
            deviceTimeZone: 'Asia/Tokyo',
          ),
          'America/New_York',
        );
        expect(
          resolveStudyDayTimeZone(
            primaryGroupTimeZone: 'not-an-iana-zone',
            deviceTimeZone: 'Asia/Kolkata',
          ),
          'Asia/Kolkata',
        );
        expect(
          resolveStudyDayTimeZone(deviceTimeZone: 'bad'),
          'Europe/Istanbul',
        );
      },
    );
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

  group('WP-254: istanbulHm / istanbulWallClock', () {
    test('UTC damgasını İstanbul duvar saatine çevirir (3 saat ileri)', () {
      // Kullanıcı 16:00'da çalıştı → DB'de 13:00Z. Ekranda 16:00 yazmalı.
      expect(istanbulHm(DateTime.utc(2026, 7, 21, 13)), '16:00');
    });

    test(
      'ham .hour ile arasındaki fark tam 3 saattir (regresyonun kendisi)',
      () {
        final instant = DateTime.utc(2026, 7, 21, 13, 5);
        expect(instant.hour, 13); // eski (bozuk) davranış
        expect(istanbulHm(instant), '16:05'); // yeni (doğru) davranış
      },
    );

    test('iki haneli sıfır dolgusu', () {
      // UTC 06:07 → İstanbul 09:07.
      expect(istanbulHm(DateTime.utc(2026, 7, 21, 6, 7)), '09:07');
    });

    test('gün sınırını aşan an: UTC 22:30 → İstanbul ertesi gün 01:30', () {
      final instant = DateTime.utc(2026, 7, 20, 22, 30);
      expect(istanbulHm(instant), '01:30');
      // Tarih seçicinin açılacağı gün de kaymamalı (session_history _edit).
      expect(istanbulDay(instant), DateTime(2026, 7, 21));
    });

    test(
      'yerel (isUtc=false) DateTime verilse de sonuç instant tabanlıdır',
      () {
        final utc = DateTime.utc(2026, 7, 21, 13);
        expect(istanbulHm(utc.toLocal()), istanbulHm(utc));
      },
    );

    test('istanbulWallClock saat/dakikayı korur, istanbulHour ile tutarlı', () {
      final instant = DateTime.utc(2026, 7, 21, 13, 42);
      final wall = istanbulWallClock(instant);
      expect(wall.hour, 16);
      expect(wall.minute, 42);
      expect(wall.hour, istanbulHour(instant));
    });
  });
}
