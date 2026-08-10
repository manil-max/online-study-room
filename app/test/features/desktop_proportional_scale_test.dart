// 🔴 WP-672 / SPEC §0 — bu dosyanın sözleşmesi TERSİNE ÇEVRİLDİ.
//
// Eski testler ölçeğin BÜYÜTMESİNİ doğruluyordu ("büyük monitörde maxScale
// tavanı → 1.5"). Doğruladıkları davranış tam olarak sahibin reddettiği
// davranıştı: masaüstü arayüzü yeniden düzenlenmiyor, büyütülüyordu. Yeşil
// bir test yanlış bir sözleşmeyi koruyabilir; buradaki ders bu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/desktop/desktop_proportional_scale.dart';

void main() {
  group('desktopProportionalScale — artık 1:1', () {
    test('SPEC §8 iddia 1: 2000×1200 → 1.0 (ÖNCE: 1.5)', () {
      expect(desktopProportionalScale(viewport: const Size(2000, 1200)), 1.0);
    });

    test('hiçbir genişlikte büyütmez', () {
      for (final w in const [1100.0, 1280.0, 1440.0, 1600.0, 1920.0, 2560.0]) {
        expect(
          desktopProportionalScale(viewport: Size(w, 1000)),
          1.0,
          reason: '$w px’te ölçek 1 değil',
        );
      }
    });

    test('dar pencerede küçültmez — metin %65’e inmez', () {
      // ÖNCE: 550 px’te 0.65 dönüyordu; 10 px’lik ipucu satırı 6.5 px’e
      // düşüyor ve okunmuyordu. Dar pencerenin doğru cevabı kırılım noktasıdır.
      expect(desktopProportionalScale(viewport: const Size(550, 900)), 1.0);
      expect(desktopProportionalScale(viewport: const Size(700, 600)), 1.0);
    });

    test('sıfır/negatif genişlikte güvenli', () {
      expect(desktopProportionalScale(viewport: const Size(0, 100)), 1.0);
    });

    testWidgets('sarmalayıcı çocuğu olduğu gibi geçirir (MediaQuery ezmez)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(2000, 1200);
      addTearDown(tester.view.reset);

      double? seen;
      await tester.pumpWidget(
        MaterialApp(
          // ignore: deprecated_member_use_from_same_package
          home: DesktopProportionalScale(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.sizeOf(context).width;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      expect(seen, 2000);
      expect(find.byType(FittedBox), findsNothing);
    });
  });
}
