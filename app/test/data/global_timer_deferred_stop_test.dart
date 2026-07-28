import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/background/timer_foreground_service.dart';
import 'package:online_study_room/core/background/timer_v2_command_outbox.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/global_timer.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/global_timer_providers.dart';
import 'package:online_study_room/data/repositories/global_timer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingRepository implements GlobalTimerRepository {
  final calls =
      <({String action, String? runId, int? revision, String origin})>[];

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
    calls.add((
      action: action,
      runId: runId,
      revision: expectedRunRevision,
      origin: payload['origin']! as String,
    ));
    if (action == 'start') {
      return GlobalTimerSnapshot(
        stateVersion: 1,
        serverTime: DateTime.utc(2026),
        run: const GlobalTimerRun(id: 'run-1', status: 'running', revision: 1),
        resultCode: 'applied',
      );
    }
    return GlobalTimerSnapshot(
      stateVersion: 2,
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
  }) => throw UnimplementedError();

  @override
  Future<GlobalTimerSnapshot> fetchSnapshot({String? deviceId}) =>
      throw UnimplementedError();
}

Profile _profile() =>
    Profile(id: 'user-1', displayName: 'Test', createdAt: DateTime.utc(2026));

Map<String, Object?> _start({required DateTime occurredAt, String? intentId}) =>
    {
      'kind': TimerV2CommandEnvelope.kind,
      'schema_version': TimerV2CommandEnvelope.schemaVersion,
      'command_id': 'start-1',
      'account_id': 'user-1',
      'installation_id': 'installation-1',
      'action': 'start',
      'client_occurred_at': occurredAt.toIso8601String(),
      'origin': 'app',
      'run_intent_id': ?intentId,
    };

Map<String, Object?> _deferredStop({
  required DateTime occurredAt,
  required String intentId,
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
  'run_intent_id': intentId,
  'deferred_until_run_identity': true,
};

Future<({ProviderContainer container, SharedPreferences prefs})> _harness(
  List<Map<String, Object?>> queue,
  _RecordingRepository repository,
) async {
  SharedPreferences.setMockInitialValues({
    globalTimerDeviceIdKey: 'device-1',
    TimerForegroundService.pendingIntervalsKey: jsonEncode(queue),
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((_) => Stream.value(_profile())),
      globalTimerModeProvider.overrideWithValue(
        GlobalTimerMode.foregroundMirror,
      ),
      globalTimerRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  // Riverpod 3'te dinleyicisiz stream provider ilk değeri yaymadan dispose
  // olabilir; flush gerçek auth snapshot'ını görmelidir.
  container.listen(authStateProvider, (_, _) {});
  await container.read(authStateProvider.future);
  return (container: container, prefs: prefs);
}

void main() {
  group('WP-415 çevrimdışı terminal niyeti', () {
    test(
      'start ardından kimliksiz terminal niyetini gerçek CAS-stop olarak yollar',
      () async {
        final now = DateTime.now().toUtc();
        final repository = _RecordingRepository();
        final harness = await _harness([
          _start(
            occurredAt: now.subtract(const Duration(minutes: 2)),
            intentId: 'intent-1',
          ),
          _deferredStop(
            occurredAt: now.subtract(const Duration(minutes: 1)),
            intentId: 'intent-1',
          ),
        ], repository);

        await harness.container
            .read(globalTimerCoordinatorProvider)
            .flushShadow();

        expect(repository.calls, [
          (action: 'start', runId: null, revision: null, origin: 'app'),
          (action: 'stop', runId: 'run-1', revision: 1, origin: 'notification'),
        ]);
        expect(
          harness.prefs.getString(TimerForegroundService.pendingIntervalsKey),
          jsonEncode(<Object?>[]),
          reason:
              'iki uç kabul edilince hayalet start bırakacak zarf kalmamalı',
        );
      },
    );

    test(
      '24 saati geçmiş start ve bağlı terminal niyetini yeniden oynatmaz',
      () async {
        final now = DateTime.now().toUtc();
        final repository = _RecordingRepository();
        final harness = await _harness([
          _start(
            occurredAt: now.subtract(const Duration(hours: 25)),
            intentId: 'intent-old',
          ),
          _deferredStop(
            occurredAt: now.subtract(const Duration(hours: 24, minutes: 59)),
            intentId: 'intent-old',
          ),
        ], repository);

        await harness.container
            .read(globalTimerCoordinatorProvider)
            .flushShadow();

        expect(repository.calls, isEmpty);
        expect(
          harness.prefs.getString(TimerForegroundService.pendingIntervalsKey),
          jsonEncode(<Object?>[]),
        );
      },
    );
  });
}
