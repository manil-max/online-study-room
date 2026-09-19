
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/auth_redirect_config.dart';
import '../../../core/config/google_sign_in_config.dart';
import '../../../features/auth/windows_google_loopback.dart';
import '../../models/account_deletion_status.dart';
import '../../models/profile.dart';
import '../auth_repository.dart';
import '../push_registration_repository.dart';

/// Kimlik e-postalarının (şifre sıfırlama ve e-posta değişikliği) mevcut auth
/// derin bağlantı hedefini üretir. Eski public parametre adı geriye uyumluluk
/// için `recoveryRedirect` olarak korunur.
typedef RecoveryRedirectResolver = Future<String?> Function();

/// 🔴 WP-609 — çevrimdışı profil yedeğinin **saf** kararı.
///
/// Ağ yolu düştüğünde hangi profilin yayınlanacağını tek yerde belirler ve
/// test edilebilir kılar. Eskiden bu karar `_profileFor`un içine gömülüydü ve
/// koşulsuz `user_metadata` profiliydi — o profil yalnız `displayName` taşır,
/// `dailyGoalMinutes` ve avatar **varsayılana** düşer.
///
/// Karşılığı sessiz bir veri kaybıydı: çevrimdışı açılışta WP-603 önbellekten
/// doğru profili gösteriyor, arka plandaki ağ turu ~20 sn sonra başarısız
/// olunca üstüne bu eksik profil yayınlanıyordu. Kullanıcı günlük hedefini
/// önce doğru görüyor, sonra sessizce varsayılana dönüyordu; hedefe bağlı her
/// şey (ilerleme halkası, "hedefi tuttun mu", seri tamamlama) o andan
/// itibaren yanlış çalışıyordu.
@visibleForTesting
Profile offlineProfileFallback({
  required String userId,
  required String? metadataDisplayName,
  required DateTime createdAt,
  required Profile? cached,
}) {
  // Önbellek yalnız AYNI kullanıcıya aitse kullanılır: hesap değiştiren
  // cihazda başkasının hedefini göstermek daha kötü bir hata olurdu.
  if (cached != null && cached.id == userId) return cached;
  return Profile(
    id: userId,
    displayName: metadataDisplayName ?? '',
    createdAt: createdAt,
  );
}

/// WP-831: Google hesabından **ID token** alan dikiş.
///
/// Depo `google_sign_in` eklentisine doğrudan bağlanmaz: eklenti platform
/// kanalı ister ve birim testte çalışmaz. Üretimde [PluginGoogleIdTokenSource],
/// testte sahte bir kaynak verilir.
abstract class GoogleIdTokenSource {
  /// Hesap seçiciyi açar ve ID token döndürür (token yoksa null).
  ///
  /// Kullanıcı seçiciyi kapatırsa [GoogleSignInException] (`canceled`) atar.
  Future<String?> fetchIdToken();

  /// Cihazdaki Google oturumunu kapatır; bir sonraki girişte hesap seçici
  /// yeniden görünür.
  Future<void> signOut();
}

/// Gerçek `google_sign_in` 7.x eklentisi üzerinden kaynak.
class PluginGoogleIdTokenSource implements GoogleIdTokenSource {
  PluginGoogleIdTokenSource({required this.serverClientId});

  /// Web türündeki OAuth istemci kimliği (`GOOGLE_WEB_CLIENT_ID`).
  final String serverClientId;

  /// `GoogleSignIn.instance.initialize` süreç başına **tam bir kez**
  /// çağrılmalı (eklenti sözleşmesi). Sağlayıcı depoyu yeniden kurabildiği
  /// için bayrak örnekte değil, sınıfta tutulur.
  static Future<void>? _initialized;

  Future<void> _ensureInitialized() {
    return _initialized ??= GoogleSignIn.instance
        .initialize(serverClientId: serverClientId)
        .catchError((Object error, StackTrace stack) {
          // Başarısız başlatma önbelleğe alınmaz; sonraki deneme yeniden dener.
          _initialized = null;
          Error.throwWithStackTrace(error, stack);
        });
  }

  @override
  Future<String?> fetchIdToken() async {
    await _ensureInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    return account.authentication.idToken;
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }
}

/// WP-866: Windows tarayıcı akışının dış uçları — sağlayıcı adresi, sistem
/// tarayıcısı ve PKCE kod değişimi.
///
/// Depo bunlara doğrudan bağlanmaz: gerçek tarayıcı ve gerçek gotrue PKCE
/// deposu birim testte çalışmaz. Üretimde [SupabaseGoogleBrowserOAuth].
abstract class GoogleBrowserOAuth {
  /// Supabase `/authorize` adresi (PKCE doğrulayıcısı yerelde saklanır).
  Future<Uri> authorizeUrl({required String redirectTo});

  /// Adresi sistem tarayıcısında açar; açılamazsa false.
  Future<bool> openExternal(Uri url);

  /// Dönüşteki `code`u saklı doğrulayıcıyla oturuma çevirir.
  Future<supa.Session> exchangeCode(String code);
}

/// gotrue 2.22.0 PKCE API'si + `url_launcher` üzerinden gerçek uçlar.
class SupabaseGoogleBrowserOAuth implements GoogleBrowserOAuth {
  SupabaseGoogleBrowserOAuth(this._client);

  final supa.SupabaseClient _client;

  @override
  Future<Uri> authorizeUrl({required String redirectTo}) async {
    // gotrue `getOAuthSignInUrl` (gotrue_client.dart:363) PKCE akışında
    // doğrulayıcıyı `pkceAsyncStorage`a yazar ve `code_challenge`lı adresi
    // döndürür; supabase_flutter varsayılan akış tipi PKCE'dir.
    final response = await _client.auth.getOAuthSignInUrl(
      provider: supa.OAuthProvider.google,
      redirectTo: redirectTo,
      // Android'de çıkış hesap seçiciyi sıfırlıyor; tarayıcıda Google çerezi
      // kalır. Hesap seçimi her girişte sorulsun ki çıkış yapan kullanıcı
      // sessizce aynı hesaba dönmesin.
      queryParams: const {'prompt': 'select_account'},
    );
    return Uri.parse(response.url);
  }

