// WP-831: "Google ile devam et" — Supabase deposunun kablo ucu.
//
// Gerçek `SupabaseAuthRepository` + gerçek gotrue istemcisi, sahte HTTP.
// Google eklentisi platform kanalı istediği için yalnız ID token kaynağı
// sahtedir; Supabase'e giden istek **gerçekten** ölçülür.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:online_study_room/core/config/google_sign_in_config.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';

import '../support/supabase_wire_harness.dart';

const _userId = 'google-user-1';

Map<String, dynamic> _authResponse() => {
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': _userId,
    'email': 'ali@gmail.com',
    'aud': 'authenticated',
    'created_at': '2026-09-16T10:00:00Z',
    'app_metadata': {'provider': 'google'},
    'user_metadata': {'full_name': 'Ali Veli'},
  },
};

class _FakeGoogle implements GoogleIdTokenSource {
  _FakeGoogle({
    this.idToken = 'google-id-token',
    this.error,
    this.signOutError,
  });

  final String? idToken;
  final Object? error;
  final Object? signOutError;
  int fetchCalls = 0;
  int signOutCalls = 0;

  @override
  Future<String?> fetchIdToken() async {
    fetchCalls++;
    final e = error;
    if (e != null) throw e;
    return idToken;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final e = signOutError;
    if (e != null) throw e;
  }
}

void main() {
  late SupabaseWireHarness wire;

  setUp(() => wire = SupabaseWireHarness());

  group('WP-831 SupabaseAuthRepository.signInWithGoogle', () {
    test(
      'ID token Supabase id_token grant ile gider, profil sunucudan okunur',
      () async {
        wire.respond('token', _authResponse());
        wire.respond('profiles', [
          {
            'id': _userId,
            'display_name': 'Ali Veli',
            'avatar_url': null,
            'created_at': '2026-09-16T10:00:00Z',
            'title_achievement_id': null,
          },
        ]);
        final google = _FakeGoogle();
        final repository = SupabaseAuthRepository(
          wire.client(),
          googleIdTokenSource: google,
        );

        final profile = await repository.signInWithGoogle();

        expect(google.fetchCalls, 1);
        final token = wire.calls.firstWhere((c) => c.table == 'token');
        expect(token.method, 'POST');
        expect(token.url.queryParameters['grant_type'], 'id_token');
        expect(token.json['provider'], 'google');
        expect(token.json['id_token'], 'google-id-token');
        // Nonce verilmez: token nonce taşımıyorsa Supabase kontrolü atlar.
        expect(token.json['nonce'], isNull);
        // İstemci görünen adı YAZMAZ (DB trigger'ının işi).
        expect(wire.calls.where((c) => c.method == 'PATCH'), isEmpty);
        expect(profile.id, _userId);
        expect(profile.displayName, 'Ali Veli');
        expect(repository.currentUser?.id, _userId);
      },
    );

    test(
      'kullanici seciciyi kapatirsa cancelled kodu, sunucuya istek yok',
      () async {
        final repository = SupabaseAuthRepository(
          wire.client(),
          googleIdTokenSource: _FakeGoogle(
            error: const GoogleSignInException(
              code: GoogleSignInExceptionCode.canceled,
            ),
          ),
        );

        await expectLater(
          repository.signInWithGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.code,
              'code',
              AuthErrorCode.cancelled,
            ),
          ),
        );
        expect(wire.calls, isEmpty);
      },
    );

    test('baska eklenti hatasi iptal SAYILMAZ (kodsuz hata)', () async {
      final repository = SupabaseAuthRepository(
        wire.client(),
        googleIdTokenSource: _FakeGoogle(
          error: const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
          ),
        ),
      );

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', isNull)),
      );
      expect(wire.calls, isEmpty);
    });

    test('ID token yoksa sunucuya gidilmez', () async {
      final repository = SupabaseAuthRepository(
        wire.client(),
        googleIdTokenSource: _FakeGoogle(idToken: null),
      );

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', isNull)),
      );
      expect(wire.calls, isEmpty);
    });

    test('sunucu reddederse kod mevcut sinflandiricidan gelir', () async {
      wire.respond('token', {
        'error_code': 'over_request_rate_limit',
        'msg': 'Too many requests',
        'message': 'Too many requests',
      }, status: 429);
      final repository = SupabaseAuthRepository(
        wire.client(),
        googleIdTokenSource: _FakeGoogle(),
      );

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.rateLimited,
          ),
        ),
      );
    });

    test(
      'yapilandirma yoksa (test ortami: Android degil) fail-closed',
      () async {
        // Varsayılan kaynak yalnız Android + dolu kimlikte kurulur.
        expect(GoogleSignInConfig.platformEnabled, isFalse);
        final repository = SupabaseAuthRepository(wire.client());

        await expectLater(
          repository.signInWithGoogle(),
          throwsA(isA<AuthException>().having((e) => e.code, 'code', isNull)),
        );
        expect(wire.calls, isEmpty);
      },
      // CI release koşumu GOOGLE_WEB_CLIENT_ID'yi doldurur ve flutter_test
      // platformu Android'dir: orada "yapılandırma yok" durumu kurulamaz.
      skip: GoogleSignInConfig.platformEnabled
          ? 'GOOGLE_WEB_CLIENT_ID dolu (CI define); fail-closed yolu kurulamaz'
          : false,
    );
  });

  group('WP-831 signOut Google oturumunu da kapatir', () {
    test('Google signOut cagrilir', () async {
      final google = _FakeGoogle();
      final repository = SupabaseAuthRepository(
        wire.client(),
        googleIdTokenSource: google,
      );

      await repository.signOut();

      expect(google.signOutCalls, 1);
    });

    test('Google signOut hatasi Supabase cikisini engellemez', () async {
      final google = _FakeGoogle(signOutError: StateError('plugin down'));
      final repository = SupabaseAuthRepository(
        wire.client(),
        googleIdTokenSource: google,
      );

      await repository.signOut();

      expect(google.signOutCalls, 1);
      expect(repository.currentUser, isNull);
    });
  });

  group('WP-831 GoogleSignInConfig karari', () {
    test('yalniz Android + dolu kimlik + Supabase', () {
      bool enabled({
        String id = 'web-client.apps.googleusercontent.com',
        bool isWeb = false,
        TargetPlatform platform = TargetPlatform.android,
        bool supabase = true,
      }) => GoogleSignInConfig.resolveEnabled(
        webClientId: id,
        isWeb: isWeb,
        platform: platform,
        supabaseBackend: supabase,
      );

      expect(enabled(), isTrue);
      expect(enabled(id: ''), isFalse);
      expect(enabled(id: '   '), isFalse);
      expect(enabled(isWeb: true), isFalse);
      expect(enabled(platform: TargetPlatform.windows), isFalse);
      expect(enabled(platform: TargetPlatform.iOS), isFalse);
      expect(enabled(supabase: false), isFalse);
    });
  });

  test('WP-831 bellek-ici depo Google girisini taklit etmez', () async {
    final repository = InMemoryAuthRepository();
    addTearDown(repository.dispose);

    await expectLater(
      repository.signInWithGoogle(),
      throwsA(isA<AuthException>().having((e) => e.code, 'code', isNull)),
    );
    expect(repository.currentUser, isNull);
  });
}
