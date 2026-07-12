import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/v8_test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('girişli kullanıcı V8 ana yüzeylerine cihazda geçebilir', (
    tester,
  ) async {
    final auth = await signedInV8AuthRepository();
    final preferences = await v8SharedPreferences();

    await tester.pumpWidget(
      buildV8TestApp(authRepository: auth, preferences: preferences),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Sayfa'), findsWidgets);
    var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    navigation.onDestinationSelected!(3);
    await tester.pumpAndSettle();
    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 3);
    navigation.onDestinationSelected!(4);
    await tester.pumpAndSettle();
    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 4);
    expect(find.text('Aktif grup'), findsOneWidget);
  });
}
