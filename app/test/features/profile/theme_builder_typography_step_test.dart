import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_builder_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-310 / WP-311 — sahip geri bildirimi:
/// "font seçme kısmında butonlar sabit olsun, bastıkça yer değiştiriyor" ve
/// "fontlarda bazı ayarı değiştiriyoruz neye etki ediyor görünmüyor".
Future<void> _openTypographyStep(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ThemeBuilderScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // 3. adım: Yazılar.
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('WP-310: font çipleri seçimde yer değiştirmez', (tester) async {
    await _openTypographyStep(tester);

    final chips = find.byType(ChoiceChip);
    expect(chips, findsWidgets);

    List<Rect> rects() => [
      for (var i = 0; i < tester.widgetList(chips).length; i++)
        tester.getRect(chips.at(i)),
    ];

    final before = rects();
    // "Tırnaklı" başlık fontu seçilir — ilk seçicideki ikinci çip.
    await tester.tap(chips.at(1));
    await tester.pumpAndSettle();
    final afterFirst = rects();
    expect(afterFirst, before, reason: 'seçim çiplerin ölçüsünü değiştirmemeli');

    // İkinci bir seçim de aynı yerleşimi korumalı.
    await tester.tap(chips.at(3));
    await tester.pumpAndSettle();
    expect(rects(), before);
  });

  testWidgets('WP-311: yazı adımında önizleme etiketli örnek gösterir', (
    tester,
  ) async {
    await _openTypographyStep(tester);

    // Üç font seçicisinin başlığı hem adımda hem önizlemede görünür:
    // önizleme artık hangi seçimin nereye dokunduğunu adıyla söylüyor.
    expect(find.text('Başlık yazı tipi'), findsNWidgets(2));
    expect(find.text('Gövde yazı tipi'), findsNWidgets(2));
    expect(find.text('Sayaç yazı tipi'), findsNWidgets(2));
    expect(find.text('00:42:18'), findsOneWidget);
  });
}
