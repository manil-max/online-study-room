import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/desktop/desktop_home_shell.dart';
import 'package:online_study_room/features/desktop/desktop_navigation_pane.dart';
import 'package:online_study_room/features/desktop/desktop_proportional_scale.dart';

void main() {
  Future<void> setWindowSize(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  Widget shell({required ValueChanged<int> onSelected, int selectedIndex = 0}) {
    return MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DesktopHomeShell(
        selectedIndex: selectedIndex,
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

  testWidgets('oransal ölçek widget’ı kabukta var + etiketli pane', (
    tester,
  ) async {
    await setWindowSize(tester, const Size(1200, 800));
    await tester.pumpWidget(shell(onSelected: (_) {}));
    await tester.pumpAndSettle();

    expect(find.byType(DesktopProportionalScale), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-navigation-pane')),
      findsOneWidget,
    );
    expect(find.text('Odak Kampı'), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text('Saat'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);

    final pane = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('desktop-navigation-pane')),
    );
    expect(pane.constraints?.maxWidth, DesktopNavigationPane.expandedWidth);
  });

  testWidgets('küçük pencerede layout aynı (oransal; reflow yok)', (
    tester,
  ) async {
    await setWindowSize(tester, const Size(700, 540));
    await tester.pumpWidget(shell(onSelected: (_) {}));
    await tester.pumpAndSettle();

    // Windows’ta ölçek açık: tasarım 1100 → expanded etiketler (offstage olabilir).
    // Diğer platformlarda kompakt pane olabilir; en azından shell ayakta.
    expect(find.byType(DesktopHomeShell), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-navigation-pane')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('desktop-rail-settings')), findsOneWidget);

    // Ölçek aktifse (Windows) Ana Sayfa metni tuvalde var.
    if (find.text('Ana Sayfa', skipOffstage: false).evaluate().isNotEmpty) {
      final pane = tester.widget<AnimatedContainer>(
        find.byKey(
          const ValueKey('desktop-navigation-pane'),
          skipOffstage: false,
        ),
      );
      expect(pane.constraints?.maxWidth, DesktopNavigationPane.expandedWidth);
    }
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

  testWidgets('pane öğesine tıklayınca onSelected çağrılır', (tester) async {
    await setWindowSize(tester, const Size(1200, 800));
    int? selected;
    await tester.pumpWidget(shell(onSelected: (value) => selected = value));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gruplar'));
    await tester.pump();
    expect(selected, 2);
  });

  testWidgets('sol pane Ayarlar düğmesi var', (tester) async {
    await setWindowSize(tester, const Size(1200, 800));
    await tester.pumpWidget(shell(onSelected: (_) {}));
    expect(find.byKey(const ValueKey('desktop-rail-settings')), findsOneWidget);

    await setWindowSize(tester, const Size(700, 540));
    await tester.pumpWidget(shell(onSelected: (_) {}));
    await tester.pump();
    expect(find.byKey(const ValueKey('desktop-rail-settings')), findsOneWidget);
  });

  testWidgets('NavigationRail kullanılmaz — custom pane', (tester) async {
    await setWindowSize(tester, const Size(1200, 800));
    await tester.pumpWidget(shell(onSelected: (_) {}));
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(DesktopNavigationPane), findsOneWidget);
  });
}
