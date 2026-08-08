/// WP-542: durdurma gecikmesi + iki sessiz veri kaybi yolu.
///
/// Uc bagimsiz iddia:
///   1. `stop()` UZAK cagriyi beklemez. Sunucu hic cevap vermese bile sayac
///      durur ve oturum yerel cache'e yazilir (saha sikayeti: "Durdur'a
///      basiyorum, sayac bir sure oylece duruyor").
///   2. Cihaz saati geriye giderse biten oturum SESSIZCE dusurulmez; sure
///      duvar saatinden bagimsiz monotonik olcuden kurtarilir.
///   3. Outbox tek KALICI hatali kayitla kalici olarak tikanmaz; zehirli kayit
///      dead-letter'a alinir, kuyrugun geri kalani akar. GECICI hatada eski
///      davranis (dur, sirayi koru) aynen surer.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:online_study_room/data/repositories/offline/offline_cache_store.dart';
import 'package:online_study_room/data/repositories/offline/offline_first_study_repository.dart';
import 'package:online_study_room/data/repositories/study_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';

import '../support/async_wait.dart';

class _NoopTimerNotificationService implements TimerNotificationGateway {
  const _NoopTimerNotificationService();

  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> requestPermissionIfNeeded() async {}

  @override
  Future<void> showRunning(TimerNotificationSnapshot snapshot) async {}
}

class _NoopAndroidWidgetService implements AndroidWidgetGateway {
  const _NoopAndroidWidgetService();

  @override
  Future<void> refresh({Iterable<StudyHomeWidget>? widgets}) async {}

  @override
  Future<void> saveSnapshot(AndroidWidgetSnapshot snapshot) async {}

  @override
  Future<void> seedPlaceholder() async {}
}

/// Uzak `addSession` HIC donmez — kopmus degil, ASILI kalmis bir baglanti.
/// Gercek cihazda bunun karsiligi TCP zaman asimina kadar suren bekleyistir.
class _HangingRemoteStudyRepository extends InMemoryStudyRepository {
  final _called = Completer<void>();
  final List<String> accepted = [];

  Future<void> get called => _called.future;

  @override
  Future<void> addSession(StudySession session) {
    if (!_called.isCompleted) _called.complete();
    // Tamamlanmayan future: cagri yapildi, cevap hic gelmedi.
    return Completer<void>().future;
  }
}

/// Belirli oturum id'lerinde secilen hatayi firlatan uzak repo.
class _FailingRemoteStudyRepository extends InMemoryStudyRepository {
  _FailingRemoteStudyRepository(this.failures);

  final Map<String, Object> failures;
  final List<String> accepted = [];

  @override
  Future<void> addSession(StudySession session) async {
    final failure = failures[session.id];
    if (failure != null) throw failure;
    accepted.add(session.id);
    await super.addSession(session);
  }
}

StudySession _session(String id, {String userId = 'u1', int seconds = 600}) {
  final start = DateTime(2026, 8, 8, 9);
  return StudySession(
    id: id,
    userId: userId,
    start: start,
    end: start.add(Duration(seconds: seconds)),
    durationSeconds: seconds,
    source: StudySource.live,
  );
}

