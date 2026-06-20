import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../models/profile.dart';
import '../auth_repository.dart';

/// Supabase tabanlı kimlik doğrulama. UI hiç değişmeden bellek-içi yerine geçer.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final supa.SupabaseClient _client;
  Profile? _current;

  @override
  Profile? get currentUser => _current;

  @override
  Stream<Profile?> authStateChanges() async* {
    // Açılışta mevcut oturum (varsa) yayınlanır.
    _current = await _profileFor(_client.auth.currentSession);
    yield _current;

    await for (final state in _client.auth.onAuthStateChange) {
      _current = await _profileFor(state.session);
      yield _current;
    }
  }

  /// Oturumdaki kullanıcı için profil satırını getirir (yoksa metadata'dan kurar).
  Future<Profile?> _profileFor(supa.Session? session) async {
    final user = session?.user;
    if (user == null) return null;
    final row =
        await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (row != null) return Profile.fromMap(row);
    // Trigger henüz profili oluşturmadıysa metadata'dan geçici profil.
    return Profile(
      id: user.id,
      displayName: (user.userMetadata?['display_name'] as String?) ?? '',
      createdAt: DateTime.now(),
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
      final profile = Profile(
        id: user.id,
        displayName: displayName,
        createdAt: DateTime.now(),
      );
      _current = profile;
      return profile;
    } on supa.AuthException catch (e) {
      throw AuthException(_translate(e.message));
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
    } on supa.AuthException catch (e) {
      throw AuthException(_translate(e.message));
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
    await _client
        .from('profiles')
        .update({'display_name': name}).eq('id', cur.id);
    _current = cur.copyWith(displayName: name);
  }

  @override
  Future<void> signOut() async {
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
}
