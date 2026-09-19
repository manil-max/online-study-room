// WP-866: Windows'ta "Google ile devam et" — tarayıcı + loopback + PKCE.
//
// Gerçek ağ ve gerçek tarayıcı YOK. Dinleyici gerçek bir `HttpServer`dır ama
// testte 127.0.0.1'e **rastgele** porta (0) bağlanır; "tarayıcı" aynı süreçten
// bu porta yapılan HTTP isteğidir. Sağlayıcı adresi ve kod değişimi sahte
// uçtan gelir; profil yolu gerçek depo + kayıt tutan sahte HTTP'dir.
//
// Ölçülenler:
//  1. Başarı: dinleyici tarayıcıdan ÖNCE bağlanır, dönen `code` değişime
//     birebir gider, profil döner, tarayıcıya başarı sayfası yazılır.
//  2. `error` (vazgeçme / ret) → cancelled, değişim yok.
//  3. Zaman aşımı → cancelled, port bırakılır.
//  4. Port meşgul → kendi kodu, tarayıcı hiç açılmaz, başka porta düşülmez.
//  5. İlgisiz istekler (favicon, başka yol, POST) yok sayılır.
//  6. Gerçek gotrue uçları: PKCE adresi ve `grant_type=pkce` değişimi.
//  7. Dönüş adresi tek kaynak ve Supabase izin listesiyle birebir aynı.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:online_study_room/core/config/auth_redirect_config.dart';
import 'package:online_study_room/core/config/google_sign_in_config.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
import 'package:online_study_room/features/auth/windows_google_loopback.dart';

import '../support/supabase_wire_harness.dart';

const _userId = 'google-win-user-1';
const _successLineTr = 'Giriş tamamlandı, uygulamaya dönebilirsin.';
const _successLineEn = 'Signed in, you can return to the app.';
const _failLineEn =
    'Sign-in was not completed. Return to the app and try again.';

Map<String, dynamic> _authResponse() => {
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': _userId,
    'email': 'ali@gmail.com',
    'aud': 'authenticated',
    'created_at': '2026-09-19T10:00:00Z',
    'app_metadata': {'provider': 'google'},
    'user_metadata': {'full_name': 'Ali Veli'},
  },
};

/// "Tarayıcı": dinleyiciye aynı süreçten istek atar, gövdeyi okur.
Future<({int status, String body, ContentType? type})> _browserGet(
  int port,
  String pathAndQuery, {
  String method = 'GET',
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$port$pathAndQuery'),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return (
      status: response.statusCode,
      body: body,
      type: response.headers.contentType,
    );
  } finally {
    client.close(force: true);
  }
}

/// Testte dinleyici rastgele porta bağlanır; bağlanan sunucu dışarı verilir
/// ki "tarayıcı" portu bilsin.
class _PortZeroBind {
  HttpServer? server;
  final List<(InternetAddress, int)> requested = [];

  /// Kapandıktan sonra `server.port` okunamaz; port bağlanırken saklanır.
  int? boundPort;

  Future<HttpServer> call(InternetAddress address, int port) async {
    requested.add((address, port));
    final bound = server = await HttpServer.bind(address, 0);
    boundPort = bound.port;
    return bound;
  }
}

/// Sahte tarayıcı + gotrue uçları. `onOpen`, tarayıcının açıldığı anda
/// yapılacak "kullanıcı" davranışıdır.
class _FakeBrowser implements GoogleBrowserOAuth {
  _FakeBrowser({
    required this.events,
    this.onOpen,
    this.opens = true,
    this.exchangeError,
  });

  final List<String> events;
  final Future<void> Function()? onOpen;
  final bool opens;
  final Object? exchangeError;
  final List<String> redirects = [];
  final List<String> exchangedCodes = [];
  final List<Future<void>> _browserWork = [];

  Future<void> settle() => Future.wait(_browserWork);

  @override
  Future<Uri> authorizeUrl({required String redirectTo}) async {
    events.add('authorizeUrl');
    redirects.add(redirectTo);
    return Uri.parse('https://example.supabase.co/auth/v1/authorize?x=1');
  }

  @override
  Future<bool> openExternal(Uri url) async {
    events.add('openExternal');
    final work = onOpen;
    // Tarayıcı uygulamadan bağımsız ilerler: dönüş beklenmeden gelir.
    if (work != null) _browserWork.add(work());
    return opens;
  }