/// Calisan (dogrulanmamis, duz kronometre) bir kosuyla acilmis uygulama.
Future<(ProviderContainer, Profile, SharedPreferences)> _buildRunningContainer({
  required DateTime startedAt,
  required StudyRepository Function(SharedPreferences prefs) buildRepository,
}) async {
  final auth = InMemoryAuthRepository();
  final profile = await auth.signUp(
    email: 'wp542@ornek.com',
    password: '123456',
    displayName: 'Stop QA',
  );

  SharedPreferences.setMockInitialValues(<String, Object>{
    'timer_active_started_at': startedAt.toIso8601String(),
    'timer_active_started_at_ms': startedAt.millisecondsSinceEpoch,
    'timer_active_mode': TimerMode.stopwatch.name,
    'timer_active_phase': TimerPhase.work.name,
    'timer_active_cycle': 1,
    'timer_fg_mode': 'running',
  });
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
      groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
      studyRepositoryProvider.overrideWithValue(buildRepository(prefs)),
      timerNotificationServiceProvider.overrideWithValue(
        const _NoopTimerNotificationService(),
      ),
      androidWidgetServiceProvider.overrideWithValue(
        const _NoopAndroidWidgetService(),
      ),
    ],
  );
  addTearDown(container.dispose);

  final authSub = container.listen(authStateProvider, (_, _) {});
  addTearDown(authSub.close);
  // Riverpod 3: dinleyicisiz provider her `read`de yeniden kurulur.
  final timerSub = container.listen(studyTimerProvider, (_, _) {});
  addTearDown(timerSub.close);

  await waitUntil(
    () => container.read(authStateProvider).value != null,
    reason: 'auth hazir olmali',
  );
  await waitUntil(
    () => container.read(studyTimerProvider).isRunning,
    reason: 'kayitli baslangictan sayac calisir duruma gecmeli',
  );
  return (container, profile, prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WP-542/1: Durdur uzak turu beklemez', () {
    test('uzak cagri hic donmese bile stop() doner ve oturum cache\'te', () async {
      final remote = _HangingRemoteStudyRepository();
      late OfflineCacheStore cache;
      final startedAt = DateTime.now().subtract(const Duration(minutes: 25));

      final (container, profile, _) = await _buildRunningContainer(
        startedAt: startedAt,
        buildRepository: (prefs) {
          cache = OfflineCacheStore(prefs);
          return OfflineFirstStudyRepository(
            remote: remote,
            cache: cache,
            // KRITIK: burada KISA bir zaman asimi kullanilamaz. Kisa sinir
            // bloklayan (eski) yolu da hizlandirir ve test yalanci-yesil olur;
            // sabotaj turunda tam olarak bu yasandi (322 ms ile gecti). Uretim
            // sinirindan uzun bir deger, "hic donmeyen ag" durumunu korur.
            remoteDispatchTimeout: const Duration(minutes: 5),
          );
        },
      );

      final stopwatch = Stopwatch()..start();
      await container
          .read(studyTimerProvider.notifier)
          .stop()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail(
              'stop() asili uzak cagriyi bekledi — 5 sn icinde donmedi',
            ),
          );
      stopwatch.stop();
      debugPrint(
        'WP-542 OLCUM: asili uzak cagri altinda stop() '
        '${stopwatch.elapsedMilliseconds} ms',
      );

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(2000),
        reason: 'durdurma kullanici icin anlik olmali',
      );
      expect(container.read(studyTimerProvider).isRunning, isFalse);
      expect(
        container.read(sharedPreferencesProvider).getString('timer_fg_mode'),
        'idle',
        reason: 'FGS teardown ag turunun arkasinda beklememeli',
      );

      final cached = await cache.readUserSessions(profile.id);
      expect(
        cached,
        hasLength(1),
        reason: 'oturum yerel cache\'te guvende olmali',
      );
      expect(cached!.single.durationSeconds, greaterThanOrEqualTo(1500));

      // Vazgecilmis degil, yalniz beklenmemis: uzak cagri gercekten yapilir.
      await remote.called.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('uzak addSession hic cagrilmadi'),
      );
      expect(remote.accepted, isEmpty);
    });

    test('asili uzak cagri zaman asimina ugrayinca oturum outbox\'a duser', () async {
      final remote = _HangingRemoteStudyRepository();
      late OfflineCacheStore cache;
      final startedAt = DateTime.now().subtract(const Duration(minutes: 25));

      final (container, _, _) = await _buildRunningContainer(
        startedAt: startedAt,
        buildRepository: (prefs) {
          cache = OfflineCacheStore(prefs);
          return OfflineFirstStudyRepository(
            remote: remote,
            cache: cache,
            // Bu testin iddiasi gecikme DEGIL kayip: sinir kisaltilabilir.
            remoteDispatchTimeout: const Duration(milliseconds: 300),
          );
        },
      );

      await container.read(studyTimerProvider.notifier).stop();

      var pending = await cache.readPendingStudyMutations();
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (pending.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        pending = await cache.readPendingStudyMutations();
      }
      expect(
        pending,
        hasLength(1),
        reason:
            'sinirsiz asili kalan cagri oturumu ne sunucuya ne kuyruga koyardi',
      );
      expect(remote.accepted, isEmpty);
    });
  });

  group('WP-542/2: cihaz saati geriye giderse oturum kaybolmaz', () {
    test('40 dakikalik kosu, saat 2 saat geri alininca da yazilir', () async {
      // SENARYO: kullanici T aninda basladi, 40 dk calisti (T+40'ta bir gecis
      // prefs'e yazildi), sonra cihaz saati 2 SAAT GERI alindi. Artik
      // `DateTime.now()` kayitli `startedAt`'in ONUNDE: duvar saatinden
      // turetilen sure NEGATIF. Bu, `DateTime.now()` degistirilmeden tam olarak
      // taklit edilebilir — kayitli damgalari gelecege koymak yeterlidir.
      final remote = InMemoryStudyRepository();
      final realNow = DateTime.now();
      final startedAt = realNow.add(const Duration(minutes: 80));
      final lastPersist = startedAt.add(const Duration(minutes: 40));

      final auth = InMemoryAuthRepository();
      final profile = await auth.signUp(
        email: 'wp542-clock@ornek.com',
        password: '123456',
        displayName: 'Clock QA',
      );

      SharedPreferences.setMockInitialValues(<String, Object>{
        'timer_active_started_at': startedAt.toIso8601String(),
        'timer_active_started_at_ms': startedAt.millisecondsSinceEpoch,
        'timer_active_mode': TimerMode.stopwatch.name,
        'timer_active_phase': TimerPhase.work.name,
        'timer_active_cycle': 1,
        'timer_fg_mode': 'running',
        // Sicramadan ONCEKI gercek zamanda yazilmis son damga: kosunun en az
        // 40 dk surdugunun kaniti.
        'timer_active_updated_at': lastPersist.toUtc().toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
          studyRepositoryProvider.overrideWithValue(remote),
          timerNotificationServiceProvider.overrideWithValue(
            const _NoopTimerNotificationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(
            const _NoopAndroidWidgetService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final authSub = container.listen(authStateProvider, (_, _) {});
      addTearDown(authSub.close);
      final timerSub = container.listen(studyTimerProvider, (_, _) {});
      addTearDown(timerSub.close);

      await waitUntil(
        () => container.read(authStateProvider).value != null,
        reason: 'auth hazir olmali',
      );
      await waitUntil(
        () => container.read(studyTimerProvider).isRunning,
        reason: 'kayitli baslangictan sayac calisir duruma gecmeli',
      );

      await container.read(studyTimerProvider.notifier).stop();
      await pumpEventQueue(times: 5);

      expect(container.read(studyTimerProvider).isRunning, isFalse);

      final sessions = await remote.watchUserSessions(profile.id).first;
      expect(
        sessions,
        hasLength(1),
        reason:
            'ters saat oturumu dusuremez — eski kod burada sessizce return ediyordu',
      );
      // "Sure makul mu": duvar saatinden degil bagimsiz alt sinirdan gelmeli.
      expect(
        sessions.single.durationSeconds,
        inInclusiveRange(2340, 2460),
        reason: '40 dakikalik kosu ~2400 sn olarak kurtarilmali',
      );
      debugPrint(
        'WP-542 OLCUM: ters saatte yazilan sure '
        '${sessions.single.durationSeconds} sn (beklenen ~2400)',
      );
    });
  });

  group('WP-542/3: outbox zehirli kayitla tikanmaz', () {
    Future<OfflineCacheStore> store() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      return OfflineCacheStore(await SharedPreferences.getInstance());
    }

    test('kalici hata (FK/CHECK ihlali) dead-letter\'a alinir, kuyruk akar', () async {
      final cache = await store();
      final remote = _FailingRemoteStudyRepository({
        // 23503 = foreign_key_violation (baska cihazda silinmis subject_id).
        'poison': const PostgrestException(
          message: 'insert violates foreign key constraint',
          code: '23503',
        ),
      });
      final repo = OfflineFirstStudyRepository(remote: remote, cache: cache);

      await cache.queueStudyMutation(OfflineStudyMutation.add(_session('s1')));
      await cache.queueStudyMutation(
        OfflineStudyMutation.add(_session('poison')),
      );
      await cache.queueStudyMutation(OfflineStudyMutation.add(_session('s3')));

      await repo.flushPending();

      expect(
        remote.accepted,
        ['s1', 's3'],
        reason: 'zehirli kaydin ARKASINDAKI kayitlar da akmali',
      );
      expect(
        await cache.readPendingStudyMutations(),
        isEmpty,
        reason: 'kuyruk kalici olarak tikanmamali',
      );
      expect(repo.deadLetteredMutations, hasLength(1));
      expect(repo.deadLetteredMutations.single.mutation.sessionId, 'poison');
    });

    test('gecici hata kuyrugu durdurur ve sirayi korur', () async {
      final cache = await store();
      final remote = _FailingRemoteStudyRepository({
        'flaky': TimeoutException('ag yok'),
      });
      final repo = OfflineFirstStudyRepository(remote: remote, cache: cache);

      await cache.queueStudyMutation(OfflineStudyMutation.add(_session('s1')));
      await cache.queueStudyMutation(
        OfflineStudyMutation.add(_session('flaky')),
      );
      await cache.queueStudyMutation(OfflineStudyMutation.add(_session('s3')));

      await repo.flushPending();

      expect(remote.accepted, ['s1']);
      final pending = await cache.readPendingStudyMutations();
      expect(
        pending.map((m) => m.sessionId),
        ['flaky', 's3'],
        reason: 'gecici hatada sira korunur (eski davranis)',
      );
      expect(repo.deadLetteredMutations, isEmpty);
    });

    test('429 (rate limit) kalici sayilmaz, 400 sayilir', () async {
      final rateLimited = await store();
      final throttledRemote = _FailingRemoteStudyRepository({
        'x': const PostgrestException(message: 'too many', code: '429'),
      });
      final throttledRepo = OfflineFirstStudyRepository(
        remote: throttledRemote,
        cache: rateLimited,
      );
      await rateLimited.queueStudyMutation(
        OfflineStudyMutation.add(_session('x')),
      );
      await throttledRepo.flushPending();
      expect(await rateLimited.readPendingStudyMutations(), hasLength(1));
      expect(throttledRepo.deadLetteredMutations, isEmpty);

      final rejected = await store();
      final badRequestRemote = _FailingRemoteStudyRepository({
        'x': const PostgrestException(message: 'bad request', code: '400'),
      });
      final rejectedRepo = OfflineFirstStudyRepository(
        remote: badRequestRemote,
        cache: rejected,
      );
      await rejected.queueStudyMutation(
        OfflineStudyMutation.add(_session('x')),
      );
      await rejectedRepo.flushPending();
      expect(await rejected.readPendingStudyMutations(), isEmpty);
      expect(rejectedRepo.deadLetteredMutations, hasLength(1));
    });
  });
}
