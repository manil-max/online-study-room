import '../models/achievement_ledger.dart';
import '../models/study_session.dart';

/// Server-authoritative başarım API'si (WP-56).
/// İstemci XP yazmaz; yalnız olay fırlatır / sözlük okur.
abstract class AchievementRepository {
  /// `achievements_dict` sözlüğü (statik seed).
  Future<List<AchievementDictEntry>> fetchDictionary();

  /// Sunucu RPC `process_achievement_event` (veya in_memory eşdeğeri).
  /// [sessions] yalnız in_memory yolu için gerekli; Supabase sunucuda hesaplar.
  Future<AchievementEventResult> processEvent({
    required String eventType,
    Map<String, dynamic> payload,
    List<StudySession> sessions,
    int dailyGoalMinutes,
    String? userId,
  });
}
