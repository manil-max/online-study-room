import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/onboarding/onboarding_prefs.dart';
import 'package:online_study_room/features/onboarding/onboarding_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('complete sets onboarding.completed_v1', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(onboardingCompletedProvider), isFalse);
    await container.read(onboardingCompletedProvider.notifier).complete();
    expect(container.read(onboardingCompletedProvider), isTrue);
    expect(prefs.getBool(kOnboardingCompletedV1), isTrue);
  });

  test('reset clears flag', () async {
    SharedPreferences.setMockInitialValues({kOnboardingCompletedV1: true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(onboardingCompletedProvider), isTrue);
    await container.read(onboardingCompletedProvider.notifier).reset();
    expect(container.read(onboardingCompletedProvider), isFalse);
  });

  testWidgets('skip finishes onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('tr'),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('hoş geldin', findRichText: true), findsWidgets);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(prefs.getBool(kOnboardingCompletedV1), isTrue);
  });
}
