import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/stats/widgets/member_chart_colors.dart';

void main() {
  test(
    'her grup büyüklüğünde üye renkleri tekil ve sıralamadan bağımsızdır',
    () {
      const surface = Color(0xFF12161E);
      final colors = memberChartColors([
        'minik-kus',
        'onur',
        'm-anil',
        'annis',
      ], surface: surface);
      final reordered = memberChartColors([
        'onur',
        'annis',
        'minik-kus',
        'm-anil',
      ], surface: surface);
      final largeGroup = memberChartColors(
        List.generate(24, (index) => 'uye-$index'),
        surface: surface,
      );

      expect(colors.values.toSet(), hasLength(4));
      expect(reordered, colors);
      expect(reordered['onur'], colors['onur']);
      expect(largeGroup.values.toSet(), hasLength(24));
    },
  );
}
