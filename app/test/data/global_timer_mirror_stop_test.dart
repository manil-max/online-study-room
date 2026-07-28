import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/global_timer.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/global_timer_providers.dart';
import 'package:online_study_room/data/repositories/global_timer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingRepository implements GlobalTimerRepository {
  final List<
    ({String action, String runId, int revision, Map<String, Object?> payload})
  >
  commands = [];
  bool rejectAsStale = false;

  @override
  Future<GlobalTimerSnapshot> acknowledge({
    required String deviceId,
    required int stateVersion,
    required String status,
    String? runId,
    int? runRevision,
    String? errorCode,
  }) async => GlobalTimerSnapshot(
    stateVersion: stateVersion,
    serverTime: DateTime.now().toUtc(),
  );

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
    commands.add((
      action: action,
      runId: runId ?? '',
      revision: expectedRunRevision ?? 0,
      payload: payload,
    ));
    return GlobalTimerSnapshot(
      stateVersion: 8,
      serverTime: DateTime.now().toUtc(),
      resultCode: rejectAsStale ? 'stale' : 'applied',
    );
  }

  @override
  Future<GlobalTimerSnapshot> fetchSnapshot({String? deviceId}) async =>
      GlobalTimerSnapshot(stateVersion: 0, serverTime: DateTime.now().toUtc());
}

void main() {
  Future<ProviderContainer> buildContainer(
    _RecordingRepository repository,
  ) async {
    SharedPreferences.setMockInitialValues({
      globalTimerDeviceIdKey: 'device-1',
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
              createdAt: DateTime(2026),
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
    await container.read(authStateProvider.future);
    return container;
  }

  test(
    'WP-379: ayna Durdur V2 stop sözleşmesine run + revizyonla gider',
    () async {
      final repository = _RecordingRepository();
      final container = await buildContainer(repository);

      await container
          .read(globalTimerCoordinatorProvider)
          .stopMirroredRun(runId: 'run-379', expectedRunRevision: 7);

      expect(repository.commands, hasLength(1));
      expect(repository.commands.single.action, 'stop');
      expect(repository.commands.single.runId, 'run-379');
      expect(repository.commands.single.revision, 7);
      expect(repository.commands.single.payload, {'origin': 'app'});
    },
  );

  test('WP-379: revision reddi aynayı yerelde başarı gibi kapatmaz', () async {
    final repository = _RecordingRepository()..rejectAsStale = true;
    final container = await buildContainer(repository);

    await expectLater(
      container
          .read(globalTimerCoordinatorProvider)
          .stopMirroredRun(runId: 'run-379', expectedRunRevision: 7),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'WP-379: istemci stop zarfı sunucunun zorunlu kimlik sözleşmesini taşır',
    () async {
      final migration = File(
        '../supabase/migrations/0088_timer_sync_delivery.sql',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      expect(
        migration,
        contains('if p_run_id is null or p_expected_run_revision is null then'),
        reason:
            'sunucu stop için run kimliği ve revision olmadan komutu reddeder',
      );

      final repository = _RecordingRepository();
      final container = await buildContainer(repository);
      await container
          .read(globalTimerCoordinatorProvider)
          .stopMirroredRun(runId: 'run-contract', expectedRunRevision: 3);
      expect(repository.commands.single.runId, isNotEmpty);
      expect(repository.commands.single.revision, greaterThan(0));
    },
  );
}
