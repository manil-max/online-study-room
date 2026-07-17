import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/stats/charts/area_line_chart.dart';
import 'package:online_study_room/features/stats/charts/gauge_chart.dart';
import 'package:online_study_room/features/stats/charts/radar_stat_chart.dart';
import 'package:online_study_room/features/stats/charts/series_palette.dart';
import 'package:online_study_room/features/stats/charts/stacked_bar_chart.dart';

void main() {
  testWidgets('GaugeChart renders percent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GaugeChart(progress: 0.42, label: 'goal')),
      ),
    );
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('AreaLineChart builds with values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 120,
            child: AreaLineChart(values: [1, 3, 2, 5]),
          ),
        ),
      ),
    );
    expect(find.byType(AreaLineChart), findsOneWidget);
  });

  testWidgets('StackedBarChart builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 120,
            child: StackedBarChart(
              stacks: [
                [1, 2],
                [2, 1],
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(StackedBarChart), findsOneWidget);
  });

  testWidgets('RadarStatChart builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: RadarStatChart(
              values: [0.5, 0.8, 0.3, 0.6],
              labels: ['A', 'B', 'C', 'D'],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(RadarStatChart), findsOneWidget);
  });

  test('SeriesPalette cycles colors and patterns', () {
    final p = SeriesPalette(
      const ColorScheme.light(primary: Colors.blue, tertiary: Colors.green),
    );
    expect(p.colorAt(0), isNot(equals(p.colorAt(1))));
    expect(p.patternLabel(0), isNotEmpty);
    expect(p.labeled(0, 'Math'), contains('Math'));
  });
}
