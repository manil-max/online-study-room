import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';

void main() {
  group('WP-216 verified live repository contract', () {
    late DateTime now;
    late InMemoryStudyRepository repo;

    setUp(() {
      now = DateTime.utc(2026, 7, 19, 20);
      repo = InMemoryStudyRepository(now: () => now);
    });

    test('retry aynı run; iki cihaz ikinci aktif run açamaz', () async {
      final first = await repo.startLiveRun(
        userId: 'u1',
        clientRequestId: 'request-1',
        clientBuild: 35,
      );
      final retry = await repo.startLiveRun(
        userId: 'u1',
        clientRequestId: 'request-1',
        clientBuild: 35,
      );

      expect(retry.id, first.id);
      expect(retry.runToken, first.runToken);
      expect(
        () => repo.startLiveRun(userId: 'u1', clientRequestId: 'other-device'),
        throwsA(isA<StateError>()),
      );
    });

    test('group snapshot yalnız doğrulanmış üyelikle sabitlenir', () async {
      expect(
        () => repo.startLiveRun(
          userId: 'u1',
          clientRequestId: 'not-member',
          groupId: 'g1',
        ),
        throwsA(isA<StateError>()),
      );

      repo.registerGroupMembership('u1', 'g1');
      final run = await repo.startLiveRun(
        userId: 'u1',
        clientRequestId: 'member',
        groupId: 'g1',
      );
      expect(run.groupIdSnapshot, 'g1');
    });

    test('pause/resume segmentleri server saatiyle birleştirir', () async {
      final run = await repo.startLiveRun(
        userId: 'u1',
        clientRequestId: 'segments',
      );
      now = now.add(const Duration(minutes: 10));
      expect(
        (await repo.pauseLiveRun(run.runToken)).status,
        LiveRunStatus.paused,
      );
      now = now.add(const Duration(minutes: 5));
      expect(
        (await repo.resumeLiveRun(run.runToken)).status,
        LiveRunStatus.running,
      );
      now = now.add(const Duration(minutes: 20));

      final session = await repo.finalizeLiveRun(run.runToken);
      final retry = await repo.finalizeLiveRun(run.runToken);
      expect(session.id, retry.id);
      expect(session.durationSeconds, 30 * 60);
      expect(session.isVerified, isTrue);
      expect(await repo.watchUserSessions('u1').first, hasLength(1));
    });

    test(
      'verified satır direct DML ile yazılamaz veya değiştirilemez',
      () async {
        final run = await repo.startLiveRun(
          userId: 'u1',
          clientRequestId: 'immutable',
        );
        now = now.add(const Duration(minutes: 1));
        final verified = await repo.finalizeLiveRun(run.runToken);

        expect(() => repo.addSession(verified), throwsA(isA<StateError>()));
        expect(() => repo.updateSession(verified), throwsA(isA<StateError>()));
        expect(
          () => repo.deleteSession(verified.id),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('legacy client session ve pasif config davranışı korunur', () async {
      final legacy = StudySession(
        id: 'legacy',
        userId: 'u1',
        start: now,
        end: now.add(const Duration(minutes: 5)),
        durationSeconds: 300,
        source: StudySource.live,
      );
      await repo.addSession(legacy);
      expect(
        (await repo.watchUserSessions('u1').first).single.isVerified,
        false,
      );
      expect(
        await repo.fetchVerifiedSessionConfig(),
        isA<VerifiedSessionConfig>()
            .having((value) => value.shadowMode, 'shadowMode', true)
            .having(
              (value) => value.minimumVerifiedXpBuild,
              'minimumVerifiedXpBuild',
              isNull,
            ),
      );
    });

    test('rollout kaydı raw session verisi olmadan tutulur', () async {
      await repo.recordVerifiedSessionRollout(
        platform: 'android',
        clientBuild: 35,
        capability: true,
        origin: LiveStartOrigin.dartApp,
        outcome: LiveRolloutOutcome.verifiedFinalize,
      );
      expect(repo.rolloutEvents, hasLength(1));
      expect(repo.rolloutEvents.single.platform, 'android');
      expect(repo.rolloutEvents.single.capability, isTrue);
    });
  });

  group('WP-216 SQL security contract', () {
    final migration = File(
      '../supabase/migrations/0051_verified_live_sessions.sql',
    ).readAsStringSync();

    test('direct DML non-null live_run_id yazamaz', () {
      expect(migration, contains('live_run_id is null'));
      expect(migration, contains('verified_session_immutable'));
      expect(migration, contains('study_sessions_live_run_id_key'));
    });

    test('run owner, üyelik ve tek aktif run server tarafından doğrulanır', () {
      expect(migration, contains('v_uid uuid := auth.uid()'));
      expect(migration, contains('live_study_runs_one_active_user'));
      expect(migration, contains('group_membership_required'));
      expect(migration, isNot(contains('p_user_id uuid')));
    });

    test(
      'group snapshot cascade FK değildir ve telemetry 30 günle sınırlı',
      () {
        expect(migration, contains('group_id_snapshot uuid'));
        expect(
          migration,
          isNot(contains('group_id_snapshot uuid references public.groups')),
        );
      expect(
        migration,
        contains("timezone('Europe/Istanbul', clock_timestamp()))::date - 30"),
      );
      expect(migration, contains('verified-session-rollout-retention'));
        expect(
          migration,
          contains('shadow_mode boolean not null default true'),
        );
      },
    );
  });
}
