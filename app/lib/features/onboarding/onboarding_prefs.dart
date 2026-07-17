import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/app_prefs.dart';

/// WP-151: ilk açılış tamamlandı bayrağı.
const kOnboardingCompletedV1 = 'onboarding.completed_v1';

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(kOnboardingCompletedV1) ?? false;
  }

  Future<void> complete() async {
    await ref.read(sharedPreferencesProvider).setBool(kOnboardingCompletedV1, true);
    state = true;
  }

  /// Test / ayarlardan yeniden göster.
  Future<void> reset() async {
    await ref.read(sharedPreferencesProvider).setBool(kOnboardingCompletedV1, false);
    state = false;
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
