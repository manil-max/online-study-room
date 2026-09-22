// WP-902: "Apple ile devam et" — Supabase deposunun kablo ucu + iOS Google.
//
// Gerçek `SupabaseAuthRepository` + gerçek gotrue istemcisi, sahte HTTP.
// Apple eklentisi platform kanalı istediği için yalnız kimlik bilgisi
// dikişi sahtedir; Supabase'e giden istek **gerçekten** ölçülür.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:online_study_room/core/config/google_sign_in_config.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
import 'package:online_study_room/features/auth/apple_sign_in_availability.dart';

import '../support/supabase_wire_harness.dart';

const _userId = 'apple-user-1';

Map<String, dynamic> _authResponse({
  String provider = 'apple',
  List<String> providers = const ['apple'],
}) => {
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': _userId,
    'email': 'x7@privaterelay.appleid.com',
    'aud': 'authenticated',
    'created_at': '2026-09-22T10:00:00Z',
    'app_metadata': {'provider': provider, 'providers': providers},
    'user_metadata': <String, dynamic>{},
  },
};

List<Map<String, dynamic>> _profileRow(String name) => [
  {
    'id': _userId,
    'display_name': name,
    'avatar_url': null,
    'created_at': '2026-09-22T10:00:00Z',
    'title_achievement_id': null,
  },
];

AuthorizationCredentialAppleID _credential({
  String? identityToken = 'apple-id-token',
  String? givenName,
  String? familyName,
}) => AuthorizationCredentialAppleID(
  userIdentifier: '000123.abc',
  givenName: givenName,
  familyName: familyName,
  authorizationCode: 'auth-code',
  email: null,
  identityToken: identityToken,
  state: null,
);

/// Apple'a verilen (özetlenmiş) nonce'u kaydeden sahte dikiş.
class _FakeApple {
  _FakeApple({this.credential, this.error});

  final AuthorizationCredentialAppleID? credential;
  final Object? error;
  final List<String> hashedNonces = [];

  Future<AuthorizationCredentialAppleID> call(String hashedNonce) async {
    hashedNonces.add(hashedNonce);
    final e = error;
    if (e != null) throw e;
    return credential ?? _credential();
  }
}

class _NoncedGoogle implements GoogleIdTokenSource, GoogleIdTokenNonce {
  @override
  String? get rawNonce => 'raw-google-nonce';

  @override
  Future<String?> fetchIdToken() async => 'google-ios-id-token';

  @override
  Future<void> signOut() async {}
}

