import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:online_study_room/features/desktop/desktop_navigation_pane.dart';

import '../test/support/v8_test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('girişli kullanıcı V8 ana yüzeylerine cihazda geçebilir', (
    tester,
  ) async {
    final preferences = await v8SharedPreferences();
    final auth = await signedInV8AuthRepository(prefs: preferences);

    await tester.pumpWidget(
      buildV8TestApp(authRepository: auth, preferences: preferences),
    );
    await tester.pumpAndSettle();

    expect(_selectedNavigationIndex(tester), 0);
    // 2 = Gruplar, 4 = Profil (home_shell destinations)
    _selectNavigationDestination(tester, 2);
    await tester.pumpAndSettle();
    expect(_selectedNavigationIndex(tester), 2);
    _selectNavigationDestination(tester, 4);
    await tester.pumpAndSettle();
    expect(_selectedNavigationIndex(tester), 4);
  });
}

int _selectedNavigationIndex(WidgetTester tester) {
  final desktopPane = find.byType(DesktopNavigationPane);
  if (desktopPane.evaluate().isNotEmpty) {
    return tester.widget<DesktopNavigationPane>(desktopPane).selectedIndex;
  }
  final mobileNavigation = find.byType(NavigationBar);
  return tester.widget<NavigationBar>(mobileNavigation).selectedIndex;
}

void _selectNavigationDestination(WidgetTester tester, int index) {
  final desktopPane = find.byType(DesktopNavigationPane);
  if (desktopPane.evaluate().isNotEmpty) {
    tester.widget<DesktopNavigationPane>(desktopPane).onSelected(index);
    return;
  }
  tester.widget<NavigationBar>(find.byType(NavigationBar)).onDestinationSelected!(
    index,
  );
}
