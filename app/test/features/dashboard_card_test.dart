import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';

void main() {
  group('DashboardCardConfig serileştirme', () {
    test('yükseklik yoksa "tür:genişlik" olarak kodlar/çözer', () {
      const c = DashboardCardConfig(DashboardCardType.weekly, width: 8);
      expect(c.encode(), 'weekly:8');
      final back = DashboardCardConfig.decode(c.encode());
      expect(back, c);
      expect(back!.height, isNull);
    });

    test('yükseklik ayarlıysa "tür:genişlik:yükseklik" gidiş-dönüş', () {
      const c = DashboardCardConfig(DashboardCardType.line,
          width: 12, height: 300);
      expect(c.encode(), 'line:12:300');
      final back = DashboardCardConfig.decode('line:12:300');
      expect(back!.width, 12);
      expect(back.height, 300);
    });

    test('geriye uyum: sade "tür" tam genişlik, yükseklik varsayılan', () {
      final back = DashboardCardConfig.decode('timer');
      expect(back!.width, kGridColumns);
      expect(back.height, isNull);
      expect(back.effectiveHeight, defaultCardHeight(back.size));
    });

    test('geriye uyum: eski "tür:small" yarım genişlik', () {
      final back = DashboardCardConfig.decode('today:small');
      expect(back!.width, kGridColumns ~/ 2);
      expect(back.height, isNull);
    });

    test('yükseklik sınırlara kırpılır', () {
      expect(DashboardCardConfig.decode('records:6:9999')!.height,
          kMaxCardHeight);
      expect(DashboardCardConfig.decode('records:6:10')!.height,
          kMinCardHeight);
      expect(const DashboardCardConfig(DashboardCardType.records)
          .withHeight(9999)
          .height,
          kMaxCardHeight);
    });

    test('withWidth yüksekliği korur', () {
      const c = DashboardCardConfig(DashboardCardType.goal,
          width: 4, height: 250);
      expect(c.withWidth(8).height, 250);
    });
  });
}
