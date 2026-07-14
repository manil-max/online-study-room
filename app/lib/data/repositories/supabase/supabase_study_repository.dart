import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/stats/session_window.dart';
import '../../models/daily_stat.dart';
import '../../models/study_session.dart';
import '../../models/user_study_summary.dart';
import '../study_repository.dart';

/// Supabase tabanlı çalışma oturumu deposu. UI hiç değişmeden bellek-içi yerine geçer.
class SupabaseStudyRepository implements StudyRepository {
  SupabaseStudyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> addSession(StudySession session) async {
    // Oturum id'si istemcide üretilen idempotency anahtarıdır. Ağ cevabı
    // kaybolup outbox tekrar denendiğinde aynı oturum ikinci kez eklenmez.
    await _client
        .from('study_sessions')
        .upsert(session.toMap(), onConflict: 'id');
  }

  @override
  Future<void> updateSession(StudySession session) async {
    await _client
        .from('study_sessions')
        .update(session.toMap())
        .eq('id', session.id);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _client.from('study_sessions').delete().eq('id', sessionId);
  }

  Future<List<StudySession>> _fetchHotWindowSessions(String userId) async {
    final cutoff = sessionHotWindowStart().toUtc().toIso8601String();
    final rows = await _client
        .from('study_sessions')
        .select()
        .eq('user_id', userId)
        .gte('start_time', cutoff)
        .order('start_time', ascending: false);
    return (rows as List<dynamic>)
        .map((r) => StudySession.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Stream<List<StudySession>> watchUserSessions(String userId) {
    // Sıcak pencere (90g): select + kullanıcı filtreli realtime yenileme.
    // Tüm geçmişi stream ile indirmez → RAM/CPU (OPT N2).
    late final StreamController<List<StudySession>> controller;
    RealtimeChannel? channel;
    Timer? debounce;
    var refreshSeq = 0;

    Future<void> refresh() async {
      final seq = ++refreshSeq;
      try {
        final rows = await _fetchHotWindowSessions(userId);
        if (!controller.isClosed && seq == refreshSeq) {
          controller.add(rows);
        }
      } catch (e, st) {
        if (!controller.isClosed && seq == refreshSeq) {
          controller.addError(e, st);
        }
      }
    }

    void scheduleRefresh() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 400), () {
        unawaited(refresh());
      });
    }

    controller = StreamController<List<StudySession>>(
      onListen: () {
        unawaited(refresh());
        channel = _client
            .channel('user_sessions_hot_$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'study_sessions',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (_) => scheduleRefresh(),
            )
            .subscribe();
      },
      onCancel: () async {
        debounce?.cancel();
        if (channel != null) await _client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }

  @override
  Future<UserStudySummary> fetchUserStudySummary(String userId) async {
    try {
      final raw = await _client.rpc(
        'user_study_summary',
        params: {'p_user_id': userId},
      );
      if (raw is Map) {
        return UserStudySummary.fromMap(Map<String, dynamic>.from(raw));
      }
    } catch (_) {
      // RPC henüz deploy edilmemişse sıcak pencereden kaba özet.
    }
    final hot = await _fetchHotWindowSessions(userId);
    final hotSec = hot.fold<int>(0, (a, s) => a + s.durationSeconds);
    final yearStart = DateTime(DateTime.now().year);
    final yearSec = hot
        .where((s) => !s.start.isBefore(yearStart))
        .fold<int>(0, (a, s) => a + s.durationSeconds);
    return UserStudySummary(
      lifetimeSeconds: hotSec,
      yearSeconds: yearSec,
      hotWindowSeconds: hotSec,
    );
  }

  @override
  Stream<List<StudySession>> watchGroupSessions(String groupId) {
    // group_id sütunu kaldırıldı (0010). Bu metot artık kullanılmıyor
    // (UI/provider'da çağıran yok — K4 kararı). Arayüz uyumluluğu için
    // boş stream döndürüyoruz. İleride üyelik tabanlı sorguya geçilebilir.
    return Stream.value(const []);
  }

  /// Sunucuda toplanmış günlük veriyi `group_daily_totals` RPC'sinden çeker.
  Future<List<DailyStat>> _fetchDailyStats(String groupId) async {
    final rows =
        await _client.rpc('group_daily_totals', params: {'p_group_id': groupId})
            as List<dynamic>;
    return rows
        .map((r) => DailyStat.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Stream<List<DailyStat>> watchGroupDailyStats(String groupId) {
    // group_id sütunu kaldırıldı (0010). Realtime filtre artık group_id'ye
    // dayanamaz; tüm study_sessions değişikliklerinde RPC'yi yeniden çağırırız
    // (RPC zaten group_id parametresiyle sunucuda süzüyor — K6 kararı).
    // OPT N1: debounce — her satır değişiminde tam RPC fırtınasını keser.
    late final StreamController<List<DailyStat>> controller;
    RealtimeChannel? channel;
    Timer? debounce;
    var refreshSeq = 0;

    Future<void> refresh() async {
      final seq = ++refreshSeq;
      try {
        final stats = await _fetchDailyStats(groupId);
        if (!controller.isClosed && seq == refreshSeq) {
          controller.add(stats);
        }
      } catch (e, st) {
        if (!controller.isClosed && seq == refreshSeq) {
          controller.addError(e, st);
        }
      }
    }

    void scheduleRefresh() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 900), () {
        unawaited(refresh());
      });
    }

    controller = StreamController<List<DailyStat>>(
      onListen: () {
        unawaited(refresh());
        channel = _client
            .channel('group_daily_$groupId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'study_sessions',
              callback: (_) => scheduleRefresh(),
            )
            .subscribe();
      },
      onCancel: () async {
        debounce?.cancel();
        if (channel != null) await _client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }
}
