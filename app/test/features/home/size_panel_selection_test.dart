import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/home_screen.dart';

/// WP-291: Sabit alt boyut paneli, `effectiveSelectedConfig` ile hangi karta
/// bağlanacağını belirler. Panel grid'in altındaki akıştan çıkıp bottomSheet'e
/// taşındığı için bu mantık artık tek bir saf fonksiyonda; testi burada.
void main() {
  const a = DashboardCardConfig(DashboardCardType.timer, x: 0, y: 0, w: 2, h: 2);
  const b = DashboardCardConfig(DashboardCardType.goal, x: 0, y: 2, w: 2, h: 1);

  group('effectiveSelectedConfig', () {
    test('düzen boşsa null', () {
      expect(effectiveSelectedConfig(const [], DashboardCardType.timer), isNull);
    });

    test('seçim yoksa ilk karta düşer', () {
      expect(effectiveSelectedConfig(const [a, b], null)?.type,
          DashboardCardType.timer);
    });

    test('seçili kart düzendeyse onu döndürür', () {
      expect(effectiveSelectedConfig(const [a, b], DashboardCardType.goal)?.type,
          DashboardCardType.goal);
    });

    test('seçili kart silinmişse ilk karta düşer (panel boş kalmaz)', () {
      expect(
        effectiveSelectedConfig(const [a, b], DashboardCardType.records)?.type,
        DashboardCardType.timer,
      );
    });
  });
}
