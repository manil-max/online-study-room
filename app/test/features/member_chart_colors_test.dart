import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/stats/widgets/member_chart_colors.dart';

void main() {
  test(
    'her grup büyüklüğünde üye renkleri tekil ve sıralamadan bağımsızdır',
    () {
      final colors = memberChartColors([
        'minik-kus',
        'onur',
        'm-anil',
        'annis',
      ]);
      final reordered = memberChartColors([
        'onur',
        'annis',
        'minik-kus',
        'm-anil',
      ]);
      final largeGroup = memberChartColors(
        List.generate(24, (index) => 'uye-$index'),
      );

      expect(colors.values.toSet(), hasLength(4));
      expect(reordered, colors);
      expect(reordered['onur'], colors['onur']);
      expect(largeGroup.values.toSet(), hasLength(24));
    },
  );
}
