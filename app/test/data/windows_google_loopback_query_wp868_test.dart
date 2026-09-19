// WP-868: loopback dinleyicisi bozuk sorgu dizesiyle gelen isteği yanıtsız
// bırakıp dinleyicinin içinden yakalanmamış hata fırlatıyordu.
//
// Senaryo: `/auth-callback?code=a%E0b` (geçersiz UTF-8 yüzde kodlaması).
// Dart `HttpRequest.uri` bunu kabul eder ama `uri.queryParameters`
// `FormatException` atar. `_onRequest` içinde yakalanmadığı için:
//  - hata zone'a yakalanmamış hata olarak düşer (Flutter'da hata raporu),
//  - tarayıcı sekmesi yanıt almadan asılı kalır,
//  - akış ne tamamlanır ne düşer; 5 dakikalık zaman aşımına kadar bekler.
//
// Beklenen: istek 400 alır, akış bozulmaz; sonraki geçerli dönüş sayılır.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/features/auth/windows_google_loopback.dart';

Future<HttpServer> _bindPortZero(InternetAddress address, int port) =>
    HttpServer.bind(address, 0);

/// Ham soket: `HttpClient` bozuk yüzde kodlamasını yeniden kodlar, tarayıcı
/// ise adres çubuğundakini olduğu gibi yollar.
Future<String?> _rawGet(int port, String target) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  try {
    socket.write('GET $target HTTP/1.1\r\nHost: 127.0.0.1\r\n'
        'Connection: close\r\n\r\n');
    await socket.flush();
    return await socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 3), onTimeout: () => '');
  } finally {
    socket.destroy();
  }
}

void main() {
  test('bozuk sorgu 400 alir, akis bozulmaz, sonraki donus sayilir', () async {
    final uncaught = <Object>[];
    // Yalnız dinleyici korumalı zone'da kurulur: dinleyicinin içinden kaçan
    // hata buraya düşer, test gövdesinin kendi beklentileri düşmez.
    final opened = Completer<LoopbackSession>();
    runZonedGuarded(
      () => WindowsGoogleLoopback(
        bind: _bindPortZero,
        timeout: const Duration(minutes: 5),
      ).open().then(opened.complete),
      (error, _) => uncaught.add(error),
    );
    final session = await opened.future;
    try {
      final bad = await _rawGet(session.port, '/auth-callback?code=a%E0b');
      expect(
        bad,
        startsWith('HTTP/1.1 400'),
        reason: 'bozuk sorgu yanitsiz kaldi (tarayici sekmesi asili)',
      );

      final good = _rawGet(session.port, '/auth-callback?code=ok');
      final callback = await session.waitForCallback().timeout(
        const Duration(seconds: 3),
      );
      expect(callback?.code, 'ok');
      await session.finish(signedIn: true);
      expect(await good, startsWith('HTTP/1.1 200'));
    } finally {
      await session.finish();
    }
    expect(uncaught, isEmpty, reason: 'dinleyiciden yakalanmamis hata');
  });
}
