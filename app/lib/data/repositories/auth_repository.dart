import 'dart:typed_data';

import '../models/profile.dart';

/// Kimlik doğrulama hatası (kullanıcıya gösterilebilir Türkçe mesaj taşır).
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

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

  Future<Profile> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Profile> signIn({required String email, required String password});

  /// E-postaya şifre sıfırlama bağlantısı gönderir. Güvenlik için e-posta
  /// kayıtlı değilse bile kullanıcıya hesap var/yok bilgisi sızdırılmamalıdır.
  Future<void> sendPasswordResetEmail(String email);

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

  Future<void> signOut();
}
