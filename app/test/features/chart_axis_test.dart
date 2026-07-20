import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/stats/widgets/chart_axis.dart';

void main() {
  group('WP-237 axisLabelStep', () {
    test('yer varken her etiket (adım 1)', () {
      // 14 gün, 380px, ~22px/etiket → ~17 kapasite → hepsi sığar.
      expect(axisLabelStep(14, 380), 1);
      expect(axisLabelStep(7, 200), 1);
    });

    test('dar alanda çakışmayacak adım seçer', () {
      // 30 gün, 200px → ~9 kapasite → adım ceil(30/9)=4.
      final step = axisLabelStep(30, 200);
      expect(step, greaterThan(1));
      expect((30 / step).ceil(), lessThanOrEqualTo((200 / 22).floor()));
    });

    test('genişlik bilinmiyorsa her etiket', () {
      expect(axisLabelStep(30, 0), 1);
      expect(axisLabelStep(30, -5), 1);
    });

    test('tek/boş seri', () {
      expect(axisLabelStep(1, 100), 1);
      expect(axisLabelStep(0, 100), 1);
    });
  });

  group('WP-237 Y ekseni', () {
    test('niceMinuteInterval ~4 aralık verir', () {
      // maxY 120dk → hedef 30 → aday 30.
      expect(niceMinuteInterval(120), 30);
      // maxY 60 → hedef 15 → 15.
      expect(niceMinuteInterval(60), 15);
      // 0/negatif → güvenli 15.
      expect(niceMinuteInterval(0), 15);
    });

    test('axisUsesHours eşiği 90 dk', () {
      expect(axisUsesHours(89), isFalse);
      expect(axisUsesHours(90), isTrue);
      expect(axisUsesHours(200), isTrue);
    });
  });
}
