import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/profile/appearance_screen.dart';
import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  testWidgets('AppearanceScreen shows predefined and custom palettes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Görünüm ve atmosfer'), findsOneWidget);
    expect(find.text('Hazır Paletler'), findsOneWidget);
    // Some predefined palettes should be found
    expect(find.text('Lacivert'), findsOneWidget);
    expect(find.text('Mor Gece'), findsOneWidget);

    // 3 custom palettes
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Özel Paletler'),
      100,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Özel Paletler'), findsOneWidget);
    expect(find.text('Özel 1'), findsOneWidget);
    expect(find.text('Özel 2'), findsOneWidget);
    expect(find.text('Özel 3'), findsOneWidget);

    // Scroll down to edit buttons
    final editButtons = find.byTooltip('Düzenle');
    await tester.scrollUntilVisible(
      editButtons.first,
      100,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(editButtons, findsNWidgets(3));

    await tester.tap(editButtons.first);
    await tester.pumpAndSettle();

    // Editor modal should open
    expect(find.text('Özel Palet 1 Düzenle'), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);

    // Just close it
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
  });
}
