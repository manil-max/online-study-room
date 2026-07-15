import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/utils/duration_format.dart';

void main() {
  group('formatHms', () {
    test('sıfır ve normal değerler', () {
      expect(formatHms(0), '00:00:00');
      expect(formatHms(3661), '01:01:01');
      expect(formatHms(59), '00:00:59');
    });
    test('negatif değer sıfıra sabitlenir', () {
      expect(formatHms(-10), '00:00:00');
    });
  });

  group('formatHuman', () {
    test('İngilizce grafik kısaltmaları kısa kalır', () {
      expect(formatHumanForLocale(40, 'en'), '40s');
      expect(formatHumanForLocale(125, 'en'), '2m');
      expect(formatHumanForLocale(3700, 'en'), '1h 1m');
      expect(formatHumanForLocale(4 * 3600 + 5 * 60, 'en'), '4h 5m');
      expect(formatHumanForLocale(6 * 3600, 'en'), '6h');
    });

    test('Türkçe seçiliyken İngilizce kısaltma sızmaz', () {
      expect(formatHumanForLocale(40, 'tr'), '40sn');
      expect(formatHumanForLocale(125, 'tr'), '2dk');
      expect(formatHumanForLocale(3700, 'tr'), '1sa 1dk');
      expect(formatHumanForLocale(4 * 3600 + 5 * 60, 'tr'), '4sa 5dk');
      expect(formatHumanForLocale(6 * 3600, 'tr'), '6sa');
    });
  });

  group('formatHumanSeconds', () {
    test('saniyeyi her zaman içerir ve dili korur', () {
      expect(formatHumanSecondsForLocale(40, 'en'), '40s');
      expect(formatHumanSecondsForLocale(125, 'en'), '2m 5s');
      expect(formatHumanSecondsForLocale(3725, 'en'), '1h 2m 5s');
      expect(formatHumanSecondsForLocale(40, 'tr'), '40sn');
      expect(formatHumanSecondsForLocale(125, 'tr'), '2dk 5sn');
      expect(formatHumanSecondsForLocale(3725, 'tr'), '1sa 2dk 5sn');
    });
    test('negatif değer sıfıra sabitlenir', () {
      expect(formatHumanSecondsForLocale(-5, 'tr'), '0sn');
    });
  });
}
