import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/background/timer_foreground_service.dart';
import 'package:online_study_room/core/background/timer_v2_command_outbox.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/global_timer.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/global_timer_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/global_timer_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-431 — kanonik komut protokolünün sözleşmesi.
///
/// WP-430 kanıtı kök nedeni tek cümleye indirdi: *kimliği olmayan cihazın
/// hiçbir yüzeyi koşuya dokunamıyor ve hata da vermiyordu.* Bu dosya onarımın
/// üç ayağını kilitler: **rol** (kim durduruyor), **kimlik bileti** (neyi
/// durduruyor) ve **hata sınıfı** (başarısız komuta ne olacak).
class _RecordingRepository implements GlobalTimerRepository {
  _RecordingRepository({this.failure});

  final Object? failure;
  final calls = <({String action, String? runId, int? revision})>[];

  @override
  Future<GlobalTimerSnapshot> applyCommand({
    required String commandId,
    required String deviceId,
    required String action,
    String? runId,
    int? expectedRunRevision,
    DateTime? clientOccurredAt,
    Map<String, Object?> payload = const {},
  }) async {
    calls.add((action: action, runId: runId, revision: expectedRunRevision));
    if (failure != null) throw failure!;
    return GlobalTimerSnapshot(
      stateVersion: 3,
      serverTime: DateTime.utc(2026),
      resultCode: 'applied',
    );
  }

  @override
  Future<GlobalTimerSnapshot> acknowledge({
    required String deviceId,
    required int stateVersion,
    required String status,
    String? runId,
    int? runRevision,
    String? errorCode,
  }) async =>
      GlobalTimerSnapshot(stateVersion: stateVersion, serverTime: DateTime.utc(2026));

  @override
  Future<GlobalTimerSnapshot> fetchSnapshot({String? deviceId}) async =>
      GlobalTimerSnapshot(stateVersion: 0, serverTime: DateTime.utc(2026));
}

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

