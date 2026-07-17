import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  test('resolve locales for new packages', () {
    expect(
      resolvePreferredAppLocale(null, AppLanguage.arabic).languageCode,
      'ar',
    );
    expect(
      resolvePreferredAppLocale(null, AppLanguage.german).languageCode,
      'de',
    );
    expect(
      resolvePreferredAppLocale(const Locale('ar'), AppLanguage.system)
          .languageCode,
      'ar',
    );
    expect(
      resolvePreferredAppLocale(const Locale('de'), AppLanguage.system)
          .languageCode,
      'de',
    );
    // EN/TR regression
    expect(
      resolvePreferredAppLocale(const Locale('tr'), AppLanguage.system)
          .languageCode,
      'tr',
    );
    expect(
      resolvePreferredAppLocale(const Locale('fr'), AppLanguage.system)
          .languageCode,
      'en',
    );
  });

  test('RTL only for Arabic', () {
    expect(isRtlLocale(const Locale('ar')), isTrue);
    expect(isRtlLocale(const Locale('en')), isFalse);
    expect(isRtlLocale(const Locale('tr')), isFalse);
    expect(isRtlLocale(const Locale('de')), isFalse);
    expect(textDirectionForLocale(const Locale('ar')), TextDirection.rtl);
    expect(textDirectionForLocale(const Locale('en')), TextDirection.ltr);
  });

  testWidgets('Arabic MaterialApp is RTL; EN is LTR', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
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
    expect(find.text('rtl'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
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
          builder: (context) =>
              Text(AppLocalizations.of(context).statsBugun),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bugün'), findsOneWidget);
  });
}
