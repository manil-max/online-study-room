// WP-938 — soket acmayan Realtime + sahte http katmanli SupabaseClient.
//
// Gercek `SupabaseGroupRepository` ve paketin gercek `.stream()`
// (`SupabaseStreamBuilder`) kodu calisir. Sahte olan yalniz:
//   * `RealtimeClient.channel/removeChannel` — kanal soket acmaz; testler
//     `emitStatus(timedOut)` ile Realtime'in kurulamadigini, `emitUpdate` ile
//     canli bir degisikligi taklit eder;
//   * http katmani — yol basina satir dondurur, cagri sayar, istenirse
//     PostgREST hatasi (500) uretir.
// Suzgec/esleme mantigi test icinde yeniden yazilmaz.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class Wp938FakeChannel extends RealtimeChannel {
  Wp938FakeChannel(this.name, RealtimeClient socket) : super(name, socket);

  /// `RealtimeChannel.topic` paket-ici (`@internal`); ad burada tutulur.
  final String name;

  void Function(PostgresChangePayload payload)? _changeCallback;
  void Function(RealtimeSubscribeStatus status, Object? error)? _statusCallback;
  bool unsubscribed = false;

  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) callback,
  }) {
    _changeCallback = callback;
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) {
    _statusCallback = callback;
    return this;
  }

  @override
  Future<String> unsubscribe([Duration? timeout]) async {
    unsubscribed = true;
    return 'ok';
  }

  /// Soket kurulamadi / kanal dustu / yeniden baglandi.
  void emitStatus(RealtimeSubscribeStatus status, [Object? error]) {
    final callback = _statusCallback;
    if (callback == null) throw StateError('subscribe() cagrilmadi: $name');
    callback(status, error);
  }

  /// Canli UPDATE olayi (tablo satiri degisti).
  void emitUpdate(String table, Map<String, dynamic> record) {
    final callback = _changeCallback;
    if (callback == null) throw StateError('onPostgresChanges yok: $name');
    callback(
      PostgresChangePayload(
        schema: 'public',
        table: table,
        commitTimestamp: DateTime.utc(2026, 10, 7),
        eventType: PostgresChangeEvent.update,
        newRecord: record,
        oldRecord: record,
        errors: null,
      ),
    );
  }
}

class Wp938FakeRealtime extends RealtimeClient {
  Wp938FakeRealtime()
    : super(
        'ws://localhost:54321/realtime/v1',
        params: const {'apikey': 'test-anon-key'},
      );

  final List<Wp938FakeChannel> created = [];
  final List<RealtimeChannel> removed = [];

  /// `.stream()` kanallari `realtime:public:<tablo>:<n>` konusunu kullanir.
  List<Wp938FakeChannel> forTable(String table) => [
    for (final c in created)
      if (c.name.startsWith('realtime:public:$table:')) c,
  ];

  /// Henuz birakilmamis (canli) kanallar.
  List<Wp938FakeChannel> get live => [
    for (final c in created)
      if (!c.unsubscribed && !removed.contains(c)) c,
  ];

  @override
  RealtimeChannel channel(
    String topic, [
    RealtimeChannelConfig params = const RealtimeChannelConfig(),
  ]) {
    final c = Wp938FakeChannel('realtime:$topic', this);
    created.add(c);
    return c;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    removed.add(channel);
    return 'ok';
  }
}

class Wp938FakeSupabaseClient extends SupabaseClient {
  Wp938FakeSupabaseClient(this.fakeRealtime, http.Client httpClient)
    : super(
        'http://localhost:54321',
        'test-anon-key',
        httpClient: httpClient,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

  final Wp938FakeRealtime fakeRealtime;

  @override
  RealtimeClient get realtime => fakeRealtime;
}

/// Yol (`/rest/v1/<tablo>` ya da `/rest/v1/rpc/<ad>`) basina yanit.
class Wp938Backend extends http.BaseClient {
  /// Tablo/RPC adi -> donecek satirlar.
  final Map<String, Object?> rows = {};

  /// Bu adlar 500 + PostgREST govdesiyle doner.
  final Set<String> failing = {};

  final Map<String, int> calls = {};

  int callsTo(String name) => calls[name] ?? 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final segments = request.url.pathSegments;
    final name = segments.isEmpty ? '' : segments.last;
    calls[name] = (calls[name] ?? 0) + 1;
    if (failing.contains(name)) {
      return _json(500, {
        'code': 'XX000',
        'message': 'boom',
        'details': null,
        'hint': null,
      }, request);
    }
    return _json(200, rows[name] ?? const <Object>[], request);
  }

  http.StreamedResponse _json(
    int status,
    Object? body,
    http.BaseRequest request,
  ) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    status,
    request: request,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, dynamic> wp938GroupRow(String id, String name) => {
  'id': id,
  'name': name,
  'invite_code': 'KOD$id',
  'created_by': 'u1',
  'created_at': '2026-09-01T10:00:00Z',
  'daily_goal_minutes': 120,
};

Map<String, dynamic> wp938MemberRow(String groupId, String userId) => {
  'group_id': groupId,
  'user_id': userId,
  'left_at': null,
};
