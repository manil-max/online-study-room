import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/theme_presets.dart';
import 'package:online_study_room/features/profile/theme_studio_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Tema Stüdyosu atmosfer ailelerini listeler ve canlı önizleme gösterir',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: ThemeStudioScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tema Stüdyosu'), findsOneWidget);
    expect(find.text('Canlı önizleme'), findsOneWidget);
    expect(find.text('Kamp Ateşi'), findsOneWidget);
    expect(find.textContaining('Keskin Modern'), findsWidgets);
    // Yeni atmosferler + Material You scroll ile erişilebilir
    await tester.scrollUntilVisible(
      find.text('Buzul'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Buzul'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Gelecek Kenarı'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Gelecek Kenarı'), findsOneWidget);
    expect(kThemePresets.length, greaterThanOrEqualTo(15));
  });
}
