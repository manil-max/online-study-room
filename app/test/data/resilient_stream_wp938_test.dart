// WP-938 — canli akis (Realtime) koparsa grup akislari REST ile devam eder.
//
// Sahibin beta raporu: Gruplar sekmesi ve ana ekrandaki grup kartlari
// "Beklenmeyen bir hata olustu" diyor, yenile/tekrar dene ise yaramiyordu.
// Sunucu saglikliydi; `supabase-2.13.0` `.stream()` kanal `timedOut` /
// `channelError` durumunu `RealtimeSubscribeException` olarak AKISA yaziyor,
// `StreamProvider` da veriyi bu hatayla degistiriyordu.
//
// Iki katman olculur:
//   1. `resilientRealtimeStream` sozlesmesi — saf denetlenebilir akislarla,
//      sahte saatle (fake_async): yoklama, geri cekilme, iptal temizligi.
//   2. Gercek `SupabaseGroupRepository.watchUserGroups` — paketin gercek
//      `.stream()` kodu, soket acmayan sahte Realtime ile.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/repositories/supabase/resilient_stream.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_group_repository.dart';

import '../support/fake_realtime_supabase_wp938.dart';

/// Denetlenebilir "canli" kaynak: her abonelik yeni bir controller.
class _LiveSource {
  final List<StreamController<int>> subscriptions = [];

  StreamController<int> get current => subscriptions.last;

  int get activeCount => subscriptions.where((c) => c.hasListener).length;

  Stream<int> open() {
    final c = StreamController<int>();
    subscriptions.add(c);
    return c.stream;
  }
}

RealtimeSubscribeException _timedOut() =>
    RealtimeSubscribeException(RealtimeSubscribeStatus.timedOut);

