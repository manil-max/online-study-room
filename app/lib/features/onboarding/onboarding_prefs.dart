import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/prefs/app_prefs.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/models/profile.dart';

/// WP-151/166: onboarding tamam bayrağı (kullanıcıya özel).
///
/// Eski cihaz geneli `onboarding.completed_v1` hesap değişiminde yanlış hesaba
/// taşırdı (WP-166). Kalıcı anahtar: `onboarding.completed_v1.<userId>`.
const kOnboardingCompletedV1 = 'onboarding.completed_v1';

String onboardingCompletedKeyFor(String userId) =>
    '$kOnboardingCompletedV1.$userId';

/// Prefs yazımı (saf); test ve notifier ortak.
Future<void> persistOnboardingComplete(
  SharedPreferences prefs,
  String userId,
) async {
  await prefs.setBool(onboardingCompletedKeyFor(userId), true);
  await prefs.remove(kOnboardingCompletedV1);
}

Future<void> persistOnboardingReset(
  SharedPreferences prefs,
  String? userId,
) async {
  if (userId != null) {
    await prefs.setBool(onboardingCompletedKeyFor(userId), false);
  }
  await prefs.remove(kOnboardingCompletedV1);
}

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final auth = ref.watch(authStateProvider);

    // Auth yüklenene kadar "tamam" sayma — aksi halde AuthGate kısa süre HomeShell'e kaçar.
    if (auth.isLoading) return false;

    final Profile? user = auth.asData?.value;
    // Çıkışlı: AuthGate AuthScreen gösterir; true = onboarding engeli yok.
    if (user == null) return true;

    return prefs.getBool(onboardingCompletedKeyFor(user.id)) ?? false;
  }

  Future<void> complete() async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    await persistOnboardingComplete(
      ref.read(sharedPreferencesProvider),
      user.id,
    );
    state = true;
  }

  /// Test / ayarlardan yeniden göster (yalnız aktif kullanıcı).
  Future<void> reset() async {
    final user = ref.read(authStateProvider).asData?.value;
    await persistOnboardingReset(
      ref.read(sharedPreferencesProvider),
      user?.id,
    );
    state = false;
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
