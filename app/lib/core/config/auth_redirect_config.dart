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

/// 🔴 WP-866: Windows'ta "Google ile devam et" akışının dönüş adresi.
///
/// `google_sign_in`in Windows uygulaması yok; giriş sistem tarayıcısında
/// yapılır ve Supabase kullanıcıyı bu **loopback** adresine geri yollar
/// (RFC 8252 §7.3). Uygulama aynı adreste kısa ömürlü bir HTTP dinleyicisi
/// açar, gelen `code`u PKCE ile oturuma çevirir.
///
/// **Tek kaynak budur.** Aynı dize Supabase yönlendirme izin listesinde de
/// birebir durur (`.github/workflows/supabase-auth-config.yml`, `allow_list`);
/// liste joker taşımadığı için adres, port veya yol bir karakter bile farklı
/// olursa Supabase dönüşü reddeder. Bu yüzden port meşgulse başka porta
/// **düşülmez** — o port listede yoktur.
const String windowsGoogleLoopbackRedirect =
    'http://127.0.0.1:53682/auth-callback';

/// [windowsGoogleLoopbackRedirect]'in ayrıştırılmış hâli (host/port/yol
/// buradan okunur; ikinci bir sabit tutulmaz).
final Uri windowsGoogleLoopbackUri = Uri.parse(windowsGoogleLoopbackRedirect);
