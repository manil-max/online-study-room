import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../core/config/auth_redirect_config.dart';
import '../../l10n/app_localizations.dart';

/// WP-866: Windows'ta Google girişinin **dönüş ucu** (RFC 8252 loopback).
///
/// Akış: uygulama [windowsGoogleLoopbackRedirect] adresinde kısa ömürlü bir
/// HTTP dinleyicisi açar → tarayıcı Google + Supabase'ten geçip bu adrese
/// `?code=…` ile döner → tek istek alınır, tarayıcıya küçük bir sayfa
/// yazılır, dinleyici kapanır.
///
/// Bu dosya yalnız dinleyicidir: tarayıcıyı açmak ve kodu oturuma çevirmek
/// Supabase deposunun işidir. Kod/token burada **asla** loglanmaz.

/// Dinleyiciyi bağlayan dikiş (testte meşgul port ve sahte bağlama için).
typedef LoopbackBind =
    Future<HttpServer> Function(InternetAddress address, int port);

Future<HttpServer> _bindLoopback(InternetAddress address, int port) =>
    HttpServer.bind(address, port);

/// Sabit port başka bir süreçte açık. Başka porta düşülmez: o port Supabase
/// yönlendirme izin listesinde yoktur ve dönüş reddedilir.
class LoopbackPortBusyException implements Exception {
  const LoopbackPortBusyException(this.port);
  final int port;

  @override
  String toString() => 'LoopbackPortBusyException(port: $port)';
}

/// Dönüş adresine gelen **tek** istek.
///
/// Supabase başarıda `code`, kullanıcı reddettiğinde veya sağlayıcı hata
/// verdiğinde `error` (+ `error_description`) taşır.
class LoopbackCallback {
  const LoopbackCallback({this.code, this.error});

  final String? code;
  final String? error;

  /// Kullanıcı vazgeçti / izin vermedi / sağlayıcı reddetti.
  bool get denied => error != null && error!.isNotEmpty;
}

/// Dinleyici fabrikası: sabit adres, sabit port, zaman aşımı.
class WindowsGoogleLoopback {
  WindowsGoogleLoopback({
    LoopbackBind? bind,
    Uri? redirect,
    this.timeout = defaultTimeout,
  }) : _bind = bind ?? _bindLoopback,
       _redirect = redirect ?? windowsGoogleLoopbackUri;

  /// Kullanıcı tarayıcıda bu süre içinde dönmezse akış sessizce biter.
  static const defaultTimeout = Duration(minutes: 5);

  final LoopbackBind _bind;
  final Uri _redirect;
  final Duration timeout;

  /// Tarayıcı açılmadan **önce** çağrılır: port alınamıyorsa kullanıcı boşuna
  /// Google'a gönderilmez.
  ///
  /// Port meşgulse [LoopbackPortBusyException] atar.
  Future<LoopbackSession> open() async {
    final HttpServer server;
    try {
      server = await _bind(InternetAddress(_redirect.host), _redirect.port);
    } on SocketException {
      throw LoopbackPortBusyException(_redirect.port);
    }
    return LoopbackSession._(server, _redirect.path, timeout);
  }
}

/// Açık bir dinleyici. [finish] çağrılana (veya zaman aşımı dolana) kadar
/// yaşar; ikisi de idempotenttir.
class LoopbackSession {
  LoopbackSession._(this._server, this._path, Duration timeout) {
    _subscription = _server.listen(
      _onRequest,
      // Bozuk bir istek (yarım bağlantı vb.) akışı düşürmez.
      onError: (Object _) {},
      cancelOnError: false,
    );
    _timer = Timer(timeout, () {
      _complete(null);
      unawaited(finish());
    });
  }

  final HttpServer _server;
  final String _path;
  late final StreamSubscription<HttpRequest> _subscription;
  late final Timer _timer;
  final _result = Completer<LoopbackCallback?>();

  /// Dönüş isteği; sayfa [finish]te yazılsın diye bekletilir.
  HttpRequest? _pending;
  bool _finished = false;

  /// Dinleyicinin gerçekten bağlandığı port (testte 0 ile bağlanır).
  int get port => _server.port;

  /// Dönüşü bekler. Zaman aşımında veya erken kapanışta `null` döner.
  Future<LoopbackCallback?> waitForCallback() => _result.future;

  void _complete(LoopbackCallback? value) {
    if (!_result.isCompleted) _result.complete(value);
  }

