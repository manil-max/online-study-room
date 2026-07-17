import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../models/account_deletion_status.dart';
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
  final StreamController<void> _recoveryController =
      StreamController<void>.broadcast();

  Profile? _current;

  @override
  Profile? get currentUser => _current;

  @override
  String? get currentUserEmail {
    if (_current == null) return null;
    for (final entry in _accounts.entries) {
      if (entry.value.profile.id == _current!.id) return entry.key;
    }
    return null;
  }

  @override
  Stream<void> get passwordRecoveryEvents => _recoveryController.stream;

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
  Future<void> sendPasswordResetEmail(String email) async {
    final key = email.trim().toLowerCase();
    if (key.isEmpty || !key.contains('@')) {
      throw const AuthException('Geçerli bir e-posta girin.');
    }
    // Güvenlik için hesap var/yok bilgisi dönülmez. Gerçek e-posta gönderimi
    // Supabase implementasyonunda yapılır.
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final cur = _current;
    if (cur == null) return;
    if (newPassword.length < 6) {
      throw const AuthException('Şifre en az 6 karakter olmalı.');
    }
    for (final key in _accounts.keys) {
      if (_accounts[key]!.profile.id == cur.id) {
        _accounts[key] = _Account(newPassword, _accounts[key]!.profile);
        break;
      }
    }
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    final cur = _current;
    if (cur == null) return;
    final key = newEmail.trim().toLowerCase();
    if (key.isEmpty || !key.contains('@')) {
      throw const AuthException('Geçerli bir e-posta girin.');
    }
    if (_accounts.containsKey(key)) {
      throw const AuthException('Bu e-posta zaten kayıtlı.');
    }

    String? oldKey;
    for (final k in _accounts.keys) {
      if (_accounts[k]!.profile.id == cur.id) {
        oldKey = k;
        break;
      }
    }
    if (oldKey != null) {
      final acc = _accounts.remove(oldKey)!;
      _accounts[key] = acc;
    }
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
  Future<void> updateDailyGoal(int minutes) async {
    final cur = _current;
    if (cur == null) return;
    final safe = minutes.clamp(1, 24 * 60);
    final updated = cur.copyWith(dailyGoalMinutes: safe);
    _current = updated;
    for (final acc in _accounts.values) {
      if (acc.profile.id == cur.id) acc.profile = updated;
    }
    _controller.add(updated);
  }

  @override
  Future<void> updateAnimal(String animal) async {
    final cur = _current;
    if (cur == null) return;
    final safe = animal.trim();
    if (safe.isEmpty) return;
    final updated = cur.copyWith(animal: safe);
    _current = updated;
    for (final acc in _accounts.values) {
      if (acc.profile.id == cur.id) acc.profile = updated;
    }
    _controller.add(updated);
  }

  @override
  Future<void> updateMonthlyReportOptIn(bool value) async {
    final cur = _current;
    if (cur == null) return;
    final updated = cur.copyWith(monthlyReportOptIn: value);
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
      'Profil fotoğrafı yüklemek için Supabase bağlantısı gerekli.',
    );
  }

  AccountDeletionStatus? _deletion;

  @override
  Future<AccountDeletionStatus> requestAccountDeletion() async {
    final cur = _current;
    if (cur == null) {
      throw const AuthException('Oturum bulunamadı.');
    }
    if (_deletion?.active == true) return _deletion!;
    final now = DateTime.now();
    _deletion = AccountDeletionStatus(
      active: true,
      status: 'scheduled',
      requestedAt: now,
      purgeAfter: now.add(const Duration(days: 14)),
    );
    return _deletion!;
  }

  @override
  Future<AccountDeletionStatus> cancelAccountDeletion() async {
    final d = _deletion;
    if (d == null || !d.active) {
      throw const AuthException('Aktif silme isteği yok.');
    }
    _deletion = const AccountDeletionStatus(active: false, status: 'canceled');
    return _deletion!;
  }

  @override
  Future<AccountDeletionStatus> fetchAccountDeletionStatus() async {
    return _deletion ?? AccountDeletionStatus.inactive;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
    _recoveryController.close();
  }
}
