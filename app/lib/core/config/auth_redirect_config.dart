/// WP-287: Şifre sıfırlama / auth recovery derin bağlantısı.
///
/// Sorun: `resetPasswordForEmail` `redirectTo` olmadan çağrılınca Supabase,
/// e-postadaki bağlantıyı projenin **Site URL**'ine (varsayılan `localhost:3000`)
/// yönlendiriyordu; kullanıcı "check your internet connection" hatası alıp
/// şifresini sıfırlayamıyordu.
///
/// Bu yardımcı, uygulamanın Android derin bağlantı scheme'ini üretir.
/// `AndroidManifest.xml` şu intent-filter'ı taşır:
/// `<data android:scheme="${authCallbackScheme}" android:host="login-callback" />`
///
/// **Önemli:** scheme, applicationId'nin BİREBİR aynısı DEĞİLDİR — alt çizgisiz
/// bir tabanı vardır (`build.gradle.kts` `authCallbackScheme` placeholder'ı):
///   applicationId  `com.manilmax.online_study_room[.beta|.local]`
///   scheme         `com.manilmax.onlinestudyroom[.beta|.local]`
/// İkisi yalnız suffix'te (`.beta` / `.local` / yok) örtüşür. Bu yüzden scheme
/// paket adından **suffix devşirilerek** üretilir; sabit yazılmaz ki beta/stable/
/// local akışları aynı telefonda birbirine karışmasın.
library;

const String _appIdBase = 'com.manilmax.online_study_room';
const String _schemeBase = 'com.manilmax.onlinestudyroom';
const String _callbackHost = 'login-callback';

/// Paket adından (package_info_plus `packageName`) uygun recovery derin
/// bağlantısını üretir.
///
/// - [isAndroid] false ise (Windows/masaüstü/web) `null` döner: bu platformlarda
///   scheme kaydı yoktur, kullanıcı e-postadaki **kod (OTP)** yolunu kullanır.
/// - Paket adı beklenen tabanla başlamıyorsa güvenli tarafta kalıp `null` döner
///   (yanlış bir scheme'e yönlendirmektense OTP yoluna düş).
String? authRecoveryRedirectUrl(String packageName, {required bool isAndroid}) {
  if (!isAndroid) return null;
  final trimmed = packageName.trim();
  if (!trimmed.startsWith(_appIdBase)) return null;
  final suffix = trimmed.substring(_appIdBase.length); // '', '.beta', '.local'
  return '$_schemeBase$suffix://$_callbackHost';
}