  void _onRequest(HttpRequest request) {
    // Yalnız ilk `GET <yol>` sayılır. favicon, ikinci dönüş, başka yol ya da
    // yöntem sessizce 404 alır — akışı ne bozar ne de tamamlar.
    if (_result.isCompleted ||
        _finished ||
        request.method != 'GET' ||
        request.uri.path != _path) {
      request.response.statusCode = HttpStatus.notFound;
      unawaited(request.response.close().catchError((Object _) {}));
      return;
    }
    // WP-868: geçersiz UTF-8 yüzde kodlaması (`%E0`) `queryParameters`ta
    // FormatException atar; yakalanmazsa istek yanıtsız kalır ve hata
    // dinleyiciden kaçar. Bozuk istek 400 alır, akışı tamamlamaz.
    final Map<String, String> query;
    try {
      query = request.uri.queryParameters;
    } on FormatException {
      request.response.statusCode = HttpStatus.badRequest;
      unawaited(request.response.close().catchError((Object _) {}));
      return;
    }
    _pending = request;
    _complete(LoopbackCallback(code: query['code'], error: query['error']));
  }

  /// WP-867: kullanıcı uygulamada "Vazgeç"e bastı.
  ///
  /// Dönüş henüz gelmediyse bekleme `null` ile biter (zaman aşımıyla aynı
  /// sessiz yol) ve dinleyici hemen kapanır: port bırakılır, yeniden deneme
  /// beklemeden bağlanabilir. Dönüş **zaten geldiyse** geç kalınmıştır —
  /// kod değişimi sürer ve sonuç sayfasını [finish] yazar; iptal no-op'tur.
  /// İdempotenttir.
  Future<void> cancel() async {
    if (_result.isCompleted || _finished) return;
    _complete(null);
    await finish();
  }

  /// Tarayıcıya sonuç sayfasını yazar ve dinleyiciyi kapatır.
  ///
  /// [signedIn] yalnız oturum **gerçekten** kurulduysa true verilir; aksi
  /// hâlde sayfa "tamamlanamadı" der (tarayıcıda yalancı başarı yok).
  Future<void> finish({bool signedIn = false}) =>
      // WP-875: ikinci çağıran (ör. zaman aşımı zamanlayıcısı kapatmayı
      // başlattıktan sonra deponun `finally`si) aynı kapanışı BEKLER; yoksa
      // port daha kapanmadan dönülür ve hemen yeniden deneme "port meşgul"
      // alır (CI Linux'ta ölçüldü).
      _finishing ??= _finish(signedIn: signedIn);

  Future<void>? _finishing;

  Future<void> _finish({required bool signedIn}) async {
    _finished = true;
    _timer.cancel();
    _complete(null);
    final request = _pending;
    _pending = null;
    if (request != null) {
      try {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
          ..headers.set(HttpHeaders.connectionHeader, 'close')
          // Adres çubuğundaki `code` hiçbir yere sızmasın.
          ..headers.set('Referrer-Policy', 'no-referrer')
          ..write(loopbackResultPage(signedIn: signedIn));
        await request.response.close();
      } catch (_) {
        // Tarayıcı sekmesi kapanmış olabilir; oturum sonucu bundan bağımsız.
      }
    }
    await _subscription.cancel();
    await _server.close(force: true);
  }
}

/// Tarayıcıda gösterilen tek satırlık TR + EN sayfa (kendi içinde, dış
/// kaynak yok). Metinler katalogdan gelir; iki dil birden yazılır çünkü
/// tarayıcının dili uygulamanınkiyle aynı olmak zorunda değil.
String loopbackResultPage({required bool signedIn}) {
  String line(Locale locale) {
    final l10n = lookupAppLocalizations(locale);
    return signedIn
        ? l10n.authGoogleTarayiciGirisTamamlandi
        : l10n.authGoogleTarayiciGirisTamamlanamadi;
  }

  const escape = HtmlEscape();
  final title = escape.convert(
    lookupAppLocalizations(const Locale('tr')).appTitle,
  );
  final tr = escape.convert(line(const Locale('tr')));
  final en = escape.convert(line(const Locale('en')));
  return '<!doctype html><html lang="tr"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<title>$title</title>'
      '<style>body{font-family:system-ui,sans-serif;margin:0;min-height:100vh;'
      'display:flex;align-items:center;justify-content:center;'
      'text-align:center;padding:16px;color:#1f2937;background:#f9fafb}'
      '@media(prefers-color-scheme:dark){body{color:#e5e7eb;background:#111827}}'
      'p{margin:6px 0;font-size:18px}p+p{opacity:.75;font-size:16px}</style>'
      '</head><body><main><p>$tr</p><p lang="en">$en</p></main></body></html>';
}
