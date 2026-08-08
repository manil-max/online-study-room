// WP-543 — elle kurulan realtime kanallarinin yeniden baglanma sozlesmesi.
//
// 🔴 Neden var: `SupabaseStudyRepository` iki akista (`watchUserSessions`,
// `watchGroupDailyStats`) `.stream()` yerine `channel(...).subscribe()` ile
// ELLE kanal kuruyor. Paketin `.stream()` yolu yeniden baglanmada veriyi
// kendisi tazeler (`supabase-2.13.0/lib/src/supabase_stream_builder.dart`,
// `_wasSubscribed` deseni); elle kurulan kanal tazelemez. Kullanici
// istatistik ekranini acik birakip ag 5 dakika kopunca soket rejoin oluyor
// ama hicbir refetch tetiklenmiyordu: liste bir sonraki postgres
// degisikligine kadar donuk kaliyor, kopukluk sirasinda baska cihazda
// yazilan oturumlar hic gorunmuyordu.
//
// Ikinci belirti ayni kok nedenden: `offline_first_study_repository`
// icindeki grup istatistigi yeniden dinleme dongusu ancak akis HATA yayarsa
// uyaniyor. Sessizce dusen sokette hata uretilmedigi icin liderlik tablosu
// ekran kapanip acilana kadar donuk kaliyordu.
//
// Yontem: gercek `SupabaseStudyRepository` calistirilir. Sahte olan yalniz
// `SupabaseClient.channel/removeChannel` (soket acilmaz) ve http katmani
// (satirlari kim kac kez cekti sayilir). Suzgec/mantik test icinde YENIDEN
// YAZILMAZ — mevcut testlerin tuzagi tam olarak buydu.
//
// Mevcut `offline_first_repository_test.dart:127` toparlanmayi
// `Stream.error(...)` uretorek kanitliyor, yani SESSIZ soket kaybini hic
// modellemiyor. Buradaki testler tam o boslugu kapatir: tek bir postgres
// olayi bile gelmeden, sadece kanal `subscribed` durumuna geri dondugu icin
// veri tazelenmeli.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_study_repository.dart';

Map<String, dynamic> _sessionRow(String id, int seconds) => {
  'id': id,
  'user_id': 'u1',
  'subject_id': null,
  'start_time': '2026-08-01T09:00:00Z',
  'end_time': '2026-08-01T09:30:00Z',
  'duration_seconds': seconds,
  'source': 'live',
  'live_run_id': null,
  'day': '2026-08-01',
};

Map<String, dynamic> _dailyRow(int seconds) => {
  'user_id': 'u1',
  'day': '2026-08-01',
  'seconds': seconds,
};

