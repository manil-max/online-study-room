import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/auth/windows_google_loopback.dart';

/// WP-875: zaman aşımı zamanlayıcısı `finish()`i başlatınca deponun
/// `finally`sindeki ikinci `finish()` kapanışı BEKLEMEDEN dönüyordu. Port daha
/// kapanmadan akış bitiyor; hemen yeniden deneme (ve CI Linux'ta WP-866
/// testi, beta-v8708) "shared flag to bind()" / port meşgul alıyordu.
///
/// Windows'ta kapanış neredeyse anlık olduğu için yarış yerelde görünmez; bu
/// yüzden kapanışı bilerek yavaşlatan bir sunucu sarmalayıcısıyla ölçülür.
class _SlowCloseServer extends StreamView<HttpRequest> implements HttpServer {
  _SlowCloseServer(this._inner) : super(_inner);

  final HttpServer _inner;
  final closeGate = Completer<void>();
  bool closed = false;

  @override
  int get port => _inner.port;

  @override
  Future<void> close({bool force = false}) async {
    await closeGate.future;
    await _inner.close(force: force);
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<(LoopbackSession, _SlowCloseServer)> open({
    Duration timeout = WindowsGoogleLoopback.defaultTimeout,
  }) async {
    late _SlowCloseServer server;
    final session = await WindowsGoogleLoopback(
      bind: (address, _) async =>
          server = _SlowCloseServer(await HttpServer.bind(address, 0)),
      timeout: timeout,
    ).open();
    return (session, server);
  }

  test('zaman asimindan sonra finish() kapanisi bekler', () async {
    final (session, server) = await open(
      timeout: const Duration(milliseconds: 1),
    );
    // Zaman aşımı: bekleme null ile biter, zamanlayıcı kapanışı başlatmıştır.
    expect(await session.waitForCallback(), isNull);

    var done = false;
    final finishing = session.finish().then((_) => done = true);
    await pumpEventQueue();
    expect(done, isFalse, reason: 'kapanış bitmeden finish() dönmemeli');

    server.closeGate.complete();
    await finishing;
    expect(server.closed, isTrue);
  });

  test('ayni anda iki finish ayni kapanisi paylasir', () async {
    final (session, server) = await open();
    final first = session.finish();
    var secondDone = false;
    final second = session.finish().then((_) => secondDone = true);
    await pumpEventQueue();
    expect(secondDone, isFalse);

    server.closeGate.complete();
    await Future.wait([first, second]);
    expect(server.closed, isTrue);
  });
}
