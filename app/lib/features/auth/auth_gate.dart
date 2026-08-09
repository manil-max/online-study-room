import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../data/providers/push_notification_providers.dart';
import '../../core/navigation/home_shell.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/onboarding_prefs.dart';
import '../onboarding/onboarding_screen.dart';
import '../updater/release_notes_screen.dart';
import '../updater/updater_dialog.dart';
import 'auth_screen.dart';
import 'recovery_screen.dart';

/// Oturum durumuna göre giriş ekranını veya ana uygulamayı gösterir.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  late final StreamSubscription<void> _recoverySub;

  /// WP-603: çevrimdışı açılış şeridi oturumda bir kez gösterilir.
  bool _offlineNoticeShown = false;

  @override
  void initState() {
    super.initState();
    // Uygulama açılışında bir kez güncelleme kontrolü (sadece Android'de iş yapar).
    // Sessizdir: güncelleme yoksa veya hata olursa kullanıcı hiçbir şey görmez.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await maybeShowWhatsNewDialog(context);
      if (mounted) await maybeShowUpdateDialog(context);
    });

    _recoverySub = ref
        .read(authRepositoryProvider)
        .passwordRecoveryEvents
        .listen((_) {
          if (mounted) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RecoveryScreen()));
          }
        });
  }

  @override
  void dispose() {
    _recoverySub.cancel();
    super.dispose();
  }

  /// Çevrimdışı açılışı tek bir şeritte duyurur.
  ///
  /// Kare sonuna erteleniyor: bayrak `authStateProvider` akışından kalkar ve
  /// o an ekranda henüz `Scaffold` olmayabilir; `ScaffoldMessenger` mesajı
  /// asacak bir yüzey ister.
  void _announceOfflineOpen() {
    if (_offlineNoticeShown) return;
    _offlineNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          key: const Key('auth-gate-offline-notice'),
          content: Text(AppLocalizations.of(context).authCevrimdisiAcildi),
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // WP-266: token kaydı HomeShell'e bağlı kalmasın; auth/onboarding boyunca
    // kullanıcı+tercih değişimleri server device registry ile uzlaşsın.
    ref.watch(pushLifecycleListenerProvider);
    // 🔴 WP-603: sessiz çevrimdışılık, kullanıcıya "uygulama bozuk" dedirtiyor.
    // Açılış yerel oturumla tamamlandığında bunu BİR KEZ söyle; engelleme,
    // yalnız bildir. `ref.listen` kullanılıyor çünkü olay bir DEĞİŞİM: bayrak
    // açılıştan ~2 sn sonra kalkar, `build` içinde okunan anlık değer değil.
    ref.listen<bool>(authOpenedOfflineProvider, (previous, next) {
      if (!next || previous == true) return;
      _announceOfflineOpen();
    });
    final authState = ref.watch(authStateProvider);
    final l10n = AppLocalizations.of(context);

    final onboardingDone = ref.watch(onboardingCompletedProvider);

    return authState.when(
      data: (profile) {
        if (profile == null) return const AuthScreen();
        // WP-151: ilk giriş sonrası atlanabilir onboarding.
        if (!onboardingDone) return const OnboardingScreen();
        return const HomeShell();
      },
      // 🔴 WP-593: hata dali WP-539'da cikis kazandi ama YUKLEME dali
      // duz spinner olarak kaldi. Oturum akisi hic cevap vermezse (uykuda
      // kalan istek, DNS'te asili baglanti) cember sonsuza kadar doner ve
      // kullanicinin tek caresi uygulamayi oldurmektir. Makul bir sure sonra
      // ayni cikis burada da verilir.
      loading: () => AuthGateLoadingView(
        onRetry: () => ref.invalidate(authStateProvider),
      ),
      // 🔴 WP-539: burası **çıkışsız bir ekrandı** — tek bir hata cümlesi, hiç
      // düğme yok. Oturum akışı düştüğünde (bayat refresh token, sunucuya
      // ulaşılamaması) kullanıcı ne yeniden deneyebiliyor ne de çıkıp yeniden
      // giriş yapabiliyordu; tek çare uygulamayı öldürmekti.
      error: (_, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.authOturumDurumuOkunamadi,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('auth-gate-retry'),
                  onPressed: () => ref.invalidate(authStateProvider),
                  child: Text(l10n.authTekrarDene),
                ),
                // İkinci çıkış: akışı yeniden kurmak yetmiyorsa (bozuk yerel
                // oturum) kullanıcı temiz bir giriş ekranına dönebilmeli.
                TextButton(
                  key: const Key('auth-gate-signout'),
                  onPressed: () async {
                    try {
                      await ref.read(authRepositoryProvider).signOut();
                    } catch (_) {
                      // Oturum zaten bozuksa signOut da düşebilir; kullanıcıyı
                      // burada tutmanın anlamı yok, akış yine de tazelenir.
                    }
                    ref.invalidate(authStateProvider);
                  },
                  child: Text(l10n.profileCikisYap),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yukleme dalinin "bir yere varmiyor" esigi. Cold start'ta oturum okuma
/// birkac saniye surebilir; bu sure dolduktan sonra sessiz beklemek degil
/// konusmak gerekir.
@visibleForTesting
const Duration kAuthGateLoadingTimeout = Duration(seconds: 12);

/// Once spinner, [kAuthGateLoadingTimeout] sonra cikisli mesaj.
///
/// "Tekrar dene" olu anahtar degildir: akisi yeniden kurar **ve** bekleme
/// sayacini sifirlar, yani kullanici tekrar spinner gorur.
///
/// 🔴 Gorunur (private degil) cunku `AuthGate`in kendisi `initState` icinde
/// Supabase'e bagli saglayicilar okuyor; butun kabugu widget testinde ayaga
/// kaldirmak zaman asimi davranisini olcmek icin gereksiz ve kirilgan bir
/// bagimlilik yaratirdi. Olculen sey burada dogrudan bu govdedir.
@visibleForTesting
class AuthGateLoadingView extends StatefulWidget {
  const AuthGateLoadingView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  State<AuthGateLoadingView> createState() => _AuthGateLoadingState();
}

class _AuthGateLoadingState extends State<AuthGateLoadingView> {
  Timer? _timer;
  bool _stalled = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(kAuthGateLoadingTimeout, () {
      if (mounted) setState(() => _stalled = true);
    });
  }

  void _retry() {
    widget.onRetry();
    setState(() => _stalled = false);
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: _stalled
            ? ErrorRetryView(
                message: AppLocalizations.of(context).authOturumDurumuOkunamadi,
                onRetry: _retry,
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
