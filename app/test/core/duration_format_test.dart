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
    test('saniye / dakika / saat', () {
      expect(formatHuman(40), '40 sn');
      expect(formatHuman(125), '2 dk');
      expect(formatHuman(3700), '1 sa 1 dk');
    });
  });
}
