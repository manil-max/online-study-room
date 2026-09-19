// WP-871: "Vazgeç" PKCE adresi hazırlanırken gelirse tarayıcı yine açılıyordu.
//
// WP-867 sözleşmesi: "Vazgeç port alınırken geldiyse tarayıcı hiç açılmaz."
// Ama bağlama ile tarayıcı arasında ikinci bir bekleme daha var:
// `authorizeUrl` (gotrue PKCE doğrulayıcısını diske yazar). Vazgeç o sırada
// gelince dinleyici kapanıyor, fakat depo bayrağa bir daha bakmadan
// `openExternal` çağırıyordu: kullanıcı vazgeçtikten sonra Google sayfası
// açılıyor ve oradan dönüş, kapanmış porta düşüp "siteye ulaşılamıyor"
// hatasıyla bitiyordu.
//
// Beklenen: Vazgeç tarayıcı açılmadan önceki her beklemede geçerlidir.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
import 'package:online_study_room/features/auth/windows_google_loopback.dart';

import '../support/supabase_wire_harness.dart';

class _PortZeroBind {
  int? boundPort;

  Future<HttpServer> call(InternetAddress address, int port) async {
    final server = await HttpServer.bind(address, 0);
    boundPort = server.port;
    return server;
  }
}

/// `authorizeUrl` kapı açılana kadar bekler (PKCE doğrulayıcısı yazılıyor).
class _SlowAuthorizeBrowser implements GoogleBrowserOAuth {
  final authorizeStarted = Completer<void>();
  final gate = Completer<void>();
  int opens = 0;

  @override
  Future<Uri> authorizeUrl({required String redirectTo}) async {
    authorizeStarted.complete();
    await gate.future;
    return Uri.parse('https://example.supabase.co/auth/v1/authorize?x=1');
  }

  @override
  Future<bool> openExternal(Uri url) async {
    opens++;
    return true;
  }

  @override
  Future<supa.Session> exchangeCode(String code) =>
      throw StateError('degisim beklenmiyordu');
}

void main() {
  test('adres hazirlanirken vazgecilirse tarayici acilmaz', () async {
    final wire = SupabaseWireHarness();
    final bind = _PortZeroBind();
    final browser = _SlowAuthorizeBrowser();
    final repo = SupabaseAuthRepository(
      wire.client(),
      googleBrowserOAuth: browser,
      googleLoopback: WindowsGoogleLoopback(
        bind: bind.call,
        timeout: const Duration(seconds: 10),
      ),
    );

    final pending = expectLater(
      repo.signInWithGoogle(),
      throwsA(
        isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.cancelled,
        ),
      ),
    );
    await browser.authorizeStarted.future;
    await repo.cancelGoogleSignIn();
    browser.gate.complete();
    await pending;

    expect(browser.opens, 0, reason: 'vazgecildikten sonra tarayici acildi');
    // Port bırakıldı.
    final again = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      bind.boundPort!,
    );
    await again.close(force: true);
  });
}
