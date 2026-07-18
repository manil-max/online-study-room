import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/features/stats/widgets/stats_period_bar.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-190: tek yatay satır (scroll, Wrap yok) + kompakt kıyas; textScale 1.3.
void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    double textScale = 1.0,
    double width = 360,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: SizedBox(width: width, child: const StatsPeriodBar()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('single horizontal row: scroll not Wrap; 6 periods + compare',
      (tester) async {
    await pumpBar(tester, width: 280);

    expect(find.byType(Wrap), findsNothing);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byIcon(Icons.compare_arrows), findsOneWidget);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);

    // Chip satırı + kıyas aynı yükseklik bandında (~44)
    final bar = tester.getRect(find.byType(StatsPeriodBar));
    expect(bar.height, lessThan(90), reason: 'header stays compact single row');
  });

  testWidgets('compare icon toggles comparePrevious', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: StatsPeriodBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(statsPeriodProvider).comparePrevious, isFalse);
    await tester.tap(find.byIcon(Icons.compare_arrows));
    await tester.pumpAndSettle();
    expect(container.read(statsPeriodProvider).comparePrevious, isTrue);
  });

  testWidgets('textScale 1.3 does not overflow', (tester) async {
    await pumpBar(tester, textScale: 1.3, width: 320);
    expect(tester.takeException(), isNull);
    expect(find.byType(StatsPeriodBar), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);
  });
}
