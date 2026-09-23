// WP-936 — oturum/istatistik listeleri PostgREST `max_rows` sinirinda
// sessizce kesilmez.
//
// 🔴 Neden var: PostgREST tek yanitta en fazla `max_rows` satir dondurur
// (`supabase/config.toml` -> `[api] max_rows = 1000`; barindirilan Supabase
// varsayilani da 1000). Sinir asildiginda HATA yoktur, liste sessizce kisa
// gelir. `getUserSessionsInRange` sayfalamadan ve eskiden-yeniye sirali
// cektigi icin Yil / Tumu doneminde 1000'den fazla oturumu olan kullanicinin
// EN YENI oturumlari kirilimlardan (saat dagilimi, ders halkasi, isi
// haritasi, egilim) dusuyordu; toplam ise sunucuda hesaplandigi icin dogru
// kaliyordu -> ayni ekranda iki sayi birbirini tutmuyordu.
//
// Ayni sinif: `group_daily_totals` (tum zamanlar x uye x gun satiri; grup
// egilimi / liderlik) ve 90 gunluk sicak pencere (`watchUserSessions`;
// <=90 gunluk donemlerin kirilimi buradan beslenir).
//
// Yontem: gercek repository + gercek postgrest sorgu ureticisi. Sahte olan
// yalniz http katmani: `offset`/`limit` parametrelerini okuyup en fazla 1000
// satir donduren bir PostgREST taklidi. Realtime kanali soket acmayan bir
// sahteyle degistirilir (WP-543 testindeki desen).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:online_study_room/data/repositories/supabase/supabase_analytics_query_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_study_repository.dart';

const _serverMaxRows = 1000;

String _two(int n) => n.toString().padLeft(2, '0');

/// `i`. oturum: 2026-01-01'den baslayarak gunde 10 oturum, dakikalar artan.
Map<String, dynamic> _sessionRow(int i) {
  final start = DateTime.utc(2026, 1, 1, 6).add(
    Duration(days: i ~/ 10, minutes: (i % 10) * 30),
  );
  final day = DateTime.utc(start.year, start.month, start.day);
  return {
    'id': 's${i.toString().padLeft(5, '0')}',
    'user_id': 'u1',
    'subject_id': null,
    'start_time': start.toIso8601String(),
    'end_time': start.add(const Duration(minutes: 25)).toIso8601String(),
    'duration_seconds': 1500,
    'source': 'live',
    'live_run_id': null,
    'day': '${day.year}-${_two(day.month)}-${_two(day.day)}',
  };
}

/// `i`. grup satiri: 20 uye x gun.
Map<String, dynamic> _dailyRow(int i) {
  final day = DateTime.utc(2025, 1, 1).add(Duration(days: i ~/ 20));
  return {
    'user_id': 'u${(i % 20).toString().padLeft(2, '0')}',
    'day': '${day.year}-${_two(day.month)}-${_two(day.day)}',
    'seconds': 600 + i,
  };
}

/// Istenen (offset, limit) cifti; parametre yoksa null.
typedef _Page = ({int? offset, int? limit});

/// PostgREST taklidi: satirlar istemcinin istedigi sirada tutulur, yanit
/// `offset`/`limit`e uyar ve **asla** [_serverMaxRows]'dan fazla satir
/// dondurmez (gercek sunucunun sessiz kesmesi).
class _CappedPostgrest extends http.BaseClient {
  _CappedPostgrest(this.rows);

  /// Yol sonu ('/study_sessions', '/rpc/group_daily_totals') -> satirlar.
  final Map<String, List<Map<String, dynamic>>> rows;
  final List<_Page> pages = [];
  final List<Uri> urls = [];

  /// true ise her istege tam sayfa doner (sonsuz tablo) — ust sinir testi.
  bool endless = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url;
    urls.add(url);
    final q = url.queryParameters;
    final offset = q['offset'] == null ? null : int.parse(q['offset']!);
    final limit = q['limit'] == null ? null : int.parse(q['limit']!);
    pages.add((offset: offset, limit: limit));

    List<Map<String, dynamic>> body = const [];
    for (final entry in rows.entries) {
      if (!url.path.endsWith(entry.key)) continue;
      final all = entry.value;
      final start = offset ?? 0;
      var take = _serverMaxRows;
      if (limit != null && limit < take) take = limit;
      if (endless) {
        body = List.generate(take, (k) => _sessionRow(start + k));
      } else if (start < all.length) {
        final end = start + take > all.length ? all.length : start + take;
        body = all.sublist(start, end);
      }
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// Soket acmayan kanal (WP-543 testindeki desen).
class _SilentChannel extends RealtimeChannel {
  _SilentChannel(super.topic, super.socket);

  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) callback,
  }) =>
      this;

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) =>
      this;
}

