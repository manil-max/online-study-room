import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../models/profile.dart';
import '../auth_repository.dart';

class _Account {
  _Account(this.password, this.profile);
  final String password;
  Profile profile;
}

/// Bellek-içi (kalıcı olmayan) kimlik doğrulama. Geliştirme/test için; uygulama
/// yeniden başlayınca veriler sıfırlanır. Supabase entegrasyonuna kadar geçicidir.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository();

  final _uuid = const Uuid();
  final Map<String, _Account> _accounts = {};
  final StreamController<Profile?> _controller =
      StreamController<Profile?>.broadcast();

  Profile? _current;

  @override
  Profile? get currentUser => _current;

  @override
  Stream<Profile?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<Profile> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final key = email.trim().toLowerCase();
    if (key.isEmpty || !key.contains('@')) {
      throw const AuthException('Geçerli bir e-posta girin.');
    }
    if (password.length < 6) {
      throw const AuthException('Şifre en az 6 karakter olmalı.');
    }
    if (displayName.trim().isEmpty) {
      throw const AuthException('Görünen ad boş olamaz.');
    }
    if (_accounts.containsKey(key)) {
      throw const AuthException('Bu e-posta zaten kayıtlı.');
    }

    final profile = Profile(
      id: _uuid.v4(),
      displayName: displayName.trim(),
      createdAt: DateTime.now(),
    );
    _accounts[key] = _Account(password, profile);
    _current = profile;
    _controller.add(_current);
    return profile;
  }

  @override
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    final account = _accounts[key];
    if (account == null || account.password != password) {
      throw const AuthException('E-posta veya şifre hatalı.');
    }
    _current = account.profile;
    _controller.add(_current);
    return account.profile;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final cur = _current;
    if (cur == null) return;
    final name = displayName.trim();
    if (name.isEmpty) {
      throw const AuthException('Görünen ad boş olamaz.');
    }
    final updated = cur.copyWith(displayName: name);
    _current = updated;
    for (final acc in _accounts.values) {
      if (acc.profile.id == cur.id) acc.profile = updated;
    }
    _controller.add(updated);
  }

  @override
  Future<void> updateAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    // Bellek-içi modda gerçek depolama yok; yükleme Supabase gerektirir.
    throw const AuthException(
        'Profil fotoğrafı yüklemek için Supabase bağlantısı gerekli.');
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
