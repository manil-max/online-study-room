import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/stats/session_window.dart';
import '../../models/daily_stat.dart';
import '../../models/study_session.dart';
import '../../models/user_study_summary.dart';
import '../study_repository.dart';

/// Bellek-içi (kalıcı olmayan) çalışma oturumu deposu. Supabase'e kadar geçicidir.
class InMemoryStudyRepository implements StudyRepository {
  InMemoryStudyRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final List<StudySession> _sessions = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final DateTime Function() _now;
  final Uuid _uuid = const Uuid();
  final Map<String, LiveStudyRun> _runs = {};
  final Map<String, String> _requestRuns = {};
  final Map<String, List<_MemoryLiveSegment>> _segments = {};
  final Set<String> _memberships = {};
  final Set<String> _ownedSubjects = {};

  VerifiedSessionConfig verifiedSessionConfig =
      const VerifiedSessionConfig.shadow();
  final List<
    ({
      String platform,
      int clientBuild,
      bool capability,
      LiveStartOrigin? origin,
      LiveRolloutOutcome? outcome,
    })
  >
  rolloutEvents = [];

  void registerGroupMembership(String userId, String groupId) {
    _memberships.add('$userId:$groupId');
  }

  void registerOwnedSubject(String userId, String subjectId) {
    _ownedSubjects.add('$userId:$subjectId');
  }

  LiveStudyRun _replaceRun(
    LiveStudyRun run, {
    required LiveRunStatus status,
    DateTime? finalizedAt,
    String? sessionId,
  }) {
    final next = LiveStudyRun(
      id: run.id,
      runToken: run.runToken,
      userId: run.userId,
      groupIdSnapshot: run.groupIdSnapshot,
      subjectIdSnapshot: run.subjectIdSnapshot,
      status: status,
      clientBuild: run.clientBuild,
      startedAt: run.startedAt,
      finalizedAt: finalizedAt ?? run.finalizedAt,
      sessionId: sessionId ?? run.sessionId,
    );
    _runs[run.id] = next;
    return next;
  }

  LiveStudyRun _runForToken(String runToken) {
    return _runs.values.firstWhere(
      (run) => run.runToken == runToken,
      orElse: () => throw StateError('live_run_not_found'),
    );
  }

  @override
  Future<LiveStudyRun> startLiveRun({
    required String userId,
    required String clientRequestId,
    String? groupId,
    String? subjectId,
    int clientBuild = 0,
  }) async {
    final requestKey = '$userId:$clientRequestId';
    final existingId = _requestRuns[requestKey];
    if (existingId != null) return _runs[existingId]!;
    if (_runs.values.any(
      (run) =>
          run.userId == userId &&
          (run.status == LiveRunStatus.running ||
              run.status == LiveRunStatus.paused),
    )) {
      throw StateError('active_live_run_exists');
    }
    if (groupId != null && !_memberships.contains('$userId:$groupId')) {
      throw StateError('group_membership_required');
    }
    if (subjectId != null && !_ownedSubjects.contains('$userId:$subjectId')) {
      throw StateError('subject_ownership_required');
    }
    if (clientBuild < 0) throw ArgumentError.value(clientBuild, 'clientBuild');

    final now = _now().toUtc();
    final run = LiveStudyRun(
      id: _uuid.v4(),
      runToken: _uuid.v4(),
      userId: userId,
      groupIdSnapshot: groupId,
      subjectIdSnapshot: subjectId,
      status: LiveRunStatus.running,
      clientBuild: clientBuild,
      startedAt: now,
    );
    _runs[run.id] = run;
    _requestRuns[requestKey] = run.id;
    _segments[run.id] = [_MemoryLiveSegment(now)];
    return run;
  }

  @override
  Future<LiveStudyRun> pauseLiveRun(String runToken) async {
    final run = _runForToken(runToken);
    if (run.status == LiveRunStatus.paused) return run;
    if (run.status != LiveRunStatus.running) {
      throw StateError('live_run_not_active');
    }
    _segments[run.id]!.last.endedAt = _now().toUtc();
    return _replaceRun(run, status: LiveRunStatus.paused);
  }

  @override
  Future<LiveStudyRun> resumeLiveRun(String runToken) async {
    final run = _runForToken(runToken);
    if (run.status == LiveRunStatus.running) return run;
    if (run.status != LiveRunStatus.paused) {
      throw StateError('live_run_not_active');
    }
    _segments[run.id]!.add(_MemoryLiveSegment(_now().toUtc()));
    return _replaceRun(run, status: LiveRunStatus.running);
  }

