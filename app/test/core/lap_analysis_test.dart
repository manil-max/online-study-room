import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/lap_analysis.dart';

void main() {
  group('LapAnalysis.fromTotals', () {
    test('boş liste → boş analiz, indeksler -1', () {
      final a = LapAnalysis.fromTotals(const []);
      expect(a.isEmpty, isTrue);
      expect(a.splitsMs, isEmpty);
      expect(a.fastestIndex, -1);
      expect(a.slowestIndex, -1);
    });

    test('tek tur → split=total, en hızlı 0, yavaş vurgusu yok', () {
      final a = LapAnalysis.fromTotals(const [5000]);
      expect(a.splitsMs, [5000]);
      expect(a.fastestIndex, 0);
      expect(a.slowestIndex, -1);
    });

    test('toplamlardan tur sürelerini (split) türetir', () {
      // artan total 3000, 8000, 9500 → split 3000, 5000, 1500
      final a = LapAnalysis.fromTotals(const [3000, 8000, 9500]);
      expect(a.splitsMs, [3000, 5000, 1500]);
      expect(a.fastestIndex, 2); // 1500 en küçük
      expect(a.slowestIndex, 1); // 5000 en büyük
    });

    test('deltaVsPrevious önceki tura göre farkı verir; ilk turda null', () {
      final a = LapAnalysis.fromTotals(const [3000, 8000, 9500]);
      expect(a.deltaVsPrevious(0), isNull);
      expect(a.deltaVsPrevious(1), 2000); // 5000 - 3000
      expect(a.deltaVsPrevious(2), -3500); // 1500 - 5000
      expect(a.deltaVsPrevious(9), isNull); // aralık dışı
    });

    test('hepsi eşit → yavaş vurgusu yok (slowestIndex -1)', () {
      final a = LapAnalysis.fromTotals(const [2000, 4000, 6000]);
      expect(a.splitsMs, [2000, 2000, 2000]);
      expect(a.fastestIndex, 0);
      expect(a.slowestIndex, -1);
    });

    test('azalan toplam negatif split üretmez (0\'a kırpılır)', () {
      final a = LapAnalysis.fromTotals(const [5000, 3000]);
      expect(a.splitsMs, [5000, 0]);
      expect(a.fastestIndex, 1);
      expect(a.slowestIndex, 0);
    });
  });

  group('formatStopwatch', () {
    test('bir saatin altı → mm:ss.cc', () {
      final s = formatStopwatch(
        const Duration(minutes: 2, seconds: 5, milliseconds: 230),
      );
      expect(s, '02:05.23');
    });

    test('centiseconds kapalı → mm:ss', () {
      final s = formatStopwatch(
        const Duration(minutes: 2, seconds: 5, milliseconds: 230),
        centiseconds: false,
      );
      expect(s, '02:05');
    });

    test('bir saat ve üzeri → h:mm:ss.cc', () {
      final s = formatStopwatch(
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(s, '1:02:03.00');
    });
  });

  group('formatCountdown', () {
    test('bir saatin altı → mm:ss', () {
      expect(formatCountdown(const Duration(minutes: 5, seconds: 9)), '05:09');
    });

    test('bir saat ve üzeri → h:mm:ss', () {
      expect(
        formatCountdown(const Duration(hours: 1, minutes: 0, seconds: 5)),
        '1:00:05',
      );
    });

    test('negatif süre 00:00\'a kırpılır', () {
      expect(formatCountdown(const Duration(seconds: -5)), '00:00');
    });
  });
}
