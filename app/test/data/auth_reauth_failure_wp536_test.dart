import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
// `show`: supabase da `AuthException` tanimliyor; bizimkiyle carpismasin.
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// WP-536: yeniden kimlik doğrulama hatası **şifre hakkında hüküm vermemeli**.
///
/// Sahip sahada şunu bildirdi: *"doğru şifre girmeme rağmen birkaç kez hata
/// veriyor, öyle girebiliyorum."*
///
/// Kök neden: `changePassword` mevcut şifreyi `signInWithPassword` ile
/// doğruluyor ve o çağrıdan gelen **her** `AuthException` — hız sınırı hariç —
/// `invalidCurrentPassword` sayılıyordu. Ağ hatası da (`gotrue` onu
/// `AuthRetryableFetchException` olarak sarar) bu kovaya düşüyordu; yani
/// bağlantı bir an titrediğinde kullanıcıya "mevcut şifre hatalı" deniyordu.
///
/// 🔴 Bu testin ilk sürümü **kaynak taramasıydı ve yalancı yeşildi**: ilgili
/// satırın başına `if (false && ...)` yazınca metin dosyada durduğu için test
/// geçmeye devam etti. Bu sürüm gerçek `SupabaseAuthRepository`yi sahte bir
/// HTTP istemcisiyle çalıştırır ve **davranışı** ölçer.
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
      'created_at': '2026-08-01T10:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': {'display_name': 'Ali'},
    },
  };

  /// İlk `token` çağrısı (giriş) başarılı döner; sonraki `token` çağrısı
  /// (mevcut şifre doğrulaması) [onReauth] ile belirlenen şekilde başarısız
  /// olur. `profiles` okumaları boş liste döner.
  Future<SupabaseAuthRepository> repositoryFailingReauthWith(
    Future<http.StreamedResponse> Function(http.BaseRequest request) onReauth,
  ) async {
    var tokenCalls = 0;
    final client = SupabaseClient(
      'http://localhost:54321',
      'test-anon-key',
      httpClient: _FakeClient((request) async {
        final path = request.url.path;
        if (path.contains('/token')) {
          tokenCalls++;
          if (tokenCalls > 1) return onReauth(request);
          return _json(request, tokenResponse());
        }
        if (path.contains('/profiles')) return _json(request, <dynamic>[]);
        return _json(request, <String, dynamic>{});
      }),
    );
    final repository = SupabaseAuthRepository(client);
    await repository.signIn(email: email, password: 'guvenli123');
    return repository;
  }

  test('ag hatasi: sifre suclanmaz, network kodu doner', () async {
    final repository = await repositoryFailingReauthWith(
      (_) async => throw http.ClientException('connection closed'),
    );

    await expectLater(
      repository.changePassword(
        currentPassword: 'guvenli123',
        newPassword: 'yeniguvenli456',
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.network,
        ),
      ),
    );
  });

  test('sunucu invalid_credentials derse sifre hatali denir', () async {
    final repository = await repositoryFailingReauthWith(
      (request) async => _json(request, {
        'error_code': 'invalid_credentials',
        'msg': 'Invalid login credentials',
        'message': 'Invalid login credentials',
      }, status: 400),
    );

    await expectLater(
      repository.changePassword(
        currentPassword: 'yanlissifre',
        newPassword: 'yeniguvenli456',
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.invalidCurrentPassword,
        ),
      ),
    );
  });

  test('hiz siniri ayri kalir', () async {
    final repository = await repositoryFailingReauthWith(
      (request) async => _json(request, {
        'error_code': 'over_request_rate_limit',
        'msg': 'For security purposes, you can only request this after 25s.',
        'message':
            'For security purposes, you can only request this after 25s.',
      }, status: 429),
    );

    await expectLater(
      repository.changePassword(
        currentPassword: 'guvenli123',
        newPassword: 'yeniguvenli456',
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.rateLimited,
        ),
      ),
    );
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
