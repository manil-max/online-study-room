import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/daily_stat.dart';
import '../../models/presence.dart';
import '../../models/study_session.dart';

class OfflineCacheStore {
  OfflineCacheStore(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'offline_cache_v1';
  static const _studyUsersKey = '$_prefix:study_users';
  static const _presenceGroupsKey = '$_prefix:presence_groups';
  static const _studyMutationsKey = '$_prefix:study_mutations';
  static const _pendingPresenceKey = '$_prefix:pending_presence';

  Future<List<StudySession>?> readUserSessions(String userId) async {
    final raw = _prefs.getString(_studyKey(userId));
    if (raw == null) return null;
    return _decodeList(raw).map(StudySession.fromMap).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
  }

  Future<void> saveUserSessions(
    String userId,
    List<StudySession> sessions,
  ) async {
    final sorted = sessions.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    await _prefs.setString(
      _studyKey(userId),
      jsonEncode(sorted.map((s) => s.toMap()).toList()),
    );
    await _addToStringList(_studyUsersKey, userId);
  }

  Future<void> upsertCachedSession(StudySession session) async {
    final current = await readUserSessions(session.userId) ?? const [];
    final next = [
      for (final item in current)
        if (item.id != session.id) item,
      session,
    ];
    await saveUserSessions(session.userId, next);
  }

  Future<void> removeCachedSession(String sessionId) async {
    final users = _prefs.getStringList(_studyUsersKey) ?? const [];
    for (final userId in users) {
      final current = await readUserSessions(userId);
      if (current == null) continue;
      final next = current.where((s) => s.id != sessionId).toList();
      if (next.length != current.length) {
        await saveUserSessions(userId, next);
      }
    }
  }

  Future<List<DailyStat>?> readGroupDailyStats(String groupId) async {
    final raw = _prefs.getString(_dailyStatsKey(groupId));
    if (raw == null) return null;
    return _decodeList(raw).map(DailyStat.fromMap).toList();
  }

  Future<void> saveGroupDailyStats(
    String groupId,
    List<DailyStat> stats,
  ) async {
    await _prefs.setString(
      _dailyStatsKey(groupId),
      jsonEncode(stats.map(_dailyStatToJson).toList()),
    );
  }

  Future<List<Presence>?> readGroupPresence(String groupId) async {
    final raw = _prefs.getString(_presenceKey(groupId));
    if (raw == null) return null;
    return _decodeList(raw).map(Presence.fromMap).toList();
  }

  Future<void> saveGroupPresence(String groupId, List<Presence> rows) async {
    await _prefs.setString(
      _presenceKey(groupId),
      jsonEncode(rows.map(_presenceToJson).toList()),
    );
    await _addToStringList(_presenceGroupsKey, groupId);
  }

  Future<void> upsertCachedPresence(Presence presence) async {
    final groupId = presence.groupId;
    if (groupId == null) return;
    final current = await readGroupPresence(groupId) ?? const [];
    final next = [
      for (final item in current)
        if (item.userId != presence.userId) item,
      presence,
    ];
    await saveGroupPresence(groupId, next);
  }

  Future<List<OfflineStudyMutation>> readPendingStudyMutations() async {
    final raw = _prefs.getString(_studyMutationsKey);
    if (raw == null) return const [];
    return _decodeList(raw).map(OfflineStudyMutation.fromJson).toList();
  }

  Future<void> replacePendingStudyMutations(
    List<OfflineStudyMutation> mutations,
  ) async {
    await _prefs.setString(
      _studyMutationsKey,
      jsonEncode(mutations.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> queueStudyMutation(OfflineStudyMutation mutation) async {
    final current = await readPendingStudyMutations();
    final id = mutation.sessionId;
    final existing = current.where((m) => m.sessionId == id).toList();
    final withoutSame = current.where((m) => m.sessionId != id).toList();
    final normalized = _coalesceStudyMutation(existing, mutation);
    await replacePendingStudyMutations([
      ...withoutSame,
      ...?(normalized == null ? null : <OfflineStudyMutation>[normalized]),
    ]);
  }

  Future<List<Presence>> readPendingPresence() async {
    final raw = _prefs.getString(_pendingPresenceKey);
    if (raw == null) return const [];
    return _decodeList(raw).map(Presence.fromMap).toList();
  }

  Future<void> queuePresence(Presence presence) async {
    final current = await readPendingPresence();
    final next = [
      for (final item in current)
        if (item.userId != presence.userId) item,
      presence,
    ];
    await _prefs.setString(
      _pendingPresenceKey,
      jsonEncode(next.map(_presenceToJson).toList()),
    );
  }

  Future<void> replacePendingPresence(List<Presence> rows) async {
    await _prefs.setString(
      _pendingPresenceKey,
      jsonEncode(rows.map(_presenceToJson).toList()),
    );
  }

  static OfflineStudyMutation? _coalesceStudyMutation(
    List<OfflineStudyMutation> existing,
    OfflineStudyMutation mutation,
  ) {
    final hadAdd = existing.any((m) => m.type == OfflineStudyMutationType.add);
    if (mutation.type == OfflineStudyMutationType.update && hadAdd) {
      return OfflineStudyMutation.add(mutation.session!);
    }
    if (mutation.type == OfflineStudyMutationType.delete && hadAdd) {
      // Henüz sunucuya ulaşmamış ekleme silindiyse uzaktaki dünyada hiçbir
      // işlem yoktur; gereksiz delete yerine outbox kaydını tamamen kaldır.
      return null;
    }
    return mutation;
  }

  Future<void> _addToStringList(String key, String value) async {
    final current = _prefs.getStringList(key) ?? const [];
    if (current.contains(value)) return;
    await _prefs.setStringList(key, [...current, value]);
  }

  static List<Map<String, dynamic>> _decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Map<String, dynamic> _dailyStatToJson(DailyStat stat) {
    return {
      'user_id': stat.userId,
      'day': stat.day.toIso8601String(),
      'seconds': stat.seconds,
    };
  }

  static Map<String, dynamic> _presenceToJson(Presence presence) {
    return {
      'user_id': presence.userId,
      'group_id': presence.groupId,
      'status': presence.status.name,
      'started_at': presence.startedAt?.toUtc().toIso8601String(),
      'today_seconds': presence.todaySeconds,
      'subject_id': presence.subjectId,
      'updated_at': presence.updatedAt?.toUtc().toIso8601String(),
    };
  }

  static String _studyKey(String userId) => '$_prefix:study:$userId';
  static String _dailyStatsKey(String groupId) => '$_prefix:daily:$groupId';
  static String _presenceKey(String groupId) => '$_prefix:presence:$groupId';
}

enum OfflineStudyMutationType { add, update, delete }

class OfflineStudyMutation {
  const OfflineStudyMutation._({
    required this.type,
    required this.sessionId,
    this.session,
  });

  factory OfflineStudyMutation.add(StudySession session) {
    return OfflineStudyMutation._(
      type: OfflineStudyMutationType.add,
      sessionId: session.id,
      session: session,
    );
  }

  factory OfflineStudyMutation.update(StudySession session) {
    return OfflineStudyMutation._(
      type: OfflineStudyMutationType.update,
      sessionId: session.id,
      session: session,
    );
  }

  factory OfflineStudyMutation.delete(String sessionId) {
    return OfflineStudyMutation._(
      type: OfflineStudyMutationType.delete,
      sessionId: sessionId,
    );
  }

  factory OfflineStudyMutation.fromJson(Map<String, dynamic> json) {
    final type = OfflineStudyMutationType.values.byName(json['type'] as String);
    final sessionJson = json['session'] as Map?;
    return OfflineStudyMutation._(
      type: type,
      sessionId: json['session_id'] as String,
      session: sessionJson == null
          ? null
          : StudySession.fromMap(Map<String, dynamic>.from(sessionJson)),
    );
  }

  final OfflineStudyMutationType type;
  final String sessionId;
  final StudySession? session;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'session_id': sessionId,
      'session': session?.toMap(),
    };
  }
}
