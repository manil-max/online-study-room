import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/theme_presets.dart';
import 'package:online_study_room/features/profile/theme_studio_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Tema Stüdyosu 12 aile listeler ve canlı önizleme gösterir',
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
    expect(find.text('Campfire Night'), findsOneWidget);
    expect(find.textContaining('Deep AMOLED'), findsWidgets);
    // 12 preset isimleri scroll edilebilir listede
    await tester.scrollUntilVisible(
      find.text('Material You'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Material You'), findsOneWidget);
    expect(kThemePresets.length, 12);
  });
}
