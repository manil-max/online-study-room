// WP-834: şifre yazma reddinin **sebebi** koda çevriliyor mu?
//
// Sahip v85'te (gerçek cihaz, production) sıfırlama bağlantısından gelip yeni
// şifresini yazdı, "Beklenmeyen bir hata oluştu." gördü; **tek harf**
// değiştirince aynı şifre kabul edildi. Yani sunucu somut bir sebep söylemişti
// ve depo katmanı o sebebi kodsuz bırakıyordu.
//
// Bu test sahte bir HTTP istemcisiyle **gerçek** `SupabaseAuthRepository`yi
// çalıştırır ve gotrue'nun gövdesini birebir taklit eder. Kaynak tarayan bir
// test bu dönüşü kilitleyemez: kod dizesi dosyada dursa da dal ölü olabilir.
//
// Gövde biçimleri gotrue-2.22.0 `lib/src/fetch.dart:87-115` ve
// `lib/src/types/auth_exception.dart:93-105` okunarak yazıldı; kod dizeleri
// `lib/src/types/error_code.dart` satır 15/61/63/66/67'den alındı.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
// `show`: supabase da `AuthException` tanimliyor; bizimkiyle carpismasin.
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

void main() {
  const email = 'ali@example.com';

  Map<String, dynamic> tokenResponse() => {
    'access_token': 'test-access-token',
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': 'user-1',
      'email': email,
      'aud': 'authenticated',
      'created_at': '2026-09-01T10:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': {'display_name': 'Ali'},
    },
  };

  /// Giriş yapmış bir depo; `updateUser` (PUT /user) çağrısı [onWrite] ile
  /// belirlenen hatayla düşer. `token` (giriş + yeniden doğrulama) ve
  /// `profiles` yolları başarılı kalır ki test yalnız şifre yazmasını ölçsün.
  Future<SupabaseAuthRepository> repositoryFailingWriteWith(
    Future<http.StreamedResponse> Function(http.BaseRequest request) onWrite, {
    Future<http.StreamedResponse> Function(http.BaseRequest request)? onVerify,
  }) async {
    final client = SupabaseClient(
      'http://localhost:54321',
      'test-anon-key',
      httpClient: _FakeClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/verify') && onVerify != null) {
          return onVerify(request);
        }
        if (path.contains('/token')) return _json(request, tokenResponse());
        if (path.contains('/profiles')) return _json(request, <dynamic>[]);
        if (request.method == 'PUT' && path.endsWith('/user')) {
          return onWrite(request);
        }
        return _json(request, <String, dynamic>{});
      }),
    );
    final repository = SupabaseAuthRepository(client);
    await repository.signIn(email: email, password: 'guvenli123');
    return repository;
  }

  /// gotrue `weak_password` gövdesi: kodun yanında **sebep dizisi** gelir.
  http.StreamedResponse weakPasswordBody(
    http.BaseRequest request,
    List<String> reasons,
  ) {
    const text = 'Password is known to be weak and easy to guess.';
    return _json(request, {
      'error_code': 'weak_password',
      'msg': text,
      'message': text,
      'weak_password': {'reasons': reasons},
    }, status: 422);
  }

  Matcher throwsCode(String code) => throwsA(
    isA<AuthException>().having((e) => e.code, 'code', code),
  );

  group('WP-834 zayif sifre alt sebepleri', () {
    test('🔴 sizmis sifre (pwned) kendi kodunu alir', () async {
      final repository = await repositoryFailingWriteWith(
        (request) async => weakPasswordBody(request, const ['pwned']),
      );

      await expectLater(
        repository.updatePassword('yeniguvenli456'),
        throwsCode(AuthErrorCode.weakPasswordPwned),
      );
    });

    test('kisa sifre (length) kendi kodunu alir', () async {
      final repository = await repositoryFailingWriteWith(
        (request) async => weakPasswordBody(request, const ['length']),
      );

      await expectLater(
        repository.updatePassword('yeniguvenli456'),
        throwsCode(AuthErrorCode.weakPasswordLength),
      );
    });

    test('karakter cesidi (characters) kendi kodunu alir', () async {
      final repository = await repositoryFailingWriteWith(
        (request) async => weakPasswordBody(request, const ['characters']),
      );

      await expectLater(
        repository.updatePassword('yeniguvenli456'),
        throwsCode(AuthErrorCode.weakPasswordCharacters),
      );
    });

    test('sebep bildirilmezse genel zayif sifre koduna duser', () async {
      final repository = await repositoryFailingWriteWith(
        (request) async => weakPasswordBody(request, const []),
      );

      await expectLater(
        repository.updatePassword('yeniguvenli456'),
        throwsCode(AuthErrorCode.weakPassword),
      );
    });
  });

  group('WP-834 diger sifre yazma redleri', () {
    test('🔴 same_password kurtarma yolunda da kod tasir', () async {
      final repository = await repositoryFailingWriteWith(
        (request) async => _json(request, {
          'error_code': 'same_password',
          'msg': 'New password should be different from the old password.',
          'message': 'New password should be different from the old password.',
        }, status: 422),
      );

      await expectLater(
        repository.updatePassword('yeniguvenli456'),
        throwsCode(AuthErrorCode.samePassword),
      );
    });

    test(
      '🔴 ayarlardaki degistirme yolu da sebebi tasir (eskiden yalniz hiz siniri)',
      () async {
        final repository = await repositoryFailingWriteWith(
          (request) async => weakPasswordBody(request, const ['pwned']),
        );

        await expectLater(
          repository.changePassword(
            currentPassword: 'guvenli123',
            newPassword: 'yeniguvenli456',
          ),
          throwsCode(AuthErrorCode.weakPasswordPwned),
        );
      },
    );

    test('over_request_rate_limit hiz siniri kodunu verir', () async {
      final repository = await repositoryFailingWriteWith(
        (request) async => _json(request, {
          'error_code': 'over_request_rate_limit',
          'msg': 'Request rate limit reached',
          'message': 'Request rate limit reached',
        }, status: 429),
      );

      await expectLater(
        repository.updatePassword('yeniguvenli456'),
        throwsCode(AuthErrorCode.rateLimited),
      );
    });

    test('session_not_found oturum koduna duser', () async {
      final repository = await repositoryFailingWriteWith(
        (request) async => _json(request, {
          'error_code': 'session_not_found',
          'msg': 'Session from session_id claim in JWT does not exist',
          'message': 'Session from session_id claim in JWT does not exist',
        }, status: 403),
      );

      await expectLater(
        repository.updatePassword('yeniguvenli456'),
        throwsCode(AuthErrorCode.noSession),
      );
    });

    test('🔴 kod ile sifirlamada otp_expired kodsuz kalmaz', () async {
      final repository = await repositoryFailingWriteWith(
        (request) async => _json(request, <String, dynamic>{}),
        onVerify: (request) async => _json(request, {
          'error_code': 'otp_expired',
          'msg': 'Token has expired or is invalid',
          'message': 'Token has expired or is invalid',
        }, status: 403),
      );

      await expectLater(
        repository.resetPasswordWithCode(
          email: email,
          code: '123456',
          newPassword: 'yeniguvenli456',
        ),
        throwsCode(AuthErrorCode.otpExpired),
      );
    });
  });
}

http.StreamedResponse _json(
  http.BaseRequest request,
  Object body, {
  int status = 200,
}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    status,
    request: request,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}
