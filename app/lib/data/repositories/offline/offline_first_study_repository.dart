import 'dart:async';

import '../../../core/observability/observability_service.dart';
import '../../../core/stats/session_window.dart';
import '../../models/daily_stat.dart';
import '../../models/study_session.dart';
import '../../models/user_study_summary.dart';
import '../study_repository.dart';
import 'offline_cache_store.dart';

class OfflineFirstStudyRepository implements StudyRepository {
  OfflineFirstStudyRepository({
    required StudyRepository remote,
    required OfflineCacheStore cache,
    Duration groupStatsReconnectDelay = const Duration(seconds: 2),
  }) : this._(remote, cache, groupStatsReconnectDelay);

  OfflineFirstStudyRepository._(
    this._remote,
    this._cache,
    this._groupStatsReconnectDelay,
  );

  final StudyRepository _remote;
  final OfflineCacheStore _cache;
  final Duration _groupStatsReconnectDelay;
  bool _isFlushing = false;

  /// Aktif [watchUserSessions] dinleyicilerine mutation sonrası anında push.
  /// Realtime gecikse bile UI (bugün toplam, istatistik) cache gerçeğini görür.
  final Map<String, StreamController<List<StudySession>>> _sessionLocalHubs =
      {};

  @override
  Future<LiveStudyRun> startLiveRun({
    required String userId,
    required String clientRequestId,
    String? groupId,
    String? subjectId,
    int clientBuild = 0,
  }) => _remote.startLiveRun(
    userId: userId,
    clientRequestId: clientRequestId,
    groupId: groupId,
    subjectId: subjectId,
    clientBuild: clientBuild,
  );

  @override
  Future<LiveStudyRun> pauseLiveRun(String runToken) =>
      _remote.pauseLiveRun(runToken);

  @override
  Future<LiveStudyRun> resumeLiveRun(String runToken) =>
      _remote.resumeLiveRun(runToken);

  @override
  Future<StudySession> finalizeLiveRun(String runToken) =>
      _remote.finalizeLiveRun(runToken);

  @override
  Future<VerifiedSessionConfig> fetchVerifiedSessionConfig() =>
      _remote.fetchVerifiedSessionConfig();

  @override
  Future<void> recordVerifiedSessionRollout({
    required String platform,
    required int clientBuild,
    required bool capability,
    LiveStartOrigin? origin,
    LiveRolloutOutcome? outcome,
  }) => _remote.recordVerifiedSessionRollout(
    platform: platform,
    clientBuild: clientBuild,
    capability: capability,
    origin: origin,
    outcome: outcome,
  );

  Future<void> flushPending() async {
    if (_isFlushing) return;
    _isFlushing = true;
    final stopwatch = Stopwatch()..start();
    var pendingCount = 0;
    var appliedCount = 0;
    var remainingCount = 0;
    try {
      final pending = await _cache.readPendingStudyMutations();
      pendingCount = pending.length;
      final remaining = <OfflineStudyMutation>[];

      for (var i = 0; i < pending.length; i++) {
        final mutation = pending[i];
        try {
          await _applyMutation(mutation);
          appliedCount++;
        } catch (_) {
          remaining.addAll(pending.skip(i));
          break;
        }
      }

      await _cache.replacePendingStudyMutations(remaining);
      remainingCount = remaining.length;
    } finally {
      _isFlushing = false;
      if (pendingCount > 0) {
        ObservabilityService.instance.outboxFlush(
          pendingCount: pendingCount,
          appliedCount: appliedCount,
          remainingCount: remainingCount,
          elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        );
      }
    }
  }

