import 'dart:typed_data';

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/account_deletion_status.dart';
import '../../models/profile.dart';
import '../auth_repository.dart';

/// Kimlik e-postalarının (şifre sıfırlama ve e-posta değişikliği) mevcut auth
/// derin bağlantı hedefini üretir. Eski public parametre adı geriye uyumluluk
/// için `recoveryRedirect` olarak korunur.
typedef RecoveryRedirectResolver = Future<String?> Function();

/// Supabase tabanlı kimlik doğrulama. UI hiç değişmeden bellek-içi yerine geçer.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._client, {
    RecoveryRedirectResolver? recoveryRedirect,
  }) : _recoveryRedirect = recoveryRedirect ?? (() async => null);

  final supa.SupabaseClient _client;

  /// Auth bağlantılarının döneceği derin bağlantı (Android) veya null.
  final RecoveryRedirectResolver _recoveryRedirect;
  Profile? _current;
  final _recoveryController = StreamController<void>.broadcast();

  /// WP-478: profil mutasyonlarının yayın kanalı.
  ///
  /// `authStateChanges()` yalnız **iki** olayda yayın yapıyordu: açılıştaki ilk
  /// okuma ve auth durumu değişimi. `updateTitle` gibi profil mutasyonları
  /// `_current`'ı tazeliyor ama akışa hiçbir şey düşmüyordu; `authStateProvider`
  /// bu akıştan beslendiği için ekranlar **bayat profili** okumaya devam
  /// ediyordu. Ünvanda görünmesinin sebebi iki ayrı ekranın (Başarımlar ve
  /// Sosyal Profil) aynı gerçeği okumasıydı — diğer alanlar yerel `setState`
  /// tuttuğu için hatayı gizliyordu.
  final _profileMutations = StreamController<Profile?>.broadcast();

  /// Güncellenmiş profili dinleyicilere duyurur.
  void _emitProfile() {
    if (_profileMutations.isClosed) return;
    _profileMutations.add(_current);
  }

  @override
  Profile? get currentUser => _current;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  Stream<void> get passwordRecoveryEvents => _recoveryController.stream;

  @override
  Stream<Profile?> authStateChanges() {
    // İki kaynak tek akışta birleşir: oturum olayları ve profil mutasyonları.
    // Mutasyonlar `async*` gövdesine dışarıdan enjekte edilemediği için
    // birleştirme burada yapılıyor.
    final merged = StreamController<Profile?>();
    StreamSubscription<Profile?>? sessions;
    StreamSubscription<Profile?>? mutations;
    merged
      ..onListen = () {
        sessions = _sessionProfiles().listen(
          merged.add,
          onError: merged.addError,
          onDone: merged.close,
        );
        mutations = _profileMutations.stream.listen(merged.add);
      }
      ..onCancel = () {
        // 🔴 `_sessionProfiles()` `await for` içinde askıdayken `cancel()`
        // **tamamlanmıyor**: `async*` üreticisi ancak kaynak bir olay daha
        // ürettiğinde çözülüyor, `onAuthStateChange` ise sessiz kalabiliyor.
        // Bu davranış WP-478 öncesinde de vardı (akış doğrudan bu üreticiydi);
        // burada yalnız **beklenmiyor**, aksi hâlde iptal eden taraf askıda
        // kalırdı. Ölçüldü: `test/data/auth_profile_emission_test.dart`.
        unawaited(sessions?.cancel() ?? Future<void>.value());
        return mutations?.cancel() ?? Future<void>.value();
      };
    return merged.stream;
  }

  Stream<Profile?> _sessionProfiles() async* {
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
          if (state.event == supa.AuthChangeEvent.passwordRecovery) {
            _recoveryController.add(null);
          }
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
      // WP-287: redirectTo verilmezse Supabase linki Site URL'e (localhost)
      // yönlendiriyordu → "check your internet connection". Android'de derin
      // bağlantıya yönlendir; Windows/masaüstünde null döner ve kullanıcı
      // e-postadaki kodu (OTP) kullanır. Hesap var/yok bilgisi sızdırılmaz.
      final redirectTo = await _recoveryRedirect();
      await _client.auth.resetPasswordForEmail(safe, redirectTo: redirectTo);
    } on supa.AuthException catch (e) {
      throw AuthException(_translateRecovery(e.message));
    }
  }

  @override
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final safeEmail = email.trim();
    final safeCode = code.trim();
    if (safeEmail.isEmpty || !safeEmail.contains('@')) {
      throw const AuthException('Geçerli bir e-posta girin.');
    }
    if (safeCode.isEmpty) {
      throw const AuthException('Kodu gir.');
    }
    if (newPassword.length < 6) {
      throw const AuthException('Şifre en az 6 karakter olmalı.');
    }
    try {
      // Kod recovery oturumu kurar, ardından yeni şifre yazılır.
      await _client.auth.verifyOTP(
        email: safeEmail,
        token: safeCode,
        type: supa.OtpType.recovery,
      );
      await _client.auth.updateUser(supa.UserAttributes(password: newPassword));
    } on supa.AuthException catch (e) {
      throw AuthException(_translateRecovery(e.message));
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    if (newPassword.length < 6) {
      throw const AuthException('Şifre en az 6 karakter olmalı.');
    }
    try {
      await _client.auth.updateUser(supa.UserAttributes(password: newPassword));
    } on supa.AuthException catch (e) {
      throw AuthException(_translate(e.message));
    }
  }

  /// WP-319: mevcut şifre **gerçekten** doğrulanır, sonra yenisi yazılır.
  ///
  /// Supabase'de eski şifreyi doğrulayan bir API yok; tek yol aynı şifreyle
  /// yeniden kimlik doğrulamak. Bu çağrı başarılı olursa aynı kullanıcı için
  /// yeni bir oturum kurulur (kullanıcı değişmez, dışarı atılmaz); başarısızsa
  /// `updateUser`'a **hiç gelinmez**.
  ///
  /// WP-319-G: yazma başarılı olunca **diğer tüm oturumlar** kapatılır.
  @override
  Future<PasswordChangeOutcome> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AuthException(
        'Oturum bulunamadı. Yeniden giriş yap.',
        code: AuthErrorCode.noSession,
      );
    }
    if (newPassword.length < 6) {
      throw const AuthException(
        'Şifre en az 6 karakter olmalı.',
        code: AuthErrorCode.weakPassword,
      );
    }
    if (newPassword == currentPassword) {
      throw const AuthException(
        'Yeni şifre mevcut şifreyle aynı olamaz.',
        code: AuthErrorCode.samePassword,
      );
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on supa.AuthException catch (e) {
      throw AuthException(
        _reauthMessage(e.message),
        code: _isRateLimit(e.message)
            ? AuthErrorCode.rateLimited
            : AuthErrorCode.invalidCurrentPassword,
      );
    }

    try {
      await _client.auth.updateUser(supa.UserAttributes(password: newPassword));
    } on supa.AuthException catch (e) {
      throw AuthException(
        _translate(e.message),
        code: _isRateLimit(e.message) ? AuthErrorCode.rateLimited : null,
      );
    }

    // Buradan sonra şifre **değişmiştir**. Diğer cihazların oturumu kapatılamazsa
    // atılacak bir istisna kullanıcıya "işlem olmadı" dedirtir ve artık geçersiz
    // olan eski şifreyle tekrar denetir; bu yüzden hata değil **sonuç** dönülür.
    return await _revokeOtherSessions()
        ? PasswordChangeOutcome.done
        : PasswordChangeOutcome.otherSessionsKept;
  }

  /// WP-319-G: bu cihaz hariç tüm oturumları sonlandırır (`SignOutScope.others`).
  ///
  /// `others` kapsamı yerel oturuma dokunmaz ve `signedOut` olayı **yayınlamaz**
  /// (gotrue `signOut`), yani kullanıcı kendi cihazında giriş ekranına düşmez —
  /// düşseydi bu özellik cezaya dönerdi ve kullanılmazdı.
  Future<bool> _revokeOtherSessions() async {
    try {
      await _client.auth.signOut(scope: supa.SignOutScope.others);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// WP-458: e-posta değişikliği, mevcut şifreyle yeniden doğrulanmadan
  /// `updateUser` aşamasına geçemez. Supabase güvenli e-posta değişikliği
  /// açıksa cevapta `newEmail` pending kalır ve mevcut e-posta oturumda
  /// korunur; bağlantıların doğrulanmasını SDK/Supabase tamamlar.
  @override
  Future<EmailChangeOutcome> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final currentEmail = _client.auth.currentUser?.email?.trim().toLowerCase();
    if (currentEmail == null ||
        currentEmail.isEmpty ||
        _client.auth.currentSession == null) {
      throw const AuthException(
        'Oturum bulunamadı. Yeniden giriş yap.',
        code: AuthErrorCode.noSession,
      );
    }
    final key = newEmail.trim().toLowerCase();
    if (key.isEmpty || !key.contains('@')) {
      throw const AuthException(
        'Geçerli bir e-posta girin.',
        code: AuthErrorCode.invalidEmail,
      );
    }
    if (key == currentEmail) {
      throw const AuthException(
        'Yeni e-posta mevcut e-postayla aynı olamaz.',
        code: AuthErrorCode.sameEmail,
      );
    }

    try {
      await _client.auth.signInWithPassword(
        email: currentEmail,
        password: currentPassword,
      );
    } on supa.AuthException catch (e) {
      throw AuthException(
        _reauthMessage(e.message),
        code: _isRateLimit(e.message)
            ? AuthErrorCode.rateLimited
            : AuthErrorCode.invalidCurrentPassword,
      );
    }

    try {
      final redirectTo = await _recoveryRedirect();
      final response = await _client.auth.updateUser(
        supa.UserAttributes(email: key),
        emailRedirectTo: redirectTo,
      );
      final pendingEmail = response.user?.newEmail?.trim();
      return pendingEmail != null && pendingEmail.isNotEmpty
          ? EmailChangeOutcome.verificationPending
          : EmailChangeOutcome.confirmed;
    } on supa.AuthException catch (e) {
      throw AuthException(
        _translate(e.message),
        code: _emailChangeCode(e.message),
      );
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
    try {
      await _client
          .from('profiles')
          .update({'display_name': name})
          .eq('id', cur.id);
    } on supa.PostgrestException catch (error) {
      if (error.message.contains('public_name_not_allowed')) {
        throw const AuthException('public_name_not_allowed');
      }
      rethrow;
    }
    _current = cur.copyWith(displayName: name);
    _emitProfile();
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
    _emitProfile();
  }

  @override
  Future<void> updateAnimal(String animal) async {
    final cur = _current;
    if (cur == null) return;
    final safe = animal.trim();
    if (safe.isEmpty) return;
    await _client.from('profiles').update({'animal': safe}).eq('id', cur.id);
    _current = cur.copyWith(animal: safe);
    _emitProfile();
  }

  @override
  Future<void> updateTitle(String? achievementId) async {
    final cur = _current;
    if (cur == null) return;
    final safe = achievementId?.trim();
    final value = (safe == null || safe.isEmpty) ? null : safe;
    try {
      await _client
          .from('profiles')
          .update({'title_achievement_id': value})
          .eq('id', cur.id);
    } on supa.PostgrestException catch (error) {
      // 0115 trigger'i: kazanilmamis unvan sunucuda reddedilir. Ekran bu
      // durumu kullaniciya anlasilir gostersin diye kod korunur.
      if (error.message.contains('title_not_earned')) {
        throw const AuthException('title_not_earned');
      }
      rethrow;
    }
    _current = value == null
        ? cur.copyWith(clearTitle: true)
        : cur.copyWith(titleAchievementId: value);
    _emitProfile();
  }

  @override
  Future<void> updateMonthlyReportOptIn(bool value) async {
    final cur = _current;
    if (cur == null) return;
    await _client
        .from('profiles')
        .update({'monthly_report_opt_in': value})
        .eq('id', cur.id);
    _current = cur.copyWith(monthlyReportOptIn: value);
    _emitProfile();
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
      _emitProfile();
    } on supa.StorageException catch (e) {
      throw AuthException('Fotoğraf yüklenemedi: ${e.message}');
    }
  }

  @override
  Future<AccountDeletionStatus> requestAccountDeletion() async {
    try {
      final raw = await _client.rpc('request_account_deletion');
      if (raw is Map) {
        return AccountDeletionStatus.fromMap(Map<String, dynamic>.from(raw));
      }
      return AccountDeletionStatus.inactive;
    } on supa.PostgrestException catch (e) {
      throw AuthException(_translate(e.message));
    }
  }

  @override
  Future<AccountDeletionStatus> cancelAccountDeletion() async {
    try {
      final raw = await _client.rpc('cancel_account_deletion');
      if (raw is Map) {
        return AccountDeletionStatus.fromMap(Map<String, dynamic>.from(raw));
      }
      return AccountDeletionStatus.inactive;
    } on supa.PostgrestException catch (e) {
      throw AuthException(_translate(e.message));
    }
  }

  @override
  Future<AccountDeletionStatus> fetchAccountDeletionStatus() async {
    try {
      final raw = await _client.rpc('my_account_deletion_status');
      if (raw is Map) {
        return AccountDeletionStatus.fromMap(Map<String, dynamic>.from(raw));
      }
      return AccountDeletionStatus.inactive;
    } on supa.PostgrestException catch (e) {
      throw AuthException(_translate(e.message));
    }
  }

  @override
  Future<void> signOut() async {
    // WP-266: token eski hesaba bağlı kalıp çıkıştan sonra özel bildirim
    // göstermesin. Push cleanup hatası oturum kapatmayı engellemez; yeni login
    // aynı tokenı atomik olarak yeni kullanıcıya taşır.
    try {
      final prefs = await SharedPreferences.getInstance();
      final installationId = prefs.getString('push_installation_id_v1');
      if (installationId != null && installationId.trim().isNotEmpty) {
        await _client.rpc(
          'unregister_push_device',
          params: {'p_installation_id': installationId.trim()},
        );
      }
    } catch (_) {}
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

  /// WP-319: hız sınırı mı, yoksa yanlış şifre mi? İkisi kullanıcıya **farklı**
  /// şey söyler: biri "yanlış yazdın", diğeri "biraz bekle".
  bool _isRateLimit(String message) {
    final m = message.toLowerCase();
    return m.contains('security purposes') ||
        m.contains('rate limit') ||
        m.contains('too many') ||
        m.contains('only request');
  }

  /// Yeniden kimlik doğrulama hatası. Buraya yalnız "mevcut şifre" denemesi
  /// düşer, giriş ekranı değil — bu yüzden mesaj "e-posta veya şifre hatalı"
  /// değil, doğrudan **mevcut şifre** hakkındadır.
  String _reauthMessage(String message) {
    if (_isRateLimit(message)) {
      return 'Çok sık denedin. Biraz bekleyip tekrar dene.';
    }
    return 'Mevcut şifre hatalı.';
  }

  String? _emailChangeCode(String message) {
    final m = message.toLowerCase();
    if (_isRateLimit(message)) return AuthErrorCode.rateLimited;
    if (m.contains('already registered') ||
        m.contains('already exists') ||
        m.contains('already been registered')) {
      return AuthErrorCode.emailAlreadyInUse;
    }
    if (m.contains('invalid') && m.contains('email')) {
      return AuthErrorCode.invalidEmail;
    }
    if (m.contains('session') &&
        (m.contains('missing') || m.contains('expired'))) {
      return AuthErrorCode.noSession;
    }
    return null;
  }

  /// Recovery/OTP akışına özel hata çevirisi (kod süresi + hız sınırı).
  String _translateRecovery(String message) {
    final m = message.toLowerCase();
    if (m.contains('expired') ||
        m.contains('invalid') ||
        m.contains('token has')) {
      return 'Kod geçersiz veya süresi dolmuş. Yeni kod iste.';
    }
    if (m.contains('security purposes') ||
        m.contains('rate limit') ||
        m.contains('too many') ||
        m.contains('only request')) {
      return 'Çok sık denedin. Biraz bekleyip tekrar dene.';
    }
    return _translate(message);
  }
}
