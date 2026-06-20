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

  Future<Profile> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
