import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/observability/observability_service.dart';
import '../../../core/stats/session_window.dart';
import '../../models/daily_stat.dart';
import '../../models/study_session.dart';
import '../../models/user_study_summary.dart';
import '../study_repository.dart';
import 'offline_cache_store.dart';

/// WP-542: "yerel yazim bitince don, uzak turu arka planda surdur" yetenegi.
///
/// `StudyRepository` arayuzunun kendisine eklenemez: o dosya bu is paketinin
/// SAHIP yollarinda degil ve arayuze yeni uye eklemek TUM implementasyonlari
/// (in-memory, supabase, test sahteleri) kirar. Yetenek bu yuzden ayri bir
/// arayuzle tanimlanir; cagiran taraf `is` testiyle secer, desteklemeyen
/// repolarda eski (bloklayan) `addSession` yolu aynen kalir.
abstract interface class LocalFirstSessionWriter {
  /// Yalniz YEREL yazim (cache + yerel stream emit) bitene kadar bekler.
  /// Uzak gonderim arka planda surer; basarisiz olursa outbox'a kuyruklanir.
  Future<void> addSessionLocalFirst(StudySession session);
}

/// WP-542: kalici hata yuzunden kuyruktan dusurulen mutasyonun kaydi.
///
/// Kalici dead-letter deposu `OfflineCacheStore`'a yazilirdi ama o dosya bu is
/// paketinin SAHIP yollarinda degil; bu yuzden kayit surec omru boyunca
/// bellekte tutulur ve ayrica `ObservabilityService` ile raporlanir. Kuyrugun
/// sonsuza dek tikanmasindansa gorunur bir kayip tercih edilir.
class DeadLetteredStudyMutation {
  const DeadLetteredStudyMutation({
    required this.mutation,
    required this.errorType,
    required this.occurredAt,
  });

  final OfflineStudyMutation mutation;
  final String errorType;
  final DateTime occurredAt;
}

class OfflineFirstStudyRepository
    implements StudyRepository, LocalFirstSessionWriter {
  OfflineFirstStudyRepository({
    required StudyRepository remote,
    required OfflineCacheStore cache,
    Duration groupStatsReconnectDelay = const Duration(seconds: 2),
    Duration remoteDispatchTimeout = const Duration(seconds: 12),
  }) : this._(remote, cache, groupStatsReconnectDelay, remoteDispatchTimeout);

  OfflineFirstStudyRepository._(
    this._remote,
    this._cache,
    this._groupStatsReconnectDelay,
    this._remoteDispatchTimeout,
  );

  final StudyRepository _remote;
  final OfflineCacheStore _cache;
  final Duration _groupStatsReconnectDelay;

  /// WP-542: arka plana atilan uzak turun ust siniri. Zaman asimi KALICI bir
  /// hata degildir — mutasyon outbox'a alinir, baglanti donunce yeniden denenir.
  /// Sinir olmadan asili bir istek mutasyonu ne sunucuya ne de kuyruga koyardi.
  final Duration _remoteDispatchTimeout;

  bool _isFlushing = false;

  final List<DeadLetteredStudyMutation> _deadLetters = [];

  /// Kalici hata yuzunden kuyruktan dusurulen mutasyonlar (tani icin).
  List<DeadLetteredStudyMutation> get deadLetteredMutations =>
      List.unmodifiable(_deadLetters);

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
        } catch (error, stackTrace) {
          // WP-542: KALICI ile GECICI hatayi ayir.
          //
          // Eskiden ayrim yoktu: ilk hatada dongu kirilir, o kayit ve
          // ARKASINDAKI TUM kayitlar kuyrukta birakilirdi. Hata kaliciysa
          // (silinmis subject_id -> FK ihlali 23503, ya da
          // `study_sessions_time_order` / `study_sessions_duration_bound`
          // CHECK ihlali 23514) kuyruk SONSUZA DEK tikanir; kullanicinin
          // butun calisma suresi yalniz yerel cache'te birikir ve uygulama
          // silinince tamamen kaybolur.
          //
          // Kalici hatada tek kayit dusurulur (dead-letter + telemetri),
          // kuyrugun geri kalani akmaya devam eder. Gecici hatada (ag,
          // 5xx, zaman asimi) eski davranis aynen surer: dur ve sirayi koru.
          if (_isPermanentRemoteFailure(error)) {
            _recordDeadLetter(mutation, error, stackTrace);
            continue;
          }
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
    await _writeSessionLocally(session);
    await _dispatchAddSessionRemote(session);
  }

  /// WP-542: Durdur'a basildiginda kullanicinin bekledigi tek is YEREL yazimdir.
  ///
  /// Saha sikayeti: "Durdur'a basiyorum, sayac bir sure oylece duruyor." Sebep
  /// [addSession]'in uzak turu `await` etmesiydi; kotu agda TCP zaman asimina
  /// kadar (dakikalar) `_finish()` calismiyordu — Durdur dugmesi devre disi,
  /// FGS bildirimi/widget hala "calisiyor", presence hala `studying`.
  ///
  /// Burada uzak gonderim ateşle-unut'tur: hata/zaman asimi outbox'a duser,
  /// `flushPending` sonradan akitir. Kullanici icin durdurma anliktir.
  @override
  Future<void> addSessionLocalFirst(StudySession session) async {
    await _writeSessionLocally(session);
    unawaited(_dispatchAddSessionRemote(session));
  }

  Future<void> _writeSessionLocally(StudySession session) async {
    await _cache.upsertCachedSession(session);
    await _publishLocalUserSessions(session.userId);
  }

  Future<void> _dispatchAddSessionRemote(StudySession session) async {
    try {
      await Future(() async {
        await flushPending();
        await _remote.addSession(session);
      }).timeout(_remoteDispatchTimeout);
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

  /// WP-542: bu hata TEKRAR DENEYINCE de ayni sonucu verir mi?
  ///
  /// Kalici sayilanlar:
  ///   * SQLSTATE `23xxx` — butunluk ihlali (FK 23503, CHECK 23514, unique
  ///     23505). Ayni govde tekrar gonderilirse yine reddedilir.
  ///   * Postgrest'in `code` alanina yazdigi 4xx HTTP durumlari — istek
  ///     gecersiz/yetkisiz. 408 (timeout) ve 429 (rate limit) HARIC: onlar
  ///     gecicidir, sirayi bozmadan beklenmeli.
  /// Bunlarin disinda kalan her sey (ag, soket, 5xx, TimeoutException) gecici
  /// sayilir; kuyruk durur ve sira korunur.
  static bool _isPermanentRemoteFailure(Object error) {
    if (error is! PostgrestException) return false;
    final code = error.code;
    if (code == null || code.isEmpty) return false;
    if (code.length == 5 && code.startsWith('23')) return true;
    final status = int.tryParse(code);
    if (status == null) return false;
    if (status == 408 || status == 429) return false;
    return status >= 400 && status < 500;
  }

  void _recordDeadLetter(
    OfflineStudyMutation mutation,
    Object error,
    StackTrace stackTrace,
  ) {
    _deadLetters.add(
      DeadLetteredStudyMutation(
        mutation: mutation,
        errorType: error.runtimeType.toString(),
        occurredAt: DateTime.now(),
      ),
    );
    // Sessiz kayip yok: dusurulen her kayit telemetriye dusen bir hatadir.
    unawaited(
      ObservabilityService.instance.captureOperationFailure(
        operation: ObservabilityOperation.timer,
        error: error,
        stackTrace: stackTrace,
      ),
    );
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