void main() {
  group('WP-938 resilientRealtimeStream sozlesmesi', () {
    test('dinlenince REST verisi hemen gelir (soket hic baglanmasa da)', () {
      fakeAsync((async) {
        final live = _LiveSource();
        var fetches = 0;
        final seen = <int>[];
        final sub = resilientRealtimeStream<int>(
          realtime: live.open,
          fetch: () async => 10 + fetches++,
        ).listen(seen.add);
        async.flushMicrotasks();

        expect(seen, [10]);
        expect(live.activeCount, 1);
        sub.cancel();
        async.flushMicrotasks();
      });
    });

    test('timedOut hata olarak akmaz: son veri kalir, yoklama + geri cekilmeli '
        'yeniden abonelik baslar', () {
      fakeAsync((async) {
        final live = _LiveSource();
        var restValue = 1;
        var fetches = 0;
        final seen = <int>[];
        final errors = <Object>[];
        final sub = resilientRealtimeStream<int>(
          realtime: live.open,
          fetch: () async {
            fetches++;
            return restValue;
          },
        ).listen(seen.add, onError: errors.add);
        async.flushMicrotasks();
        expect(seen, [1]);
        expect(fetches, 1);

        live.current.addError(_timedOut());
        async.flushMicrotasks();

        expect(errors, isEmpty, reason: 'Realtime hatasi ekrana dusmemeli');
        expect(live.activeCount, 0, reason: 'kopuk abonelik birakilmali');
        expect(fetches, 2, reason: 'kopuklukta hemen REST tazelemesi');

        // Geri cekilme: 5 sn sonra yeni abonelik.
        async.elapse(const Duration(seconds: 4));
        expect(live.subscriptions, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(live.subscriptions, hasLength(2));
        expect(live.activeCount, 1);

        // Yoklama: 30 sn'de REST yeniden okunur ve yeni veri akar.
        restValue = 2;
        async.elapse(const Duration(seconds: 25));
        expect(fetches, 3);
        expect(seen.last, 2);
        expect(errors, isEmpty);

        sub.cancel();
        async.flushMicrotasks();
      });
    });

    test('geri cekilme 5 -> 15 -> 60 sn tavanina cikar', () {
      fakeAsync((async) {
        final live = _LiveSource();
        final sub = resilientRealtimeStream<int>(
          realtime: live.open,
          fetch: () async => 0,
        ).listen((_) {}, onError: (_) {});
        async.flushMicrotasks();

        void failAndExpectRetryAfter(Duration delay) {
          final before = live.subscriptions.length;
          live.current.addError(_timedOut());
          async.flushMicrotasks();
          async.elapse(delay - const Duration(milliseconds: 1));
          expect(live.subscriptions.length, before, reason: 'erken: $delay');
          async.elapse(const Duration(milliseconds: 1));
          expect(live.subscriptions.length, before + 1, reason: 'gec: $delay');
        }

        failAndExpectRetryAfter(const Duration(seconds: 5));
        failAndExpectRetryAfter(const Duration(seconds: 15));
        failAndExpectRetryAfter(const Duration(seconds: 60));
        failAndExpectRetryAfter(const Duration(seconds: 60));

        sub.cancel();
        async.flushMicrotasks();
      });
    });

    test('Realtime toparlaninca canli guncellemeler akar, yoklama durur', () {
      fakeAsync((async) {
        final live = _LiveSource();
        var fetches = 0;
        final seen = <int>[];
        final sub = resilientRealtimeStream<int>(
          realtime: live.open,
          fetch: () async {
            fetches++;
            return 0;
          },
        ).listen(seen.add);
        async.flushMicrotasks();

        live.current.addError(_timedOut());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5)); // yeniden abonelik
        live.current.add(42);
        async.flushMicrotasks();
        expect(seen.last, 42);

        // 30 sn hatasiz yasayan abonelik saglikli: yoklama durur.
        async.elapse(const Duration(seconds: 30));
        final settled = fetches;
        async.elapse(const Duration(minutes: 5));
        expect(
          fetches,
          settled,
          reason: 'saglikli Realtime varken yoklama yok',
        );

        live.current.add(43);
        async.flushMicrotasks();
        expect(seen.last, 43);
        expect(async.pendingTimers, isEmpty);

        sub.cancel();
        async.flushMicrotasks();
      });
    });

    test('REST hatasi (PostgrestException) gizlenmez', () {
      fakeAsync((async) {
        final live = _LiveSource();
        final errors = <Object>[];
        final sub = resilientRealtimeStream<int>(
          realtime: live.open,
          fetch: () async =>
              throw const PostgrestException(message: 'boom', code: '42501'),
        ).listen((_) {}, onError: errors.add);
        async.flushMicrotasks();

        expect(errors, hasLength(1));
        expect(errors.single, isA<PostgrestException>());
        sub.cancel();
        async.flushMicrotasks();
      });
    });

    test('canli kaynagin veri hatasi da gizlenmez (Realtime hatasi degil)', () {
      fakeAsync((async) {
        final live = _LiveSource();
        final errors = <Object>[];
        final sub = resilientRealtimeStream<int>(
          realtime: live.open,
          fetch: () async => 0,
        ).listen((_) {}, onError: errors.add);
        async.flushMicrotasks();

        live.current.addError(StateError('esleme hatasi'));
        async.flushMicrotasks();
        expect(errors.single, isA<StateError>());
        sub.cancel();
        async.flushMicrotasks();
      });
    });

    test('canli veriden once baslamis REST cevabi yeni veriyi ezmez', () {
      fakeAsync((async) {
        final live = _LiveSource();
        final gate = Completer<int>();
        final seen = <int>[];
        final sub = resilientRealtimeStream<int>(
          realtime: live.open,
          fetch: () => gate.future,
        ).listen(seen.add);
        async.flushMicrotasks();

        live.current.add(7); // canli veri once geldi
        async.flushMicrotasks();
        gate.complete(1); // eski REST cevabi sonra
        async.flushMicrotasks();

        expect(seen, [7]);
        sub.cancel();
        async.flushMicrotasks();
      });
    });

    test('canli akis sessizce kapanirsa (closed) yoklamaya gecer', () {
      fakeAsync((async) {
        final live = _LiveSource();
        var fetches = 0;
        final errors = <Object>[];
        final sub = resilientRealtimeStream<int>(
          realtime: live.open,
          fetch: () async => fetches++,
        ).listen((_) {}, onError: errors.add);
        async.flushMicrotasks();

        live.current.close();
        async.flushMicrotasks();
        expect(errors, isEmpty);
        expect(fetches, 2);
        async.elapse(const Duration(seconds: 5));
        expect(live.subscriptions, hasLength(2));

        sub.cancel();
        async.flushMicrotasks();
      });
    });

    test('iptal: zamanlayici ve abonelik kalmaz', () {
      fakeAsync((async) {
        final live = _LiveSource();
        final sub = resilientRealtimeStream<int>(
          realtime: live.open,
          fetch: () async => 0,
        ).listen((_) {});
        async.flushMicrotasks();
        live.current.addError(_timedOut());
        async.flushMicrotasks();
        expect(
          async.pendingTimers,
          isNotEmpty,
          reason: 'kopuklukta yoklama + yeniden deneme kurulmus olmali',
        );

        sub.cancel();
        async.flushMicrotasks();

        expect(async.pendingTimers, isEmpty);
        expect(live.activeCount, 0);
        async.elapse(const Duration(minutes: 10));
        expect(live.subscriptions, hasLength(1), reason: 'iptalden sonra yok');
      });
    });
  });

  group('WP-938 gercek SupabaseGroupRepository.watchUserGroups', () {
    late Wp938FakeRealtime realtime;
    late Wp938Backend backend;
    late Wp938FakeSupabaseClient client;

    setUp(() {
      realtime = Wp938FakeRealtime();
      backend = Wp938Backend()
        ..rows['group_members'] = [wp938MemberRow('g1', 'u1')]
        ..rows['groups'] = [wp938GroupRow('g1', 'Kamp Ekibi')];
      client = Wp938FakeSupabaseClient(realtime, backend);
    });

    test(
      'Realtime timedOut: hata yok, gruplar REST ile kalir ve tazelenir',
      () {
        fakeAsync((async) {
          final repo = SupabaseGroupRepository(client);
          final seen = <List<StudyGroup>>[];
          final errors = <Object>[];
          final sub = repo
              .watchUserGroups('u1')
              .listen(seen.add, onError: errors.add);
          async.flushMicrotasks();

          expect(seen.last.single.name, 'Kamp Ekibi');
          final first = realtime.forTable('group_members').single;

          first.emitStatus(RealtimeSubscribeStatus.timedOut);
          async.flushMicrotasks();

          expect(errors, isEmpty, reason: 'eski kod burada hata yayiyordu');
          expect(seen.last.single.name, 'Kamp Ekibi');
          expect(first.unsubscribed, isTrue);

          // Yoklama tazeler: sunucuda ad degisti.
          backend.rows['groups'] = [wp938GroupRow('g1', 'Yeni Ad')];
          async.elapse(const Duration(seconds: 30));
          expect(seen.last.single.name, 'Yeni Ad');
          expect(
            realtime.forTable('group_members'),
            hasLength(greaterThanOrEqualTo(2)),
            reason: 'abonelik geri cekilmeyle yeniden kuruldu',
          );

          sub.cancel();
          async.flushMicrotasks();
          expect(async.pendingTimers, isEmpty);
          expect(
            realtime.live,
            isEmpty,
            reason: 'iptalden sonra canli kanal yok',
          );
        });
      },
    );

    test('REST hatasi (500) gercek ariza olarak gorunur', () {
      fakeAsync((async) {
        backend.failing.add('group_members');
        final repo = SupabaseGroupRepository(client);
        final errors = <Object>[];
        final sub = repo
            .watchUserGroups('u1')
            .listen((_) {}, onError: errors.add);
        async.flushMicrotasks();

        expect(errors, isNotEmpty);
        expect(errors.first, isA<PostgrestException>());
        sub.cancel();
        async.flushMicrotasks();
        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
