import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/updater/play_in_app_update.dart';
import 'package:online_study_room/features/updater/play_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-941 — Play in-app review kapısı, eşiği ve sınırları.
///
/// Testler gerçek `InAppReview` eklentisine **hiç** dokunmaz: tek giriş
/// [PlayReviewGateway] ve o da provider'dan ezilir. Cihaz gerekmez.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 7, 12);

  setUp(() {
    debugResetPlayReview();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugResetPlayReview();
    debugPlayReviewChannel = null;
    debugPlayReviewPlatform = null;
    debugPlayReviewInForeground = null;
    debugPlayReviewClock = null;
  });

  Future<PlayReviewStore> store([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    return PlayReviewStore(await SharedPreferences.getInstance());
  }

  Future<PlayReviewOutcome> ask({
    required PlayReviewGateway gateway,
    required PlayReviewStore store,
    PlayReviewLaunchState? launch,
    DistributionChannel channel = DistributionChannel.play,
    TargetPlatform platform = TargetPlatform.android,
    bool isWeb = false,
    DateTime? at,
    bool inForeground = true,
    bool midSession = false,
    bool updateFlow = false,
  }) => maybeRequestPlayReview(
    gateway: gateway,
    store: store,
    launch: launch ?? PlayReviewLaunchState(),
    channel: channel,
    now: at ?? now,
    inForeground: inForeground,
    midSession: midSession,
    updateFlowThisLaunch: () async => updateFlow,
    isWeb: isWeb,
    platform: platform,
  );

  group('kapı', () {
    test(
      'yalnız Play + Android; diğer her kanalda eklenti çağrılmaz',
      () async {
        for (final channel in DistributionChannel.values) {
          final gateway = _FakeReviewGateway();
          final s = await store({PlayReviewStore.qualifyingSessionsKey: 5});
          final outcome = await ask(
            gateway: gateway,
            store: s,
            channel: channel,
          );
          if (channel == DistributionChannel.play) {
            expect(outcome, PlayReviewOutcome.requested, reason: '$channel');
            expect(gateway.requests, 1, reason: '$channel');
          } else {
            expect(
              outcome,
              PlayReviewOutcome.notApplicable,
              reason: '$channel',
            );
            expect(gateway.touched, isFalse, reason: '$channel');
          }
        }
      },
    );

    test(
      'Play kanalı bile olsa iOS / Windows / macOS / web çağırmaz',
      () async {
        for (final platform in [
          TargetPlatform.iOS,
          TargetPlatform.windows,
          TargetPlatform.macOS,
        ]) {
          final gateway = _FakeReviewGateway();
          final s = await store({PlayReviewStore.qualifyingSessionsKey: 5});
          expect(
            await ask(gateway: gateway, store: s, platform: platform),
            PlayReviewOutcome.notApplicable,
            reason: '$platform',
          );
          expect(gateway.touched, isFalse, reason: '$platform');
        }
        final web = _FakeReviewGateway();
        final s = await store({PlayReviewStore.qualifyingSessionsKey: 5});
        expect(
          await ask(gateway: web, store: s, isWeb: true),
          PlayReviewOutcome.notApplicable,
        );
        expect(web.touched, isFalse);
      },
    );

    test('kapı WP-913 ile birebir aynı', () {
      for (final channel in DistributionChannel.values) {
        for (final platform in TargetPlatform.values) {
          for (final isWeb in [false, true]) {
            expect(
              PlayReviewPolicy.appliesTo(
                channel: channel,
                platform: platform,
                isWeb: isWeb,
              ),
              PlayInAppUpdate.appliesTo(
                channel: channel,
                platform: platform,
                isWeb: isWeb,
              ),
            );
          }
        }
      }
    });
  });

  group('eşik', () {
    StudySession session(String id, {required int minutes, DateTime? end}) {
      final e = end ?? now;
      return StudySession(
        id: id,
        userId: 'u1',
        start: e.subtract(Duration(minutes: minutes)),
        end: e,
        durationSeconds: minutes * 60,
        source: StudySource.live,
      );
    }

    test('ilk çalıştırmada geçmiş sayılmaz, filigran konur', () async {
      final s = await store();
      final added = await ingestPlayReviewSessions(
        store: s,
        sessions: [for (var i = 0; i < 9; i++) session('old$i', minutes: 60)],
        now: now,
        localRunSeen: true,
      );
      expect(added, 0);
      expect(s.qualifyingSessions, 0);
      expect(s.watermarkMs, now.millisecondsSinceEpoch);
    });

    test('4 uygun seans → istek yok, 5. → istek; kısa seans sayılmaz', () async {
      final start = now.subtract(const Duration(days: 3));
      final s = await store({
        PlayReviewStore.watermarkKey: start.millisecondsSinceEpoch,
      });
      final gateway = _FakeReviewGateway();
      final launch = PlayReviewLaunchState();
      final sessions = <StudySession>[];
      var t = start;

      Future<PlayReviewOutcome> record(int minutes) async {
        t = t.add(const Duration(hours: 2));
        sessions.insert(
          0,
          session('s${sessions.length}', minutes: minutes, end: t),
        );
        // Liste her kayıtta yeniden yayınlanır; eski satırlar ikinci kez sayılmaz.
        await ingestPlayReviewSessions(
          store: s,
          sessions: List.of(sessions),
          now: t,
          localRunSeen: true,
        );
        return ask(gateway: gateway, store: s, launch: launch, at: t);
      }

      for (var i = 0; i < 4; i++) {
        expect(await record(25), PlayReviewOutcome.belowThreshold);
        // Kısa seanslar arada — sayılmaz.
        expect(await record(19), PlayReviewOutcome.belowThreshold);
      }
      expect(s.qualifyingSessions, 4);
      expect(gateway.touched, isFalse);

      expect(await record(20), PlayReviewOutcome.requested);
      expect(s.qualifyingSessions, 5);
      expect(gateway.requests, 1);
      expect(s.requestCount, 1);
    });

    test('manuel kayıt, eski satır ve yerel koşusuz satır sayılmaz', () async {
      final s = await store({
        PlayReviewStore.watermarkKey: now
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch,
      });
      final manual = StudySession(
        id: 'm',
        userId: 'u1',
        start: now.subtract(const Duration(hours: 1)),
        end: now,
        durationSeconds: 3600,
        source: StudySource.manual,
      );
      final stale = session(
        'stale',
        minutes: 30,
        end: now.subtract(const Duration(hours: 2)),
      );
      expect(
        await ingestPlayReviewSessions(
          store: s,
          sessions: [manual, stale],
          now: now,
          localRunSeen: true,
        ),
        0,
      );
      final other = session(
        'other',
        minutes: 30,
        end: now.add(const Duration(minutes: 1)),
      );
      expect(
        await ingestPlayReviewSessions(
          store: s,
          sessions: [other],
          now: now.add(const Duration(minutes: 1)),
          localRunSeen: false,
        ),
        0,
        reason: 'bu süreçte yerel sayaç koşmadı: başka cihazın seansı',
      );
      expect(s.qualifyingSessions, 0);
    });
  });

  group('sınırlar', () {
    test('120 gün dolmadan ikinci istek yok; dolunca var', () async {
      final s = await store({
        PlayReviewStore.qualifyingSessionsKey: 9,
        PlayReviewStore.requestCountKey: 1,
        PlayReviewStore.lastRequestedAtKey: now
            .subtract(const Duration(days: 119))
            .millisecondsSinceEpoch,
      });
      final gateway = _FakeReviewGateway();
      expect(
        await ask(gateway: gateway, store: s),
        PlayReviewOutcome.coolingDown,
      );
      expect(gateway.touched, isFalse);

      expect(
        await ask(
          gateway: gateway,
          store: s,
          at: now.add(const Duration(days: 1)),
        ),
        PlayReviewOutcome.requested,
      );
      expect(s.requestCount, 2);
    });

    test('toplam 3 istekten sonra bir daha sorulmaz', () async {
      final s = await store({
        PlayReviewStore.qualifyingSessionsKey: 40,
        PlayReviewStore.requestCountKey: 3,
        PlayReviewStore.lastRequestedAtKey: now
            .subtract(const Duration(days: 900))
            .millisecondsSinceEpoch,
      });
      final gateway = _FakeReviewGateway();
      expect(
        await ask(gateway: gateway, store: s),
        PlayReviewOutcome.maxReached,
      );
      expect(gateway.touched, isFalse);
    });

    test('aynı açılışta ikinci deneme yok', () async {
      final s = await store({PlayReviewStore.qualifyingSessionsKey: 5});
      final gateway = _FakeReviewGateway(available: false);
      final launch = PlayReviewLaunchState();
      expect(
        await ask(gateway: gateway, store: s, launch: launch),
        PlayReviewOutcome.unavailable,
      );
      expect(
        await ask(gateway: gateway, store: s, launch: launch),
        PlayReviewOutcome.alreadyThisLaunch,
      );
      expect(gateway.availabilityChecks, 1);
      expect(gateway.requests, 0);
      expect(s.requestCount, 0, reason: 'gösterilemediyse hak harcanmaz');
    });

    test('Play güncelleme sayfası bu açılışta çıktıysa sorulmaz', () async {
      final s = await store({PlayReviewStore.qualifyingSessionsKey: 5});
      final gateway = _FakeReviewGateway();
      expect(
        await ask(gateway: gateway, store: s, updateFlow: true),
        PlayReviewOutcome.updateFlowThisLaunch,
      );
      expect(gateway.touched, isFalse);
    });

    test('güncelleme akışı tespiti: yalnız sayfa açan durum sayılır', () async {
      Future<bool> shown(_FakeUpdateGateway g, {bool hint = false}) =>
          playUpdateFlowShownThisLaunch(
            launch: PlayReviewLaunchState(),
            updateGateway: g,
            restartHintPending: hint,
          );
      expect(
        await shown(_FakeUpdateGateway(available: true, flexible: true)),
        isTrue,
      );
      expect(
        await shown(_FakeUpdateGateway(available: true, flexible: false)),
        isFalse,
      );
      expect(
        await shown(_FakeUpdateGateway(available: false, flexible: true)),
        isFalse,
      );
      expect(await shown(_FakeUpdateGateway(throws: true)), isFalse);
      expect(await shown(_FakeUpdateGateway(), hint: true), isTrue);

      final launch = PlayReviewLaunchState();
      final g = _FakeUpdateGateway(available: true, flexible: true);
      await playUpdateFlowShownThisLaunch(
        launch: launch,
        updateGateway: g,
        restartHintPending: false,
      );
      await playUpdateFlowShownThisLaunch(
        launch: launch,
        updateGateway: g,
        restartHintPending: false,
      );
      expect(g.checks, 1, reason: 'süreç başına bir kez sorulur');
    });
  });

  group('hata ve an', () {
    test('isAvailable / requestReview hatası yutulur', () async {
      for (final gateway in [
        _FakeReviewGateway(throwOnAvailable: true),
        _FakeReviewGateway(throwOnRequest: true),
      ]) {
        final s = await store({PlayReviewStore.qualifyingSessionsKey: 5});
        final launch = PlayReviewLaunchState();
        expect(
          await ask(gateway: gateway, store: s, launch: launch),
          PlayReviewOutcome.failed,
        );
        expect(s.requestCount, 0);
        expect(launch.attempted, isTrue, reason: 'aynı açılışta döngü yok');
      }
    });

    test('seans ortasında ya da arka planda çağrılmaz (ertelenir)', () async {
      final s = await store({PlayReviewStore.qualifyingSessionsKey: 5});
      final gateway = _FakeReviewGateway();
      final launch = PlayReviewLaunchState();
      expect(
        await ask(gateway: gateway, store: s, launch: launch, midSession: true),
        PlayReviewOutcome.deferred,
      );
      expect(
        await ask(
          gateway: gateway,
          store: s,
          launch: launch,
          inForeground: false,
        ),
        PlayReviewOutcome.deferred,
      );
      expect(gateway.touched, isFalse);
      expect(launch.attempted, isFalse, reason: 'erteleme hakkı yakmaz');
      expect(
        await ask(gateway: gateway, store: s, launch: launch),
        PlayReviewOutcome.requested,
      );
    });
  });

  group('kabuk provider', () {
    test('Play dışı kanalda provider hiçbir şeye dokunmaz', () async {
      debugPlayReviewPlatform = TargetPlatform.android;
      debugPlayReviewChannel = DistributionChannel.githubStable;
      final gateway = _FakeReviewGateway();
      // `sharedPreferencesProvider` ezilmedi: kapı prefs'ten önce dönmeli.
      final container = ProviderContainer(
        overrides: [playReviewGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      container.listen(playReviewProvider, (_, _) {});
      await pumpEventQueue();
      expect(gateway.touched, isFalse);
    });

    test(
      '5. uzun seans koşu sırasında kaydedilir; istek seans bitince',
      () async {
        debugPlayReviewPlatform = TargetPlatform.android;
        debugPlayReviewChannel = DistributionChannel.play;
        debugPlayReviewInForeground = true;
        debugPlayReviewClock = () => now;
        SharedPreferences.setMockInitialValues({
          PlayReviewStore.qualifyingSessionsKey: 4,
          PlayReviewStore.watermarkKey: now
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        });
        final prefs = await SharedPreferences.getInstance();
        final gateway = _FakeReviewGateway();
        final updates = _FakeUpdateGateway();
        final sessions = StreamController<List<StudySession>>();
        addTearDown(sessions.close);

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playReviewGatewayProvider.overrideWithValue(gateway),
            playInAppUpdateGatewayProvider.overrideWithValue(updates),
            userSessionsProvider.overrideWith((ref) => sessions.stream),
            playReviewTimerSignalProvider.overrideWith(
              (ref) => ref.watch(_signalProvider),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.listen(playReviewProvider, (_, _) {});
        // Yerel sayaç koşuyor (pomodoro: çalışma fazı kaydedilir, mola başlar).
        container.read(_signalProvider.notifier).set((
          midSession: true,
          localRun: true,
        ));
        await pumpEventQueue();

        sessions.add([
          StudySession(
            id: 'p1',
            userId: 'u1',
            start: now.subtract(const Duration(minutes: 25)),
            end: now,
            durationSeconds: 25 * 60,
            source: StudySource.live,
          ),
        ]);
        await pumpEventQueue();
        expect(prefs.getInt(PlayReviewStore.qualifyingSessionsKey), 5);
        expect(gateway.touched, isFalse, reason: 'seans ortasında sorulmaz');

        container.read(_signalProvider.notifier).set((
          midSession: false,
          localRun: false,
        ));
        await pumpEventQueue();
        expect(gateway.requests, 1);
        expect(updates.checks, 1);
        expect(prefs.getInt(PlayReviewStore.requestCountKey), 1);
      },
    );
  });
}

final _signalProvider =
    NotifierProvider<_SignalNotifier, PlayReviewTimerSignal>(
      _SignalNotifier.new,
    );

class _SignalNotifier extends Notifier<PlayReviewTimerSignal> {
  @override
  PlayReviewTimerSignal build() => (midSession: false, localRun: false);

  void set(PlayReviewTimerSignal value) => state = value;
}

class _FakeReviewGateway implements PlayReviewGateway {
  _FakeReviewGateway({
    this.available = true,
    this.throwOnAvailable = false,
    this.throwOnRequest = false,
  });

  final bool available;
  final bool throwOnAvailable;
  final bool throwOnRequest;
  int availabilityChecks = 0;
  int requests = 0;

  bool get touched => availabilityChecks > 0 || requests > 0;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    if (throwOnAvailable) throw Exception('play yok');
    return available;
  }

  @override
  Future<void> requestReview() async {
    requests++;
    if (throwOnRequest) throw Exception('istek düştü');
  }
}

class _FakeUpdateGateway implements PlayInAppUpdateGateway {
  _FakeUpdateGateway({
    this.available = false,
    this.flexible = false,
    this.throws = false,
  });

  final bool available;
  final bool flexible;
  final bool throws;
  int checks = 0;

  @override
  Future<PlayUpdateSnapshot> checkForUpdate() async {
    checks++;
    if (throws) throw Exception('play yok');
    return PlayUpdateSnapshot(
      updateAvailable: available,
      flexibleAllowed: flexible,
    );
  }

  @override
  Future<bool> startFlexibleUpdate() async => false;

  @override
  Future<void> completeFlexibleUpdate() async {}
}
