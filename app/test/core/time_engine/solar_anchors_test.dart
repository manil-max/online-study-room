// WP-377: kamp gökyüzünün mevsime göre kayması.
//
// Sahip "gece gündüz saatlerinde sorun var" dedi. Kodda doğrulandı: çıpalar
// yıl boyu sabitti (05:30 · 06:30 · 18:30 · 19:30) ve gerçek güneşten
// ±2,5 saate kadar sapıyordu. Bu testler modeli **gerçek güneş saatlerine
// karşı** ölçer — kendi ürettiği sayıyı tekrar etmez.
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/sky_phase.dart';
import 'package:online_study_room/core/time_engine/solar_anchors.dart';

/// NOAA gündoğumu denklemiyle hesaplanmış İstanbul referansı (2026, dakika).
/// Sıra: sivil şafak · gündoğumu · günbatımı · sivil karanlık.
const _istanbul2026 = <String, List<int>>{
  '01-15': [477, 507, 1080, 1110], // 07:57 08:27 18:00 18:30
  '03-21': [399, 427, 1157, 1184], // 06:39 07:07 19:17 19:44
  '06-21': [298, 332, 1240, 1273], // 04:58 05:32 20:40 21:13
  '07-28': [324, 356, 1225, 1256], // 05:24 05:56 20:25 20:56
  '09-21': [383, 410, 1144, 1171], // 06:23 06:50 19:04 19:31
  '12-21': [474, 505, 1059, 1090], // 07:54 08:25 17:39 18:10
};

DateTime _date(String key) {
  final parts = key.split('-');
  return DateTime(2026, int.parse(parts[0]), int.parse(parts[1]), 12);
}

void main() {
  group('solarSkyAnchors', () {
    test('gerçek güneş saatlerine 20 dakikadan fazla sapmaz', () {
      _istanbul2026.forEach((key, expected) {
        final anchors = solarSkyAnchors(_date(key));
        final actual = [
          anchors.dawnMinute,
          anchors.sunriseMinute,
          anchors.sunsetMinute,
          anchors.duskMinute,
        ];
        for (var i = 0; i < 4; i++) {
          expect(
            (actual[i] - expected[i]).abs(),
            lessThanOrEqualTo(20),
            reason:
                '$key çıpa $i: model ${actual[i]} dk, gerçek ${expected[i]} dk',
          );
        }
      });
    });

    test('🔴 bugünkü sabit çıpalar aynı testi geçemez', () {
      // Kapanın kendisi: düzeltme geri alınıp `kDefaultSkyAnchors` kullanılırsa
      // sapma 20 dakikayı fena hâlde aşar. Bu iddia düşerse birileri modeli
      // sabit çıpalara geri döndürmüş demektir.
      var worst = 0;
      _istanbul2026.forEach((key, expected) {
        final fixed = [
          kDefaultSkyAnchors.dawnMinute,
          kDefaultSkyAnchors.sunriseMinute,
          kDefaultSkyAnchors.sunsetMinute,
          kDefaultSkyAnchors.duskMinute,
        ];
        for (var i = 0; i < 4; i++) {
          final deviation = (fixed[i] - expected[i]).abs();
          if (deviation > worst) worst = deviation;
        }
      });
      expect(worst, greaterThan(120), reason: 'sabit çıpaların en kötü sapması');
    });

    test('yılın her günü geçerli ve sıralı çıpa üretir', () {
      for (var day = 0; day < 366; day++) {
        final date = DateTime(2026).add(Duration(days: day));
        final anchors = solarSkyAnchors(date);
        expect(
          anchors.isValid,
          isTrue,
          reason: '$date için sıra bozuldu: '
              '${anchors.dawnMinute}/${anchors.sunriseMinute}/'
              '${anchors.sunsetMinute}/${anchors.duskMinute}',
        );
        // skyPhase geçersiz çıpada fırlatır; sözleşme uçtan uca tutmalı.
        expect(() => skyPhase(date, anchors), returnsNormally);
      }
    });

    test('kutup enlemlerinde bile sıralı kalır (gün doğmuyor/batmıyor)', () {
      for (final latitude in [78.0, 68.0, -78.0, 0.0]) {
        for (final month in [1, 6, 12]) {
          final date = DateTime(2026, month, 15, 12);
          final anchors = solarSkyAnchors(date, latitude: latitude);
          expect(
            anchors.isValid,
            isTrue,
            reason: 'enlem $latitude ay $month için sıra bozuldu',
          );
        }
      }
    });

    test('yaz günü kıştan uzundur', () {
      final summer = solarSkyAnchors(DateTime(2026, 6, 21, 12));
      final winter = solarSkyAnchors(DateTime(2026, 12, 21, 12));
      final summerLength = summer.sunsetMinute - summer.sunriseMinute;
      final winterLength = winter.sunsetMinute - winter.sunriseMinute;

      expect(summerLength, greaterThan(winterLength));
      // İstanbul enleminde fark kabaca 5,5 saat.
      expect(summerLength - winterLength, greaterThan(4 * 60));
    });

    test('21 Haziran akşamı 19:30 artık gece değil gündüzdür', () {
      // Sahibin gördüğü hatanın birebir kaydı: sahne 19:30'da geceye
      // geçiyordu, oysa güneş 20:40'ta batıyor.
      final at1930 = DateTime(2026, 6, 21, 19, 30);
      final phaseNow = skyPhase(at1930, solarSkyAnchors(at1930)).phase;
      final phaseBefore = skyPhase(at1930, kDefaultSkyAnchors).phase;

      expect(phaseBefore, SkyPhase.night);
      expect(phaseNow, SkyPhase.day);
    });

    test('21 Aralık akşamı 18:00 artık gündüz değil gecedir', () {
      // Ters yönü: kışın güneş 17:39'da batarken sahne 18:30'a kadar
      // gündüz kalıyordu.
      final at1800 = DateTime(2026, 12, 21, 18);
      final phaseNow = skyPhase(at1800, solarSkyAnchors(at1800)).phase;
      final phaseBefore = skyPhase(at1800, kDefaultSkyAnchors).phase;

      expect(phaseBefore, SkyPhase.day);
      expect(phaseNow, isNot(SkyPhase.day));
    });
  });
}
