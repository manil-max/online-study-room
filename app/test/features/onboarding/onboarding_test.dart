import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/onboarding/onboarding_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('per-user prefs keys do not cross accounts', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await persistOnboardingComplete(prefs, 'user-a');
    expect(prefs.getBool(onboardingCompletedKeyFor('user-a')), isTrue);
    expect(prefs.getBool(onboardingCompletedKeyFor('user-b')), isNull);
    expect(prefs.getBool(kOnboardingCompletedV1), isNull);
    expect(
      onboardingCompletedKeyFor('user-a'),
      isNot(equals(kOnboardingCompletedV1)),
    );
  });

  test('legacy global alone is not a per-user completion', () async {
    SharedPreferences.setMockInitialValues({kOnboardingCompletedV1: true});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingCompletedKeyFor('user-x')), isNull);
    // complete for user-x clears legacy and sets only per-user.
    await persistOnboardingComplete(prefs, 'user-x');
    expect(prefs.getBool(onboardingCompletedKeyFor('user-x')), isTrue);
    expect(prefs.getBool(kOnboardingCompletedV1), isNull);
  });

  test('reset clears only active user key and legacy', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await persistOnboardingComplete(prefs, 'user-a');
    await persistOnboardingComplete(prefs, 'user-b');
    await persistOnboardingReset(prefs, 'user-a');
    expect(prefs.getBool(onboardingCompletedKeyFor('user-a')), isFalse);
    expect(prefs.getBool(onboardingCompletedKeyFor('user-b')), isTrue);
  });
}
