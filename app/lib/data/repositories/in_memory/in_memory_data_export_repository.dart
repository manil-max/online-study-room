import '../../../core/stats/istanbul_calendar.dart';
import '../../../core/stats/session_window.dart';
import '../../../core/stats/study_stats.dart';
import '../../models/study_session.dart';
import '../../models/subject.dart';
import '../../models/user_study_summary.dart';
import '../data_export_repository.dart';

/// Demo/test: seed ile doldurulur. Başka userId için boş.
class InMemoryDataExportRepository implements DataExportRepository {
  final Map<String, Map<String, dynamic>> profiles = {};
  final Map<String, List<StudySession>> sessions = {};
  final Map<String, List<Subject>> subjects = {};
  final Map<String, UserStudySummary> summaries = {};
  final Map<String, List<Map<String, dynamic>>> achievements = {};
  final Map<String, int> xpByUser = {};

  void seed({
    required String userId,
    Map<String, dynamic>? profile,
    List<StudySession> sessionList = const [],
    List<Subject> subjectList = const [],
    UserStudySummary? summary,
    List<Map<String, dynamic>> achievementList = const [],
    int xp = 0,
  }) {
    if (profile != null) profiles[userId] = profile;
    sessions[userId] = List.of(sessionList);
    subjects[userId] = List.of(subjectList);
    if (summary != null) summaries[userId] = summary;
    achievements[userId] = List.of(achievementList);
    xpByUser[userId] = xp;
  }

  @override
  Future<DataExportBundle> buildExport({
    required String userId,
    required DataExportRange range,
  }) async {
    final allSessions = sessions[userId] ?? const [];
    final now = DateTime.now();
    // Istanbul takvim yılı (cihaz TZ kayması / yılbaşı kenarı).
    final yearStart = startOfYear(istanbulDay(now));
    final filtered = switch (range) {
      DataExportRange.hot90 => allSessions
          .where((s) => isSessionInHotWindow(s.start, now: now))
          .toList(),
      DataExportRange.year => allSessions
          .where((s) => !dayOf(s.start).isBefore(yearStart))
          .toList(),
      DataExportRange.all => List.of(allSessions),
    };

    // Portability payload: e-posta / token yok; yalnız self aggregate + self sessions.
    final safeProfile = _sanitizeProfile(profiles[userId]);
    final payload = <String, dynamic>{
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'schema_version': 1,
      'user_id': userId,
      'profile': safeProfile,
      'summary': summaries[userId]?.toMap(),
      'xp': xpByUser[userId],
      'subjects': [for (final s in subjects[userId] ?? const []) s.toMap()],
      'sessions': [for (final s in filtered) s.toMap()],
      'achievements': achievements[userId] ?? const [],
      'range': range.name,
    };

    return DataExportBundle(
      payload: payload,
      sessionCount: filtered.length,
    );
  }

  /// E-posta, token ve bilinmeyen gizli alanları dışarı sızdırma.
  static Map<String, dynamic>? _sanitizeProfile(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    const allow = {
      'display_name',
      'daily_goal_minutes',
      'animal',
      'monthly_report_opt_in',
      'created_at',
      'id',
    };
    return {
      for (final e in raw.entries)
        if (allow.contains(e.key)) e.key: e.value,
    };
  }
}
