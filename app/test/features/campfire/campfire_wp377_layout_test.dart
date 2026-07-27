// WP-377: sahip tarafından seçilen kompozisyon sayıları ve marşmelov çubuğunun
// halka genişliğine uyumu.
//
// Sayılar `campfire_wp377_preview.png` önizlemesinden seçildi (2026-07-28):
// gökyüzü üstten 85 px kırpık, halka çarpanı 1.50. Bu dosya seçimi kayda geçirir
// ki bir sonraki tur "biraz daha" diye sürüklenmesin.
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_layout.dart';

void main() {
  group('sahip seçimi', () {
    test('gökyüzü 360 → 275 kırpıldı', () {
      expect(kCampfireSceneHeight, 275);
    });

    test('kırpma yalnız gökyüzünden gitti — zemin bandı korundu', () {
      // Kırpma öncesi kompozisyon: yükseklik 360, zemin oranı 0.66.
      const previousHeight = 360.0;
      const previousGroundY = 0.66;
      const previousBand = previousHeight * (1 - previousGroundY); // 122.4 px

      final currentBand =
          kCampfireSceneHeight * (1 - kCampfireGroundYFactor);

      // 🔴 Kapan: yükseklik düşürülüp zemin oranı güncellenmezse bant daralır
      // ve sahne aşağıdan da kırpılır — hayvanların ayakları kesilir.
      expect(currentBand, closeTo(previousBand, 0.5));
    });

    test('telefon halkası 1.50', () {
      expect(kCampfirePhoneRingWidthMultiplier, 1.5);
    });
  });

  group('campfireStickReach', () {
    test('masaüstünde (ringScale 1) hiçbir şeyi değiştirmez', () {
      expect(campfireStickReach(0.76, 1), closeTo(0.76, 1e-9));
    });

    test('halka genişledikçe çubuk uzar', () {
      final atOldRing = campfireStickReach(0.76, 1.2);
      final atNewRing = campfireStickReach(0.76, 1.5);

      expect(atNewRing, greaterThan(atOldRing));
      expect(atOldRing, greaterThan(0.76));
    });

    test('ucun ateşe mutlak boşluğu halka genişliğinden bağımsızdır', () {
      // Çubuk ucu `mesafe × reach` kadar ilerler; kalan boşluk
      // `mesafe × (1 − reach)`. Halka genişleyince mesafe de aynı oranda
      // büyüdüğü için boşluk sabit kalmalı.
      const baseDistance = 100.0;
      const baseReach = 0.76;

      double gapAt(double ringScale) {
        final distance = baseDistance * ringScale;
        return distance * (1 - campfireStickReach(baseReach, ringScale));
      }

      final reference = gapAt(1);
      for (final ringScale in [1.2, 1.35, 1.5]) {
        expect(
          gapAt(ringScale),
          closeTo(reference, 0.001),
          reason: 'ringScale $ringScale için boşluk kaydı',
        );
      }
    });

    test('painter sözleşmesini bozacak değer üretmez (0 < reach < 1)', () {
      for (final base in [0.05, 0.5, 0.76, 0.95]) {
        for (final ringScale in [0.5, 1.0, 1.5, 3.0, 10.0]) {
          final reach = campfireStickReach(base, ringScale);
          expect(reach, greaterThan(0));
          expect(reach, lessThan(1));
        }
      }
    });

    test('geçersiz ölçekte tabanı korur', () {
      expect(campfireStickReach(0.76, 0), 0.76);
      expect(campfireStickReach(0.76, -1), 0.76);
    });
  });
}
