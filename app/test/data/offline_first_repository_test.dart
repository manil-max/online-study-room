import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/providers/offline_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/offline/offline_cache_store.dart';
import 'package:online_study_room/data/repositories/offline/offline_first_presence_repository.dart';
import 'package:online_study_room/data/repositories/offline/offline_first_study_repository.dart';
import 'package:online_study_room/data/repositories/presence_repository.dart';
import 'package:online_study_room/data/repositories/study_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

StudySession _session(String id, {int seconds = 600}) {
  final start = DateTime(2026, 7, 11, 9);
  return StudySession(
    id: id,
    userId: 'u1',
    start: start,
    end: start.add(Duration(seconds: seconds)),
    durationSeconds: seconds,
    source: StudySource.live,
  );
}

Presence _presence(PresenceStatus status, {String userId = 'u1'}) {
  return Presence(
    userId: userId,
    groupId: 'g1',
    status: status,
    startedAt: status == PresenceStatus.studying
        ? DateTime(2026, 7, 11, 9)
        : null,
    todaySeconds: 600,
    updatedAt: DateTime(2026, 7, 11, 9, 10),
  );
}

Future<OfflineCacheStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return OfflineCacheStore(await SharedPreferences.getInstance());
}

void main() {
  test('study write failure is cached and flushed later', () async {
    final cache = await _store();
    final remote = _FakeStudyRepository()..failWrites = true;
    final repo = OfflineFirstStudyRepository(remote: remote, cache: cache);
    final session = _session('s1');

    await repo.addSession(session);

    expect(remote.sessions, isEmpty);
    expect((await cache.readUserSessions('u1'))!.single.id, 's1');
    expect(await cache.readPendingStudyMutations(), hasLength(1));

    remote.failWrites = false;
    await repo.flushPending();

    expect(remote.sessions.single.id, 's1');
    expect(await cache.readPendingStudyMutations(), isEmpty);
  });

  test('offline add sonra silme outbox kaydını tamamen kaldırır', () async {
    final cache = await _store();
    final remote = _FakeStudyRepository()..failWrites = true;
    final repo = OfflineFirstStudyRepository(remote: remote, cache: cache);

    await repo.addSession(_session('ephemeral'));
    await repo.deleteSession('ephemeral');

    expect(await cache.readPendingStudyMutations(), isEmpty);
  });

  test(
    'study stream falls back to cached user sessions after remote error',
    () async {
      final cache = await _store();
      final remote = _FakeStudyRepository()..failUserSessionStream = true;
      final repo = OfflineFirstStudyRepository(remote: remote, cache: cache);
      await cache.saveUserSessions('u1', [_session('cached')]);

      final rows = await repo.watchUserSessions('u1').first;

      expect(rows.single.id, 'cached');
    },
  );

  test('gecikmiş realtime snapshot bekleyen yerel eklemeyi ezmez', () async {
    final cache = await _store();
    final remote = _FakeStudyRepository()..failWrites = true;
    final repo = OfflineFirstStudyRepository(remote: remote, cache: cache);
    await repo.addSession(_session('pending'));

    final reconciled = await repo.watchUserSessions('u1').skip(1).first;

    expect(reconciled.map((session) => session.id), contains('pending'));
  });

  test('group daily stats are cached for offline dashboard reads', () async {
    final cache = await _store();
    final remote = _FakeStudyRepository();
    final repo = OfflineFirstStudyRepository(remote: remote, cache: cache);
    remote.dailyStats = [
      DailyStat(userId: 'u1', day: DateTime(2026, 7, 11), seconds: 1200),
    ];

    final onlineRows = await repo.watchGroupDailyStats('g1').first;
    expect(onlineRows.single.seconds, 1200);

    final offlineRemote = _FakeStudyRepository()..failDailyStatsStream = true;
    final offlineRepo = OfflineFirstStudyRepository(
      remote: offlineRemote,
      cache: cache,
    );
    final offlineRows = await offlineRepo.watchGroupDailyStats('g1').first;

    expect(offlineRows.single.seconds, 1200);
  });

  test('repository providers now return offline-first wrappers', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(studyRepositoryProvider),
      isA<OfflineFirstStudyRepository>(),
    );
    expect(
      container.read(presenceRepositoryProvider),
      isA<OfflineFirstPresenceRepository>(),
    );
    expect(container.read(offlineCacheStoreProvider), isA<OfflineCacheStore>());
  });

  test(
    'presence write failure keeps latest value and flushes it later',
    () async {
      final cache = await _store();
      final remote = _FakePresenceRepository()..failWrites = true;
      final repo = OfflineFirstPresenceRepository(remote: remote, cache: cache);

      await repo.setPresence(_presence(PresenceStatus.studying));
      await repo.setPresence(_presence(PresenceStatus.offline));

      expect(remote.rows, isEmpty);
      expect(
        (await cache.readGroupPresence('g1'))!.single.status,
        PresenceStatus.offline,
      );
      expect(await cache.readPendingPresence(), hasLength(1));

      remote.failWrites = false;
      await repo.flushPending();

      expect(remote.rows.single.status, PresenceStatus.offline);
      expect(await cache.readPendingPresence(), isEmpty);
    },
  );

  test(
    'presence stream falls back to cached group rows after remote error',
    () async {
      final cache = await _store();
      final remote = _FakePresenceRepository()..failStream = true;
      final repo = OfflineFirstPresenceRepository(remote: remote, cache: cache);
      await cache.saveGroupPresence('g1', [_presence(PresenceStatus.studying)]);

      final rows = await repo.watchGroupPresence('g1').first;

      expect(rows.single.status, PresenceStatus.studying);
    },
  );
}

class _FakeStudyRepository implements StudyRepository {
  final sessions = <StudySession>[];
  var dailyStats = <DailyStat>[];
  bool failWrites = false;
  bool failUserSessionStream = false;
  bool failDailyStatsStream = false;

  @override
  Future<void> addSession(StudySession session) async {
    if (failWrites) throw StateError('offline');
    sessions.add(session);
  }

  @override
  Future<void> updateSession(StudySession session) async {
    if (failWrites) throw StateError('offline');
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index == -1) {
      sessions.add(session);
    } else {
      sessions[index] = session;
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if (failWrites) throw StateError('offline');
    sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Stream<List<StudySession>> watchUserSessions(String userId) async* {
    if (failUserSessionStream) throw StateError('offline');
    yield sessions.where((s) => s.userId == userId).toList();
  }

  @override
  Future<UserStudySummary> fetchUserStudySummary(String userId) async {
    final mine = sessions.where((s) => s.userId == userId);
    final sec = mine.fold<int>(0, (a, s) => a + s.durationSeconds);
    return UserStudySummary(
      lifetimeSeconds: sec,
      yearSeconds: sec,
      hotWindowSeconds: sec,
    );
  }

  @override
  Stream<List<StudySession>> watchGroupSessions(String groupId) {
    return Stream.value(const []);
  }

  @override
  Stream<List<DailyStat>> watchGroupDailyStats(String groupId) async* {
    if (failDailyStatsStream) throw StateError('offline');
    yield dailyStats;
  }
}

class _FakePresenceRepository implements PresenceRepository {
  final rows = <Presence>[];
  bool failWrites = false;
  bool failStream = false;

  @override
  Future<void> setPresence(Presence presence) async {
    if (failWrites) throw StateError('offline');
    rows.removeWhere((p) => p.userId == presence.userId);
    rows.add(presence);
  }

  @override
  Stream<List<Presence>> watchGroupPresence(String groupId) async* {
    if (failStream) throw StateError('offline');
    yield rows.where((p) => p.groupId == groupId).toList();
  }
}
