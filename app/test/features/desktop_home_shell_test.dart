import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/desktop/desktop_home_shell.dart';

void main() {
  Future<void> setWindowSize(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  Widget shell({required ValueChanged<int> onSelected}) {
    return MaterialApp(
      home: DesktopHomeShell(
        selectedIndex: 0,
        screens: const [
          ColoredBox(color: Colors.red),
          ColoredBox(color: Colors.orange),
          ColoredBox(color: Colors.yellow),
          ColoredBox(color: Colors.green),
          ColoredBox(color: Colors.blue),
        ],
        onDestinationSelected: onSelected,
        onRefresh: () {},
      ),
    );
  }

  testWidgets('1008 px ve üstünde geniş navigation rail gösterir', (
    tester,
  ) async {
    await setWindowSize(tester, const Size(1200, 800));
    await tester.pumpWidget(shell(onSelected: (_) {}));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text('Odak Kampı'), findsOneWidget);
  });

  testWidgets('kompakt genişlikte rail genişlemez', (tester) async {
    await setWindowSize(tester, const Size(800, 700));
    await tester.pumpWidget(shell(onSelected: (_) {}));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('Ctrl+1…5 hedef sekmeyi seçer', (tester) async {
    await setWindowSize(tester, const Size(1200, 800));
    int? selected;
    await tester.pumpWidget(shell(onSelected: (value) => selected = value));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(selected, 3);
  });
}