class _NoSocketClient extends SupabaseClient {
  _NoSocketClient(http.Client httpClient)
      : super('http://localhost:54321', 'test-anon-key',
            httpClient: httpClient);

  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) =>
      _SilentChannel(name, realtime);

  @override
  Future<String> removeChannel(RealtimeChannel channel) async => 'ok';
}

const _threePages = <_Page>[
  (offset: 0, limit: 1000),
  (offset: 1000, limit: 1000),
  (offset: 2000, limit: 1000),
];

void main() {
  group('WP-936 — getUserSessionsInRange sayfalanir', () {
    test('2350 oturum: hepsi, sirayla, 0-999 / 1000-1999 / 2000-2999',
        () async {
      final data = List.generate(2350, _sessionRow);
      final server = _CappedPostgrest({'/study_sessions': data});
      final repo = SupabaseAnalyticsQueryRepository(_NoSocketClient(server));

      final sessions = await repo.getUserSessionsInRange(
        userId: 'u1',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      // Eski kod burada 1000 donduruyordu: en yeni 1350 oturum kayipti.
      expect(sessions.length, 2350);
      expect(sessions.first.id, 's00000');
      expect(sessions.last.id, 's02349');
      expect(
        [for (final s in sessions) s.id],
        [for (final r in data) r['id']],
        reason: 'sira korunmali, tekrar/atlama olmamali',
      );
      expect(server.pages, _threePages);

      // Kararli sira: esit start_time'da sayfa sinirinda tekrar/atlama
      // olmamasi icin id ikincil anahtar olarak gider.
      for (final url in server.urls) {
        expect(url.queryParameters['order'],
            'start_time.asc.nullslast,id.asc.nullslast');
        expect(url.queryParameters['user_id'], 'eq.u1');
      }
    });

    test('kucuk aralik: tek istek, davranis degismez', () async {
      final data = List.generate(5, _sessionRow);
      final server = _CappedPostgrest({'/study_sessions': data});
      final repo = SupabaseAnalyticsQueryRepository(_NoSocketClient(server));

      final sessions = await repo.getUserSessionsInRange(
        userId: 'u1',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      expect(sessions.length, 5);
      expect(server.pages, [(offset: 0, limit: 1000)]);
    });

    test('tam 1000 satir: kisa (bos) sayfada durur', () async {
      final data = List.generate(1000, _sessionRow);
      final server = _CappedPostgrest({'/study_sessions': data});
      final repo = SupabaseAnalyticsQueryRepository(_NoSocketClient(server));

      final sessions = await repo.getUserSessionsInRange(
        userId: 'u1',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      expect(sessions.length, 1000);
      expect(server.pages,
          [(offset: 0, limit: 1000), (offset: 1000, limit: 1000)]);
    });

    test('hep dolu sayfa donen sunucu: 50 sayfada durur (sonsuz dongu yok)',
        () async {
      final server = _CappedPostgrest({'/study_sessions': const []})
        ..endless = true;
      final repo = SupabaseAnalyticsQueryRepository(_NoSocketClient(server));

      await repo.getUserSessionsInRange(
        userId: 'u1',
        from: DateTime(2020, 1, 1),
        to: DateTime(2030, 12, 31),
      );

      expect(server.pages.length, 50);
      expect(server.pages.last, (offset: 49000, limit: 1000));
    });
  });

  group('WP-936 — ayni sinif: grup gunluk toplamlari ve sicak pencere', () {
    test('group_daily_totals 2350 satir: hepsi gelir, sirali sayfalar',
        () async {
      final data = List.generate(2350, _dailyRow);
      final server = _CappedPostgrest({'/rpc/group_daily_totals': data});
      final repo = SupabaseStudyRepository(_NoSocketClient(server));

      final stats = await repo.watchGroupDailyStats('g1').first;

      expect(stats.length, 2350);
      expect(stats.last.seconds, 600 + 2349);
      expect(server.pages, _threePages);
      for (final url in server.urls) {
        // (day, user_id) GROUP BY anahtari -> tekil, kararli sira.
        expect(url.queryParameters['order'],
            'day.asc.nullslast,user_id.asc.nullslast');
      }
    });

    test('sicak pencere 2350 oturum: hepsi gelir, sirali sayfalar', () async {
      // Sunucu satirlari istemcinin istedigi sirada (yeniden eskiye) tutar.
      final data = List.generate(2350, _sessionRow).reversed.toList();
      final server = _CappedPostgrest({'/study_sessions': data});
      final repo = SupabaseStudyRepository(_NoSocketClient(server));

      final sessions = await repo.watchUserSessions('u1').first;

      expect(sessions.length, 2350);
      expect(sessions.first.id, 's02349');
      expect(sessions.last.id, 's00000');
      expect(server.pages, _threePages);
      for (final url in server.urls) {
        expect(url.queryParameters['order'],
            'start_time.desc.nullslast,id.desc.nullslast');
      }
    });
  });
}