void main() {
  late SupabaseWireHarness wire;

  setUp(() => wire = SupabaseWireHarness());

  group('WP-902 nonce yardimcilari', () {
    test('ham nonce rastgele, 32 karakter; ozet SHA-256 onaltilik', () {
      final a = generateRawNonce();
      final b = generateRawNonce();
      expect(a, hasLength(32));
      expect(a, isNot(b));
      // Bilinen vektör: sha256("abc").
      expect(
        sha256OfNonce('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('Apple adi 0142 tetikleyicisiyle ayni normalize edilir', () {
      expect(appleDisplayName('Ayşe', 'Yılmaz'), 'Ayşe Yılmaz');
      expect(appleDisplayName('  Ali  ', null), 'Ali');
      expect(appleDisplayName(null, null), isNull);
      expect(appleDisplayName('  ', ''), isNull);
      // 24 sınırı + kesimden sonra kırpma.
      expect(
        appleDisplayName('Abcdefghijklmnopqrstuvw', 'Xyz'),
        'Abcdefghijklmnopqrstuvw',
      );
    });
  });

  group('WP-902 SupabaseAuthRepository.signInWithApple', () {
    test('kimlik token + HAM nonce Supabase\'e, Apple\'a OZET gider', () async {
      wire.respond('token', _authResponse());
      wire.respond('profiles', _profileRow('Ayşe'));
      final apple = _FakeApple();
      final repository = SupabaseAuthRepository(
        wire.client(),
        appleCredential: apple.call,
      );

      final profile = await repository.signInWithApple();

      final token = wire.calls.firstWhere((c) => c.table == 'token');
      expect(token.method, 'POST');
      expect(token.url.queryParameters['grant_type'], 'id_token');
      expect(token.json['provider'], 'apple');
      expect(token.json['id_token'], 'apple-id-token');
      final rawNonce = token.json['nonce'] as String;
      expect(rawNonce, hasLength(32));
      expect(apple.hashedNonces, [sha256OfNonce(rawNonce)]);
      expect(apple.hashedNonces.single, isNot(rawNonce));
      expect(profile.id, _userId);
      expect(repository.currentUser?.id, _userId);
      // Apple şifre kimliği değildir: hesap silme şifre sormamalı.
      expect(repository.currentUserHasPassword, isFalse);
    });

    test('ilk giris: profilde ad yoksa Apple adi yazilir', () async {
      wire.respond('token', _authResponse());
      wire.respond('profiles', _profileRow(''));
      final repository = SupabaseAuthRepository(
        wire.client(),
        appleCredential: _FakeApple(
          credential: _credential(givenName: 'Ayşe', familyName: 'Yılmaz'),
        ).call,
      );

      final profile = await repository.signInWithApple();

      final patch = wire.calls.singleWhere((c) => c.method == 'PATCH');
      expect(patch.table, 'profiles');
      expect(patch.json['display_name'], 'Ayşe Yılmaz');
      expect(patch.url.queryParameters['id'], 'eq.$_userId');
      expect(profile.displayName, 'Ayşe Yılmaz');
    });

    test('mevcut ad EZILMEZ (Apple adi gelse bile)', () async {
      wire.respond('token', _authResponse());
      wire.respond('profiles', _profileRow('Kamp Adım'));
      final repository = SupabaseAuthRepository(
        wire.client(),
        appleCredential: _FakeApple(
          credential: _credential(givenName: 'Ayşe', familyName: 'Yılmaz'),
        ).call,
      );

      final profile = await repository.signInWithApple();

      expect(wire.calls.where((c) => c.method == 'PATCH'), isEmpty);
      expect(profile.displayName, 'Kamp Adım');
    });

    test('ad yazimi reddedilirse giris yine basarili', () async {
      // Profil tablosu (GET yedeğe düşer, PATCH ad filtresine takılır).
      final failing = SupabaseWireHarness();
      failing.respond('token', _authResponse());
      failing.failWith(
        'profiles',
        status: 400,
        message: 'public_name_not_allowed',
        code: 'P0001',
      );
      final repo2 = SupabaseAuthRepository(
        failing.client(),
        appleCredential: _FakeApple(
          credential: _credential(givenName: 'Ayşe'),
        ).call,
      );
      final p2 = await repo2.signInWithApple();
      expect(p2.id, _userId);
      expect(repo2.currentUser?.id, _userId);
      expect(failing.calls.where((c) => c.method == 'PATCH'), hasLength(1));
    });

    test('kullanici vazgecerse cancelled kodu, sunucuya istek yok', () async {
      final repository = SupabaseAuthRepository(
        wire.client(),
        appleCredential: _FakeApple(
          error: const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'The user canceled the authorization attempt.',
          ),
        ).call,
      );

      await expectLater(
        repository.signInWithApple(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.cancelled,
          ),
        ),
      );
      expect(wire.calls, isEmpty);
    });

    test('baska Apple hatasi iptal SAYILMAZ (kodsuz, adli hata)', () async {
      final repository = SupabaseAuthRepository(
        wire.client(),
        appleCredential: _FakeApple(
          error: const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.failed,
            message: 'failed',
          ),
        ).call,
      );

      await expectLater(
        repository.signInWithApple(),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', isNull)
              .having(
                (e) => e.message,
                'message',
                'apple_sign_in_failed_failed',
              ),
        ),
      );
      expect(wire.calls, isEmpty);
    });

    test('kimlik token yoksa sunucuya gidilmez', () async {
      final repository = SupabaseAuthRepository(
        wire.client(),
        appleCredential: _FakeApple(
          credential: _credential(identityToken: null),
        ).call,
      );

      await expectLater(
        repository.signInWithApple(),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', isNull)
              .having((e) => e.message, 'message', 'apple_id_token_missing'),
        ),
      );
      expect(wire.calls, isEmpty);
    });

    test('sunucu reddederse kod mevcut siniflandiricidan gelir', () async {
      wire.respond('token', {
        'error_code': 'over_request_rate_limit',
        'msg': 'Too many requests',
        'message': 'Too many requests',
      }, status: 429);
      final repository = SupabaseAuthRepository(
        wire.client(),
        appleCredential: _FakeApple().call,
      );

      await expectLater(
        repository.signInWithApple(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.rateLimited,
          ),
        ),
      );
    });

    test('iOS disinda varsayilan dikis yok: fail-closed', () async {
      // flutter_test platformu Android'dir.
      final repository = SupabaseAuthRepository(wire.client());

      await expectLater(
        repository.signInWithApple(),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', isNull)),
      );
      expect(wire.calls, isEmpty);
    });

    test('e-posta hesabi sifreli sayilir', () async {
      wire.respond(
        'token',
        _authResponse(provider: 'email', providers: ['email']),
      );
      wire.respond('profiles', _profileRow('Ali'));
      final repository = SupabaseAuthRepository(wire.client());
      expect(repository.currentUserHasPassword, isFalse); // oturum yok
      await repository.signIn(email: 'ali@ornek.com', password: 'guvenli123');
      expect(repository.currentUserHasPassword, isTrue);
    });
  });

  test('WP-902 bellek-ici depo Apple girisini taklit etmez', () async {
    final repository = InMemoryAuthRepository();
    addTearDown(repository.dispose);

    await expectLater(
      repository.signInWithApple(),
      throwsA(isA<AuthException>().having((e) => e.code, 'code', isNull)),
    );
    expect(repository.currentUser, isNull);
    expect(repository.currentUserHasPassword, isFalse);
  });

  group('WP-902 Apple uygunluk tablosu', () {
    test('yalniz iOS + Supabase', () {
      bool on(TargetPlatform p, {bool web = false, bool supabase = true}) =>
          resolveAppleSignInEnabled(
            isWeb: web,
            platform: p,
            supabaseBackend: supabase,
          );

      expect(on(TargetPlatform.iOS), isTrue);
      expect(on(TargetPlatform.iOS, supabase: false), isFalse);
      expect(on(TargetPlatform.iOS, web: true), isFalse);
      expect(on(TargetPlatform.android), isFalse);
      expect(on(TargetPlatform.windows), isFalse);
      expect(on(TargetPlatform.macOS), isFalse);
      expect(on(TargetPlatform.linux), isFalse);
    });
  });

  group('WP-902 iOS Google', () {
    test(
      'iOS: web + iOS kimligi doluysa native ID token, biri bossa kapali',
      () {
        GoogleSignInFlow? flow({
          String web = 'web.apps',
          String ios = 'ios.apps',
        }) => GoogleSignInConfig.resolveFlow(
          webClientId: web,
          iosClientId: ios,
          isWeb: false,
          platform: TargetPlatform.iOS,
        );

        expect(flow(), GoogleSignInFlow.nativeIdToken);
        expect(flow(ios: ''), isNull);
        expect(flow(ios: '  '), isNull);
        expect(flow(web: ''), isNull);
        expect(
          GoogleSignInConfig.resolveEnabled(
            webClientId: 'web.apps',
            iosClientId: 'ios.apps',
            isWeb: false,
            platform: TargetPlatform.iOS,
            supabaseBackend: true,
          ),
          isTrue,
        );
        expect(
          GoogleSignInConfig.resolveEnabled(
            webClientId: 'web.apps',
            iosClientId: 'ios.apps',
            isWeb: false,
            platform: TargetPlatform.iOS,
            supabaseBackend: false,
          ),
          isFalse,
        );
        // Diğer platformlar iOS kimliğinden etkilenmez.
        for (final p in [TargetPlatform.macOS, TargetPlatform.linux]) {
          expect(
            GoogleSignInConfig.resolveFlow(
              webClientId: 'web.apps',
              iosClientId: 'ios.apps',
              isWeb: false,
              platform: p,
            ),
            isNull,
          );
        }
        expect(
          GoogleSignInConfig.resolveFlow(
            webClientId: 'web.apps',
            iosClientId: 'ios.apps',
            isWeb: true,
            platform: TargetPlatform.iOS,
          ),
          isNull,
        );
        expect(
          GoogleSignInConfig.resolveFlow(
            webClientId: 'web.apps',
            isWeb: false,
            platform: TargetPlatform.android,
          ),
          GoogleSignInFlow.nativeIdToken,
        );
      },
    );

    test(
      'nonce tasiyan kaynak: ham nonce signInWithIdToken\'a gider',
      () async {
        wire.respond(
          'token',
          _authResponse(provider: 'google', providers: ['google']),
        );
        wire.respond('profiles', _profileRow('Ali'));
        final repository = SupabaseAuthRepository(
          wire.client(),
          googleIdTokenSource: _NoncedGoogle(),
        );

        await repository.signInWithGoogle();

        final token = wire.calls.firstWhere((c) => c.table == 'token');
        expect(token.json['provider'], 'google');
        expect(token.json['id_token'], 'google-ios-id-token');
        expect(token.json['nonce'], 'raw-google-nonce');
      },
    );

    test('Android eklenti kaynagi nonce tasimaz', () {
      final source = PluginGoogleIdTokenSource(serverClientId: 'web.apps');
      expect(source.rawNonce, isNull);
      expect(source.clientId, isNull);
    });
  });
}