  @override
  Future<bool> openExternal(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  Future<supa.Session> exchangeCode(String code) async {
    // gotrue `exchangeCodeForSession` (gotrue_client.dart:379): saklı
    // doğrulayıcıyla `POST /token?grant_type=pkce`; oturumu kaydeder ve
    // `signedIn` yayınlar.
    final response = await _client.auth.exchangeCodeForSession(code);
    return response.session;
  }
}

/// Supabase tabanlı kimlik doğrulama. UI hiç değişmeden bellek-içi yerine geçer.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._client, {
    RecoveryRedirectResolver? recoveryRedirect,
    Profile? Function()? cachedProfile,
    void Function(Profile profile)? onServerProfile,
    GoogleIdTokenSource? googleIdTokenSource,
    GoogleBrowserOAuth? googleBrowserOAuth,
    WindowsGoogleLoopback? googleLoopback,
  }) : _recoveryRedirect = recoveryRedirect ?? (() async => null),
       _cachedProfile = cachedProfile ?? (() => null),
       _onServerProfile = onServerProfile ?? ((_) {}),
       // Dikişlerden biri verilirse yol odur; öteki varsayılana düşmez.
       // (CI define'ı kimliği doldurduğunda testin Android varsayılanı
       // gerçek eklentiye kaymasın.)
       _google =
           googleIdTokenSource ??
           (googleBrowserOAuth == null ? _defaultGoogleIdTokenSource() : null),
       _browserGoogle =
           googleBrowserOAuth ??
           (googleIdTokenSource == null
               ? _defaultGoogleBrowserOAuth(_client)
               : null),
       _loopback = googleLoopback ?? WindowsGoogleLoopback();

  /// WP-831: yapılandırma yoksa (kimlik boş / Android değil) kaynak **null**
  /// kalır — Google girişi fail-closed kapalıdır ve çıkışta eklentiye
  /// hiç dokunulmaz.
  static GoogleIdTokenSource? _defaultGoogleIdTokenSource() {
    if (GoogleSignInConfig.flow != GoogleSignInFlow.nativeIdToken) {
      return null;
    }
    return PluginGoogleIdTokenSource(
      serverClientId: GoogleSignInConfig.webClientId,
    );
  }

  /// WP-866: yalnız Windows + dolu kimlikte kurulur; aksi hâlde null
  /// (fail-closed, tarayıcı hiç açılmaz).
  static GoogleBrowserOAuth? _defaultGoogleBrowserOAuth(
    supa.SupabaseClient client,
  ) {
    if (GoogleSignInConfig.flow != GoogleSignInFlow.browserLoopback) {
      return null;
    }
    return SupabaseGoogleBrowserOAuth(client);
  }

  final supa.SupabaseClient _client;

  /// WP-831: Google ID token kaynağı; Google girişi kapalıysa null.
  final GoogleIdTokenSource? _google;

  /// WP-866: Windows tarayıcı akışının uçları; akış kapalıysa null.
  final GoogleBrowserOAuth? _browserGoogle;

  /// WP-866: Windows dönüş dinleyicisi. Kurulumu port almaz; port yalnız
  /// giriş anında `open` ile alınır ve akış bitince bırakılır.
  final WindowsGoogleLoopback _loopback;

  /// WP-867: o an bekleyen tarayıcı girişinin dinleyicisi (yoksa null).
  LoopbackSession? _googleSession;

  /// WP-867: "Vazgeç" dinleyici henüz açılmadan geldiyse akış açılır
  /// açılmaz kapatılsın diye tutulur.
  bool _googleCancelRequested = false;

  /// 🔴 WP-609: ağ yolu başarısız olduğunda dönülecek **son gerçek** profil.
  ///
  /// Depo `OfflineCacheStore`u doğrudan tanımaz (katman sınırı); yalnız bir
  /// okuyucu alır. Sağlayıcı bunu `offlineCacheStoreProvider`a bağlar.
  final Profile? Function() _cachedProfile;

  /// 🔴 WP-621: **yalnız sunucudan gerçekten okunan** profil için çağrılır.
  ///
  /// WP-609 ağ düşünce önbellekteki profili döndürmeyi sağladı ama yazma
  /// tarafını açık bıraktı: `auth_providers` akıştan geçen **her** profili
  /// "bir sonraki çevrimdışı açılışın yedeği" diye önbelleğe yazıyordu —
  /// çevrimdışı üretilen, günlük hedefi VARSAYILANA düşmüş yedek profil dahil.
  ///
  /// Sonuç kalıcı bir bozulmaydı: ilk açılışı çevrimdışı olan kullanıcının
  /// eksik profili "son gerçek profil" olarak diske yazılıyor, WP-609 de onu
  /// okuyordu. Yani düzeltmenin kendisi bozuk veriyi sabitliyordu.
  ///
  /// Kaynak ayrımı **burada** yapılır çünkü satırın sunucudan geldiğini yalnız
  /// depo bilir; sağlayıcı katmanı iki profili birbirinden ayıramaz.
  final void Function(Profile profile) _onServerProfile;

  /// Auth bağlantılarının döneceği derin bağlantı (Android) veya null.
  final RecoveryRedirectResolver _recoveryRedirect;
  Profile? _current;
  final _recoveryController = StreamController<void>.broadcast();

  /// WP-478: profil mutasyonlarının yayın kanalı.
  ///
  /// `authStateChanges()` yalnız **iki** olayda yayın yapıyordu: açılıştaki ilk
  /// okuma ve auth durumu değişimi. `updateTitle` gibi profil mutasyonları
  /// `_current`'ı tazeliyor ama akışa hiçbir şey düşmüyordu; `authStateProvider`
  /// bu akıştan beslendiği için ekranlar **bayat profili** okumaya devam
  /// ediyordu. Ünvanda görünmesinin sebebi iki ayrı ekranın (Başarımlar ve
  /// Sosyal Profil) aynı gerçeği okumasıydı — diğer alanlar yerel `setState`
  /// tuttuğu için hatayı gizliyordu.
  final _profileMutations = StreamController<Profile?>.broadcast();

  /// Güncellenmiş profili dinleyicilere duyurur.
  void _emitProfile() {
    if (_profileMutations.isClosed) return;
    _profileMutations.add(_current);
  }

  @override
  Profile? get currentUser => _current;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  Stream<void> get passwordRecoveryEvents => _recoveryController.stream;

  @override
  Stream<Profile?> authStateChanges() {
    // İki kaynak tek akışta birleşir: oturum olayları ve profil mutasyonları.
    // Mutasyonlar `async*` gövdesine dışarıdan enjekte edilemediği için
    // birleştirme burada yapılıyor.
    final merged = StreamController<Profile?>();
    StreamSubscription<Profile?>? sessions;
    StreamSubscription<Profile?>? mutations;
    merged
      ..onListen = () {
        // WP-748: yan kanal ÖNCE bağlanır — oturum akışının ilk turunda düşen
        // bir hata da bu kanaldan gelir ve dinleyicisiz yayın kaybolur.
        mutations = _profileMutations.stream.listen(
          (profile) {
            if (!merged.isClosed) merged.add(profile);
          },
          onError: (Object error, StackTrace stack) {
            if (!merged.isClosed) merged.addError(error, stack);
          },
        );
        sessions = _sessionProfiles().listen(
          (profile) {
            if (!merged.isClosed) merged.add(profile);
          },
          onError: (Object error, StackTrace stack) {
            if (!merged.isClosed) merged.addError(error, stack);
          },
          onDone: () {
            if (!merged.isClosed) merged.close();
          },
        );
      }
      ..onCancel = () {
        // 🔴 `_sessionProfiles()` `await for` içinde askıdayken `cancel()`
        // **tamamlanmıyor**: `async*` üreticisi ancak kaynak bir olay daha
        // ürettiğinde çözülüyor, `onAuthStateChange` ise sessiz kalabiliyor.
        // Bu davranış WP-478 öncesinde de vardı (akış doğrudan bu üreticiydi);
        // burada yalnız **beklenmiyor**, aksi hâlde iptal eden taraf askıda
        // kalırdı. Ölçüldü: `test/data/auth_profile_emission_test.dart`.
        unawaited(sessions?.cancel() ?? Future<void>.value());
        return mutations?.cancel() ?? Future<void>.value();
      };
    return merged.stream;
  }

  /// 🔴 WP-748: bu üretici TEK bir geçici hatada **kalıcı olarak ölüyordu.**
  ///
  /// `async*` bir hata fırlattığında üretici SONLANIR; abonelik `onError` →
  /// `onDone` → `close` sırasını izler. Yani geçici bir ağ hatasından sonra
  /// (gotrue, token tazelemesi 5xx/bağlantı hatası alınca `notifyException`
  /// ile hatayı `onAuthStateChange`e KOYAR ve oturumu silmez) akış bir daha
  /// hiç konuşmuyordu: o oturum boyunca giriş, çıkış ve token tazeleme
  /// olaylarının hiçbiri ekrana ulaşmıyordu. WP-741'in kapattığı sahte
  /// "İnternet yok" şeridi bunun yalnız görünen yüzüydü — şeridi geri alacak
  /// gerçek profil de aynı ölü akışın arkasında kalıyordu.
  ///
  /// Düzeltme iki parçalı: hata **yutulmaz** ([_emitSessionError] ile yan
  /// kanaldan iletilir) ama akış **sonlanmaz**.
  ///
  /// Kaynağa `handleError` ile bakılır; "yakala + yeniden abone ol" DEĞİL:
  /// gotrue'nun `onAuthStateChange`i bir `BehaviorSubject`tir ve son olayı —
  /// yani aynı hatayı — yeni aboneye TEKRAR OYNATIR, yeniden abonelik sıkı bir
  /// döngüye girerdi. Ölçüldü: `test/data/auth_error_stream_death_wp748_test.dart`.
  Stream<Profile?> _sessionProfiles() async* {
    // Açılışta mevcut oturum (varsa) yayınlanır.
    try {
      _current = await _profileFor(_client.auth.currentSession);
      yield _current;
    } catch (error, stack) {
      if (await _recoverFromStaleRefreshToken(error)) {
        yield null;
      } else {
        _emitSessionError(error, stack);
      }
    }

    await for (final state in _client.auth.onAuthStateChange.handleError(
      _onSessionSourceError,
    )) {
      if (state.event == supa.AuthChangeEvent.passwordRecovery) {
        _recoveryController.add(null);
      }
      try {
        _current = await _profileFor(state.session);
        yield _current;
      } catch (error, stack) {
        if (await _recoverFromStaleRefreshToken(error)) {
          yield null;
        } else {
          _emitSessionError(error, stack);
        }
      }
    }
  }

  /// Kaynak oturum akışının hatası: bayat token'ı temizle, aksi hâlde hatayı
  /// bildir — ama iki durumda da akışı ÖLDÜRME (WP-748).
  void _onSessionSourceError(Object error, StackTrace stack) {
    unawaited(() async {
      if (await _recoverFromStaleRefreshToken(error)) {
        // `_current` artık null; kullanıcı giriş ekranına döner.
        _emitProfile();
      } else {
        _emitSessionError(error, stack);
      }
    }());
  }

  /// Oturum akışının HATA yan kanalı.
  ///
  /// Bir `async*` üreticisi hatayı ancak **sonlanarak** yayabilir; hatayı
  /// gizlemeden akışı canlı tutmanın tek yolu onu üreticinin dışından
  /// göndermektir. `authStateChanges()` bu kanalı zaten birleştiriyor.
  void _emitSessionError(Object error, StackTrace stack) {
    if (_profileMutations.isClosed) return;
    _profileMutations.addError(error, stack);
  }

  Future<bool> _recoverFromStaleRefreshToken(Object error) async {
    if (!_isStaleRefreshToken(error)) return false;
    await _clearLocalSession();
    return true;
  }

  bool _isStaleRefreshToken(Object error) {
    if (error is supa.AuthApiException) {
      final code = error.code?.toLowerCase();
      final message = error.message.toLowerCase();
      return code == 'refresh_token_already_used' ||
          message.contains('invalid refresh token');
    }
    if (error is supa.AuthException) {
      return error.message.toLowerCase().contains('invalid refresh token');
    }
    return false;
  }

  Future<void> _clearLocalSession() async {
    try {
      await _client.auth.signOut(scope: supa.SignOutScope.local);
    } catch (_) {
      // Oturum zaten bozuksa sign-out da hata verebilir; UI login'e dönmeli.
    }
    _current = null;
  }

  /// Oturumdaki kullanıcı için profil satırını getirir (yoksa metadata'dan kurar).
  Future<Profile?> _profileFor(supa.Session? session) async {
    final user = session?.user;
    if (user == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        final profile = Profile.fromMap(row);
        // Yalnız BU yol gerçek sunucu satırıdır; yedek yollar çağırmaz.
        _onServerProfile(profile);
        return profile;
      }
    } catch (_) {
      // Çevrimdışı veya geçici sunucu hatası: oturum geçerli ama profil satırı
      // çekilemedi. Kullanıcıyı dışarı atma (oturum kalıcılığı).
      //
      // 🔴 WP-609 — buradaki yedek SESSİZ BİR VERİ KAYBIYDI. Aşağıdaki
      // metadata profili yalnız `displayName` taşır; `dailyGoalMinutes`,
      // avatar ve diğer alanlar **varsayılana** düşer. Çevrimdışı açılışta
      // WP-603 önbellekten doğru profili gösteriyor, sonra bu ağ turu ~20 sn
      // sonra başarısız olunca üstüne bu eksik profili yayınlıyordu: kullanıcı
      // günlük hedefini doğru görüyor, sonra sessizce varsayılana dönüyordu.
      // Hedefe bağlı her şey (ilerleme halkası, "hedefi tuttun mu", seri)
      // o andan itibaren yanlış oluyordu.
    }
    // Trigger henüz profili oluşturmadıysa ya da çevrimdışıysak: karar tek
    // yerde, saf ve test edilebilir (bkz. [offlineProfileFallback]).
    return offlineProfileFallback(
      userId: user.id,
      metadataDisplayName: user.userMetadata?['display_name'] as String?,
      createdAt: DateTime.now(),
      cached: _cachedProfile(),
    );
  }

  @override
  Future<Profile> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      final user = res.user;
      if (user == null) throw const AuthException('Kayıt tamamlanamadı.');
      // E-posta doğrulama açıksa kayıt bir oturum (session) döndürmez: kullanıcı
      // doğrulamadan giriş yapamaz. Sessiz kalmak yerine net bilgi ver.
      if (res.session == null) {
        throw const AuthException(
          'Hesabın oluşturuldu. Giriş yapabilmek için e-postana gönderilen '
          'doğrulama bağlantısına tıkla. (Supabase’de e-posta doğrulamayı '
          'kapatırsan doğrulama gerekmez.)',
        );
      }
      final profile = Profile(
        id: user.id,
        displayName: displayName,
        createdAt: DateTime.now(),
      );
      _current = profile;
      return profile;
    } on supa.AuthException catch (e) {
      throw AuthException(_translate(e.message), code: _authCode(e));
    }
  }

  @override
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final profile = await _profileFor(res.session);
      if (profile == null) throw const AuthException('Giriş yapılamadı.');
      _current = profile;
      return profile;
      // 🔴 WP-539: eskiden burada `code` hiç verilmiyordu. Giriş ekranı hatayı
      // Türkçe mesaja `contains` uygulayarak ayırdığı için doğrulanmamış
      // e-posta, ağ hatası ve hız sınırı **üçü birden** "Beklenmeyen bir hata
      // oluştu."ya düşüyordu.
    } on supa.AuthException catch (e) {
      throw AuthException(_translate(e.message), code: _authCode(e));
    }
  }

  /// WP-831: Google hesabıyla giriş (Android, native hesap seçici).
  ///
  /// Akış: eklentiden ID token → `signInWithIdToken(provider: google)`.
  /// Nonce **verilmez**: token nonce taşımadığında Supabase nonce kontrolünü
  /// atlar; tek başına nonce eklemek ise token'daki hash ile eşleşmediği için
  /// girişi kırar.
  ///
  /// Profil yolu e-posta girişiyle **aynıdır** ([_profileFor]). Görünen ad
  /// istemciden yazılmaz; ilk girişte DB trigger'ı Google metadata'sından
  /// (`full_name`/`name`) üretir.
  ///
  /// Mesajlar teknik ve İngilizcedir; kullanıcı metnini ekran `code`dan
  /// üretir (WP-539 sözleşmesi).
  @override
  Future<Profile> signInWithGoogle() async {
    final google = _google;
    if (google == null) {
      final browser = _browserGoogle;
      if (browser != null) return _signInWithGoogleInBrowser(browser);
      throw const AuthException('google_sign_in_unavailable');
    }
    final String? idToken;
    try {
      idToken = await google.fetchIdToken();
    } on GoogleSignInException catch (e) {
      // Kullanıcının kendi vazgeçişi hata değildir: ekran sessiz kalır.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException(
          'google_sign_in_cancelled',
          code: AuthErrorCode.cancelled,
        );
      }
      throw AuthException('google_sign_in_failed_${e.code.name}');
    }
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('google_id_token_missing');
    }
    try {
      final res = await _client.auth.signInWithIdToken(
        provider: supa.OAuthProvider.google,
        idToken: idToken,
      );
      final profile = await _profileFor(res.session);
      if (profile == null) {
        throw const AuthException('google_sign_in_no_session');
      }
      _current = profile;
      return profile;
    } on supa.AuthException catch (e) {
      throw AuthException(e.message, code: _authCode(e));
    }
  }

  /// WP-866: Windows'ta Google girişi (RFC 8252 loopback + PKCE).
  ///
  /// Sıra **sözleşmedir**:
  /// 1. Sabit porta dinleyici bağlanır — tarayıcıdan ÖNCE. Port meşgulse
  ///    kullanıcı boşuna Google'a gönderilmez: [AuthErrorCode.loopbackPortBusy].
  /// 2. gotrue PKCE adresi alınır (doğrulayıcı yerelde saklanır), sistem
  ///    tarayıcısında açılır.
  /// 3. Tek `GET /auth-callback` beklenir. `error` → kullanıcı vazgeçti /
  ///    reddetti; zaman aşımı → vazgeçti. İkisi de [AuthErrorCode.cancelled]
  ///    (ekran sessiz kalır).
  /// 4. `code` oturuma çevrilir, profil e-posta girişiyle **aynı** yoldan
  ///    ([_profileFor]) okunur.
  /// 5. Tarayıcıya sonuç sayfası yazılır ve dinleyici kapanır — hata yolunda
  ///    da (`finally`).
  ///
  /// Kod ve token hiçbir yerde loglanmaz; hata mesajları teknik ve kodsuzdur.
  Future<Profile> _signInWithGoogleInBrowser(GoogleBrowserOAuth browser) async {
    _googleCancelRequested = false;
    final LoopbackSession session;
    try {
      session = await _loopback.open();
    } on LoopbackPortBusyException {
      throw const AuthException(
        'google_loopback_port_busy',
        code: AuthErrorCode.loopbackPortBusy,
      );
    }
    _googleSession = session;
    var signedIn = false;
    try {
      // WP-867: "Vazgeç" port alınırken geldiyse tarayıcı hiç açılmaz.
      if (_googleCancelRequested) {
        throw const AuthException(
          'google_sign_in_cancelled',
          code: AuthErrorCode.cancelled,
        );
      }
      final url = await browser.authorizeUrl(
        redirectTo: windowsGoogleLoopbackRedirect,
      );
      if (!await browser.openExternal(url)) {
        throw const AuthException('google_browser_open_failed');
      }
      final callback = await session.waitForCallback();
      if (callback == null || callback.error == 'access_denied') {
        throw const AuthException(
          'google_sign_in_cancelled',
          code: AuthErrorCode.cancelled,
        );
      }
      // WP-870: yalnız `access_denied` kullanıcının kendi reddidir. Başka
      // her `error` (ör. `server_error`) sunucu/sağlayıcı hatasıdır: sessiz
      // "vazgeçti" sayılırsa tarayıcı "tamamlanamadı" derken ekran boş kalır.
      if (callback.denied) {
        throw const AuthException('google_oauth_provider_error');
      }
      final code = callback.code;
      if (code == null || code.isEmpty) {
        throw const AuthException('google_oauth_code_missing');
      }
      final supa.Session authSession;
      try {
        authSession = await browser.exchangeCode(code);
      } on supa.AuthException catch (e) {
        throw AuthException(e.message, code: _authCode(e));
      }
      final profile = await _profileFor(authSession);
      if (profile == null) {
        throw const AuthException('google_sign_in_no_session');
      }
      _current = profile;
      signedIn = true;
      return profile;
    } finally {
      if (identical(_googleSession, session)) _googleSession = null;
      await session.finish(signedIn: signedIn);
    }
  }

  /// WP-867: bekleyen Windows tarayıcı girişinden vazgeçer.
  ///
  /// Dinleyici açıksa bekleme `null` ile biter → [signInWithGoogle]
  /// [AuthErrorCode.cancelled] atar ve port hemen bırakılır. Dönüş zaten
  /// geldiyse (kod değişimi sürüyor) iptal no-op'tur: yarım oturum
  /// bırakılmaz. Android'de ve bekleyen akış yokken hiçbir şey yapmaz.
  @override
  Future<void> cancelGoogleSignIn() async {
    if (_browserGoogle == null) return;
    _googleCancelRequested = true;
    await _googleSession?.cancel();
  }

  /// WP-587: doğrulama e-postasını yeniden gönderir.
  ///
  /// `emailRedirectTo` kayıt/kurtarma ile **aynı** çözücüden gelir; aksi
  /// hâlde yeniden gönderilen bağlantı Site URL'e düşer ve uygulamaya
  /// dönmez (WP-287'de ölçülen hata).
  ///
  /// Mesajlar teknik ve İngilizcedir; kullanıcı metnini ekran `code`dan
  /// üretir (WP-539 sözleşmesi, `_reauthFailure` notuyla aynı gerekçe).
  @override
  Future<void> resendVerificationEmail(String email) async {
    final safe = email.trim();
    if (safe.isEmpty || !safe.contains('@')) {
      throw const AuthException(
        'auth_resend_invalid_email',
        code: AuthErrorCode.invalidEmail,
      );
    }
    try {
      await _client.auth.resend(
        type: supa.OtpType.signup,
        email: safe,
        emailRedirectTo: await _recoveryRedirect(),
      );
    } on supa.AuthException catch (e) {
      throw AuthException(_translate(e.message), code: _authCode(e));
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final safe = email.trim();
    if (safe.isEmpty || !safe.contains('@')) {
      throw const AuthException(
        'Geçerli bir e-posta girin.',
        code: AuthErrorCode.invalidEmail,
      );
    }
    try {
      // WP-287: redirectTo verilmezse Supabase linki Site URL'e (localhost)
      // yönlendiriyordu → "check your internet connection". Android'de derin
      // bağlantıya yönlendir; Windows/masaüstünde null döner ve kullanıcı
      // e-postadaki kodu (OTP) kullanır. Hesap var/yok bilgisi sızdırılmaz.
      final redirectTo = await _recoveryRedirect();
      await _client.auth.resetPasswordForEmail(safe, redirectTo: redirectTo);
    } on supa.AuthException catch (e) {
      throw AuthException(_translateRecovery(e.message), code: _authCode(e));
    }
  }

  @override
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final safeEmail = email.trim();
    final safeCode = code.trim();
    if (safeEmail.isEmpty || !safeEmail.contains('@')) {
      throw const AuthException(
        'Geçerli bir e-posta girin.',
        code: AuthErrorCode.invalidEmail,
      );
    }
    if (safeCode.isEmpty) {
      throw const AuthException('Kodu gir.', code: AuthErrorCode.otpExpired);
    }
    if (newPassword.length < 6) {
      throw const AuthException(
        'Şifre en az 6 karakter olmalı.',
        code: AuthErrorCode.weakPassword,
      );
    }
    try {
      // Kod recovery oturumu kurar, ardından yeni şifre yazılır.
      await _client.auth.verifyOTP(
        email: safeEmail,
        token: safeCode,
        type: supa.OtpType.recovery,
      );
      await _client.auth.updateUser(supa.UserAttributes(password: newPassword));
      // 🔴 WP-834: burada `code` HİÇ verilmiyordu ve ekran mesajı olduğu gibi
      // basıyordu. Sunucu "aynı şifre" ya da "sızmış şifre" dediğinde
      // `_translateRecovery` bunların hiçbirini tanımıyor, İngilizce ham mesaj
      // ekrana düşüyordu.
    } on supa.AuthException catch (e) {
      throw AuthException(_translateRecovery(e.message), code: _authCode(e));
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    if (newPassword.length < 6) {
      throw const AuthException(
        'Şifre en az 6 karakter olmalı.',
        code: AuthErrorCode.weakPassword,
      );
    }
    try {
      await _client.auth.updateUser(supa.UserAttributes(password: newPassword));
      // 🔴 WP-539: kurtarma ekranı bu istisnanın **içine hiç bakmıyordu**
      // (`on AuthException {` — değişken bile bağlanmamış). Süresi dolmuş
      // sıfırlama bağlantısı, zayıf şifre ve ağ hatası aynı tek cümleye
      // düşüyordu; kullanıcı hangisini düzelteceğini bilemiyordu.
    } on supa.AuthException catch (e) {
      throw AuthException(_translate(e.message), code: _authCode(e));
    }
  }

  /// WP-319: mevcut şifre **gerçekten** doğrulanır, sonra yenisi yazılır.
  ///
  /// Supabase'de eski şifreyi doğrulayan bir API yok; tek yol aynı şifreyle
  /// yeniden kimlik doğrulamak. Bu çağrı başarılı olursa aynı kullanıcı için
  /// yeni bir oturum kurulur (kullanıcı değişmez, dışarı atılmaz); başarısızsa
  /// `updateUser`'a **hiç gelinmez**.
  ///
  /// WP-319-G: yazma başarılı olunca **diğer tüm oturumlar** kapatılır.
  @override
  Future<PasswordChangeOutcome> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AuthException(
        'Oturum bulunamadı. Yeniden giriş yap.',
        code: AuthErrorCode.noSession,
      );
    }
    if (newPassword.length < 6) {
      throw const AuthException(
        'Şifre en az 6 karakter olmalı.',
        code: AuthErrorCode.weakPassword,
      );
    }
    if (newPassword == currentPassword) {
      throw const AuthException(
        'Yeni şifre mevcut şifreyle aynı olamaz.',
        code: AuthErrorCode.samePassword,
      );
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on supa.AuthException catch (e) {
      throw _reauthFailure(e);
    }

    try {
      await _client.auth.updateUser(supa.UserAttributes(password: newPassword));
      // 🔴 WP-834: burası yalnız hız sınırını tanıyordu; şifre reddinin gerçek
      // sebepleri (zayıf şifre alt sebepleri, `same_password`) **kodsuz**
      // geçiyor ve diyalog onları "Beklenmeyen bir hata oluştu."ya düşürüyordu.
    } on supa.AuthException catch (e) {
      throw AuthException(_translate(e.message), code: _authCode(e));
    }

    // Buradan sonra şifre **değişmiştir**. Diğer cihazların oturumu kapatılamazsa
    // atılacak bir istisna kullanıcıya "işlem olmadı" dedirtir ve artık geçersiz
    // olan eski şifreyle tekrar denetir; bu yüzden hata değil **sonuç** dönülür.
    return await _revokeOtherSessions()
        ? PasswordChangeOutcome.done
        : PasswordChangeOutcome.otherSessionsKept;
  }

  /// WP-319-G: bu cihaz hariç tüm oturumları sonlandırır (`SignOutScope.others`).
  ///
  /// `others` kapsamı yerel oturuma dokunmaz ve `signedOut` olayı **yayınlamaz**
  /// (gotrue `signOut`), yani kullanıcı kendi cihazında giriş ekranına düşmez —
  /// düşseydi bu özellik cezaya dönerdi ve kullanılmazdı.
  Future<bool> _revokeOtherSessions() async {
    try {
      await _client.auth.signOut(scope: supa.SignOutScope.others);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// WP-458: e-posta değişikliği, mevcut şifreyle yeniden doğrulanmadan
  /// `updateUser` aşamasına geçemez. Supabase güvenli e-posta değişikliği
  /// açıksa cevapta `newEmail` pending kalır ve mevcut e-posta oturumda
  /// korunur; bağlantıların doğrulanmasını SDK/Supabase tamamlar.
  @override
  Future<EmailChangeOutcome> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final currentEmail = _client.auth.currentUser?.email?.trim().toLowerCase();
    if (currentEmail == null ||
        currentEmail.isEmpty ||
        _client.auth.currentSession == null) {
      throw const AuthException(
        'Oturum bulunamadı. Yeniden giriş yap.',
        code: AuthErrorCode.noSession,
      );
    }
    final key = newEmail.trim().toLowerCase();
    if (key.isEmpty || !key.contains('@')) {
      throw const AuthException(
        'Geçerli bir e-posta girin.',
        code: AuthErrorCode.invalidEmail,
      );
    }
    if (key == currentEmail) {
      throw const AuthException(
        'Yeni e-posta mevcut e-postayla aynı olamaz.',
        code: AuthErrorCode.sameEmail,
      );
    }

    try {
      await _client.auth.signInWithPassword(
        email: currentEmail,
        password: currentPassword,
      );
    } on supa.AuthException catch (e) {
      throw _reauthFailure(e);
    }

    try {
      final redirectTo = await _recoveryRedirect();
      final response = await _client.auth.updateUser(
        supa.UserAttributes(email: key),
        emailRedirectTo: redirectTo,
      );
      final pendingEmail = response.user?.newEmail?.trim();
      return pendingEmail != null && pendingEmail.isNotEmpty
          ? EmailChangeOutcome.verificationPending
          : EmailChangeOutcome.confirmed;
    } on supa.AuthException catch (e) {
      throw AuthException(
        _translate(e.message),
        code: _emailChangeCode(e.message),
      );
    }
  }

  /// 🔴 WP-624: profil yazmalarının hedef kullanıcı kimliği.
  ///
  /// Altı yazma metodu `final cur = _current; if (cur == null) return;` ile
  /// başlıyordu — yani `_current` henüz dolmamışsa yazma **sessizce hiçbir şey
  /// yapmadan başarıyla dönüyordu**. Çağıran bunu başarı sayıp kullanıcıya
  /// onay gösteriyor; kullanıcı ayarını değiştirdiğini sanıyor, hiçbir şey
  /// kaydedilmiyor.
  ///
  /// Pencere küçük değil: `_current` ancak ilk `_profileFor(...)` bitince
  /// dolar ve çevrimdışı açılışta o tur ~20 saniye sürüyor (WP-603'te ölçüldü).
  /// Yani metroda uygulamayı açan kullanıcının ilk yirmi saniyedeki her ayar
  /// değişikliği sessizce kayboluyordu.
  ///
  /// 🔴 WP-610/WP-619 bu yolu **daha kötü** hâle getirmişti: o WP'ler hata
  /// dallarını düzeltip başarıda onay göstermeye başladı, ama bu yol hata
  /// atmıyor — sessizce dönüyor. Sonuç: ekranda "kaydedildi", diskte hiçbir şey.
  /// Sessiz başarısızlıktan beteri, YALAN başarıdır.
  ///
  /// Çözüm: kimliği oturumdan al. Profil satırı henüz okunmamış olabilir ama
  /// **kullanıcı kimliği açılıştan beri bellekte** (`setInitialSession`).
  String _writeTargetId() {
    final id = _current?.id ?? _client.auth.currentUser?.id;
    if (id == null) {
      // Gerçekten oturum yok: bu bir hata, sessizce yutulacak bir durum değil.
      throw const AuthException('session_required');
    }
    return id;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final cur = _current;
    final targetId = _writeTargetId();
    final name = displayName.trim();
    if (name.isEmpty) {
      throw const AuthException('Görünen ad boş olamaz.');
    }
    try {
      await _client
          .from('profiles')
          .update({'display_name': name})
          .eq('id', targetId);
    } on supa.PostgrestException catch (error) {
      if (error.message.contains('public_name_not_allowed')) {
        throw const AuthException('public_name_not_allowed');
      }
      rethrow;
    }
    _current = cur?.copyWith(displayName: name);
    _emitProfile();
  }

  @override
  Future<void> updateDailyGoal(int minutes) async {
    final cur = _current;
    final targetId = _writeTargetId();
    final safe = minutes.clamp(1, 24 * 60);
    await _client
        .from('profiles')
        .update({'daily_goal_minutes': safe})
        .eq('id', targetId);
    _current = cur?.copyWith(dailyGoalMinutes: safe);
    _emitProfile();
  }

  @override
  Future<void> updateAnimal(String animal) async {
    final cur = _current;
    final targetId = _writeTargetId();
    final safe = animal.trim();
    if (safe.isEmpty) return;
    await _client.from('profiles').update({'animal': safe}).eq('id', targetId);
    _current = cur?.copyWith(animal: safe);
    _emitProfile();
  }

  @override
  Future<void> updateTitle(String? achievementId) async {
    final cur = _current;
    final targetId = _writeTargetId();
    final safe = achievementId?.trim();
    final value = (safe == null || safe.isEmpty) ? null : safe;
    try {
      await _client
          .from('profiles')
          .update({'title_achievement_id': value})
          .eq('id', targetId);
    } on supa.PostgrestException catch (error) {
      // 0115 trigger'i: kazanilmamis unvan sunucuda reddedilir. Ekran bu
      // durumu kullaniciya anlasilir gostersin diye kod korunur.
      if (error.message.contains('title_not_earned')) {
        throw const AuthException('title_not_earned');
      }
      rethrow;
    }
    _current = value == null
        ? cur?.copyWith(clearTitle: true)
        : cur?.copyWith(titleAchievementId: value);
    _emitProfile();
  }

  @override
  Future<void> updateMonthlyReportOptIn(bool value) async {
    final cur = _current;
    final targetId = _writeTargetId();
    await _client
        .from('profiles')
        .update({'monthly_report_opt_in': value})
        .eq('id', targetId);
    _current = cur?.copyWith(monthlyReportOptIn: value);
    _emitProfile();
  }

  @override
  Future<void> updateAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final cur = _current;
    final targetId = _writeTargetId();
    // Dosya yolu: <uid>/avatar — RLS politikası ilk klasörün uid olmasını şart koşar.
    final path = '$targetId/avatar';
    try {
      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: supa.FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          );
      final base = _client.storage.from('avatars').getPublicUrl(path);
      // Önbellek kırıcı: ayni yola yüklenince CDN eskisini göstermesin.
      final url = '$base?v=${DateTime.now().millisecondsSinceEpoch}';
      await _client
          .from('profiles')
          .update({'avatar_url': url})
          .eq('id', targetId);
      _current = cur?.copyWith(avatarUrl: url);
      _emitProfile();
    } on supa.StorageException catch (e) {
      throw AuthException('Fotoğraf yüklenemedi: ${e.message}');
    }
  }

  @override
  Future<AccountDeletionStatus> requestAccountDeletion() async {
    try {
      final raw = await _client.rpc('request_account_deletion');
      if (raw is Map) {
        return AccountDeletionStatus.fromMap(Map<String, dynamic>.from(raw));
      }
      return AccountDeletionStatus.inactive;
    } on supa.PostgrestException catch (e) {
      throw AuthException(_translate(e.message));
    }
  }

  @override
  Future<AccountDeletionStatus> cancelAccountDeletion() async {
    try {
      final raw = await _client.rpc('cancel_account_deletion');
      if (raw is Map) {
        return AccountDeletionStatus.fromMap(Map<String, dynamic>.from(raw));
      }
      return AccountDeletionStatus.inactive;
    } on supa.PostgrestException catch (e) {
      throw AuthException(_translate(e.message));
    }
  }

  @override
  Future<AccountDeletionStatus> fetchAccountDeletionStatus() async {
    try {
      final raw = await _client.rpc('my_account_deletion_status');
      if (raw is Map) {
        return AccountDeletionStatus.fromMap(Map<String, dynamic>.from(raw));
      }
      return AccountDeletionStatus.inactive;
    } on supa.PostgrestException catch (e) {
      throw AuthException(_translate(e.message));
    }
  }

  @override
  Future<void> signOut() async {
    // WP-266: token eski hesaba bağlı kalıp çıkıştan sonra özel bildirim
    // göstermesin. Push cleanup hatası oturum kapatmayı engellemez; yeni login
    // aynı tokenı atomik olarak yeni kullanıcıya taşır.
    try {
      final prefs = await SharedPreferences.getInstance();
      // 🔴 WP-815: burada dize ELLE yaziliydi ve
      // `push_notification_providers.dart` icindeki private sabitin
      // kopyasiydi. Biri degisseydi cikis yolu sessizce bozulur, cihaz
      // kaydi sunucuda kalir ve eski hesabin bildirimleri bu cihaza
      // dusmeye devam ederdi. Artik tek kaynak.
      final installationId = prefs.getString(kPushInstallationIdPrefsKey);
      if (installationId != null && installationId.trim().isNotEmpty) {
        await _client.rpc(
          'unregister_push_device',
          params: {'p_installation_id': installationId.trim()},
        );
      }
    } catch (_) {}
    // WP-831: Google oturumu da kapatılır, yoksa sonraki girişte hesap seçici
    // atlanıp aynı hesap sessizce seçilebilir. En iyi çaba: bu adımın hatası
    // Supabase çıkışını ENGELLEMEZ.
    final google = _google;
    if (google != null) {
      try {
        await google.signOut();
      } catch (_) {}
    }
    await _client.auth.signOut();
    _current = null;
  }

  /// Supabase hata mesajlarını Türkçeleştirir (yaygın olanlar).
  String _translate(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login')) return 'E-posta veya şifre hatalı.';
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'Bu e-posta zaten kayıtlı.';
    }
    if (m.contains('password') && m.contains('at least')) {
      return 'Şifre en az 6 karakter olmalı.';
    }
    if (m.contains('email') && m.contains('confirm')) {
      return 'E-posta doğrulaması gerekiyor.';
    }
    return message;
  }

  /// WP-319: hız sınırı mı, yoksa yanlış şifre mi? İkisi kullanıcıya **farklı**
  /// şey söyler: biri "yanlış yazdın", diğeri "biraz bekle".
  bool _isRateLimit(String message) {
    final m = message.toLowerCase();
    return m.contains('security purposes') ||
        m.contains('rate limit') ||
        m.contains('too many') ||
        m.contains('only request');
  }

  /// Yeniden kimlik doğrulama hatası. Buraya yalnız "mevcut şifre" denemesi
  /// düşer, giriş ekranı değil — bu yüzden mesaj "e-posta veya şifre hatalı"
  /// değil, doğrudan **mevcut şifre** hakkındadır.
  String _reauthMessage(String message) {
    if (_isRateLimit(message)) {
      return 'Çok sık denedin. Biraz bekleyip tekrar dene.';
    }
    return 'Mevcut şifre hatalı.';
  }

  /// Yeniden kimlik doğrulama hatasını **sınıflandırır**.
  ///
  /// 🔴 WP-536: burası eskiden yoktu; `signInWithPassword`'dan gelen her hata
  /// `invalidCurrentPassword` sayılıyordu. `supa.AuthException`'ın altında
  /// ağ hatası (`AuthRetryableFetchException`) da var — yani bağlantı bir an
  /// titrediğinde kullanıcıya **"mevcut şifre hatalı"** deniyordu. Sahip
  /// sahada tam bunu bildirdi: doğru şifreyle birkaç kez hata aldı, sonra
  /// aynı şifre kabul edildi. Şifre hakkında hüküm vermek için sunucunun
  /// gerçekten "kimlik bilgisi geçersiz" demesi gerekir.
  AuthException _reauthFailure(supa.AuthException error) {
    // 🔴 Mesaj TEKNIK ve Ingilizcedir. Bu katman kullanıcıya metin taşımaz;
    // ekran `AuthErrorCode.network`i kendi katalogundan çevirir
    // (`l10n_audit` bu kuralı zorluyor ve ilk denememi kırmızı düşürdü).
    if (error is supa.AuthRetryableFetchException) {
      return const AuthException(
        'auth reauthentication could not reach the server',
        code: AuthErrorCode.network,
      );
    }
    if (_isRateLimit(error.message)) {
      return AuthException(
        _reauthMessage(error.message),
        code: AuthErrorCode.rateLimited,
      );
    }
    final apiCode = error is supa.AuthApiException
        ? error.code?.toLowerCase()
        : null;
    final message = error.message.toLowerCase();
    final wrongPassword =
        apiCode == 'invalid_credentials' ||
        message.contains('invalid login credentials') ||
        message.contains('invalid credentials');
    if (wrongPassword) {
      return AuthException(
        _reauthMessage(error.message),
        code: AuthErrorCode.invalidCurrentPassword,
      );
    }
    // Sunucu başka bir şey söyledi (5xx, beklenmeyen kod...). Şifre hakkında
    // hüküm vermek yanlış olur; genel hata dönülür.
    return AuthException(_translate(error.message), code: null);
  }

  /// WP-539: giriş/kayıt/sıfırlama yolundaki hatanın **nedenini** kodlar.
  ///
  /// Bu katman kullanıcı metni taşımaz (bkz. `_reauthFailure` notu, WP-536);
  /// mesaj Türkçe kalsa bile ekran artık **koda** bakar. Neden gerekliydi:
  /// `signIn`/`signUp`/`sendPasswordResetEmail` üçü de kodsuz istisna
  /// atıyordu, giriş ekranı da kodsuz istisnayı mesaj alt dizesiyle ayırmaya
  /// çalışıyordu ve tanımadığı her şeyi "Beklenmeyen bir hata oluştu."ya
  /// düşürüyordu. Ölçülen üç somut kayıp: doğrulanmamış e-posta, ağ hatası ve
  /// "şifremi unuttum" hız sınırı.
  String? _authCode(supa.AuthException error) {
    if (error is supa.AuthRetryableFetchException) return AuthErrorCode.network;
    // 🔴 WP-834: zayıf şifrenin **alt sebebi** burada kayboluyordu. gotrue
    // sunucunun `weak_password.reasons` dizisini ayrı bir tiple taşır
    // (`fetch.dart:97-108` → `AuthWeakPasswordException`), ama bu metot onu
    // sıradan bir `AuthApiException` gibi ele alıp tek `weak_password` koduna
    // düşürüyordu. Tip kontrolü `AuthApiException` dalından **önce** olmalı:
    // `AuthWeakPasswordException` `AuthApiException` değildir, yani aşağıdaki
    // `apiCode` onun için her zaman null kalır ve yalnız mesaj metnine bakan
    // "at least" taraması devreye girerdi — sızmış şifre reddinde o metin
    // yoktur ve kod **null** dönerdi. Sahibin gördüğü "Beklenmeyen bir hata"
    // tam olarak bu yol.
    if (error is supa.AuthWeakPasswordException) {
      return _weakPasswordCode(error.reasons);
    }
    // WP-834: oturum yoksa gotrue mesaj yerine ayrı bir tip atar
    // (`AuthSessionMissingException`, `types/auth_exception.dart:44`).
    if (error is supa.AuthSessionMissingException) {
      return AuthErrorCode.noSession;
    }
    if (_isRateLimit(error.message)) return AuthErrorCode.rateLimited;
    final apiCode = error is supa.AuthApiException
        ? error.code?.toLowerCase()
        : null;
    final m = error.message.toLowerCase();
    // WP-834: sunucunun şifre yazma reddine özel kodları. Kod dizeleri
    // gotrue'nun `ErrorCode` enum'undan birebir alındı
    // (`lib/src/types/error_code.dart:15,61,63,67-68`).
    if (apiCode == 'same_password') return AuthErrorCode.samePassword;
    if (apiCode == 'over_request_rate_limit' ||
        apiCode == 'over_email_send_rate_limit') {
      return AuthErrorCode.rateLimited;
    }
    if (apiCode == 'session_not_found') return AuthErrorCode.noSession;
    // Kod dizesi olmayan eski sunucularda aynı red düz metinle gelir.
    if (apiCode == 'otp_expired' ||
        m.contains('token has expired') ||
        (m.contains('otp') && m.contains('expired'))) {
      return AuthErrorCode.otpExpired;
    }
    if (apiCode == 'email_not_confirmed' ||
        (m.contains('email') && m.contains('confirm'))) {
      return AuthErrorCode.emailNotConfirmed;
    }
    if (apiCode == 'invalid_credentials' || m.contains('invalid login')) {
      return AuthErrorCode.invalidCredentials;
    }
    if (apiCode == 'weak_password' ||
        (m.contains('password') && m.contains('at least'))) {
      return AuthErrorCode.weakPassword;
    }
    if (apiCode == 'email_exists' ||
        apiCode == 'user_already_exists' ||
        m.contains('already registered') ||
        m.contains('already exists')) {
      return AuthErrorCode.emailAlreadyInUse;
    }
    if (m.contains('invalid') && m.contains('email')) {
      return AuthErrorCode.invalidEmail;
    }
    // Kurtarma oturumu düşmüş/süresi dolmuş: yeni şifre yazılamaz.
    if (m.contains('session') &&
        (m.contains('missing') || m.contains('expired'))) {
      return AuthErrorCode.noSession;
    }
    return null;
  }

  /// WP-834: `weak_password` sebep dizisini alt koda çevirir.
  ///
  /// ⚠️ Sebep **değerleri** Dart paketinde tanımlı değildir: gotrue onları
  /// sunucudan geldiği gibi taşır (`types/auth_exception.dart:94`,
  /// `final List<String> reasons`). Bu yüzden eşleme tam eşitlik değil alt
  /// dize aramasıdır — sunucu sebebi hangi biçimde yazarsa yazsın kod üretilir,
  /// tanınmayan sebep genel [AuthErrorCode.weakPassword]a düşer (sessiz
  /// "beklenmeyen hata" yerine en azından uzunluk cümlesi).
  ///
  /// Sızıntı sebebi önce bakılır: şifre kurallara uysa bile reddedilebilir,
  /// o yüzden "en az 6 karakter" cümlesi kullanıcıyı yanlış yere baktırır.
  String _weakPasswordCode(List<String> reasons) {
    final joined = reasons.join(' ').toLowerCase();
    if (joined.contains('pwned') || joined.contains('leaked')) {
      return AuthErrorCode.weakPasswordPwned;
    }
    if (joined.contains('length')) return AuthErrorCode.weakPasswordLength;
    if (joined.contains('characters')) {
      return AuthErrorCode.weakPasswordCharacters;
    }
    return AuthErrorCode.weakPassword;
  }

  String? _emailChangeCode(String message) {
    final m = message.toLowerCase();
    if (_isRateLimit(message)) return AuthErrorCode.rateLimited;
    if (m.contains('already registered') ||
        m.contains('already exists') ||
        m.contains('already been registered')) {
      return AuthErrorCode.emailAlreadyInUse;
    }
    if (m.contains('invalid') && m.contains('email')) {
      return AuthErrorCode.invalidEmail;
    }
    if (m.contains('session') &&
        (m.contains('missing') || m.contains('expired'))) {
      return AuthErrorCode.noSession;
    }
    return null;
  }

  /// Recovery/OTP akışına özel hata çevirisi (kod süresi + hız sınırı).
  String _translateRecovery(String message) {
    final m = message.toLowerCase();
    if (m.contains('expired') ||
        m.contains('invalid') ||
        m.contains('token has')) {
      return 'Kod geçersiz veya süresi dolmuş. Yeni kod iste.';
    }
    if (m.contains('security purposes') ||
        m.contains('rate limit') ||
        m.contains('too many') ||
        m.contains('only request')) {
      return 'Çok sık denedin. Biraz bekleyip tekrar dene.';
    }
    return _translate(message);
  }
}
