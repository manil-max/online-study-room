import 'dart:async';

import '../../models/study_session.dart';
import '../study_repository.dart';

/// Bellek-içi (kalıcı olmayan) çalışma oturumu deposu. Supabase'e kadar geçicidir.
class InMemoryStudyRepository implements StudyRepository {
  InMemoryStudyRepository();

  final List<StudySession> _sessions = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<StudySession> _userSessions(String userId) {
    final list = _sessions.where((s) => s.userId == userId).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return List.unmodifiable(list);
  }

  List<StudySession> _groupSessions(String groupId) {
    final list = _sessions.where((s) => s.groupId == groupId).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    return List.unmodifiable(list);
  }

  @override
  Future<void> addSession(StudySession session) async {
    _sessions.add(session);
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
  Stream<List<StudySession>> watchGroupSessions(String groupId) async* {
    yield _groupSessions(groupId);
    await for (final _ in _changes.stream) {
      yield _groupSessions(groupId);
    }
  }

  void dispose() => _changes.close();
}
