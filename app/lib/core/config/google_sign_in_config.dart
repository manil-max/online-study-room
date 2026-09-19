import 'package:flutter/foundation.dart';

/// WP-866: Google girişinin platforma göre **hangi yoldan** yapıldığı.
enum GoogleSignInFlow {
  /// Android: `google_sign_in` hesap seçicisi → ID token →
  /// `signInWithIdToken` (WP-831).
  nativeIdToken,

  /// Windows: sistem tarayıcısı → Supabase `/authorize` (PKCE) → loopback
  /// dönüşü → `exchangeCodeForSession` (WP-866). Eklentinin Windows
  /// uygulaması olmadığı için ayrı yol.
  browserLoopback,
}

/// WP-831: "Google ile devam et" girişinin derleme zamanı yapılandırması.
///
/// [webClientId], Google Cloud Console'daki **Web application** türündeki
/// OAuth istemci kimliğidir (Supabase Google sağlayıcısına da aynı kimlik
/// yazılır). Android'de `serverClientId` olarak verilir; ID token bu kimliğe
/// (`aud`) düzenlenir ve Supabase token'ı yalnız bu eşleşmeyle kabul eder.
/// Gizli değildir — istemci sırrı (client secret) burada **asla** bulunmaz.
///
/// 🔴 Fail-closed: kimlik boşsa düğme **hiç çizilmez**. Böylece kod, konsol
/// yapılandırması tamamlanmadan yayına girebilir; yarım yapılandırmada
/// kullanıcıya çalışmayan bir düğme gösterilmez.
///
/// WP-866 karar tablosu (Supabase arka ucu ayrıca şart, bkz. [resolveEnabled]):
///
/// | platform        | kimlik dolu | kimlik boş |
/// |-----------------|-------------|------------|
/// | Android         | nativeIdToken | kapalı   |
/// | Windows         | browserLoopback | kapalı |
/// | web/macOS/Linux/iOS | kapalı  | kapalı     |
///
/// Windows akışı kimliği **kullanmaz** (istemci kimliği Supabase sunucusunda
/// durur), yine de dolu olmasını şart koşar: yayın iş akışı beta (staging)
/// derlemesine bilerek **boş** kimlik yazar, çünkü staging Supabase'de Google
/// sağlayıcısı kapalıdır. Bu bayrak "bu derlemenin arka ucunda Google açık"
/// anlamını taşır; Windows beta'da düğme böylece gizli kalır.
class GoogleSignInConfig {
  const GoogleSignInConfig._();

  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Bu derlemenin Google giriş yolu (arka uçtan bağımsız); kapalıysa null.
  static GoogleSignInFlow? get flow => resolveFlow(
    webClientId: webClientId,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );

  /// Platform + kimlik koşulu (arka uçtan bağımsız). Supabase deposu kendi
  /// içinde bunu kullanır; o depo zaten Supabase arka ucudur.
  static bool get platformEnabled => flow != null;

  /// Saf karar: hangi platformda hangi yol (yukarıdaki tablo).
  static GoogleSignInFlow? resolveFlow({
    required String webClientId,
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    if (isWeb) return null;
    if (webClientId.trim().isEmpty) return null;
    return switch (platform) {
      TargetPlatform.android => GoogleSignInFlow.nativeIdToken,
      TargetPlatform.windows => GoogleSignInFlow.browserLoopback,
      _ => null,
    };
  }

  /// Saf karar: Android veya Windows (web değil) **ve** kimlik dolu.
  static bool resolvePlatformEnabled({
    required String webClientId,
    required bool isWeb,
    required TargetPlatform platform,
  }) =>
      resolveFlow(webClientId: webClientId, isWeb: isWeb, platform: platform) !=
      null;

  /// Ekranın tam kararı: platform koşulu **ve** Supabase arka ucu.
  ///
  /// Bellek-içi (demo/offline) modda Google kimliğini doğrulayacak sunucu
  /// yok; düğme orada da çizilmez.
  static bool resolveEnabled({
    required String webClientId,
    required bool isWeb,
    required TargetPlatform platform,
    required bool supabaseBackend,
  }) {
    if (!supabaseBackend) return false;
    return resolvePlatformEnabled(
      webClientId: webClientId,
      isWeb: isWeb,
      platform: platform,
    );
  }
}
