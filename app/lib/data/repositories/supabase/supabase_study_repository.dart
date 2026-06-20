import 'package:supabase_flutter/supabase_flutter.dart';

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
}
