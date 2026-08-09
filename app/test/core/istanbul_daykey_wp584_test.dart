// WP-584: `_isDayKey` HER yerel gece yarisini "zaten gun anahtari" sayiyordu.
//
// WP-561'in niyeti dogruydu: donusum IDEMPOTENT olsun, yani girdi zaten bir gun
// anahtariysa aynen donsun ve `dayOf(dayOf(x))` gunu bir geri kaydirmasin.
// Ama kapinin kosulu "UTC degil + saat alanlari sifir" idi. Bir `TZDateTime`
// da bu kosulu saglar: `TZDateTime.isUtc` yalnizca konum UTC ise true doner
// (timezone 0.11.1, `date_time.dart:114`), `.hour/.minute/...` ise o BOLGENIN
// duvar saatini verir. Sonuc: baska bir bolgenin gece yarisi cevrilmeden
// gecip kendi takvim tarihini gun anahtari olarak dayatiyordu.
//
// Somut: `TZDateTime(Asia/Dubai, 2026, 8, 9)` = 2026-08-08T20:00Z = Istanbul'da
// 8 Agustos 23:00. `istanbulDay` bunu 9 Agustos olarak donduruyordu; dogrusu
// 8 Agustos.
//
// Uretimde bugun tetiklenmesi zor cunku `DateTime.now()` tam mikrosaniye
// sifirda gelmiyor. Ama grup takvimleri IANA bolge adiyla calisir
// (`calendarDayInTimeZone`, WP-326) ve o yol `TZDateTime` uretir — yani
// kapinin kendisi zaman bombasidir.
//
// Cozum: gun anahtari bu modulde HER ZAMAN duz `DateTime(y, m, d)` olarak
// kurulur (asagidaki "cikti tipi" testi bunu kilitler). Dolayisiyla bir
// `TZDateTime` tanim geregi anahtar degil, kendi bolgesini tasiyan bir ANdir
// ve her zaman cevrilmelidir.
//
// 🔴 Bu dosya KOSUM MAKINESINDEN BAGIMSIZDIR: her an ya `DateTime.utc(...)` ya
// da acik `TZDateTime(location, ...)` ile kurulur; hicbir iddia
// `DateTime.now()`a ya da cihazin zaman dilimine dayanmaz.
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('WP-584: TZDateTime gun anahtari sayilmaz', () {
    test('Dubai gece yarisi Istanbul gunune cevrilir (hatanin kendisi)', () {
      final dubaiMidnight = tz.TZDateTime(tz.getLocation('Asia/Dubai'), 2026, 8, 9);

      // Kurulum dogrulamasi — test kendi senaryosunu kanitlar, yoksa yarin
      // "yesil ama anlamsiz" olurdu.
      expect(
        dubaiMidnight.microsecondsSinceEpoch,
        DateTime.utc(2026, 8, 8, 20).microsecondsSinceEpoch,
        reason: 'Kurulum bozuk: Dubai gece yarisi beklenen ana denk gelmiyor.',
      );
      // Eski kapinin iki kosulu da saglaniyor -> girdi "anahtar" saniliyordu.
      expect(dubaiMidnight.isUtc, isFalse);
      expect(dubaiMidnight.hour, 0);
      expect(dubaiMidnight.minute, 0);

      // An Istanbul'da 8 Agustos 23:00'dur; gun 8 Agustos olmali.
      expect(istanbulHm(dubaiMidnight), '23:00');
      expect(istanbulDay(dubaiMidnight), DateTime(2026, 8, 8));
    });

    test('calendarDayInTimeZone: girdi TZDateTime ise HEDEF bolgeye cevrilir', () {
      final istanbul = tz.getLocation('Europe/Istanbul');
      // Istanbul 9 Agustos 00:00 = 2026-08-08T21:00Z.
      final istanbulMidnight = tz.TZDateTime(istanbul, 2026, 8, 9);
      expect(
        istanbulMidnight.microsecondsSinceEpoch,
        DateTime.utc(2026, 8, 8, 21).microsecondsSinceEpoch,
        reason: 'Kurulum bozuk.',
      );
      // New York (EDT, UTC-4): 8 Agustos 17:00 -> gun 8 Agustos.
      expect(
        calendarDayInTimeZone(istanbulMidnight, 'America/New_York'),
        DateTime(2026, 8, 8),
      );
      // Tokyo (UTC+9): 9 Agustos 06:00 -> gun 9 Agustos.
      expect(
        calendarDayInTimeZone(istanbulMidnight, 'Asia/Tokyo'),
        DateTime(2026, 8, 9),
      );

      // Tokyo 9 Agustos 00:00 = 2026-08-08T15:00Z -> New York'ta 8 Agustos 11:00.
      final tokyoMidnight = tz.TZDateTime(tz.getLocation('Asia/Tokyo'), 2026, 8, 9);
      expect(
        calendarDayInTimeZone(tokyoMidnight, 'America/New_York'),
        DateTime(2026, 8, 8),
      );
    });

    test('istanbulDayStart ciktisi ayni gunu verir (davranis korundu)', () {
      // `istanbulDayStart` bir TZDateTime dondurur; onu tekrar `istanbulDay`den
      // gecirmek gunu degistirmemeli.
      final instant = DateTime.utc(2026, 8, 7, 22, 30); // Istanbul 8 Agustos 01:30
      final start = istanbulDayStart(instant);
      expect(start, isA<tz.TZDateTime>());
      expect(istanbulDay(instant), DateTime(2026, 8, 8));
      expect(istanbulDay(start), DateTime(2026, 8, 8));
    });

    test('cikti her zaman duz DateTime — kapinin ayirt edicisi budur', () {
      // Bu dosyadaki cozumun gecerliligi tam olarak bu invariant'a dayanir:
      // modulun URETTIGI anahtar hicbir zaman TZDateTime degildir, bu yuzden
      // "TZDateTime ise anahtar degildir" kurali WP-561'i kaybettirmez.
      final fromUtc = istanbulDay(DateTime.utc(2026, 8, 8, 21, 30));
      final fromTz = istanbulDay(tz.TZDateTime(tz.getLocation('Asia/Dubai'), 2026, 8, 9));
      final fromZone = calendarDayInTimeZone(DateTime.utc(2026, 8, 8, 21, 30), 'Asia/Tokyo');
      for (final key in [fromUtc, fromTz, fromZone]) {
        expect(key, isNot(isA<tz.TZDateTime>()), reason: '$key');
        expect(key.isUtc, isFalse, reason: '$key');
        // Gun->saniye haritalari duz `DateTime` anahtariyla calisir; TZDateTime
        // sizarsa hashCode eslesmez ve toplamlar sessizce sifir gorunur.
        expect(<DateTime, int>{key: 1}[DateTime(key.year, key.month, key.day)], 1);
      }
    });

    test('WP-561 kazanimi duruyor: anahtar ikinci cevrimde kaymaz', () {
      final key = istanbulDay(DateTime.utc(2026, 8, 8, 21, 30));
      expect(key, DateTime(2026, 8, 9));
      expect(istanbulDay(key), key);

      // Makineden bagimsiz kanit: cihaz offset'inin BATISINDAKI bolgeler
      // (CI = UTC, gelistirici = UTC+3) "yerel gece yarisi hala onceki bolge
      // gununde" durumunu uretir; koruma kalkarsa bunlar kirmizi doner.
      for (final zone in const ['Etc/GMT+11', 'America/New_York', 'Etc/GMT+4']) {
        final once = calendarDayInTimeZone(DateTime.utc(2026, 8, 8, 21, 30), zone);
        expect(calendarDayInTimeZone(once, zone), once, reason: zone);
      }
    });
  });
}
