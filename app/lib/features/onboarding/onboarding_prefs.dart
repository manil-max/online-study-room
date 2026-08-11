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
    //
    // 🔴 WP-709: koşul ÖNCE düz `auth.isLoading` idi ve günlük hedef
    // kaydedildikten sonra kullanıcıya bir kare TANITIM EKRANI çiziyordu.
    // Zincir: `settings_screen.dart` yazmadan sonra
    // `ref.invalidate(authStateProvider)` çağırır → akış yeniden kurulur ve
    // `SupabaseAuthRepository._sessionProfiles` ilk `yield`den önce `profiles`
    // satırını ağdan çeker. O pencerede durum "önceki değeri taşıyan
    // `AsyncLoading`"tır (`isRefreshing`): `AuthGate` `when`i varsayılan
    // `skipLoadingOnRefresh: true` ile hala VERİ dalını çizer, ama burası
    // `false` döndüğü için kapı `OnboardingScreen`e geçiyordu.
    //
    // Bilinmezlik yalnız DEĞER YOKKEN gerçektir; yeniden yükleme sırasında
    // önceki profil elimizdedir. Aynı ders: `asData` yeniden yüklemede boşalır,
    // `value` önceki değeri korur (`docs/qa/V58-ASYNC-EMPTY-AUDIT.md §1`).
    if (auth.isLoading && !auth.hasValue) return false;

    final Profile? user = auth.value;
    // Çıkışlı: AuthGate AuthScreen gösterir; true = onboarding engeli yok.
    if (user == null) return true;

    return prefs.getBool(onboardingCompletedKeyFor(user.id)) ?? false;
  }

  Future<void> complete() async {
    // 🔴 WP-716: `asData?.value` idi. `asData` **yeniden yükleme**
    // (watch bağımlılığı değişti, `isRefresh: false`) durumunda boşalır;
    // `value` önceki profili korur. Kullanıcı elimizdeyken sessizce çıkmak,
    // "Atla"yı ölü düğmeye çevirir: bayrak diske yazılmaz, hata da görünmez.
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    await persistOnboardingComplete(
      ref.read(sharedPreferencesProvider),
      user.id,
    );
    state = true;
  }

  /// Test / ayarlardan yeniden göster (yalnız aktif kullanıcı).
  Future<void> reset() async {
    // WP-716: aynı tuzak. Kimlik boş gelirse [persistOnboardingReset] yalnız
    // eski cihaz-geneli anahtarı siler, kullanıcıya özel bayrağı `false`
    // yapmaz — sıfırlama ilk yeniden yüklemede kendini geri alırdı.
    final user = ref.read(authStateProvider).value;
    await persistOnboardingReset(
      ref.read(sharedPreferencesProvider),
      user?.id,
    );
    state = false;
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
