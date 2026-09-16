import 'package:flutter/foundation.dart';

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
class GoogleSignInConfig {
  const GoogleSignInConfig._();

  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Platform + kimlik koşulu (arka uçtan bağımsız). Supabase deposu kendi
  /// içinde bunu kullanır; o depo zaten Supabase arka ucudur.
  static bool get platformEnabled => resolvePlatformEnabled(
    webClientId: webClientId,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );

  /// Saf karar: yalnız Android (web değil) **ve** kimlik dolu.
  ///
  /// Windows/web kapsam dışıdır: Windows'ta eklentinin uygulaması yok, web'de
  /// akış farklı (GIS düğmesi) ve bu WP onu kurmaz.
  static bool resolvePlatformEnabled({
    required String webClientId,
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    if (isWeb) return false;
    if (platform != TargetPlatform.android) return false;
    return webClientId.trim().isNotEmpty;
  }

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
