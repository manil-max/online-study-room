import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/main.dart' show resolveAppLocale;

void main() {
  group('resolveAppLocale', () {
    const supported = <Locale>[Locale('en'), Locale('tr')];

    test('selects Turkish only for a Turkish system locale', () {
      expect(
        resolveAppLocale(const Locale('tr', 'TR'), supported),
        const Locale('tr'),
      );
      expect(
        resolveAppLocale(const Locale('tr'), supported),
        const Locale('tr'),
      );
    });

    test('falls back to English for unsupported or missing locales', () {
      // WP-155: de/ar desteklenir; fr ve bilinmeyen → en.
      for (final locale in <Locale?>[
        const Locale('en', 'US'),
        const Locale('en', 'GB'),
        const Locale('fr', 'FR'),
        null,
      ]) {
        expect(resolveAppLocale(locale, supported), const Locale('en'));
      }
    });

    test('maps supported system locales de and ar', () {
      expect(
        resolveAppLocale(const Locale('de', 'DE'), supported),
        const Locale('de'),
      );
      expect(
        resolveAppLocale(const Locale('ar', 'SA'), supported),
        const Locale('ar'),
      );
    });
  });

  testWidgets('loads the generated English and Turkish catalogs', (
    tester,
  ) async {
    Future<void> pumpCatalog(Locale locale) {
      return tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Text(AppLocalizations.of(context).appTitle),
          ),
        ),
      );
    }

    await pumpCatalog(const Locale('en'));
    expect(find.text('Focus Camp'), findsOneWidget);

    await pumpCatalog(const Locale('tr'));
    expect(find.text('Odak Kampı'), findsOneWidget);
  });

  testWidgets('MaterialApp applies the system-locale fallback contract', (
    tester,
  ) async {
    Future<void> pumpWithSystemLocale(Locale locale) async {
      tester.binding.platformDispatcher.localesTestValue = <Locale>[locale];
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(locale),
          localeResolutionCallback: resolveAppLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) =>
                Text(Localizations.localeOf(context).toString()),
          ),
        ),
      );
    }

    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    // WP-155: Almanca sistem dili artık de (EN baseline ARB), fr → en.
    await pumpWithSystemLocale(const Locale('fr', 'FR'));
    expect(find.text('en'), findsOneWidget);

    await pumpWithSystemLocale(const Locale('de', 'DE'));
    expect(find.text('de'), findsOneWidget);

    await pumpWithSystemLocale(const Locale('tr', 'TR'));
    expect(find.text('tr'), findsOneWidget);
  });
}
