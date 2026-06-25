import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/daily_stat.dart';
import '../../models/study_session.dart';
import '../study_repository.dart';

/// Supabase tabanlı çalışma oturumu deposu. UI hiç değişmeden bellek-içi yerine geçer.
class SupabaseStudyRepository implements StudyRepository {
  SupabaseStudyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> addSession(StudySession session) async {
    await _client.from('study_sessions').insert(session.toMap());
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

  @override
  Stream<List<StudySession>> watchUserSessions(String userId) {
    return _client
        .from('study_sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('start_time', ascending: false)
        .map((rows) => rows.map(StudySession.fromMap).toList());
  }

  @override
  Stream<List<StudySession>> watchGroupSessions(String groupId) {
    return _client
        .from('study_sessions')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('start_time')
        .map((rows) => rows.map(StudySession.fromMap).toList());
  }

  /// Sunucuda toplanmış günlük veriyi `group_daily_totals` RPC'sinden çeker.
  Future<List<DailyStat>> _fetchDailyStats(String groupId) async {
    final rows = await _client.rpc(
      'group_daily_totals',
      params: {'p_group_id': groupId},
    ) as List<dynamic>;
    return rows
        .map((r) => DailyStat.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Stream<List<DailyStat>> watchGroupDailyStats(String groupId) {
    // Ham oturumları akıtmak yerine: RPC ile özet çek + study_sessions'taki
    // değişiklikleri hafif bir realtime kanalıyla dinleyip özeti tazele.
    // Böylece istemciye inen veri (üye × aktif gün) ile sınırlı kalır.
    late final StreamController<List<DailyStat>> controller;
    RealtimeChannel? channel;

    Future<void> refresh() async {
      try {
        if (!controller.isClosed) controller.add(await _fetchDailyStats(groupId));
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    controller = StreamController<List<DailyStat>>(
      onListen: () {
        refresh();
        channel = _client
            .channel('group_daily_$groupId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'study_sessions',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'group_id',
                value: groupId,
              ),
              callback: (_) => refresh(),
            )
            .subscribe();
      },
      onCancel: () async {
        if (channel != null) await _client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }
}