Future<({ProviderContainer container, SharedPreferences prefs})>
_coordinatorHarness(
  Map<String, Object> seed,
  _RecordingRepository repository,
) async {
  SharedPreferences.setMockInitialValues({
    globalTimerDeviceIdKey: 'device-1',
    ...seed,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith(
        (_) => Stream.value(
          Profile(
            id: 'user-1',
            displayName: 'Kullanıcı',
            createdAt: DateTime.utc(2026),
          ),
        ),
      ),
      globalTimerModeProvider.overrideWithValue(
        GlobalTimerMode.foregroundMirror,
      ),
      globalTimerRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  container.listen(authStateProvider, (_, _) {});
  await container.read(authStateProvider.future);
  return (container: container, prefs: prefs);
}

Map<String, Object?> _stopEnvelope({
  required DateTime occurredAt,
  String? runId,
  int? revision,
  String origin = 'notification',
}) => {
  'kind': TimerV2CommandEnvelope.kind,
  'schema_version': TimerV2CommandEnvelope.schemaVersion,
  'command_id': 'stop-1',
  'account_id': 'user-1',
  'installation_id': 'installation-1',
  'action': 'stop',
  'client_occurred_at': occurredAt.toIso8601String(),
  'origin': origin,
  'run_id': runId,
  'expected_run_revision': revision,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tek durdurma karar fonksiyonu (planTimerStop)', () {
    test('kimlikli ayna: sunucuya CAS komutu, yerel oturum YOK', () {
      final plan = planTimerStop(
        role: TimerControllerRole.mirror,
        runId: 'run-1',
        expectedRunRevision: 4,
        wasWorkPhase: true,
      );
      expect(plan.emitServerCommand, isTrue);
      expect(plan.runId, 'run-1');
      expect(plan.expectedRunRevision, 4);
      expect(
        plan.recordLocalInterval,
        isFalse,
        reason: 'projeksiyon asla oturum üretmez — V56-S01in ikinci yüzü',
      );
      expect(plan.blockedReason, isNull);
    });

    test('kimliksiz ayna: komut üretilemez ama yine oturum da yazılmaz', () {
      final plan = planTimerStop(
        role: TimerControllerRole.mirror,
        runId: null,
        expectedRunRevision: null,
        wasWorkPhase: true,
      );
      expect(plan.emitServerCommand, isFalse);
      expect(plan.recordLocalInterval, isFalse);
      expect(
        plan.blockedReason,
        'mirror_identity_missing',
        reason: 'sessiz düşme yerine adı konmuş bir engel',
      );
    });

    test('kimliksiz kaynak: terminal niyet ertelenir, oturum yerelde yazılır', () {
      final plan = planTimerStop(
        role: TimerControllerRole.source,
        runId: null,
        expectedRunRevision: null,
        wasWorkPhase: true,
      );
      expect(plan.emitServerCommand, isTrue);
      expect(plan.recordLocalInterval, isTrue);
      expect(plan.blockedReason, 'deferred_until_run_identity');
    });

    test('uygulama içi sessiz durdurma yerel aralık yazmaz (çift kayıt olmaz)', () {
      final plan = planTimerStop(
        role: TimerControllerRole.source,
        runId: 'run-1',
        expectedRunRevision: 2,
        wasWorkPhase: true,
        isSilentAppStop: true,
      );
      expect(plan.emitServerCommand, isTrue);
      expect(plan.recordLocalInterval, isFalse);
    });

    test('mola durdurması oturum üretmez', () {
      final plan = planTimerStop(
        role: TimerControllerRole.source,
        runId: 'run-1',
        expectedRunRevision: 2,
        wasWorkPhase: false,
      );
      expect(plan.recordLocalInterval, isFalse);
    });

    test('tanınmayan rol güvenli tarafa (source) düşer', () {
      expect(TimerControllerRole.parse(null), TimerControllerRole.source);
      expect(TimerControllerRole.parse('bozuk'), TimerControllerRole.source);
      expect(TimerControllerRole.parse('mirror'), TimerControllerRole.mirror);
    });
  });

  group('Hata sınıflandırması', () {
    test('sunucunun asla kabul etmeyeceği hata terminaldir', () {
      for (final code in const [
        'invalid_global_timer_origin',
        'stop_run_revision_required',
        'command_id_payload_mismatch',
        'client_clock_skew_rejected',
      ]) {
        expect(
          classifyGlobalTimerFailure(StateError('PostgrestException: $code')),
          GlobalTimerCommandFailure.terminal,
          reason: code,
        );
      }
    });

    test('kimlik/cihaz bağı hatası karantinadır', () {
      expect(
        classifyGlobalTimerFailure(StateError('active_device_required')),
        GlobalTimerCommandFailure.quarantine,
      );
    });

    test('tanınmayan hata retry sayılır — veri kaybetmemek önceliklidir', () {
      expect(
        classifyGlobalTimerFailure(StateError('SocketException: host lookup')),
        GlobalTimerCommandFailure.retry,
      );
      expect(
        classifyGlobalTimerFailure(StateError('global_timer_v2_disabled')),
        GlobalTimerCommandFailure.retry,
        reason: 'bayrak yeniden açılabilir; komut atılmamalı',
      );
    });
  });

  group('Kuyruk dayanıklılığı', () {
    test('zehirli zarf kuyruktan düşer, sağlam kayıtlar kalmaya devam eder',
        () async {
      final now = DateTime.now().toUtc();
      final repository = _RecordingRepository(
        failure: StateError('PostgrestException: invalid_global_timer_origin'),
      );
      final harness = await _coordinatorHarness({
        TimerForegroundService.pendingIntervalsKey: jsonEncode([
          _stopEnvelope(occurredAt: now, runId: 'run-1', revision: 1),
          // V2 olmayan sıradan bir aralık kaydı: kuyrukta kalmalı.
          {'id': 'interval-1', 'start': 'a', 'end': 'b', 'subject': ''},
        ]),
      }, repository);

      await harness.container.read(globalTimerCoordinatorProvider).flushShadow();

      final remaining =
          jsonDecode(
                harness.prefs.getString(
                      TimerForegroundService.pendingIntervalsKey,
                    ) ??
                    '[]',
              )
              as List;
      expect(
        remaining.map((item) => (item as Map)['id']),
        ['interval-1'],
        reason: 'terminal hata yalnız kendi zarfını düşürür',
      );
    });

    test('geçici hata zarfı kuyrukta bırakır', () async {
      final now = DateTime.now().toUtc();
      final repository = _RecordingRepository(
        failure: StateError('SocketException: host lookup failed'),
      );
      final envelope = _stopEnvelope(
        occurredAt: now,
        runId: 'run-1',
        revision: 1,
      );
      final harness = await _coordinatorHarness({
        TimerForegroundService.pendingIntervalsKey: jsonEncode([envelope]),
      }, repository);

      await harness.container.read(globalTimerCoordinatorProvider).flushShadow();

      final remaining =
          jsonDecode(
                harness.prefs.getString(
                      TimerForegroundService.pendingIntervalsKey,
                    ) ??
                    '[]',
              )
              as List;
      expect(remaining, hasLength(1));
    });
  });

  group('Ayna durdurma kimlik hijyeni', () {
    test('başarılı ayna Durdur kimlik biletini tüketir', () async {
      final repository = _RecordingRepository();
      final harness = await _coordinatorHarness({
        TimerV2CommandEnvelope.runIdKey: 'run-1',
        TimerV2CommandEnvelope.runRevisionKey: '4',
      }, repository);

      await harness.container
          .read(globalTimerCoordinatorProvider)
          .stopMirroredRun(runId: 'run-1', expectedRunRevision: 4);

      expect(repository.calls.single.action, 'stop');
      expect(
        harness.prefs.getString(TimerV2CommandEnvelope.runIdKey),
        isNull,
        reason:
            'bilet bırakılırsa _finish yolundaki native STOP_SILENT ölü koşuya '
            'ikinci, zehirli bir stop zarfı üretir',
      );
    });
  });

  group('Soğuk açılış — ayna diriltilmez (V56-S04)', () {
    test('sekiz saatlik ayna izi canlı sayaç olarak geri gelmez', () async {
      final startedAt = DateTime.now().subtract(const Duration(hours: 8));
      SharedPreferences.setMockInitialValues({
        'timer_active_started_at': startedAt.toIso8601String(),
        'timer_active_started_at_ms': startedAt.millisecondsSinceEpoch,
        'timer_active_mode': 'stopwatch',
        'timer_active_phase': 'work',
        'timer_fg_mode': 'running',
        'timer_global_mirror_run_id': 'run-ghost',
        'timer_global_mirror_run_revision': 2,
      });
      final prefs = await SharedPreferences.getInstance();
      final auth = InMemoryAuthRepository();
      await auth.signUp(
        email: 'mirror@ornek.com',
        password: '123456',
        displayName: 'Mirror QA',
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
          studyRepositoryProvider.overrideWithValue(InMemoryStudyRepository()),
          timerNotificationServiceProvider.overrideWithValue(
            const _NoopTimerNotificationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(
            const _NoopAndroidWidgetService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(studyTimerProvider);
      expect(
        state.isRunning,
        isFalse,
        reason: 'sunucu doğrulamadan ayna canlı sayaç açamaz',
      );
      expect(state.isGlobalTimerMirror, isFalse);
      expect(state.startedAt, isNull);

      await pumpEventQueue(times: 20);

      expect(
        prefs.getString('timer_active_started_at'),
        isNull,
        reason: 'yerel iz de düşer; sonraki reconcile onu SOURCE sanmamalı',
      );
    });

    test('kendi koşusu (source) soğuk açılışta normal biçimde geri gelir', () async {
      final startedAt = DateTime.now().subtract(const Duration(minutes: 20));
      SharedPreferences.setMockInitialValues({
        'timer_active_started_at': startedAt.toIso8601String(),
        'timer_active_started_at_ms': startedAt.millisecondsSinceEpoch,
        'timer_active_mode': 'stopwatch',
        'timer_active_phase': 'work',
        'timer_fg_mode': 'running',
      });
      final prefs = await SharedPreferences.getInstance();
      final auth = InMemoryAuthRepository();
      await auth.signUp(
        email: 'source@ornek.com',
        password: '123456',
        displayName: 'Source QA',
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
          studyRepositoryProvider.overrideWithValue(InMemoryStudyRepository()),
          timerNotificationServiceProvider.overrideWithValue(
            const _NoopTimerNotificationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(
            const _NoopAndroidWidgetService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(studyTimerProvider);
      expect(
        state.isRunning,
        isTrue,
        reason: 'kendi koşusunu kaybetmek regresyon olurdu',
      );
      expect(state.startedAt, isNotNull);
    });
  });
}
