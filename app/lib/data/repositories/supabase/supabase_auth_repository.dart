import 'dart:typed_data';

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
    try {
      _current = await _profileFor(_client.auth.currentSession);
      yield _current;
    } catch (error) {
      if (await _recoverFromStaleRefreshToken(error)) {
        yield null;
      } else {
        rethrow;
      }
    }

    while (true) {
      try {
        await for (final state in _client.auth.onAuthStateChange) {
          try {
            _current = await _profileFor(state.session);
            yield _current;
          } catch (error) {
            if (await _recoverFromStaleRefreshToken(error)) {
              yield null;
            } else {
              rethrow;
            }
          }
        }
        return;
      } catch (error) {
        if (await _recoverFromStaleRefreshToken(error)) {
          yield null;
          continue;
        } else {
          rethrow;
        }
      }
    }
  }

  Future<bool> _recoverFromStaleRefreshToken(Object error) async {
    if (!_isStaleRefreshToken(error)) return false;
    await _clearLocalSession();
    return true;
  }

  bool _isStaleRefreshToken(Object error) {
    if (error is supa.AuthApiException) {
      final code = error.code?.toLowerCase();
      final message = error.message.toLowerCase();
      return code == 'refresh_token_already_used' ||
          message.contains('invalid refresh token');
    }
    if (error is supa.AuthException) {
      return error.message.toLowerCase().contains('invalid refresh token');
    }
    return false;
  }

  Future<void> _clearLocalSession() async {
    try {
      await _client.auth.signOut(scope: supa.SignOutScope.local);
    } catch (_) {
      // Oturum zaten bozuksa sign-out da hata verebilir; UI login'e dönmeli.
    }
    _current = null;
  }

  /// Oturumdaki kullanıcı için profil satırını getirir (yoksa metadata'dan kurar).
  Future<Profile?> _profileFor(supa.Session? session) async {
    final user = session?.user;
    if (user == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) return Profile.fromMap(row);
    } catch (_) {
      // Çevrimdışı veya geçici sunucu hatası: oturum geçerli ama profil satırı
      // çekilemedi. Kullanıcıyı dışarı atma (oturum kalıcılığı) — metadata'dan
      // geçici profille içeride tut; profil bağlanınca tekrar yüklenir.
    }
    // Trigger henüz profili oluşturmadıysa veya çevrimdışıysak metadata'dan profil.
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
      // E-posta doğrulama açıksa kayıt bir oturum (session) döndürmez: kullanıcı
      // doğrulamadan giriş yapamaz. Sessiz kalmak yerine net bilgi ver.
      if (res.session == null) {
        throw const AuthException(
          'Hesabın oluşturuldu. Giriş yapabilmek için e-postana gönderilen '
          'doğrulama bağlantısına tıkla. (Supabase’de e-posta doğrulamayı '
          'kapatırsan doğrulama gerekmez.)',
        );
      }
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
  Future<void> sendPasswordResetEmail(String email) async {
    final safe = email.trim();
    if (safe.isEmpty || !safe.contains('@')) {
      throw const AuthException('Geçerli bir e-posta girin.');
    }
    try {
      await _client.auth.resetPasswordForEmail(safe);
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
        .update({'display_name': name})
        .eq('id', cur.id);
    _current = cur.copyWith(displayName: name);
  }

  @override
  Future<void> updateDailyGoal(int minutes) async {
    final cur = _current;
    if (cur == null) return;
    final safe = minutes.clamp(1, 24 * 60);
    await _client
        .from('profiles')
        .update({'daily_goal_minutes': safe})
        .eq('id', cur.id);
    _current = cur.copyWith(dailyGoalMinutes: safe);
  }

  @override
  Future<void> updateAnimal(String animal) async {
    final cur = _current;
    if (cur == null) return;
    final safe = animal.trim();
    if (safe.isEmpty) return;
    await _client.from('profiles').update({'animal': safe}).eq('id', cur.id);
    _current = cur.copyWith(animal: safe);
  }

  @override
  Future<void> updateAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final cur = _current;
    if (cur == null) return;
    // Dosya yolu: <uid>/avatar — RLS politikası ilk klasörün uid olmasını şart koşar.
    final path = '${cur.id}/avatar';
    try {
      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: supa.FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          );
      final base = _client.storage.from('avatars').getPublicUrl(path);
      // Önbellek kırıcı: ayni yola yüklenince CDN eskisini göstermesin.
      final url = '$base?v=${DateTime.now().millisecondsSinceEpoch}';
      await _client
          .from('profiles')
          .update({'avatar_url': url})
          .eq('id', cur.id);
      _current = cur.copyWith(avatarUrl: url);
    } on supa.StorageException catch (e) {
      throw AuthException('Fotoğraf yüklenemedi: ${e.message}');
    }
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
