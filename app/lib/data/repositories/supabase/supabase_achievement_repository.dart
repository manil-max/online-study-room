import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/achievement_ledger.dart';
import '../../models/achievement_metric_progress.dart';
import '../../models/study_session.dart';
import '../achievement_repository.dart';

class SupabaseAchievementRepository implements AchievementRepository {
  SupabaseAchievementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AchievementDictEntry>> fetchDictionary() async {
    final rows = await _client.from('achievements_dict').select().order('id');
    return (rows as List)
        .map(
          (e) =>
              AchievementDictEntry.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  @override
  Future<List<AchievementMetricProgress>> fetchMetricProgress(
    String userId,
  ) async {
    final rows = await _client
        .from('achievement_metric_progress')
        .select()
        .eq('user_id', userId)
        .order('achievement_id');
    return rows
        .map(
          (row) =>
              AchievementMetricProgress.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  @override
  Stream<List<AchievementMetricProgress>> watchMetricProgress(String userId) {
    return _client
        .from('achievement_metric_progress')
        .stream(primaryKey: ['user_id', 'achievement_id'])
        .eq('user_id', userId)
        .order('achievement_id')
        .map(
          (rows) => rows
              .map(AchievementMetricProgress.fromMap)
              .toList(growable: false),
        );
  }

  @override
  Future<AchievementEventResult> processEvent({
    required String eventType,
    Map<String, dynamic> payload = const {},
    List<StudySession> sessions = const [],
    int dailyGoalMinutes = 360,
    String? userId,
    DateTime? evaluationTime,
  }) async {
    // Oturum metrikleri sunucuda; sessions istemciden gönderilmez.
    final raw = await _client.rpc(
      'process_achievement_event',
      params: {'p_event_type': eventType, 'p_payload': payload},
    );
    if (raw is Map) {
      return AchievementEventResult.fromMap(Map<String, dynamic>.from(raw));
    }
    return AchievementEventResult(
      eventType: eventType,
      awarded: const [],
      totalXp: 0,
      crownRank: 'bronze_beginner',
    );
  }
}
