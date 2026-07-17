import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/stats/istanbul_calendar.dart';
import '../../../core/stats/session_window.dart';
import '../../../core/stats/study_stats.dart';
import '../../models/study_session.dart';
import '../../models/subject.dart';
import '../../models/user_study_summary.dart';
import '../data_export_repository.dart';

class SupabaseDataExportRepository implements DataExportRepository {
  SupabaseDataExportRepository(this._client);

  final SupabaseClient _client;
  static const _pageSize = 1000;

  @override
  Future<DataExportBundle> buildExport({
    required String userId,
    required DataExportRange range,
  }) async {
    // Self-only: RLS + explicit user_id filter.
    final profileRow = await _client
        .from('profiles')
        .select(
          'id, display_name, daily_goal_minutes, animal, monthly_report_opt_in, created_at',
        )
        .eq('id', userId)
        .maybeSingle();

    final subjectRows = await _client
        .from('subjects')
        .select()
        .eq('user_id', userId);
    final subjects = (subjectRows as List)
        .map((r) => Subject.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();

    final sessions = await _fetchSessions(userId, range);

    UserStudySummary? summary;
    try {
      final s = await _client.rpc(
        'get_user_study_summary',
        params: {'p_user_id': userId},
      );
      // Some deployments use auth.uid only — ignore shape mismatch.
      if (s is Map) {
        summary = UserStudySummary.fromMap(Map<String, dynamic>.from(s));
      }
    } catch (_) {
      // Fallback: summary optional.
    }

    List<Map<String, dynamic>> achievements = const [];
    try {
      final rows = await _client
          .from('user_achievements')
          .select('achievement_id, unlocked_at, progress')
          .eq('user_id', userId);
      achievements = [
        for (final r in (rows as List))
          Map<String, dynamic>.from(r as Map),
      ];
    } catch (_) {
      achievements = const [];
    }

    int? xp;
    try {
      final gp = await _client
          .from('gamification_profiles')
          .select('xp, crown_rank')
          .eq('user_id', userId)
          .maybeSingle();
      if (gp != null) {
        xp = (gp['xp'] as num?)?.toInt();
      }
    } catch (_) {}

    final payload = <String, dynamic>{
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'schema_version': 1,
      'user_id': userId,
      'profile': profileRow == null
          ? null
          : {
              'display_name': profileRow['display_name'],
              'daily_goal_minutes': profileRow['daily_goal_minutes'],
              'animal': profileRow['animal'],
              'monthly_report_opt_in': profileRow['monthly_report_opt_in'],
              'created_at': profileRow['created_at'],
            },
      'summary': summary?.toMap(),
      'xp': xp,
      'subjects': [for (final s in subjects) s.toMap()],
      'sessions': [for (final s in sessions) s.toMap()],
      'achievements': achievements,
      'range': range.name,
    };

    return DataExportBundle(
      payload: payload,
      sessionCount: sessions.length,
    );
  }

  Future<List<StudySession>> _fetchSessions(
    String userId,
    DataExportRange range,
  ) async {
    DateTime? gte;
    final now = DateTime.now();
    switch (range) {
      case DataExportRange.hot90:
        gte = sessionHotWindowStart(now: now);
      case DataExportRange.year:
        // Istanbul takvim yılı başlangıcı.
        gte = startOfYear(istanbulDay(now));
      case DataExportRange.all:
        gte = null;
    }

    final all = <StudySession>[];
    var from = 0;
    while (true) {
      final filter = _client.from('study_sessions').select().eq('user_id', userId);
      final withTime = gte == null
          ? filter
          : filter.gte('start_time', gte.toUtc().toIso8601String());
      final rows = await withTime
          .order('start_time', ascending: false)
          .range(from, from + _pageSize - 1);
      final batch = (rows as List)
          .map((r) => StudySession.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      all.addAll(batch);
      if (batch.length < _pageSize) break;
      from += _pageSize;
      if (from > 100000) break; // safety cap
    }
    return all;
  }
}
