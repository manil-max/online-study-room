import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readRepoFile(String relativePath) {
  final repoRoot = Directory.current.parent.path;
  return File('$repoRoot/$relativePath').readAsStringSync();
}

void main() {
  final migration = _readRepoFile(
    'supabase/migrations/0051_verified_live_sessions.sql',
  );
  final model = _readRepoFile('app/lib/data/models/study_session.dart');
  final supabaseRepository = _readRepoFile(
    'app/lib/data/repositories/supabase/supabase_study_repository.dart',
  );
  final inMemoryRepository = _readRepoFile(
    'app/lib/data/repositories/in_memory/in_memory_study_repository.dart',
  );
  final studyProviders = _readRepoFile(
    'app/lib/data/providers/study_providers.dart',
  );
  final nativeStore = _readRepoFile(
    'app/android/app/src/main/kotlin/com/manilmax/online_study_room/timer/TimerStateStore.kt',
  );
  final plan = _readRepoFile(
    'docs/GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md',
  );

  group('WP-337 V3 legacy compatibility gate', () {
    test('legacy active-run and request-id invariants are explicit', () {
      expect(migration, contains('live_study_runs_one_active_user'));
      expect(migration, contains("where status in ('running', 'paused')"));
      expect(migration, contains('unique (user_id, client_request_id)'));
      expect(
        migration,
        contains("status in ('running', 'paused', 'finalized', 'cancelled')"),
      );
      expect(
        migration,
        contains(
          "check ((status = 'finalized') = (finalized_at is not null and session_id is not null))",
        ),
      );
    });

    test(
      'legacy start is user-locked and repositories retain its RPC contract',
      () {
        expect(
          migration,
          contains('pg_advisory_xact_lock(hashtextextended(v_uid::text, 216))'),
        );
        expect(migration, contains('start_verified_live_run'));
        expect(supabaseRepository, contains("'start_verified_live_run'"));
        expect(
          supabaseRepository,
          contains("'p_client_request_id': clientRequestId"),
        );
        expect(
          inMemoryRepository,
          contains("final requestKey = '\u0024userId:\u0024clientRequestId';"),
        );
        expect(inMemoryRepository, contains('active_live_run_exists'));
      },
    );

    test('legacy DTO remains frozen while V2 requires a separate DTO/RPC', () {
      expect(
        model,
        contains(
          'enum LiveRunStatus { running, paused, finalized, cancelled }',
        ),
      );
      expect(model, contains('LiveRunStatus.values.byName'));
      expect(
        plan,
        contains('Legacy `LiveStudyRun/LiveRunStatus` modeli donuktur.'),
      );
      expect(plan, contains('V2 snapshot ayrı DTO/RPC ile parse edilir.'));
      expect(
        studyProviders,
        contains('bool get _verifiedServerAvailable => false;'),
      );
    });

    test('local command bridge and durable interval queue remain distinct', () {
      expect(studyProviders, contains('state.commandSeq'));
      expect(studyProviders, contains('pendingIntervalsKey'));
      expect(nativeStore, contains('appendPendingVerifiedCommand'));
      expect(nativeStore, contains('.put("runToken", runToken)'));
      expect(
        plan,
        contains(
          '`commandSeq` distributed command sürümü veya server outbox sırası değildir.',
        ),
      );
      expect(
        plan,
        contains(
          '`pendingIntervals` içindeki kalıcı UUID/kısmi-ack mekanizması',
        ),
      );
    });

    test(
      'V2 migration decisions keep one active index and a separate rollout gate',
      () {
        expect(plan, contains('ikinci bir `state` kolonu eklenmez.'));
        expect(
          plan,
          contains(
            'Tek aktif-study invariant\'ı legacy ve V2\'yi birlikte kapsar',
          ),
        );
        expect(
          plan,
          contains(
            'Start command `command_id`, run satırındaki zorunlu `client_request_id` alanına aynen yazılır.',
          ),
        );
        expect(
          plan,
          contains(
            'V2 ve legacy start RPC\'leri aynı kullanıcı advisory-lock alanını kullanır.',
          ),
        );
        expect(
          plan,
          contains(
            'Legacy `_verifiedServerAvailable` bayrağı V2 için yeniden adlandırılmış kapı değildir ve açılmaz.',
          ),
        );
      },
    );
  });
}
