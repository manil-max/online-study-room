// Supabase repository'lerini **gerçek PostgREST sorgu üreticisiyle** test etmek
// için kablo seviyesi koşum takımı.
//
// 🔴 Neden var: 22 `Supabase*Repository` sınıfının hiçbiri hiçbir testte
// örneklenmiyordu (kapsam %0). Testlerin tamamı `InMemory*` sahtelerini
// kullanıyordu, yani sahaya giden kod hiç çalıştırılmıyordu. Sonuç:
// `get_user_study_summary` WP-152'den beri tanımsız bir RPC'yi çağırıyordu ve
// hiçbir test görmedi.
//
// Yaklaşım: `SupabaseClient`'a sahte bir **http istemcisi** verilir. Böylece
// `postgrest` paketinin gerçek sorgu üreticisi çalışır ve test, kabloya
// **gerçekten ne gittiğini** doğrular: RPC adı, gövdedeki parametreler,
// `select` dizesi, filtreler, header'lar. Repository'yi mock'lamak bunu
// yakalayamaz — mock, yanlış RPC adını da mutlulukla kabul eder.
//
// Ayrıca hata yolu test edilebilir: [SupabaseWireHarness.failWith] ile
// PostgREST hata gövdesi döndürülür ve repository'nin onu doğru istisnaya
// çevirdiği doğrulanır.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kabloya giden tek bir istek.
class WireCall {
  WireCall({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;

  /// `/rest/v1/rpc/<ad>` çağrısındaki fonksiyon adı; RPC değilse null.
  String? get rpcName {
    final segments = url.pathSegments;
    final index = segments.indexOf('rpc');
    if (index == -1 || index + 1 >= segments.length) return null;
    return segments[index + 1];
  }

  /// `/rest/v1/<tablo>` çağrısındaki tablo adı; RPC ise null.
  String? get table {
    final segments = url.pathSegments;
    if (segments.contains('rpc')) return null;
    final index = segments.indexOf('v1');
    if (index == -1 || index + 1 >= segments.length) return null;
    return segments[index + 1];
  }

  /// POST gövdesi JSON ise ayrıştırılmış hâli, değilse boş harita.
  Map<String, dynamic> get json {
    if (body.isEmpty) return const {};
    final decoded = jsonDecode(body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
  }

  /// `?select=...` parametresi.
  String? get select => url.queryParameters['select'];

  @override
  String toString() => '$method ${url.path}?${url.query} $body';
}

/// Sahte yanıt.
class WireResponse {
  const WireResponse(this.body, {this.status = 200});

  /// PostgREST hata biçimi — repository'nin istisna eşlemesini sınamak için.
  factory WireResponse.error({
    required int status,
    required String message,
    String code = '',
  }) =>
      WireResponse(
        jsonEncode({
          'message': message,
          'code': code,
          'details': null,
          'hint': null,
        }),
        status: status,
      );

  final Object? body;
  final int status;
}

/// Test koşum takımı: istekleri kaydeder, kanned yanıt döndürür.
class SupabaseWireHarness {
  SupabaseWireHarness({WireResponse? defaultResponse})
      : _default = defaultResponse ?? const WireResponse([]);

  final WireResponse _default;
  final List<WireCall> calls = [];

  /// RPC adı / tablo adı -> yanıt. Eşleşme yoksa [_default] döner.
  final Map<String, WireResponse> _responses = {};

  /// Belirli bir RPC veya tablo için yanıt tanımlar.
  void respond(String nameOrTable, Object? body, {int status = 200}) {
    _responses[nameOrTable] = WireResponse(body, status: status);
  }

  /// Belirli bir RPC veya tablo için PostgREST hatası döndürür.
  void failWith(
    String nameOrTable, {
    required int status,
    required String message,
    String code = '',
  }) {
    _responses[nameOrTable] =
        WireResponse.error(status: status, message: message, code: code);
  }

  /// Test edilecek repository'ye verilecek istemci.
  SupabaseClient client() => SupabaseClient(
        'http://localhost:54321',
        'test-anon-key',
        httpClient: _RecordingClient(this),
      );

  WireCall get last => calls.last;

  /// Verilen RPC'ye yapılan tek çağrı; yoksa/birden çoksa hata.
  WireCall rpc(String name) {
    final matches = calls.where((c) => c.rpcName == name).toList();
    if (matches.length != 1) {
      throw StateError(
        '`$name` icin beklenen 1 cagri, bulunan ${matches.length}. '
        'Kaydedilenler: ${calls.map((c) => c.rpcName ?? c.table).toList()}',
      );
    }
    return matches.single;
  }

  WireResponse _responseFor(WireCall call) =>
      _responses[call.rpcName ?? call.table ?? ''] ?? _default;
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._harness);

  final SupabaseWireHarness _harness;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body =
        request is http.Request ? request.body : '';
    final call = WireCall(
      method: request.method,
      url: request.url,
      headers: Map<String, String>.from(request.headers),
      body: body,
    );
    _harness.calls.add(call);

    final response = _harness._responseFor(call);
    final encoded = utf8.encode(
      response.body is String
          ? response.body! as String
          : jsonEncode(response.body),
    );
    return http.StreamedResponse(
      Stream.value(encoded),
      response.status,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
