import 'dart:async';

import '../../../core/stats/session_window.dart';
import '../../models/daily_stat.dart';
import '../../models/study_session.dart';
import '../../models/user_study_summary.dart';
import '../study_repository.dart';

/// Bellek-içi (kalıcı olmayan) çalışma oturumu deposu. Supabase'e kadar geçicidir.
class InMemoryStudyRepository implements StudyRepository {
  InMemoryStudyRepository();

  final List<StudySession> _sessions = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<StudySession> _userSessions(String userId) {
    final list = _sessions
        .where(
          (s) =>
              s.userId == userId && isSessionInHotWindow(s.start),
        )
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
      _sessions[i] = session;
      _changes.add(null);
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
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
