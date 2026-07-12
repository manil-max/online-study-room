import 'dart:async';

import '../../models/daily_stat.dart';
import '../../models/study_session.dart';
import '../study_repository.dart';
import 'offline_cache_store.dart';

class OfflineFirstStudyRepository implements StudyRepository {
  OfflineFirstStudyRepository({
    required StudyRepository remote,
    required OfflineCacheStore cache,
  }) : this._(remote, cache);

  OfflineFirstStudyRepository._(this._remote, this._cache);

  final StudyRepository _remote;
  final OfflineCacheStore _cache;
  bool _isFlushing = false;

  Future<void> flushPending() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      final pending = await _cache.readPendingStudyMutations();
      final remaining = <OfflineStudyMutation>[];

      for (var i = 0; i < pending.length; i++) {
        final mutation = pending[i];
        try {
          await _applyMutation(mutation);
        } catch (_) {
          remaining.addAll(pending.skip(i));
          break;
        }
      }

      await _cache.replacePendingStudyMutations(remaining);
    } finally {
      _isFlushing = false;
    }
  }

  @override
  Future<void> addSession(StudySession session) async {
    await _cache.upsertCachedSession(session);
    try {
      await flushPending();
      await _remote.addSession(session);
    } catch (_) {
      await _cache.queueStudyMutation(OfflineStudyMutation.add(session));
    }
  }

  @override
  Future<void> updateSession(StudySession session) async {
    await _cache.upsertCachedSession(session);
    try {
      await flushPending();
      await _remote.updateSession(session);
    } catch (_) {
      await _cache.queueStudyMutation(OfflineStudyMutation.update(session));
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _cache.removeCachedSession(sessionId);
    try {
      await flushPending();
      await _remote.deleteSession(sessionId);
    } catch (_) {
      await _cache.queueStudyMutation(OfflineStudyMutation.delete(sessionId));
    }
  }

  @override
  Stream<List<StudySession>> watchUserSessions(String userId) async* {
    final cached = await _cache.readUserSessions(userId);
    if (cached != null) yield cached;

    try {
      await flushPending();
      await for (final rows in _remote.watchUserSessions(userId)) {
        // Realtime snapshot gecikmiş olsa bile yerel outbox'taki değişiklikleri
        // ezemez; flush tamamlanana kadar ikisini geçici canonical listede birleştir.
        final reconciled = await _reconcileRemoteSessions(rows);
        await _cache.saveUserSessions(userId, reconciled);
        yield reconciled;
        unawaited(flushPending());
      }
    } catch (error, stackTrace) {
      final fallback = await _cache.readUserSessions(userId);
      if (fallback != null) {
        yield fallback;
      } else {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  @override
  Stream<List<StudySession>> watchGroupSessions(String groupId) {
    return _remote.watchGroupSessions(groupId);
  }

  @override
  Stream<List<DailyStat>> watchGroupDailyStats(String groupId) async* {
    final cached = await _cache.readGroupDailyStats(groupId);
    if (cached != null) yield cached;

    try {
      await flushPending();
      await for (final rows in _remote.watchGroupDailyStats(groupId)) {
        await _cache.saveGroupDailyStats(groupId, rows);
        yield rows;
        unawaited(flushPending());
      }
    } catch (error, stackTrace) {
      final fallback = await _cache.readGroupDailyStats(groupId);
      if (fallback != null) {
        yield fallback;
      } else {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  Future<void> _applyMutation(OfflineStudyMutation mutation) {
    return switch (mutation.type) {
      OfflineStudyMutationType.add => _remote.addSession(mutation.session!),
      OfflineStudyMutationType.update => _remote.updateSession(
        mutation.session!,
      ),
      OfflineStudyMutationType.delete => _remote.deleteSession(
        mutation.sessionId,
      ),
    };
  }

  Future<List<StudySession>> _reconcileRemoteSessions(
    List<StudySession> remoteRows,
  ) async {
    final byId = {for (final session in remoteRows) session.id: session};
    for (final mutation in await _cache.readPendingStudyMutations()) {
      switch (mutation.type) {
        case OfflineStudyMutationType.add:
        case OfflineStudyMutationType.update:
          byId[mutation.sessionId] = mutation.session!;
        case OfflineStudyMutationType.delete:
          byId.remove(mutation.sessionId);
      }
    }
    final rows = byId.values.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return rows;
  }
}
