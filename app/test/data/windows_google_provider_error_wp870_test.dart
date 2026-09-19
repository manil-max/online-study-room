// WP-870: Windows Google girişinde sunucu/sağlayıcı hatası "kullanıcı
// vazgeçti" sayılıyordu.
//
// Senaryo: kullanıcı tarayıcıda hesabını seçer; Supabase kullanıcıyı
// kaydedemez (ör. `Database error saving new user`) ve dönüş adresine
// `?error=server_error&error_description=…` ile yollar. `LoopbackCallback.denied`
// her `error`u "reddetti" sayıyordu → depo `AuthErrorCode.cancelled` atıyor →
// giriş ekranı bilerek **hiçbir şey** göstermiyor. Tarayıcı "tamamlanamadı"
// derken uygulama sessiz kalıyor; kullanıcı düğmeye tekrar tekrar basıyor.
// Android yolunda aynı sunucu hatası ekrana yazılır.
//
// Beklenen: yalnız `access_denied` (kullanıcının kendi reddi) sessizdir;
// başka her `error` kodsuz AuthException'dır ve ekran hatayı gösterir.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
import 'package:online_study_room/features/auth/windows_google_loopback.dart';

import '../support/supabase_wire_harness.dart';

Future<void> _browserGet(int port, String pathAndQuery) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port$pathAndQuery'),
    );
    final response = await request.close();
    await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

class _PortZeroBind {
  HttpServer? server;

  Future<HttpServer> call(InternetAddress address, int port) async =>
      server = await HttpServer.bind(address, 0);
}

/// Tarayıcı açılınca dönüş adresine verilen sorguyla gelir.
class _ReturningBrowser implements GoogleBrowserOAuth {
  _ReturningBrowser(this.bind, this.query);

  final _PortZeroBind bind;
  final String query;
  final List<String> exchangedCodes = [];
  final List<Future<void>> _work = [];

  Future<void> settle() => Future.wait(_work);

  @override
  Future<Uri> authorizeUrl({required String redirectTo}) async =>
      Uri.parse('https://example.supabase.co/auth/v1/authorize?x=1');

  @override
  Future<bool> openExternal(Uri url) async {
    _work.add(_browserGet(bind.server!.port, '/auth-callback?$query'));
    return true;
  }

  @override
  Future<supa.Session> exchangeCode(String code) async {
    exchangedCodes.add(code);
    throw StateError('degisim beklenmiyordu');
  }
}

void main() {
  late SupabaseWireHarness wire;
  late _PortZeroBind bind;

  setUp(() {
    wire = SupabaseWireHarness();
    bind = _PortZeroBind();
  });

  SupabaseAuthRepository repo(GoogleBrowserOAuth browser) =>
      SupabaseAuthRepository(
        wire.client(),
        googleBrowserOAuth: browser,
        googleLoopback: WindowsGoogleLoopback(
          bind: bind.call,
          timeout: const Duration(seconds: 10),
        ),
      );

  test('sunucu hatasi sessiz vazgecis sayilmaz, ekran hatayi gosterir', () async {
    final browser = _ReturningBrowser(
      bind,
      'error=server_error&error_description=Database+error+saving+new+user',
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
    expect(browser.exchangedCodes, isEmpty);
  });

  test('kullanicinin kendi reddi (access_denied) sessiz kalir', () async {
    final browser = _ReturningBrowser(bind, 'error=access_denied');

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
  });
}
