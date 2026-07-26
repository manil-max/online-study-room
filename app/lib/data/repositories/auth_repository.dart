import 'dart:typed_data';

import '../models/account_deletion_status.dart';
import '../models/profile.dart';

/// WP-319: Hatanın **nedeni** için makine-okunur kod.
///
/// Mevcut ekranlar hatayı Türkçe mesaj metnine `contains` uygulayarak ayırıyor
/// ([auth_screen.dart:254](../../features/auth/auth_screen.dart)); bu kırılgan —
/// mesaj bir gün düzenlenirse dal sessizce yanlış tarafa düşer ve kullanıcı
/// "beklenmeyen hata" görür. Yeni yollar nedeni kodla taşır, UI kodu
/// yerelleştirir. Eski çağrı yerleri değişmedi: `code` isteğe bağlıdır.
class AuthErrorCode {
  const AuthErrorCode._();

  /// Mevcut şifre yanlış — **işlem yapılmadı**.
  static const String invalidCurrentPassword = 'invalid_current_password';

  /// Yeni şifre kural sınırının altında.
  static const String weakPassword = 'weak_password';

  /// Yeni şifre mevcut şifreyle aynı.
  static const String samePassword = 'same_password';

  /// Sunucu hız sınırı: art arda çok fazla deneme.
  static const String rateLimited = 'rate_limited';

  /// Oturum yok/süresi dolmuş.
  static const String noSession = 'no_session';
}

/// Kimlik doğrulama hatası (kullanıcıya gösterilebilir Türkçe mesaj taşır).
class AuthException implements Exception {
  const AuthException(this.message, {this.code});
  final String message;

  /// Varsa [AuthErrorCode] sabitlerinden biri; UI bunu yerelleştirir.
  final String? code;

  @override
  String toString() => message;
}

/// Kimlik doğrulama soyutlaması. Şimdilik bellek-içi implementasyonu kullanılır;
/// ileride Supabase implementasyonu ile değiştirilecek (bkz. project.md §4).
abstract class AuthRepository {
  /// Oturum durumu akışı: giriş yapan kullanıcı veya null (çıkış/giriş yok).
  Stream<Profile?> authStateChanges();

  /// O an giriş yapmış kullanıcı (yoksa null).
  Profile? get currentUser;

  /// O an giriş yapmış kullanıcının e-posta adresi (yoksa null).
  String? get currentUserEmail;

  Future<Profile> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Profile> signIn({required String email, required String password});

  /// E-postaya şifre sıfırlama bağlantısı (ve şablonda `{{ .Token }}` varsa 6
  /// haneli kod) gönderir. Güvenlik için e-posta kayıtlı değilse bile kullanıcıya
  /// hesap var/yok bilgisi sızdırılmamalıdır (user-enumeration koruması).
  Future<void> sendPasswordResetEmail(String email);

  /// WP-287: E-postadaki 6 haneli recovery kodu ile şifreyi sıfırlar.
  /// Derin bağlantının olmadığı platformlarda (Windows/masaüstü) ve link'in
  /// açılmadığı durumlarda tek çalışan yol budur; her platformda geçerlidir.
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Giriş yapan kullanıcının şifresini günceller.
  ///
  /// 🔴 **Mevcut şifreyi doğrulamaz.** Yalnız kimliğin **zaten** kanıtlandığı
  /// yerde kullanılır: recovery (OTP/derin bağlantı) oturumu. Ayarlar
  /// ekranından çağrılmaz — orası [changePassword] kullanır.
  Future<void> updatePassword(String newPassword);

  /// WP-319: Giriş yapan kullanıcının şifresini **mevcut şifresini doğrulayarak**
  /// değiştirir.
  ///
  /// Neden ayrı metot: Supabase `updateUser(password:)` eski şifreyi **kontrol
  /// etmez** — oturumu ele geçiren biri şifreyi sessizce değiştirebilir ve
  /// kullanıcı "mevcut şifre" alanını doldurduğu için korunduğunu sanır. Bu,
  /// alanın hiç olmamasından kötüdür. Doğrulama sorumluluğunu ekrana bırakmak
  /// yerine tek yere, repository sözleşmesine koyuyoruz: bu metodu çağıran
  /// doğrulamayı **atlayamaz**.
  ///
  /// Doğrulama başarısızsa hiçbir şey yazılmaz ve
  /// [AuthErrorCode.invalidCurrentPassword] kodlu [AuthException] atılır.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Giriş yapan kullanıcının e-postasını günceller.
  Future<void> updateEmail(String newEmail);

  /// Yalnızca şifre sıfırlama (recovery) oturumu başladığında tetiklenir.
  Stream<void> get passwordRecoveryEvents;

  /// Giriş yapan kullanıcının görünen adını günceller.
  Future<void> updateDisplayName(String displayName);

  /// Giriş yapan kullanıcının günlük hedefini (dakika) günceller (§3.7).
  Future<void> updateDailyGoal(int minutes);

  /// Giriş yapan kullanıcının kamp hayvanını günceller (§2G). [animal] katalog
  /// kimliğidir (bkz. `core/animals/camp_animal.dart`).
  Future<void> updateAnimal(String animal);

  /// Profil fotoğrafını yükler ve `avatar_url`'ı günceller (Supabase Storage gerekir).
  Future<void> updateAvatar({
    required Uint8List bytes,
    required String contentType,
  });

  /// Aylık çalışma raporu e-postası tercihini günceller.
  Future<void> updateMonthlyReportOptIn(bool value);

  /// WP-114: hesap silme isteği (14 gün grace, sunucu).
  Future<AccountDeletionStatus> requestAccountDeletion();

  /// Grace içinde iptal.
  Future<AccountDeletionStatus> cancelAccountDeletion();

  /// Son istek durumu.
  Future<AccountDeletionStatus> fetchAccountDeletionStatus();

  Future<void> signOut();
}
