import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/onboarding/onboarding_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    setActiveAppLocale(const Locale('en'));
  });

  testWidgets('first onboarding page offers and persists a language choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const _LocalizedOnboardingHost(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('onboarding-language-choice')), findsOne);
    expect(find.byKey(const ValueKey('onboarding-language-system')), findsOne);
    expect(find.byKey(const ValueKey('onboarding-language-turkish')), findsOne);
    expect(find.byKey(const ValueKey('onboarding-language-english')), findsOne);

    final turkishChoice = find.byKey(
      const ValueKey('onboarding-language-turkish'),
    );
    await Scrollable.ensureVisible(
      tester.element(turkishChoice),
      alignment: 0.5,
    );
    await tester.pump();
    final scrollRect = tester.getRect(find.byType(SingleChildScrollView));
    final choiceRect = tester.getRect(turkishChoice);
    expect(choiceRect.top, greaterThanOrEqualTo(scrollRect.top));
    expect(choiceRect.bottom, lessThanOrEqualTo(scrollRect.bottom));
    final button = tester.widget<OutlinedButton>(turkishChoice);
    expect(button.onPressed, isNotNull);
    await tester.tap(turkishChoice);
    await tester.pumpAndSettle();

    expect(prefs.getString('app_language_preference'), 'turkish');
    expect(
      find.byKey(const ValueKey('onboarding-language-choice')),
      findsNothing,
    );
    expect(
      Localizations.localeOf(tester.element(find.byType(OnboardingScreen))),
      const Locale('tr'),
    );
  });

  testWidgets('stored preference does not repeat the first-page choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app_language_preference': AppLanguage.system.name,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const _LocalizedOnboardingHost(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('onboarding-language-choice')),
      findsNothing,
    );
  });
}

class _LocalizedOnboardingHost extends ConsumerWidget {
  const _LocalizedOnboardingHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(appLanguageProvider);
    return MaterialApp(
      locale: resolvePreferredAppLocale(const Locale('en'), preference),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const OnboardingScreen(),
    );
  }
}
