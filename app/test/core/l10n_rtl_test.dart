import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  test('resolve locales for the EN/TR-only package', () {
    expect(
      resolvePreferredAppLocale(
        const Locale('ar'),
        AppLanguage.system,
      ).languageCode,
      'en',
    );
    // EN/TR regression
    expect(
      resolvePreferredAppLocale(
        const Locale('tr'),
        AppLanguage.system,
      ).languageCode,
      'tr',
    );
    expect(
      resolvePreferredAppLocale(
        const Locale('fr'),
        AppLanguage.system,
      ).languageCode,
      'en',
    );
  });

  test('EN/TR-only package has no RTL locale', () {
    expect(isRtlLocale(const Locale('ar')), isFalse);
    expect(isRtlLocale(const Locale('en')), isFalse);
    expect(isRtlLocale(const Locale('tr')), isFalse);
    expect(textDirectionForLocale(const Locale('ar')), TextDirection.ltr);
    expect(textDirectionForLocale(const Locale('en')), TextDirection.ltr);
  });

  testWidgets('unsupported Arabic falls back to EN/LTR', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: resolvePreferredAppLocale(
          const Locale('ar'),
          AppLanguage.system,
        ),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            final dir = Directionality.of(context);
            return Text(dir == TextDirection.rtl ? 'rtl' : 'ltr');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ltr'), findsOneWidget);
  });

  testWidgets('TR and EN localizations still load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Text(AppLocalizations.of(context).statsBugun),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bugün'), findsOneWidget);
  });
}
