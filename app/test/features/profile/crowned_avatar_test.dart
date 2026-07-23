import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/progression_visuals.dart';
import 'package:online_study_room/core/widgets/crowned_avatar.dart';

void main() {
  testWidgets('CrownedAvatar paints crown + ring, not workspace_premium', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CrownedAvatar(
              displayName: 'Ada',
              radius: 32,
              crownRank: 'gold_achiever',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CrownedAvatar), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byIcon(Icons.workspace_premium), findsNothing);
    // WP-195b: taç CustomPaint boyutu ~%18 daha büyük (1.15→1.36, 0.75→0.89).
    final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    final crown = paints.where((p) => p.painter is CrownPainter).first;
    expect(crown.size.width, closeTo(32 * 1.36, 0.01));
    expect(crown.size.height, closeTo(32 * 0.89, 0.01));
  });

  test('xpBarMetrics crown thresholds progress', () {
    final m = xpBarMetrics(5000);
    expect(m.currentXp, 5000);
    expect(m.nextThreshold, 20000);
    expect(m.progress, greaterThan(0));
    expect(m.progress, lessThanOrEqualTo(1));
    expect(m.next, greaterThan(m.floor));
  });
}