  @override
  Future<StudySession> finalizeLiveRun(String runToken) async {
    var run = _runForToken(runToken);
    if (run.status == LiveRunStatus.finalized) {
      return _sessions.firstWhere((session) => session.id == run.sessionId);
    }
    if (run.status != LiveRunStatus.running &&
        run.status != LiveRunStatus.paused) {
      throw StateError('live_run_not_active');
    }
    final now = _now().toUtc();
    final segments = _segments[run.id]!;
    if (segments.last.endedAt == null) segments.last.endedAt = now;
    final duration = segments.fold<int>(
      0,
      (total, segment) =>
          total + segment.endedAt!.difference(segment.startedAt).inSeconds,
    );
    final session = StudySession(
      id: run.id,
      userId: run.userId,
      subjectId: run.subjectIdSnapshot,
      start: run.startedAt,
      end: now,
      durationSeconds: duration,
      source: StudySource.live,
      liveRunId: run.id,
    );
    _sessions.add(session);
    run = _replaceRun(
      run,
      status: LiveRunStatus.finalized,
      finalizedAt: now,
      sessionId: session.id,
    );
    _changes.add(null);
    return session;
  }

  @override
  Future<VerifiedSessionConfig> fetchVerifiedSessionConfig() async =>
      verifiedSessionConfig;

  @override
  Future<void> recordVerifiedSessionRollout({
    required String platform,
    required int clientBuild,
    required bool capability,
    LiveStartOrigin? origin,
    LiveRolloutOutcome? outcome,
  }) async {
    rolloutEvents.add((
      platform: platform,
      clientBuild: clientBuild,
      capability: capability,
      origin: origin,
      outcome: outcome,
    ));
  }

  List<StudySession> _userSessions(String userId) {
    final list =
        _sessions
            .where((s) => s.userId == userId && isSessionInHotWindow(s.start))
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    return List.unmodifiable(list);
  }

  List<StudySession> _allUserSessions(String userId) {
    final list = _sessions.where((s) => s.userId == userId).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return list;
  }

  @override
  Future<void> addSession(StudySession session) async {
    if (session.isVerified) {
      throw StateError('verified_session_requires_server');
    }
    final index = _sessions.indexWhere((item) => item.id == session.id);
    if (index == -1) {
      _sessions.add(session);
    } else {
      _sessions[index] = session;
    }
    _changes.add(null);
  }

  @override
  Future<void> updateSession(StudySession session) async {
    final i = _sessions.indexWhere((s) => s.id == session.id);
    if (i != -1) {
      if (_sessions[i].isVerified || session.isVerified) {
        throw StateError('verified_session_immutable');
      }
      _sessions[i] = session;
      _changes.add(null);
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if (_sessions.any((s) => s.id == sessionId && s.isVerified)) {
      throw StateError('verified_session_immutable');
    }
    _sessions.removeWhere((s) => s.id == sessionId);
    _changes.add(null);
  }

  @override
  Stream<List<StudySession>> watchUserSessions(String userId) async* {
    yield _userSessions(userId);
    await for (final _ in _changes.stream) {
      yield _userSessions(userId);
    }
  }

  @override
  Future<UserStudySummary> fetchUserStudySummary(String userId) async {
    final all = _allUserSessions(userId);
    final now = DateTime.now();
    final yearStart = DateTime(now.year);
    final hotStart = sessionHotWindowStart(now: now);
    var lifetime = 0;
    var year = 0;
    var hot = 0;
    for (final s in all) {
      lifetime += s.durationSeconds;
      if (!s.start.isBefore(yearStart)) year += s.durationSeconds;
      if (!s.start.isBefore(hotStart)) hot += s.durationSeconds;
    }
    return UserStudySummary(
      lifetimeSeconds: lifetime,
      yearSeconds: year,
      hotWindowSeconds: hot,
    );
  }

  @override
  Stream<List<StudySession>> watchGroupSessions(String groupId) async* {
    // group_id sütunu kaldırıldı (K4). Bu metot artık kullanılmıyor;
    // arayüz uyumluluğu için boş liste döndürüyoruz.
    yield const [];
  }

  /// Tüm oturumları (userId, gün) bazında toplar — Supabase RPC'sinin
  /// bellek-içi karşılığı. Demo modda tüm oturumlar görünür.
  List<DailyStat> _groupDailyStats(String groupId) {
    // Bellek-içi modda group_members bilgisi yok; tüm oturumları topla.
    final totals = <String, Map<DateTime, int>>{};
    for (final s in _sessions) {
      (totals[s.userId] ??= {}).update(
        s.day,
        (v) => v + s.durationSeconds,
        ifAbsent: () => s.durationSeconds,
      );
    }
    return [
      for (final user in totals.entries)
        for (final day in user.value.entries)
          DailyStat(userId: user.key, day: day.key, seconds: day.value),
    ];
  }

  @override
  Stream<List<DailyStat>> watchGroupDailyStats(String groupId) async* {
    yield _groupDailyStats(groupId);
    await for (final _ in _changes.stream) {
      yield _groupDailyStats(groupId);
    }
  }

  void dispose() => _changes.close();
}

class _MemoryLiveSegment {
  _MemoryLiveSegment(this.startedAt);

  final DateTime startedAt;
  DateTime? endedAt;
}
