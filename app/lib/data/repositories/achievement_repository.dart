import '../models/achievement_ledger.dart';
import '../models/achievement_metric_progress.dart';
import '../models/study_session.dart';

/// Server-authoritative başarım API'si (WP-56).
/// İstemci XP yazmaz; yalnız olay fırlatır / sözlük okur.
abstract class AchievementRepository {
  /// `achievements_dict` sözlüğü (statik seed).
  Future<List<AchievementDictEntry>> fetchDictionary();

  /// Private real-metric projection. Supabase RLS still enforces auth.uid().
  Future<List<AchievementMetricProgress>> fetchMetricProgress(String userId);

  Stream<List<AchievementMetricProgress>> watchMetricProgress(String userId);

  /// Sunucu RPC `process_achievement_event` (veya in_memory eşdeğeri).
  /// [sessions] yalnız in_memory yolu için gerekli; Supabase sunucuda hesaplar.
  Future<AchievementEventResult> processEvent({
    required String eventType,
    Map<String, dynamic> payload,
    List<StudySession> sessions,
    int dailyGoalMinutes,
    String? userId,
    DateTime? evaluationTime,
  });
}
