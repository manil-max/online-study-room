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

/// 🔴 WP-741: cevrimdisilik iddiasinin ZARIF BEKLEME suresi.
///
/// Sahip (2026-08-22, gercek cihaz): "internet bagli olmasina ragmen bazen
/// uygulamayi acinca altta 'internet yok' uyarisi geciyor, ama internet var ve
/// uygulamayi normal kullaniyorum."
///
/// Kok neden: `kAuthColdStartBudget` (2 sn) bir **GECIKME** olcusudur,
/// baglanti olcusu degil. Soguk acilista saglikli agda da dolabilir
/// (DNS isinmasi, hucresel el sikismasi, ilk TLS turu). Butce dolar dolmaz
/// "Internet yok" demek, olculmemis bir iddiayi kullaniciya gercek diye
/// sunmaktir.
///
/// Cozum butceyi BUYUTMEK degil: butce uygulamanin ne zaman ACILDIGINI
/// belirler ve WP-603'un kazanimidir (cemberde takilmama) — buyutmek dogrudan
/// o kazanimi geri alirdi. Bunun yerine **acilis** ile **iddia** ayrilir:
/// uygulama yine 2 sn'de acilir, iddia bu kadar daha beklenir ve bu sure
/// icinde akis konusursa hic soylenmez.
///
/// 4 saniye secildi: iddiayi 2 + 4 = 6 sn'ye tasir. Gercekten cevrimdisi
/// cihaz o pencerede cevap veremez (olculen zincir 10 sn token tazeleme + 10
/// sn istek tavani, bkz. `kAuthColdStartBudget`), yani gercek cevrimdisi
/// kullanici uyariyi almaya devam eder; yalnizca YAVAS ama VAR olan ag sessiz
/// kalir.
@visibleForTesting
const Duration kOfflineNoticeGrace = Duration(seconds: 4);

/// Oturum durumuna göre giriş ekranını veya ana uygulamayı gösterir.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  late final StreamSubscription<void> _recoverySub;

  /// WP-603: çevrimdışı açılış şeridi oturumda bir kez gösterilir.
  ///
  /// WP-741: artık "şunu şu an ekranda tutuyoruz" demektir. Şerit kendiliğinden
  /// kapanınca veya iddia geri alınınca düşer; durum GERÇEKTEN tekrarlarsa
  /// (bayrak `false` → `true`) yeniden söylenebilsin diye.
  bool _offlineNoticeShown = false;

  /// WP-741: iddiayı geciktiren zamanlayıcı ([kOfflineNoticeGrace]).
  Timer? _offlineNoticeTimer;

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
    _offlineNoticeTimer?.cancel();
    _recoverySub.cancel();
    super.dispose();
  }

  /// WP-741: iddiayı hemen değil, [kOfflineNoticeGrace] sonra kurar.
  ///
  /// Bekleme dolmadan bayrak düşerse ([_withdrawOfflineNotice]) kullanıcı
  /// hiçbir şey görmez — yavaş ama çalışan ağda doğru davranış budur.
  void _scheduleOfflineNotice() {
    if (_offlineNoticeShown || _offlineNoticeTimer != null) return;
    _offlineNoticeTimer = Timer(kOfflineNoticeGrace, () {
      _offlineNoticeTimer = null;
      if (!mounted) return;
      // Bekleme sonunda durum hâlâ geçerli mi? Zamanlayıcı ile bayrağın
      // düşmesi arasındaki yarışı bu okuma kapatır.
      if (!ref.read(authOpenedOfflineProvider)) return;
      _announceOfflineOpen();
    });
  }

  /// WP-741: iddiayı GERİ ALIR.
  ///
  /// Gerçek profil geldiğinde `onRemoteProfile` → `clear()` bayrağı `false`
  /// yapıyordu, ama asılmış şerit kendi 6 saniyesini doldurmaya devam
  /// ediyordu: kullanıcı çevrimiçiyken ekranda "İnternet yok" okumaya devam
  /// ediyordu. Geri alma olmadan gecikme tek başına yetmez.
  void _withdrawOfflineNotice() {
    _offlineNoticeTimer?.cancel();
    _offlineNoticeTimer = null;
    if (!_offlineNoticeShown) return;
    _offlineNoticeShown = false;
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  }

  /// Çevrimdışı açılışı tek bir şeritte duyurur.
  ///
  /// 🔴 WP-741: kare sonuna erteleme KALDIRILDI. Eski gerekçe bayrağın
  /// `authStateProvider` akışından, henüz `Scaffold` yokken kalkabilmesiydi;
  /// çağrı artık [kOfflineNoticeGrace] zamanlayıcısından, yani kare dışından ve
  /// ağacın oturduğu bir anda geliyor. Erteleme burada **zararlıydı**:
  /// `addPostFrameCallback` kendiliğinden kare planlamaz, ekran durgunsa
  /// (kimse `setState` çağırmıyorsa) geri çağırım hiç çalışmaz ve şerit hiç
  /// asılmazdı. Ölçüldü: `serit asildiktan sonra ... INDIRILIR` testi.
  void _announceOfflineOpen() {
    if (_offlineNoticeShown) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    _offlineNoticeShown = true;
    final notice = messenger.showSnackBar(
      SnackBar(
        key: const Key('auth-gate-offline-notice'),
        content: Text(AppLocalizations.of(context).authCevrimdisiAcildi),
        duration: const Duration(seconds: 6),
      ),
    );
    // Şerit kendiliğinden kapandığında bayrağı bırak: aksi hâlde çok sonra gelen
    // bir geri alma, o an ekranda olan BAŞKA bir şeridi indirirdi.
    notice.closed.then((_) {
      if (mounted) _offlineNoticeShown = false;
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
    //
    // 🔴 WP-741: bayrak iki yönlü dinlenir. Kalkması iddiayı hemen kurmaz
    // ([kOfflineNoticeGrace] beklenir); düşmesi ise iddiayı GERİ ALIR. Eski
    // gövde yalnız `true`ya bakıyordu, bu yüzden `clear()` ekranda hiçbir
    // karşılık üretmiyordu.
    ref.listen<bool>(authOpenedOfflineProvider, (previous, next) {
      if (next) {
        _scheduleOfflineNotice();
      } else {
        _withdrawOfflineNotice();
      }
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