  @override
  Future<void> addSession(StudySession session) async {
    await _cache.upsertCachedSession(session);
    await _publishLocalUserSessions(session.userId);
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
    await _publishLocalUserSessions(session.userId);
    try {
      await flushPending();
      await _remote.updateSession(session);
    } catch (_) {
      await _cache.queueStudyMutation(OfflineStudyMutation.update(session));
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final affectedUserIds = await _cache.removeCachedSession(sessionId);
    for (final userId in affectedUserIds) {
      await _publishLocalUserSessions(userId);
    }
    try {
      await flushPending();
      await _remote.deleteSession(sessionId);
    } catch (_) {
      await _cache.queueStudyMutation(OfflineStudyMutation.delete(sessionId));
    }
  }

  @override
  Stream<List<StudySession>> watchUserSessions(String userId) {
    // Controller, remote stream bitsin/kopsa bile local hub emit'lerini taşır;
    // böylece manuel oturum ekleme realtime beklemeden UI'ya yansır (H1).
    final controller = StreamController<List<StudySession>>();
    StreamSubscription<List<StudySession>>? remoteSub;
    StreamSubscription<List<StudySession>>? localSub;
    var active = true;

    Future<void> emitCached() async {
      final cached = await _cache.readUserSessions(userId);
      if (!active || controller.isClosed) return;
      if (cached != null) {
        controller.add(_hotOnly(cached));
      }
    }

    Future<void> start() async {
      await emitCached();
      if (!active || controller.isClosed) return;

      localSub = _sessionHub(userId).stream.listen((rows) {
        if (!controller.isClosed) controller.add(rows);
      });

      try {
        // Remote dinlemeyi bloklamasın: flush arka planda; ilk snapshot cache'ten
        // zaten gitti. Eski kod await flushPending() ile yavaş ağda watch'u kilitliyordu.
        unawaited(flushPending());
        final realtimeStopwatch = Stopwatch()..start();
        remoteSub = _remote
            .watchUserSessions(userId)
            .listen(
              (rows) async {
                final reconciled = _hotOnly(
                  await _reconcileRemoteSessions(rows),
                );
                final pendingCount =
                    (await _cache.readPendingStudyMutations()).length;
                ObservabilityService.instance.realtimeSnapshot(
                  sessionCount: reconciled.length,
                  pendingOutboxCount: pendingCount,
                  elapsedMilliseconds: realtimeStopwatch.elapsedMilliseconds,
                );
                realtimeStopwatch
                  ..reset()
                  ..start();
                await _cache.saveUserSessions(userId, reconciled);
                if (!controller.isClosed) controller.add(reconciled);
                unawaited(flushPending());
              },
              onError: (Object error, StackTrace stackTrace) async {
                final fallback = await _cache.readUserSessions(userId);
                ObservabilityService.instance.realtimeFallback(
                  hadCachedRows: fallback != null,
                );
                if (controller.isClosed) return;
                if (fallback != null) {
                  controller.add(_hotOnly(fallback));
                } else {
                  controller.addError(error, stackTrace);
                }
              },
            );
      } catch (error, stackTrace) {
        final fallback = await _cache.readUserSessions(userId);
        ObservabilityService.instance.realtimeFallback(
          hadCachedRows: fallback != null,
        );
        if (controller.isClosed) return;
        if (fallback != null) {
          controller.add(_hotOnly(fallback));
        } else {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller
      ..onListen = () {
        unawaited(start());
      }
      ..onCancel = () async {
        active = false;
        await remoteSub?.cancel();
        await localSub?.cancel();
      };

    return controller.stream;
  }

  @override
  Future<UserStudySummary> fetchUserStudySummary(String userId) {
    return _remote.fetchUserStudySummary(userId);
  }

  List<StudySession> _hotOnly(List<StudySession> rows) {
    return filterHotWindowSessions(rows, startOf: (s) => s.start);
  }

  @override
  Stream<List<StudySession>> watchGroupSessions(String groupId) {
    return _remote.watchGroupSessions(groupId);
  }

  @override
  Stream<List<DailyStat>> watchGroupDailyStats(String groupId) async* {
    final cached = await _cache.readGroupDailyStats(groupId);
    if (cached != null) yield cached;

    while (true) {
      try {
        unawaited(flushPending());
        await for (final rows in _remote.watchGroupDailyStats(groupId)) {
          await _cache.saveGroupDailyStats(groupId, rows);
          yield rows;
          unawaited(flushPending());
        }
        return;
      } catch (error, stackTrace) {
        final fallback = await _cache.readGroupDailyStats(groupId);
        if (fallback == null) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        // Realtime/RPC anlık kesilirse dashboard eski ama doğru cache'i tutar.
        // Önceki akış bu noktada bittiği için bağlantı geri geldiğinde ikinci
        // cihazdaki yeni toplam hiç görünmüyordu. Kontrollü tekrar dinleme,
        // cache yoksa hatayı gizlemeden yalnız güvenli fallback'te yapılır.
        yield fallback;
        await Future<void>.delayed(_groupStatsReconnectDelay);
      }
    }
  }

  StreamController<List<StudySession>> _sessionHub(String userId) {
    return _sessionLocalHubs.putIfAbsent(
      userId,
      () => StreamController<List<StudySession>>.broadcast(),
    );
  }

  Future<void> _publishLocalUserSessions(String userId) async {
    final hub = _sessionLocalHubs[userId];
    if (hub == null || hub.isClosed || !hub.hasListener) return;
    final cached =
        await _cache.readUserSessions(userId) ?? const <StudySession>[];
    if (!hub.isClosed) {
      hub.add(_hotOnly(cached));
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
    return _hotOnly(rows);
  }
}
