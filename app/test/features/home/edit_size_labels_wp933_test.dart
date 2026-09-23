// WP-933 — pano düzenlemede ızgara ölçüsü ("32×28") yerine insan diliyle
// boyut (Küçük / Orta / Büyük / Geniş).
//
// 🔴 Kusur: her kartın üstündeki çipte ve alttaki boyut panelinde "32×28",
// "16×16" gibi ızgara hücre sayıları yazıyordu; panel metni ayrıca
// "Boyut 32×28 • dok…" diye kesiliyordu.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

DashboardCardConfig _c(int w, int h) =>
    DashboardCardConfig(DashboardCardType.tasks, w: w, h: h);

Future<void> _pumpEditing(WidgetTester tester, Locale locale) async {
  SharedPreferences.setMockInitialValues({
    'dashboard_layout_v2_32': <String>[
      'timer:0:0:32:28',
      'today:0:28:16:16',
      'tasks:0:44:32:12',
    ],
    'dashboard_grid_last_columns': 32,
  });
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: HomeScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.longPress(find.byType(Card).first);
  await tester.pump(const Duration(milliseconds: 600));
}

List<String> _texts(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    if (t.data != null) t.data!,
];

void main() {
  test('boyut siniflari: sayac Buyuk, yarim kart Orta, kisa serit Genis', () {
    final l10n = lookupAppLocalizations(const Locale('tr'));
    expect(_c(32, 28).humanSizeLabel(l10n, 32), l10n.homeBuyuk);
    expect(_c(16, 16).humanSizeLabel(l10n, 32), l10n.homeOrta);
    expect(_c(32, 12).humanSizeLabel(l10n, 32), l10n.homeGenis);
    expect(_c(32, 16).humanSizeLabel(l10n, 32), l10n.homeGenis);
    expect(_c(8, 8).humanSizeLabel(l10n, 32), l10n.homeKucuk);
  });

  for (final locale in const [Locale('tr'), Locale('en')]) {
    testWidgets('duzenleme modunda izgara olcusu yazmaz '
        '(${locale.languageCode})', (tester) async {
      await _pumpEditing(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final grid = RegExp(r'\d+\s*×\s*\d+');

      expect(
        _texts(tester).where(grid.hasMatch),
        isEmpty,
        reason: 'Kart ciplerinde "32×28" gibi izgara olcusu yaziyor.',
      );
      expect(find.text(l10n.homeBuyuk), findsOneWidget);
      expect(find.text(l10n.homeOrta), findsOneWidget);
      expect(find.text(l10n.homeGenis), findsOneWidget);

      // Boyut paneli (secili kart = ilk kart, sayac).
      expect(
        find.text(l10n.homeKartBoyutEtiketi(l10n.homeBuyuk)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