void main() {
  group('WP-543 — kanal rejoin sozlesmesi', () {
    test(
      'kullanici oturumlari: sessiz soket kaybindan sonraki rejoin veriyi tazeler',
      () async {
        final harness = _RealtimeHarness()
          ..sessionRows = [_sessionRow('s1', 600)];
        final repo = SupabaseStudyRepository(harness.client);

        final seen = <List<StudySession>>[];
        final errors = <Object>[];
        final sub = repo
            .watchUserSessions('u1')
            .listen(seen.add, onError: errors.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();

        expect(harness.sessionSelectCount, 1, reason: 'onListen ilk cekimi');
        expect(harness.channels, hasLength(1));
        final channel = harness.channels.single;

        // Ilk join — `onListen` zaten cekti, ikinci cekim OLMAMALI.
        channel.emitStatus(RealtimeSubscribeStatus.subscribed);
        await pumpEventQueue();
        expect(harness.sessionSelectCount, 1);

        // Ag kopar, geri gelir. Hicbir postgres olayi gelmez; kopukluk
        // sirasinda baska cihaz sunucuya yeni oturum yazmistir.
        harness.sessionRows = [_sessionRow('s1', 600), _sessionRow('s2', 1800)];
        channel.emitStatus(RealtimeSubscribeStatus.subscribed);
        await pumpEventQueue();

        expect(
          harness.sessionSelectCount,
          2,
          reason: 'rejoin refetch tetiklemeli (WP-543 kok neden)',
        );
        expect(seen.last.map((s) => s.id), containsAll(<String>['s1', 's2']));
        expect(errors, isEmpty);
      },
    );

    test(
      'grup gunluk toplamlari: sessiz soket kaybindan sonraki rejoin veriyi tazeler',
      () async {
        final harness = _RealtimeHarness()..dailyRows = [_dailyRow(1200)];
        final repo = SupabaseStudyRepository(harness.client);

        final seen = <List<DailyStat>>[];
        final sub = repo.watchGroupDailyStats('g1').listen(seen.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();

        expect(harness.dailyTotalsCount, 1);
        final channel = harness.channels.single;

        channel.emitStatus(RealtimeSubscribeStatus.subscribed);
        await pumpEventQueue();
        expect(harness.dailyTotalsCount, 1);

        harness.dailyRows = [_dailyRow(1800)];
        channel.emitStatus(RealtimeSubscribeStatus.subscribed);
        await pumpEventQueue();

        expect(harness.dailyTotalsCount, 2);
        expect(seen.last.single.seconds, 1800);
      },
    );

    // 🔴 Sessiz olum yasak: ust kattaki yeniden dinleme dongusu
    // (`offline_first_study_repository.watchGroupDailyStats`) YALNIZ akis
    // hata yayarsa uyaniyor.
    test('kanal hatasi akisa duser, sessizce yutulmaz', () async {
      final harness = _RealtimeHarness()..dailyRows = [_dailyRow(1200)];
      final repo = SupabaseStudyRepository(harness.client);

      final errors = <Object>[];
      final sub = repo
          .watchGroupDailyStats('g1')
          .listen((_) {}, onError: errors.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      harness.channels.single.emitStatus(
        RealtimeSubscribeStatus.channelError,
        'socket dropped',
      );
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect(errors.single, isA<RealtimeSubscribeException>());
      expect(
        (errors.single as RealtimeSubscribeException).status,
        RealtimeSubscribeStatus.channelError,
      );
    });

    test('zaman asimi da akisa duser (kullanici oturumlari)', () async {
      final harness = _RealtimeHarness()
        ..sessionRows = [_sessionRow('s1', 600)];
      final repo = SupabaseStudyRepository(harness.client);

      final errors = <Object>[];
      final sub = repo
          .watchUserSessions('u1')
          .listen((_) {}, onError: errors.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      harness.channels.single.emitStatus(RealtimeSubscribeStatus.timedOut);
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect(
        (errors.single as RealtimeSubscribeException).status,
        RealtimeSubscribeStatus.timedOut,
      );
    });

    // Teardown'un kendi urettigi `closed` hata sayilmamali; iptalden sonra
    // gelen `subscribed` de bos yere refetch etmemeli.
    test('iptalden sonraki durum olaylari ne refetch ne hata uretir', () async {
      final harness = _RealtimeHarness()
        ..sessionRows = [_sessionRow('s1', 600)];
      final repo = SupabaseStudyRepository(harness.client);

      final errors = <Object>[];
      final sub = repo
          .watchUserSessions('u1')
          .listen((_) {}, onError: errors.add);
      await pumpEventQueue();
      final channel = harness.channels.single;
      channel.emitStatus(RealtimeSubscribeStatus.subscribed);

      await sub.cancel();
      channel
        ..emitStatus(RealtimeSubscribeStatus.subscribed)
        ..emitStatus(RealtimeSubscribeStatus.closed);
      await pumpEventQueue();

      expect(harness.sessionSelectCount, 1);
      expect(errors, isEmpty);
      expect(harness.removedChannels, contains(channel));
    });

    // Postgres olay yolu bozulmamali: debounce sonrasi hala tazeleniyor.
    test('postgres olayi debounce sonrasi hala tazeliyor', () async {
      final harness = _RealtimeHarness()
        ..sessionRows = [_sessionRow('s1', 600)];
      final repo = SupabaseStudyRepository(harness.client);

      final sub = repo.watchUserSessions('u1').listen((_) {});
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(harness.sessionSelectCount, 1);

      harness.channels.single.emitChange();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(harness.sessionSelectCount, 2);
    });
  });
}

/// Soket acmayan sahte kanal: `onPostgresChanges` ve `subscribe` yakalanir.
class _FakeRealtimeChannel extends RealtimeChannel {
  _FakeRealtimeChannel(super.topic, super.socket);

  void Function(PostgresChangePayload payload)? _changeCallback;
  void Function(RealtimeSubscribeStatus status, Object? error)? _statusCallback;

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

  /// Soketin sessizce dusup rejoin olmasi / hata vermesi.
  void emitStatus(RealtimeSubscribeStatus status, [Object? error]) {
    final callback = _statusCallback;
    if (callback == null) {
      fail(
        'subscribe() durum callback almadi: kanal yeniden baglanmayi '
        'gorebilecek bir kanci kurmuyor (WP-543 regresyonu).',
      );
    }
    callback(status, error);
  }

  void emitChange() {
    final callback = _changeCallback;
    if (callback == null) fail('onPostgresChanges kancasi kurulmadi.');
    callback(
      PostgresChangePayload(
        schema: 'public',
        table: 'study_sessions',
        commitTimestamp: DateTime.utc(2026, 8, 1),
        eventType: PostgresChangeEvent.insert,
        newRecord: const {},
        oldRecord: const {},
        errors: null,
      ),
    );
  }
}

class _FakeSupabaseClient extends SupabaseClient {
  _FakeSupabaseClient(this._harness, http.Client httpClient)
    : super('http://localhost:54321', 'test-anon-key', httpClient: httpClient);

  final _RealtimeHarness _harness;

  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    final created = _FakeRealtimeChannel(name, realtime);
    _harness.channels.add(created);
    return created;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    _harness.removedChannels.add(channel);
    return 'ok';
  }
}

/// Http katmani sahte, sorgu ureticisi gercek: kac kez cekildigi sayilir.
class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this._harness);

  final _RealtimeHarness _harness;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    Object? body = const <Object>[];
    if (path.endsWith('/rpc/group_daily_totals')) {
      _harness.dailyTotalsCount++;
      body = _harness.dailyRows;
    } else if (path.endsWith('/study_sessions')) {
      _harness.sessionSelectCount++;
      body = _harness.sessionRows;
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _RealtimeHarness {
  _RealtimeHarness() {
    client = _FakeSupabaseClient(this, _RecordingHttpClient(this));
  }

  late final _FakeSupabaseClient client;
  final List<_FakeRealtimeChannel> channels = [];
  final List<RealtimeChannel> removedChannels = [];

  int sessionSelectCount = 0;
  int dailyTotalsCount = 0;
  List<Map<String, dynamic>> sessionRows = [];
  List<Map<String, dynamic>> dailyRows = [];
}