  @override
  Future<supa.Session> exchangeCode(String code) async {
    events.add('exchangeCode');
    exchangedCodes.add(code);
    final e = exchangeError;
    if (e != null) throw e;
    return supa.Session.fromJson(_authResponse())!;
  }
}

void main() {
  group('WP-866 SupabaseAuthRepository.signInWithGoogle (Windows)', () {
    late SupabaseWireHarness wire;
    late _PortZeroBind bind;
    late List<String> events;

    setUp(() {
      wire = SupabaseWireHarness();
      bind = _PortZeroBind();
      events = [];
    });

    SupabaseAuthRepository repo(
      _FakeBrowser browser, {
      Duration timeout = const Duration(seconds: 10),
      LoopbackBind? customBind,
    }) => SupabaseAuthRepository(
      wire.client(),
      googleBrowserOAuth: browser,
      googleLoopback: WindowsGoogleLoopback(
        bind:
            customBind ??
            (address, port) {
              events.add('bind');
              return bind(address, port);
            },
        timeout: timeout,
      ),
    );

    test(
      'basari: once bind, sonra tarayici; code degisime birebir gider',
      () async {
        wire.respond('profiles', [
          {
            'id': _userId,
            'display_name': 'Ali Veli',
            'avatar_url': null,
            'created_at': '2026-09-19T10:00:00Z',
            'title_achievement_id': null,
          },
        ]);
        late ({int status, String body, ContentType? type}) page;
        final browser = _FakeBrowser(
          events: events,
          onOpen: () async {
            page = await _browserGet(
              bind.server!.port,
              '/auth-callback?code=pkce-code-123',
            );
          },
        );

        final profile = await repo(browser).signInWithGoogle();
        await browser.settle();

        // Sıra sözleşmedir: port alınmadan tarayıcı açılmaz.
        expect(events, [
          'bind',
          'authorizeUrl',
          'openExternal',
          'exchangeCode',
        ]);
        // Sabit adrese bağlanılmak istendi (testte 0'a yönlendirildi).
        expect(bind.requested.single.$1.address, '127.0.0.1');
        expect(bind.requested.single.$2, 53682);
        expect(browser.redirects.single, windowsGoogleLoopbackRedirect);
        expect(browser.exchangedCodes, ['pkce-code-123']);
        expect(profile.id, _userId);
        expect(profile.displayName, 'Ali Veli');
        expect(page.status, HttpStatus.ok);
        expect(page.type?.mimeType, 'text/html');
        expect(page.body, contains(_successLineTr));
        expect(page.body, contains(_successLineEn));
        // Kod tarayıcıya geri yazılmaz.
        expect(page.body, isNot(contains('pkce-code-123')));
      },
    );

    test('kullanici vazgecer / reddeder -> cancelled, degisim yok', () async {
      late ({int status, String body, ContentType? type}) page;
      final browser = _FakeBrowser(
        events: events,
        onOpen: () async {
          page = await _browserGet(
            bind.server!.port,
            '/auth-callback?error=access_denied'
            '&error_description=The+user+denied',
          );
        },
      );

      await expectLater(
        repo(browser).signInWithGoogle(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.cancelled,
          ),
        ),
      );
      await browser.settle();

      expect(browser.exchangedCodes, isEmpty);
      expect(wire.calls, isEmpty);
      expect(page.body, contains(_failLineEn));
      expect(page.body, isNot(contains(_successLineEn)));
    });

    test('zaman asimi -> cancelled (sessiz), port birakilir', () async {
      final browser = _FakeBrowser(events: events);

      await expectLater(
        repo(
          browser,
          timeout: const Duration(milliseconds: 150),
        ).signInWithGoogle(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.cancelled,
          ),
        ),
      );

      expect(browser.exchangedCodes, isEmpty);
      // Dinleyici kapandı: aynı porta yeniden bağlanılabiliyor.
      final again = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        bind.boundPort!,
      );
      await again.close(force: true);
    });

    test(
      'port mesgul -> kendi kodu; tarayici acilmaz, baska porta dusulmez',
      () async {
        final requestedPorts = <int>[];
        final browser = _FakeBrowser(events: events);

        await expectLater(
          repo(
            browser,
            customBind: (address, port) async {
              requestedPorts.add(port);
              throw SocketException(
                'Only one usage of each socket address',
                port: port,
              );
            },
          ).signInWithGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.code,
              'code',
              AuthErrorCode.loopbackPortBusy,
            ),
          ),
        );

        expect(requestedPorts, [53682]);
        expect(events, isEmpty);
      },
    );

    test('ilgisiz istekler yok sayilir, gercek donus sayilir', () async {
      wire.respond('profiles', [
        {
          'id': _userId,
          'display_name': 'Ali Veli',
          'avatar_url': null,
          'created_at': '2026-09-19T10:00:00Z',
          'title_achievement_id': null,
        },
      ]);
      final statuses = <int>[];
      final browser = _FakeBrowser(
        events: events,
        onOpen: () async {
          final port = bind.server!.port;
          statuses.add((await _browserGet(port, '/favicon.ico')).status);
          statuses.add((await _browserGet(port, '/?code=wrong-path')).status);
          statuses.add(
            (await _browserGet(
              port,
              '/auth-callback?code=posted',
              method: 'POST',
            )).status,
          );
          statuses.add(
            (await _browserGet(port, '/auth-callback?code=real-code')).status,
          );
        },
      );

      final profile = await repo(browser).signInWithGoogle();
      await browser.settle();

      expect(statuses, [404, 404, 404, 200]);
      expect(browser.exchangedCodes, ['real-code']);
      expect(profile.id, _userId);
    });

    test('tarayici acilamazsa kodsuz hata, dinleyici kapanir', () async {
      final browser = _FakeBrowser(events: events, opens: false);

      await expectLater(
        repo(browser).signInWithGoogle(),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', isNull)),
      );

      final again = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        bind.boundPort!,
      );
      await again.close(force: true);
    });

    test(
      'degisim reddedilirse iptal SAYILMAZ, tarayiciya basari yazilmaz',
      () async {
        late ({int status, String body, ContentType? type}) page;
        final browser = _FakeBrowser(
          events: events,
          exchangeError: supa.AuthException(
            'Code verifier could not be found in local storage.',
          ),
          onOpen: () async {
            page = await _browserGet(
              bind.server!.port,
              '/auth-callback?code=stale',
            );
          },
        );

        await expectLater(
          repo(browser).signInWithGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.code,
              'code',
              isNot(AuthErrorCode.cancelled),
            ),
          ),
        );
        await browser.settle();

        expect(page.body, contains(_failLineEn));
        expect(page.body, isNot(contains(_successLineEn)));
      },
    );
  });

  group('WP-866 WindowsGoogleLoopback', () {
    test('gercek port mesgulse LoopbackPortBusyException', () async {
      final holder = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => holder.close(force: true));
      final loopback = WindowsGoogleLoopback(
        redirect: Uri.parse('http://127.0.0.1:${holder.port}/auth-callback'),
      );

      await expectLater(
        loopback.open(),
        throwsA(
          isA<LoopbackPortBusyException>().having(
            (e) => e.port,
            'port',
            holder.port,
          ),
        ),
      );
    });

    test('ikinci donus sayilmaz, finish idempotent', () async {
      final bind = _PortZeroBind();
      final session = await WindowsGoogleLoopback(bind: bind.call).open();
      final first = _browserGet(session.port, '/auth-callback?code=one');
      final callback = await session.waitForCallback();
      expect(callback?.code, 'one');
      expect(callback?.denied, isFalse);

      final second = await _browserGet(session.port, '/auth-callback?code=two');
      expect(second.status, 404);

      await session.finish(signedIn: true);
      await session.finish(signedIn: true);
      expect((await first).status, 200);
    });

    test('sonuc sayfasi iki dilde, kacisli ve dis kaynaksiz', () {
      final ok = loopbackResultPage(signedIn: true);
      expect(ok, contains(_successLineTr));
      expect(ok, contains(_successLineEn));
      expect(ok, isNot(contains('<script')));
      expect(ok, isNot(contains('http')));
      final fail = loopbackResultPage(signedIn: false);
      expect(fail, contains(_failLineEn));
      expect(fail, contains('Giriş tamamlanamadı.'));
    });
  });

  group('WP-866 gercek gotrue PKCE uclari', () {
    test('authorize adresi: google + loopback + S256 + hesap secici', () async {
      final storage = _MemoryStorage();
      final client = supa.SupabaseClient(
        'http://localhost:54321',
        'test-anon-key',
        authOptions: supa.AuthClientOptions(pkceAsyncStorage: storage),
      );
      addTearDown(client.dispose);

      final url = await SupabaseGoogleBrowserOAuth(
        client,
      ).authorizeUrl(redirectTo: windowsGoogleLoopbackRedirect);

      expect(url.path, '/auth/v1/authorize');
      final q = url.queryParameters;
      expect(q['provider'], 'google');
      expect(q['redirect_to'], windowsGoogleLoopbackRedirect);
      expect(q['flow_type'], 'pkce');
      expect(q['code_challenge_method'], 's256');
      expect(q['code_challenge'], isNotEmpty);
      expect(q['prompt'], 'select_account');
      // Doğrulayıcı cihazda kalır, adrese girmez.
      final verifier = storage.values.values.single;
      expect(url.toString(), isNot(contains(verifier)));
    });

    test('degisim grant_type=pkce ile saklı dogrulayiciyi gonderir', () async {
      final storage = _MemoryStorage();
      http.Request? tokenRequest;
      final client = supa.SupabaseClient(
        'http://localhost:54321',
        'test-anon-key',
        authOptions: supa.AuthClientOptions(pkceAsyncStorage: storage),
        httpClient: MockClient((request) async {
          tokenRequest = request;
          return http.Response(
            jsonEncode(_authResponse()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final oauth = SupabaseGoogleBrowserOAuth(client);
      await oauth.authorizeUrl(redirectTo: windowsGoogleLoopbackRedirect);
      final verifier = storage.values.values.single;

      final session = await oauth.exchangeCode('code-from-loopback');

      expect(session.user.id, _userId);
      expect(tokenRequest!.url.path, '/auth/v1/token');
      expect(tokenRequest!.url.queryParameters['grant_type'], 'pkce');
      final body = jsonDecode(tokenRequest!.body) as Map<String, dynamic>;
      expect(body['auth_code'], 'code-from-loopback');
      expect(body['code_verifier'], verifier);
      // Tek kullanımlık: doğrulayıcı değişimden sonra silinir.
      expect(storage.values, isEmpty);
    });
  });

  group('WP-866 karar ve tek kaynak', () {
    test('Windows tarayici yolu, Android ID token yolu (degismedi)', () {
      GoogleSignInFlow? flow(TargetPlatform p, {String id = 'x.apps'}) =>
          GoogleSignInConfig.resolveFlow(
            webClientId: id,
            isWeb: false,
            platform: p,
          );

      expect(flow(TargetPlatform.android), GoogleSignInFlow.nativeIdToken);
      expect(flow(TargetPlatform.windows), GoogleSignInFlow.browserLoopback);
      // Beta (staging) derlemesi boş kimlik yazar: Windows'ta da kapalı.
      expect(flow(TargetPlatform.windows, id: ''), isNull);
      expect(flow(TargetPlatform.windows, id: '  '), isNull);
      expect(flow(TargetPlatform.macOS), isNull);
      expect(flow(TargetPlatform.linux), isNull);
      expect(flow(TargetPlatform.iOS), isNull);
      expect(
        GoogleSignInConfig.resolveFlow(
          webClientId: 'x.apps',
          isWeb: true,
          platform: TargetPlatform.windows,
        ),
        isNull,
      );
      expect(
        GoogleSignInConfig.resolveEnabled(
          webClientId: 'x.apps',
          isWeb: false,
          platform: TargetPlatform.windows,
          supabaseBackend: false,
        ),
        isFalse,
      );
    });

    test('donus adresi Supabase izin listesiyle birebir ayni', () {
      expect(windowsGoogleLoopbackUri.scheme, 'http');
      expect(windowsGoogleLoopbackUri.host, '127.0.0.1');
      expect(windowsGoogleLoopbackUri.port, 53682);
      expect(windowsGoogleLoopbackUri.path, '/auth-callback');
      final workflow = File(
        '../.github/workflows/supabase-auth-config.yml',
      ).readAsStringSync();
      final allowList = RegExp(
        r"allow_list='([^']*)'",
      ).firstMatch(workflow)!.group(1)!.split(',');
      expect(allowList, contains(windowsGoogleLoopbackRedirect));
    });
  });
}

class _MemoryStorage extends supa.GotrueAsyncStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> getItem({required String key}) async => values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}
