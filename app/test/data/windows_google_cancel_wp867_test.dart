// WP-867: Windows Google girişinde tarayıcı beklerken "Vazgeç".
//
// Gerçek tarayıcı yok; dinleyici gerçek bir `HttpServer`dır ve testte
// 127.0.0.1'e rastgele porta (0) bağlanır (WP-866 test deseni).
//
// Ölçülenler:
//  1. LoopbackSession.cancel: bekleme null ile biter, port hemen bırakılır
//     (aynı porta yeniden bağlanılabilir), idempotenttir.
//  2. Dönüş zaten geldiyse cancel no-op'tur (kod değişimi bozulmaz).
//  3. Depo: bekleyen giriş cancelGoogleSignIn ile `cancelled` düşer, değişim
//     yok, port bırakılır ve yeniden deneme hemen başlar.
//  4. Vazgeç port alınırken gelirse tarayıcı hiç açılmaz.
//  5. Bekleyen akış yokken cancel no-op; bellek-içi depo da no-op.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
import 'package:online_study_room/features/auth/windows_google_loopback.dart';

import '../support/supabase_wire_harness.dart';

const _userId = 'google-win-user-867';

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

Future<int> _browserGet(int port, String pathAndQuery) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port$pathAndQuery'),
    );
    final response = await request.close();
    await response.transform(utf8.decoder).join();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

Future<void> _expectPortFree(int port) async {
  final again = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  await again.close(force: true);
}

class _PortZeroBind {
  HttpServer? server;
  int? boundPort;
  int binds = 0;

  /// Verilirse bağlama bu tamamlanana kadar bekler (port alınırken iptal).
  Completer<void>? gate;

  Future<HttpServer> call(InternetAddress address, int port) async {
    binds++;
    final g = gate;
    if (g != null) await g.future;
    final bound = server = await HttpServer.bind(address, 0);
    boundPort = bound.port;
    return bound;
  }
}

class _FakeBrowser implements GoogleBrowserOAuth {
  _FakeBrowser({this.onOpen});

  final Future<void> Function()? onOpen;
  int opens = 0;
  final List<String> exchangedCodes = [];
  final List<Future<void>> _work = [];

  Future<void> settle() => Future.wait(_work);

  @override
  Future<Uri> authorizeUrl({required String redirectTo}) async =>
      Uri.parse('https://example.supabase.co/auth/v1/authorize?x=1');

  @override
  Future<bool> openExternal(Uri url) async {
    opens++;
    final work = onOpen;
    if (work != null) _work.add(work());
    return true;
  }

  @override
  Future<supa.Session> exchangeCode(String code) async {
    exchangedCodes.add(code);
    return supa.Session.fromJson(_authResponse())!;
  }
}

final _isCancelled = throwsA(
  isA<AuthException>().having((e) => e.code, 'code', AuthErrorCode.cancelled),
);

/// Dinleyici bağlanıp bekleme başlayana kadar olay döngüsünü döndürür.
Future<void> _untilOpened(_PortZeroBind bind, _FakeBrowser browser) async {
  for (var i = 0; i < 200 && browser.opens == 0; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(browser.opens, 1, reason: 'tarayici acilmadi');
  expect(bind.server, isNotNull);
}

void main() {
  group('WP-867 LoopbackSession.cancel', () {
    test('bekleme null ile biter, port hemen birakilir, idempotent', () async {
      final bind = _PortZeroBind();
      final session = await WindowsGoogleLoopback(bind: bind.call).open();
      final wait = session.waitForCallback();

      await session.cancel();
      await session.cancel();

      expect(await wait, isNull);
      await _expectPortFree(bind.boundPort!);
      // finish sonradan çağrılsa da güvenli.
      await session.finish();
    });

    test('donus zaten geldiyse cancel no-op, kod korunur', () async {
      final bind = _PortZeroBind();
      final session = await WindowsGoogleLoopback(bind: bind.call).open();
      final page = _browserGet(session.port, '/auth-callback?code=early');
      final callback = await session.waitForCallback();

      await session.cancel();

      expect(callback?.code, 'early');
      // Dinleyici hâlâ açık: sonuç sayfasını finish yazar.
      await session.finish(signedIn: true);
      expect(await page, HttpStatus.ok);
      await _expectPortFree(bind.boundPort!);
    });
  });

  group('WP-867 SupabaseAuthRepository.cancelGoogleSignIn', () {
    late SupabaseWireHarness wire;
    late _PortZeroBind bind;

    setUp(() {
      wire = SupabaseWireHarness();
      bind = _PortZeroBind();
    });

    SupabaseAuthRepository repo(_FakeBrowser browser) => SupabaseAuthRepository(
      wire.client(),
      googleBrowserOAuth: browser,
      googleLoopback: WindowsGoogleLoopback(
        bind: bind.call,
        // Vazgeç olmadan 5 dakika beklenirdi; testte süre dolmaz.
        timeout: const Duration(minutes: 5),
      ),
    );

    test('bekleyen giris -> cancelled, degisim yok, port birakilir', () async {
      final browser = _FakeBrowser();
      final r = repo(browser);

      final pending = r.signInWithGoogle();
      final expectation = expectLater(pending, _isCancelled);
      await _untilOpened(bind, browser);
      await r.cancelGoogleSignIn();
      await expectation;

      expect(browser.exchangedCodes, isEmpty);
      expect(wire.calls, isEmpty);
      await _expectPortFree(bind.boundPort!);
    });

    test('vazgecten sonra yeniden deneme hemen calisir', () async {
      wire.respond('profiles', [
        {
          'id': _userId,
          'display_name': 'Ali Veli',
          'avatar_url': null,
          'created_at': '2026-09-19T10:00:00Z',
          'title_achievement_id': null,
        },
      ]);
      var attempt = 0;
      final browser = _FakeBrowser(
        onOpen: () async {
          attempt++;
          if (attempt == 2) {
            await _browserGet(bind.server!.port, '/auth-callback?code=retry');
          }
        },
      );
      final r = repo(browser);

      final first = expectLater(r.signInWithGoogle(), _isCancelled);
      await _untilOpened(bind, browser);
      await r.cancelGoogleSignIn();
      await first;

      final profile = await r.signInWithGoogle();
      await browser.settle();

      expect(bind.binds, 2);
      expect(browser.exchangedCodes, ['retry']);
      expect(profile.id, _userId);
    });

    test('port alinirken vazgecilirse tarayici hic acilmaz', () async {
      bind.gate = Completer<void>();
      final browser = _FakeBrowser();
      final r = repo(browser);

      final pending = expectLater(r.signInWithGoogle(), _isCancelled);
      await Future<void>.delayed(Duration.zero);
      await r.cancelGoogleSignIn();
      bind.gate!.complete();
      await pending;

      expect(browser.opens, 0);
      await _expectPortFree(bind.boundPort!);
    });

    test('bekleyen akis yokken no-op; sonraki giris etkilenmez', () async {
      final browser = _FakeBrowser(
        onOpen: () async {
          await _browserGet(
            bind.server!.port,
            '/auth-callback?error=access_denied',
          );
        },
      );
      final r = repo(browser);

      await r.cancelGoogleSignIn();

      // Önceki "Vazgeç" bir sonraki denemeyi baştan iptal etmez: akış
      // tarayıcıya kadar gider (burada kullanıcı reddeder).
      await expectLater(r.signInWithGoogle(), _isCancelled);
      await browser.settle();
      expect(browser.opens, 1);
    });

    test('bellek-ici depo: no-op', () async {
      await InMemoryAuthRepository().cancelGoogleSignIn();
    });
  });
}
